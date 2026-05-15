import 'dart:typed_data';
import '../models/food_item.dart';
import 'worker_ai_service.dart';

class MealParseResult {
  final bool success;
  final List<FoodItemDraft>? items;
  final String? title;
  final String? errorMessage;

  MealParseResult({required this.success, this.items, this.title, this.errorMessage});
}

class MedicationParseResult {
  final bool success;
  final String? name;
  final double? dose;
  final String? unit;
  final String? route;
  final String? notes;
  final String? errorMessage;

  MedicationParseResult({
    required this.success,
    this.name,
    this.dose,
    this.unit,
    this.route,
    this.notes,
    this.errorMessage,
  });
}

abstract class AiService {
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  });
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes});

  factory AiService.fromEnv() => WorkerAiService();
}
