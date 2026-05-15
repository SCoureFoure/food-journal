import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/food_item.dart';
import 'ai_service.dart';

class GeminiAiService implements AiService {
  static const _modelName = 'gemini-flash-latest';

  static const _systemPrompt = '''
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

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'GEMINI_API_KEY not set in .env',
      );
    }

    final parts = <Part>[];
    if (imageBytes != null) parts.add(DataPart('image/jpeg', imageBytes));
    final textParts = <String>[
      if (mealContext != null) mealContext,
      if (mealType != null) 'Meal type: $mealType',
      if (text != null && text.isNotEmpty) text,
    ];
    if (textParts.isNotEmpty) parts.add(TextPart(textParts.join('\n')));

    if (parts.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'Provide text or image to parse.',
      );
    }

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
      );

      final response = await model.generateContent([Content.multi(parts)]);
      final rawText = response.text ?? '';

      // Strip markdown code fences Gemini sometimes adds despite instructions
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'\s*```'), '')
          .trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      final foods = (json['foods'] as List)
          .map((f) => FoodItemDraft.fromJson(f as Map<String, dynamic>))
          .toList();
      final title = json['title'] as String?;

      return MealParseResult(success: true, items: foods, title: title);
    } catch (e) {
      return MealParseResult(success: false, errorMessage: e.toString());
    }
  }

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
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return MedicationParseResult(success: false, errorMessage: 'GEMINI_API_KEY not set in .env');
    }

    final parts = <Part>[];
    if (imageBytes != null) parts.add(DataPart('image/jpeg', imageBytes));
    if (text != null && text.isNotEmpty) parts.add(TextPart(text));

    if (parts.isEmpty) {
      return MedicationParseResult(success: false, errorMessage: 'Provide text or image to parse.');
    }

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system(_medicationSystemPrompt),
      );
      final response = await model.generateContent([Content.multi(parts)]);
      final rawText = response.text ?? '';
      final cleaned = rawText
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'\s*```'), '')
          .trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;
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

  static double? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
