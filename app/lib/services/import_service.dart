import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/food_item.dart';
import '../models/food_memory.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/medication.dart';
import '../models/reaction_log.dart';
import '../models/saved_item.dart';
import '../models/water_log.dart';
import '../models/weight_log.dart';
import 'storage_service.dart';

class MealImportRecord {
  final MealEntry meal;
  final List<FoodItem> foodItems;
  final List<List<Ingredient>> ingredientsByItem;
  final List<ReactionLog> reactionLogs;

  const MealImportRecord({
    required this.meal,
    required this.foodItems,
    required this.ingredientsByItem,
    required this.reactionLogs,
  });

  String get dupeKey {
    final date = meal.date.toIso8601String().split('T').first;
    final names = foodItems.map((i) => i.name.toLowerCase()).toList()..sort();
    return '$date|${meal.time}|${meal.mealType}|${names.join(',')}';
  }
}

class ImportPayload {
  final int version;
  final List<MealImportRecord> meals;
  final List<Medication> medications;
  final List<FoodMemory> foodMemories;
  final List<WaterLog> waterLogs;
  final List<WeightLog> weightLogs;
  final List<SavedItem> savedItems;

  const ImportPayload({
    required this.version,
    required this.meals,
    required this.medications,
    required this.foodMemories,
    this.waterLogs = const [],
    this.weightLogs = const [],
    this.savedItems = const [],
  });
}

class ImportSelection {
  final Set<int> mealIndices;
  final Set<int> medicationIndices;
  final Set<int> foodMemoryIndices;
  final Set<int> waterIndices;
  final Set<int> weightIndices;
  final Set<int> savedItemIndices;

  const ImportSelection({
    required this.mealIndices,
    required this.medicationIndices,
    required this.foodMemoryIndices,
    this.waterIndices = const {},
    this.weightIndices = const {},
    this.savedItemIndices = const {},
  });

  int get totalCount =>
      mealIndices.length +
      medicationIndices.length +
      foodMemoryIndices.length +
      waterIndices.length +
      weightIndices.length +
      savedItemIndices.length;
}

class ImportService {
  final StorageService _storage;

  ImportService(this._storage);

