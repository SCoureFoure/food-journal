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

class FoodDbSearchResult {
  final bool success;
  final List<FoodItemDraft>? items;
  final String? errorMessage;

  FoodDbSearchResult({required this.success, this.items, this.errorMessage});
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

  /// Searches an external open food database (USDA FoodData Central) via the
  /// Worker. Returns drafts with name + estimated macros for one-tap insert.
  Future<FoodDbSearchResult> searchFoodDatabase(String query);

  factory AiService.fromEnv() => WorkerAiService();
}
