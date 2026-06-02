import 'dart:convert';
import 'dart:io';

import '../models/food_item.dart';
import '../models/food_memory.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/medication.dart';
import '../models/reaction_log.dart';
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

  const ImportPayload({
    required this.version,
    required this.meals,
    required this.medications,
    required this.foodMemories,
  });
}

class ImportSelection {
  final Set<int> mealIndices;
  final Set<int> medicationIndices;
  final Set<int> foodMemoryIndices;

  const ImportSelection({
    required this.mealIndices,
    required this.medicationIndices,
    required this.foodMemoryIndices,
  });

  int get totalCount =>
      mealIndices.length + medicationIndices.length + foodMemoryIndices.length;
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

    return ImportPayload(
      version: version,
      meals: meals,
      medications: medications,
      foodMemories: foodMemories,
    );
  }

  Future<ImportPayload> parseFile(String filePath) async {
    final content = await File(filePath).readAsString();
    return parseJson(content);
  }

  Future<({Set<int> mealDupes, Set<int> medDupes, Set<int> memoryDupes})> detectDupes(
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

    return (mealDupes: mealDupes, medDupes: medDupes, memoryDupes: memoryDupes);
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
