import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'ai_service.dart';

class AnthropicAiService implements AiService {
  final _client = http.Client();

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  static const _mealSystemPrompt = '''
You are a meal-logging assistant. Parse the user's meal description (text and/or photo) and return ONLY valid JSON with no markdown, no explanation.

If the input begins with a "Recent meals:" section, use it only as context to resolve temporal references (e.g. "leftovers from last night", "same as yesterday", "the usual"). Extract food items from the current meal description that follows — not from the history block. Do not repeat or list historical entries as new food items.

Return this exact structure:
{
  "title": "string",
  "foods": [
    {
      "name": "string",
      "portion": "string or null",
      "prep": "string or null",
      "calories": number or null,
      "protein": number or null,
      "carbs": number or null,
      "fat": number or null,
      "ingredients": ["string", ...],
      "notes": "string or null"
    }
  ]
}

Guidelines:
- title: short descriptive name for the overall meal (e.g. "Grilled Salmon with Asparagus", "Avocado Toast"). Use the meal type provided as context but make it descriptive, not just "Breakfast" or "Lunch".
- Estimate calories and macros (protein/carbs/fat in grams) where possible; use null if truly unknown
- Extract ingredients as simple item names (e.g. "olive oil", "feta cheese")
- portion: describe size/weight/volume (e.g. "1 medium", "~5 oz", "2 tbsp")
- prep: cooking method and seasonings (e.g. "baked with honey", "sautéed in olive oil")
''';

  static const _medicationSystemPrompt = '''
You are a medication-logging assistant. Parse the user's description (text and/or photo) and return ONLY valid JSON with no markdown, no explanation.

Return this exact structure:
{
  "name": "string",
  "dose": number or null,
  "unit": "mg" | "g" | "mL" | "mcg" | "tablets" | "capsules" | "other" | null,
  "route": "oral" | "topical" | "inhaled" | "sublingual" | "IV" | "other" | null,
  "notes": "string or null"
}

Guidelines:
- name: the medication or supplement name exactly as stated (e.g. "Ibuprofen", "Vitamin D3")
- dose: numeric amount ONLY if explicitly stated (e.g. 400 for "400mg"); null if not mentioned
- unit: ONLY if explicitly stated; null if not mentioned — do NOT infer from dose alone
- route: ONLY if explicitly stated; null if not mentioned — do NOT assume "oral"
- notes: any relevant context not captured above
- Do NOT estimate, assume, or infer any field. If not explicitly provided, return null.
''';

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async {
    if (_apiKey.isEmpty) {
      return MealParseResult(success: false, errorMessage: 'ANTHROPIC_API_KEY not set in .env');
    }

    final effectiveText = [
      if (mealContext != null) mealContext,
      if (mealType != null) 'Meal type: $mealType',
      if (text != null && text.isNotEmpty) text,
    ].join('\n').trim();

    final content = _buildContent(
      text: effectiveText.isNotEmpty ? effectiveText : null,
      imageBytes: imageBytes,
    );
    if (content == null) {
      return MealParseResult(success: false, errorMessage: 'Provide text or image to parse.');
    }

    try {
      final raw = await _call(_mealSystemPrompt, content);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final foods = (json['foods'] as List)
          .map((f) => FoodItemDraft.fromJson(f as Map<String, dynamic>))
          .toList();
      return MealParseResult(success: true, items: foods, title: json['title'] as String?);
    } catch (e) {
      return MealParseResult(success: false, errorMessage: e.toString());
    }
  }

  @override
  Future<MedicationParseResult> parseMedication({
    String? text,
    Uint8List? imageBytes,
  }) async {
    if (_apiKey.isEmpty) {
      return MedicationParseResult(success: false, errorMessage: 'ANTHROPIC_API_KEY not set in .env');
    }

    final content = _buildContent(text: text, imageBytes: imageBytes);
    if (content == null) {
      return MedicationParseResult(success: false, errorMessage: 'Provide text or image to parse.');
    }

    try {
      final raw = await _call(_medicationSystemPrompt, content);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MedicationParseResult(
        success: true,
        name: json['name'] as String?,
        dose: _parseNum(json['dose']),
        unit: json['unit'] as String?,
        route: json['route'] as String?,
        notes: json['notes'] as String?,
      );
    } catch (e) {
      return MedicationParseResult(success: false, errorMessage: e.toString());
    }
  }

  List<Map<String, dynamic>>? _buildContent({String? text, Uint8List? imageBytes}) {
    final content = <Map<String, dynamic>>[];
    if (imageBytes != null) {
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }
    if (text != null && text.isNotEmpty) {
      content.add({'type': 'text', 'text': text});
    }
    return content.isEmpty ? null : content;
  }

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Future<String> _call(String systemPrompt, List<Map<String, dynamic>> content) async {
    final response = await _client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': 'claude-sonnet-4-6',
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': content},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['content'] as List).first['text'] as String;
  }
}
