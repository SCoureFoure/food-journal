import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_item.dart';
import '../models/grocery.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/medication.dart';
import '../models/reaction_log.dart';
import '../models/saved_item.dart';
import '../models/water_log.dart';
import '../models/weight_log.dart';
import 'ai_service.dart';
import 'storage_service.dart';

/// Meal-count windows offered by the grocery-list export.
const List<int> kGroceryMealWindows = [10, 30, 60];

/// Day windows offered by the grocery-list export.
const List<int> kGroceryDayWindows = [7, 14, 30];

/// The window mode the Export screen starts on.
const GroceryWindowMode kDefaultGroceryWindowMode = GroceryWindowMode.meals;

/// Default size for each mode.
const int kDefaultGroceryMealWindow = 30;
const int kDefaultGroceryDayWindow = 30;

class ExportTypes {
  final bool meals;
  final bool medications;
  final bool foodMemories;
  final bool waterLogs;
  final bool weightLogs;
  final bool savedItems;

  /// Embed photos (base64) in the export. Default true so single-item callers
  /// keep images; the Export screen defaults its switch off to keep files small.
  final bool images;

  const ExportTypes({
    this.meals = true,
    this.medications = true,
    this.foodMemories = true,
    this.waterLogs = true,
    this.weightLogs = true,
    this.savedItems = true,
    this.images = true,
  });
}

class ExportService {
  final StorageService _storage;
  final AiService _ai;

  ExportService(this._storage, {AiService? ai}) : _ai = ai ?? AiService.fromEnv();

  Future<void> exportJson({
    DateTime? from,
    DateTime? to,
    ExportTypes types = const ExportTypes(),
  }) async {
    final payload = await buildPayload(from: from, to: to, types: types);
    await _shareJson(payload, 'food_journal');
  }

  Future<void> exportMealJson(int mealId) async {
    final meal = await _storage.getMealById(mealId);
    if (meal == null) throw Exception('Meal not found');

    final foodItems = await _storage.getFoodItemsForMeal(mealId);
    final itemsList = <Map<String, dynamic>>[];
    for (final item in foodItems) {
      final ingredients = item.id != null
          ? await _storage.getIngredientsForFoodItem(item.id!)
          : <Ingredient>[];
      itemsList.add(foodItemToJson(item, ingredients));
    }

    final reactionLogs = await _storage.getReactionLogsForMeal(mealId);
    final payload = {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'meals': [mealToJson(meal, itemsList, reactionLogs)],
      'medications': <Map<String, dynamic>>[],
      'food_memories': <Map<String, dynamic>>[],
    };

    await _shareJson(payload, 'meal_share');
  }

  Future<Map<String, dynamic>> buildPayload({
    DateTime? from,
    DateTime? to,
    ExportTypes types = const ExportTypes(),
  }) async {
    final mealsList = <Map<String, dynamic>>[];
    if (types.meals) {
      final meals = await _storage.getMealsInRange(from: from, to: to);
      for (final meal in meals) {
        final foodItems = await _storage.getFoodItemsForMeal(meal.id!);
        final itemsList = <Map<String, dynamic>>[];
        for (final item in foodItems) {
          final ingredients = item.id != null
              ? await _storage.getIngredientsForFoodItem(item.id!)
              : <Ingredient>[];
          itemsList.add(foodItemToJson(item, ingredients));
        }
        final reactionLogs = await _storage.getReactionLogsForMeal(meal.id!);
        mealsList.add(mealToJson(meal, itemsList, reactionLogs,
            includeImages: types.images));
      }
    }

    final medicationsList = <Map<String, dynamic>>[];
    if (types.medications) {
      final medications = await _storage.getMedicationsInRange(from: from, to: to);
      for (final med in medications) {
        medicationsList.add(medicationToJson(med, includeImages: types.images));
      }
    }

    final foodMemoriesList = <Map<String, dynamic>>[];
    if (types.foodMemories) {
      final memories = await _storage.getFoodMemory();
      for (final m in memories) {
        foodMemoriesList.add({
          'food_name': m.foodName,
          'reaction_pattern': m.reactionPattern,
          'occurrences': m.occurrences,
          'last_seen': m.lastSeen.toIso8601String(),
          'flagged': m.flagged,
        });
      }
    }

    final waterLogsList = <Map<String, dynamic>>[];
    if (types.waterLogs) {
      final logs = await _storage.getAllWaterLogs();
      for (final w in logs) {
        if (_inRange(w.date, from, to)) waterLogsList.add(waterLogToJson(w));
      }
    }

    final weightLogsList = <Map<String, dynamic>>[];
    if (types.weightLogs) {
      final logs = await _storage.getAllWeightLogs();
      for (final w in logs) {
        if (_inRange(w.date, from, to)) weightLogsList.add(weightLogToJson(w));
      }
    }

    final savedItemsList = <Map<String, dynamic>>[];
    if (types.savedItems) {
      final items = await _storage.getAllSavedItems();
      for (final s in items) {
        savedItemsList.add(savedItemToJson(s));
      }
    }

    return {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'date_range': {
        'from': from?.toIso8601String(),
        'to': to?.toIso8601String(),
      },
      'meals': mealsList,
      'medications': medicationsList,
      'food_memories': foodMemoriesList,
      'water_logs': waterLogsList,
      'weight_logs': weightLogsList,
      'saved_items': savedItemsList,
    };
  }

