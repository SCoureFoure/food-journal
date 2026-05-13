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
}
