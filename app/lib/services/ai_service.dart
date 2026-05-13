import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/food_item.dart';
import 'anthropic_ai_service.dart';
import 'gemini_ai_service.dart';
import 'worker_ai_service.dart';

class MealParseResult {
  final bool success;
  final List<FoodItemDraft>? items;
  final String? title;
  final String? errorMessage;

  MealParseResult({required this.success, this.items, this.title, this.errorMessage});
}

abstract class AiService {
  Future<MealParseResult> parseMeal({String? text, Uint8List? imageBytes, String? mealType});

  factory AiService.fromEnv() {
    return switch (dotenv.env['AI_PROVIDER'] ?? 'anthropic') {
      'gemini' => GeminiAiService(),
      'worker' => WorkerAiService(),
      _ => AnthropicAiService(),
    };
  }
}