  static bool _inRange(DateTime date, DateTime? from, DateTime? to) {
    final d = DateTime(date.year, date.month, date.day);
    if (from != null && d.isBefore(DateTime(from.year, from.month, from.day))) {
      return false;
    }
    if (to != null && d.isAfter(DateTime(to.year, to.month, to.day))) {
      return false;
    }
    return true;
  }

  static Map<String, dynamic> mealToJson(
    MealEntry meal,
    List<Map<String, dynamic>> itemsList,
    List<ReactionLog> reactionLogs, {
    bool includeImages = true,
  }) =>
      {
        'date': meal.date.toIso8601String().split('T').first,
        'time': meal.time,
        'meal_type': meal.mealType,
        'overall_symptoms': meal.overallSymptoms,
        'raw_input': meal.rawInput,
        'created_at': meal.createdAt.toIso8601String(),
        'image_data': includeImages && meal.imageData != null
            ? base64Encode(meal.imageData!)
            : null,
        'food_items': itemsList,
        'reaction_logs': reactionLogs
            .map((r) => {
                  'checkin_time': r.checkinTime.toIso8601String(),
                  'symptoms': r.symptoms,
                  'symptom_levels':
                      r.symptomLevels.map((k, v) => MapEntry(k, v.name)),
                  'severity': r.severity.name,
                  'mood': r.mood?.name,
                  'notes': r.notes,
                })
            .toList(),
      };

  static Map<String, dynamic> foodItemToJson(FoodItem item, List<Ingredient> ingredients) => {
        'name': item.name,
        'portion': item.portion,
        'prep': item.prep,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'reaction': item.reaction.name,
        'notes': item.notes,
        'ingredients': ingredients
            .map((i) => {
                  'name': i.name,
                  'quantity': i.quantity,
                  'unit': i.unit,
                })
            .toList(),
      };

  static Map<String, dynamic> medicationToJson(Medication med,
          {bool includeImages = true}) =>
      {
        'date': med.date.toIso8601String().split('T').first,
        'time': med.time,
        'name': med.name,
        'dose': med.dose,
        'unit': med.unit,
        'route': med.route,
        'checkin_delay_minutes': med.checkinDelayMinutes,
        'raw_input': med.rawInput,
        'notes': med.notes,
        'created_at': med.createdAt.toIso8601String(),
        'image_data': includeImages && med.imageData != null
            ? base64Encode(med.imageData!)
            : null,
      };