  static ImportPayload parseJson(String jsonContent) {
    final json = jsonDecode(jsonContent) as Map<String, dynamic>;
    final version = json['version'] as int? ?? 1;

    final meals = <MealImportRecord>[];
    for (final m in (json['meals'] as List<dynamic>? ?? [])) {
      final map = m as Map<String, dynamic>;
      final meal = MealEntry(
        date: DateTime.parse(map['date'] as String),
        time: map['time'] as String,
        mealType: map['meal_type'] as String,
        overallSymptoms: map['overall_symptoms'] as String?,
        rawInput: map['raw_input'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        imageData: map['image_data'] != null
            ? base64Decode(map['image_data'] as String)
            : null,
      );

      final foodItems = <FoodItem>[];
      final ingredientsByItem = <List<Ingredient>>[];
      for (final i in (map['food_items'] as List<dynamic>? ?? [])) {
        final imap = i as Map<String, dynamic>;
        foodItems.add(FoodItem(
          mealId: 0, // placeholder; saveMeal uses its own generated id
          name: imap['name'] as String,
          portion: imap['portion'] as String?,
          prep: imap['prep'] as String?,
          calories: (imap['calories'] as num?)?.toInt(),
          protein: (imap['protein'] as num?)?.toInt(),
          carbs: (imap['carbs'] as num?)?.toInt(),
          fat: (imap['fat'] as num?)?.toInt(),
          reaction: _reactionFromName(imap['reaction'] as String?),
          notes: imap['notes'] as String?,
        ));
        ingredientsByItem.add(
          (imap['ingredients'] as List<dynamic>? ?? []).map((ing) {
            final ingmap = ing as Map<String, dynamic>;
            return Ingredient(
              foodItemId: 0, // placeholder; saveMeal uses its own generated id
              name: ingmap['name'] as String,
              quantity: ingmap['quantity'] as String?,
              unit: ingmap['unit'] as String?,
            );
          }).toList(),
        );
      }

      final reactionLogs = (map['reaction_logs'] as List<dynamic>? ?? []).map((r) {
        final rmap = r as Map<String, dynamic>;
        final symptoms = List<String>.from(rmap['symptoms'] as List);
        final severity = _reactionFromName(rmap['severity'] as String?);
        final rawLevels = rmap['symptom_levels'] as Map<String, dynamic>?;
        final levels = rawLevels != null
            ? rawLevels.map((k, v) => MapEntry(k, _reactionFromName(v as String?)))
            : {for (final s in symptoms) s: severity};
        return ReactionLog(
          checkinTime: DateTime.parse(rmap['checkin_time'] as String),
          symptoms: symptoms,
          symptomLevels: levels,
          severity: severity,
          mood: _moodFromName(rmap['mood'] as String?),
          notes: rmap['notes'] as String?,
        );
      }).toList();

      meals.add(MealImportRecord(
        meal: meal,
        foodItems: foodItems,
        ingredientsByItem: ingredientsByItem,
        reactionLogs: reactionLogs,
      ));
    }

    final medications = (json['medications'] as List<dynamic>? ?? []).map((m) {
      final map = m as Map<String, dynamic>;
      return Medication(
        date: DateTime.parse(map['date'] as String),
        time: map['time'] as String,
        name: map['name'] as String,
        dose: (map['dose'] as num?)?.toDouble(),
        unit: map['unit'] as String?,
        route: map['route'] as String?,
        checkinDelayMinutes: map['checkin_delay_minutes'] as int?,
        rawInput: map['raw_input'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        imageData: map['image_data'] != null
            ? base64Decode(map['image_data'] as String)
            : null,
      );
    }).toList();

    final foodMemories = (json['food_memories'] as List<dynamic>? ?? []).map((m) {
      final map = m as Map<String, dynamic>;
      return FoodMemory(
        foodName: map['food_name'] as String,
        reactionPattern: map['reaction_pattern'] as String?,
        occurrences: map['occurrences'] as int? ?? 0,
        lastSeen: DateTime.parse(map['last_seen'] as String),
        flagged: map['flagged'] as bool? ?? false,
      );
    }).toList();

    final waterLogs = (json['water_logs'] as List<dynamic>? ?? []).map((w) {
      final map = w as Map<String, dynamic>;
      return WaterLog(
        date: DateTime.parse(map['date'] as String),
        time: map['time'] as String,
        amountMl: (map['amount_ml'] as num).toInt(),
        notes: map['notes'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    final weightLogs = (json['weight_logs'] as List<dynamic>? ?? []).map((w) {
      final map = w as Map<String, dynamic>;
      return WeightLog(
        date: DateTime.parse(map['date'] as String),
        time: map['time'] as String,
        weightValue: (map['weight_value'] as num).toDouble(),
        unit: map['unit'] as String,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    final savedItems = (json['saved_items'] as List<dynamic>? ?? []).map((s) {
      final map = s as Map<String, dynamic>;
      return SavedItem(
        name: map['name'] as String,
        calories: (map['calories'] as num?)?.toInt(),
        protein: (map['protein'] as num?)?.toInt(),
        carbs: (map['carbs'] as num?)?.toInt(),
        fat: (map['fat'] as num?)?.toInt(),
        components: List<String>.from(map['components'] as List? ?? []),
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );
    }).toList();

    return ImportPayload(
      version: version,
      meals: meals,
      medications: medications,
      foodMemories: foodMemories,
      waterLogs: waterLogs,
      weightLogs: weightLogs,
      savedItems: savedItems,
    );
  }

  /// Reads + parses off the main isolate so a large file (many base64 photos)
  /// never blocks the UI / triggers an ANR. [parseJson] stays a pure static so
  /// it can be the isolate entry and remain unit-testable without an isolate.
  Future<ImportPayload> parseFile(String filePath) =>
      compute(_parseFileTask, filePath);

  Future<
      ({
        Set<int> mealDupes,
        Set<int> medDupes,
        Set<int> memoryDupes,
        Set<int> waterDupes,
        Set<int> weightDupes,
        Set<int> savedItemDupes,
      })> detectDupes(
    ImportPayload payload,
  ) async {
    final allMeals = await _storage.getAllMeals();
    final existingMealKeys = <String>{};
    for (final meal in allMeals) {
      final items = await _storage.getFoodItemsForMeal(meal.id!);
      final names = items.map((i) => i.name.toLowerCase()).toList()..sort();
      final date = meal.date.toIso8601String().split('T').first;
      existingMealKeys.add('$date|${meal.time}|${meal.mealType}|${names.join(',')}');
    }

    final allMeds = await _storage.getAllMedications();
    final existingMedKeys = allMeds.map((m) {
      final date = m.date.toIso8601String().split('T').first;
      return '$date|${m.time}|${m.name}|${m.dose}';
    }).toSet();

    final allMemories = await _storage.getFoodMemory();
    final existingMemoryNames = allMemories.map((m) => m.foodName.toLowerCase()).toSet();

    final allWater = await _storage.getAllWaterLogs();
    final existingWaterKeys = allWater.map((w) {
      final date = w.date.toIso8601String().split('T').first;
      return '$date|${w.time}|${w.amountMl}';
    }).toSet();

    final allWeight = await _storage.getAllWeightLogs();
    final existingWeightKeys = allWeight.map((w) {
      final date = w.date.toIso8601String().split('T').first;
      return '$date|${w.time}|${w.weightValue}|${w.unit}';
    }).toSet();

    final allSaved = await _storage.getAllSavedItems();
    final existingSavedNames = allSaved.map((s) => s.name.toLowerCase()).toSet();

    final mealDupes = <int>{};
    for (var i = 0; i < payload.meals.length; i++) {
      if (existingMealKeys.contains(payload.meals[i].dupeKey)) mealDupes.add(i);
    }

    final medDupes = <int>{};
    for (var i = 0; i < payload.medications.length; i++) {
      final m = payload.medications[i];
      final date = m.date.toIso8601String().split('T').first;
      if (existingMedKeys.contains('$date|${m.time}|${m.name}|${m.dose}')) medDupes.add(i);
    }

    final memoryDupes = <int>{};
    for (var i = 0; i < payload.foodMemories.length; i++) {
      if (existingMemoryNames.contains(payload.foodMemories[i].foodName.toLowerCase())) {
        memoryDupes.add(i);
      }
    }

    final waterDupes = <int>{};
    for (var i = 0; i < payload.waterLogs.length; i++) {
      final w = payload.waterLogs[i];
      final date = w.date.toIso8601String().split('T').first;
      if (existingWaterKeys.contains('$date|${w.time}|${w.amountMl}')) waterDupes.add(i);
    }

    final weightDupes = <int>{};
    for (var i = 0; i < payload.weightLogs.length; i++) {
      final w = payload.weightLogs[i];
      final date = w.date.toIso8601String().split('T').first;
      if (existingWeightKeys.contains('$date|${w.time}|${w.weightValue}|${w.unit}')) {
        weightDupes.add(i);
      }
    }

    final savedItemDupes = <int>{};
    for (var i = 0; i < payload.savedItems.length; i++) {
      if (existingSavedNames.contains(payload.savedItems[i].name.toLowerCase())) {
        savedItemDupes.add(i);
      }
    }

    return (
      mealDupes: mealDupes,
      medDupes: medDupes,
      memoryDupes: memoryDupes,
      waterDupes: waterDupes,
      weightDupes: weightDupes,
      savedItemDupes: savedItemDupes,
    );
  }

  Future<int> importSelected(
    ImportPayload payload,
    ImportSelection selection,
  ) async {
    int count = 0;

    for (final i in selection.mealIndices) {
      final record = payload.meals[i];
      final mealId = await _storage.saveMeal(
        record.meal,
        record.foodItems,
        record.ingredientsByItem,
      );
      for (final log in record.reactionLogs) {
        await _storage.saveReactionLog(log.copyWith(mealId: mealId));
      }
      count++;
    }

    for (final i in selection.medicationIndices) {
      await _storage.saveMedication(payload.medications[i]);
      count++;
    }

    for (final i in selection.foodMemoryIndices) {
      await _storage.insertFoodMemory(payload.foodMemories[i]);
      count++;
    }

    for (final i in selection.waterIndices) {
      await _storage.saveWaterLog(payload.waterLogs[i]);
      count++;
    }

    for (final i in selection.weightIndices) {
      await _storage.saveWeightLog(payload.weightLogs[i]);
      count++;
    }

    for (final i in selection.savedItemIndices) {
      await _storage.saveSavedItem(payload.savedItems[i]);
      count++;
    }

    return count;
  }

  static ReactionLevel _reactionFromName(String? name) {
    if (name == null) return ReactionLevel.pending;
    try {
      return ReactionLevel.values.byName(name);
    } catch (_) {
      return ReactionLevel.pending;
    }
  }

  static Mood? _moodFromName(String? name) {
    if (name == null) return null;
    try {
      return Mood.values.byName(name);
    } catch (_) {
      return null;
    }
  }
}

/// Top-level isolate entry: read the file and parse it in the background.
Future<ImportPayload> _parseFileTask(String filePath) async {
  final content = await File(filePath).readAsString();
  return ImportService.parseJson(content);
}
