import 'dart:typed_data';
import '../models/food_item.dart';
import '../models/grocery.dart';
import '../models/receipt_parser.dart';
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

class GroceryTidyResult {
  final bool success;
  final List<GrocerySection>? sections;
  final String? errorMessage;

  GroceryTidyResult({required this.success, this.sections, this.errorMessage});
}

class ReceiptParseResult {
  final bool success;
  final List<ParsedReceiptItem>? items;
  final String? errorMessage;

  ReceiptParseResult({required this.success, this.items, this.errorMessage});
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

  /// Turns a raw frequency-ranked food list into a merged, section-grouped
  /// shopping list. See specs/groceries.spec.md.
  Future<GroceryTidyResult> tidyGroceryList(String rawList);

  /// Sends receipt item text to the Worker for generic food naming. See specs/receipt_scan.spec.md.
  Future<ReceiptParseResult> parseReceipt(String ocrText, {List<String> knownFoods = const []});

  factory AiService.fromEnv() => WorkerAiService();
}