  static Map<String, dynamic> waterLogToJson(WaterLog log) => {
        'date': log.date.toIso8601String().split('T').first,
        'time': log.time,
        'amount_ml': log.amountMl,
        'notes': log.notes,
        'created_at': log.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> weightLogToJson(WeightLog log) => {
        'date': log.date.toIso8601String().split('T').first,
        'time': log.time,
        'weight_value': log.weightValue,
        'unit': log.unit,
        'notes': log.notes,
        'created_at': log.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> savedItemToJson(SavedItem item) => {
        'name': item.name,
        'calories': item.calories,
        'protein': item.protein,
        'carbs': item.carbs,
        'fat': item.fat,
        'components': item.components,
        'created_at': item.createdAt.toIso8601String(),
      };

  /// Grocery candidates for the chosen window, plus how many meals actually
  /// fed them (which the header reports). [now] is injectable for tests.
  Future<({List<GroceryCandidate> candidates, int mealsUsed})> buildGroceryCandidates({
    required GroceryWindowMode mode,
    required int size,
    DateTime? now,
  }) async {
    List<MealEntry> meals;
    if (mode == GroceryWindowMode.meals) {
      final all = await _storage.getAllMeals();
      final withId = all.where((m) => m.id != null).toList();
      withId.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.createdAt.compareTo(a.createdAt);
      });
      meals = withId.take(size).toList();
    } else {
      final anchor = now ?? DateTime.now();
      final today = DateTime(anchor.year, anchor.month, anchor.day);
      final from = today.subtract(Duration(days: size - 1));
      final all = await _storage.getMealsInRange(from: from, to: anchor);
      meals = all.where((m) => m.id != null).toList();
    }

    final inputs = <MealGroceryInput>[];
    for (final meal in meals) {
      final rows = await _storage.getFoodItemsWithIngredients(meal.id!);
      final names = <String>[];
      for (final row in rows) {
        if (row.ingredients.isNotEmpty) {
          for (final ingredient in row.ingredients) {
            names.add(ingredient.name);
          }
        } else {
          names.add(row.item.name);
        }
      }
      inputs.add(MealGroceryInput(mealId: meal.id!, names: names));
    }

    return (candidates: buildGroceryList(inputs), mealsUsed: meals.length);
  }

  /// The shareable plain-text grocery list for the chosen window.
  Future<String> buildGroceryListText({
    required GroceryWindowMode mode,
    required int size,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final r = await buildGroceryCandidates(mode: mode, size: size, now: anchor);
    return formatGroceryList(
      r.candidates,
      windowLabel: groceryWindowLabel(mode: mode, size: size, mealsUsed: r.mealsUsed),
      mealsUsed: r.mealsUsed,
      generatedAt: anchor,
    );
  }

  /// Builds the list and hands it to the OS share sheet as plain text.
  Future<void> exportGroceryList({
    required GroceryWindowMode mode,
    required int size,
  }) async {
    final text = await buildGroceryListText(mode: mode, size: size);
    await Share.share(text, subject: 'Grocery list');
  }

  /// The raw list handed to the AI tidy pass: one `name (xN)` line per candidate,
  /// in the ranked order they were generated.
  static String buildTidyPromptInput(List<GroceryCandidate> candidates) =>
      candidates.map((c) => '${c.name} (x${c.mealCount})').join('\n');

  /// The AI-tidied, section-grouped grocery list as shareable plain text.
  /// Throws [Exception] carrying the AI error message when the tidy pass fails —
  /// the caller surfaces it; the plain (non-AI) list is unaffected.
  Future<String> buildTidiedGroceryListText({
    required GroceryWindowMode mode,
    required int size,
    DateTime? now,
  }) async {
    final anchor = now ?? DateTime.now();
    final r = await buildGroceryCandidates(mode: mode, size: size, now: anchor);
    final label = groceryWindowLabel(mode: mode, size: size, mealsUsed: r.mealsUsed);

    if (r.candidates.isEmpty) {
      return formatTidiedGroceryList(const [], windowLabel: label, generatedAt: anchor);
    }

    final tidy = await _ai.tidyGroceryList(buildTidyPromptInput(r.candidates));
    if (!tidy.success || tidy.sections == null) {
      throw Exception(tidy.errorMessage ?? 'Tidy failed.');
    }

    return formatTidiedGroceryList(tidy.sections!, windowLabel: label, generatedAt: anchor);
  }

  /// Builds the tidied list and hands it to the OS share sheet as plain text.
  Future<void> exportTidiedGroceryList({
    required GroceryWindowMode mode,
    required int size,
  }) async {
    final text = await buildTidiedGroceryListText(mode: mode, size: size);
    await Share.share(text, subject: 'Grocery list');
  }

  Future<void> _shareJson(Map<String, dynamic> payload, String namePrefix) async {
    final jsonStr = jsonEncode(payload);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${namePrefix}_$timestamp.json');
    await file.writeAsString(jsonStr);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Food Journal Export',
    );
  }
}
