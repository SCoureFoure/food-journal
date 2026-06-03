import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/food_item.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/medication.dart';
import '../models/reaction_log.dart';
import '../models/saved_item.dart';
import '../models/water_log.dart';
import '../models/weight_log.dart';
import 'storage_service.dart';

class ExportTypes {
  final bool meals;
  final bool medications;
  final bool foodMemories;
  final bool waterLogs;
  final bool weightLogs;
  final bool savedItems;

  const ExportTypes({
    this.meals = true,
    this.medications = true,
    this.foodMemories = true,
    this.waterLogs = true,
    this.weightLogs = true,
    this.savedItems = true,
  });
}

class ExportService {
  final StorageService _storage;

  ExportService(this._storage);

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
        mealsList.add(mealToJson(meal, itemsList, reactionLogs));
      }
    }

    final medicationsList = <Map<String, dynamic>>[];
    if (types.medications) {
      final medications = await _storage.getMedicationsInRange(from: from, to: to);
      for (final med in medications) {
        medicationsList.add(medicationToJson(med));
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
    List<ReactionLog> reactionLogs,
  ) =>
      {
        'date': meal.date.toIso8601String().split('T').first,
        'time': meal.time,
        'meal_type': meal.mealType,
        'overall_symptoms': meal.overallSymptoms,
        'raw_input': meal.rawInput,
        'created_at': meal.createdAt.toIso8601String(),
        'image_data': meal.imageData != null ? base64Encode(meal.imageData!) : null,
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

  static Map<String, dynamic> medicationToJson(Medication med) => {
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
        'image_data': med.imageData != null ? base64Encode(med.imageData!) : null,
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

  Future<void> _shareJson(Map<String, dynamic> payload, String namePrefix) async {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
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
