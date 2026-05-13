import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import 'ai_service.dart';

class AnthropicAiService implements AiService {
  final _client = http.Client();

  String get _apiKey => dotenv.env['ANTHROPIC_API_KEY'] ?? '';

  static const _systemPrompt = '''
You are a meal-logging assistant. Parse the user's meal description (text and/or photo) and return ONLY valid JSON with no markdown, no explanation.

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
  }) async {
    if (_apiKey.isEmpty) {
      return MealParseResult(
        success: false,
        errorMessage: 'ANTHROPIC_API_KEY not set in .env',
      );
    }

    try {
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

      final parts = <String>[
        if (mealType != null) 'Meal type: $mealType',
        if (text != null && text.isNotEmpty) text,
      ];
      if (parts.isNotEmpty) {
        content.add({'type': 'text', 'text': parts.join('\n')});
      }

      if (content.isEmpty) {
        return MealParseResult(
          success: false,
          errorMessage: 'Provide text or image to parse.',
        );
      }

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
          'system': _systemPrompt,
          'messages': [
            {'role': 'user', 'content': content},
          ],
        }),
      );

      if (response.statusCode != 200) {
        return MealParseResult(
          success: false,
          errorMessage: 'API error ${response.statusCode}: ${response.body}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = (data['content'] as List).first['text'] as String;
      final json = jsonDecode(rawText) as Map<String, dynamic>;
      final foods = (json['foods'] as List)
          .map((f) => FoodItemDraft.fromJson(f as Map<String, dynamic>))
          .toList();
      final title = json['title'] as String?;

      return MealParseResult(success: true, items: foods, title: title);
    } catch (e) {
      return MealParseResult(success: false, errorMessage: e.toString());
    }
  }
}
