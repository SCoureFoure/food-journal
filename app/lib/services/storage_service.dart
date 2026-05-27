import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/food_item.dart';
import '../models/food_memory.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/medication.dart';
import '../models/reaction_log.dart';
import '../models/saved_item.dart';
import '../models/water_log.dart';
import '../models/weight_log.dart';
import 'database/app_database.dart' as db;
import 'meal_memory/meal_memory_service.dart';

class StorageService {
  // lazy so test subclasses that never touch the DB don't trigger the
  // native sqlite3 connection during construction.
  late final _db = db.AppDatabase();
  late final _memory = MealMemoryService();

  // ── Meals ────────────────────────────────────────────────────────────────────

  Future<int> saveMeal(
    MealEntry meal,
    List<FoodItem> items,
    List<List<Ingredient>> ingredientsByItem,
  ) async {
    final mealId = await _db.transaction(() async {
      final id = await _db.into(_db.meals).insert(
        db.MealsCompanion.insert(
          date: meal.date,
          time: meal.time,
          mealType: meal.mealType,
          overallSymptoms: Value(meal.overallSymptoms),
          rawInput: Value(meal.rawInput),
          createdAt: meal.createdAt,
          imageData: Value(meal.imageData),
        ),
      );

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final foodItemId = await _db.into(_db.foodItems).insert(
          db.FoodItemsCompanion.insert(
            mealId: id,
            name: item.name,
            portion: Value(item.portion),
            prep: Value(item.prep),
            calories: Value(item.calories),
            protein: Value(item.protein),
            carbs: Value(item.carbs),
            fat: Value(item.fat),
            reaction: Value(item.reaction.toInt()),
            notes: Value(item.notes),
          ),
        );

        for (final ing in ingredientsByItem[i]) {
          await _db.into(_db.ingredients).insert(
            db.IngredientsCompanion.insert(
              foodItemId: foodItemId,
              name: ing.name,
              quantity: Value(ing.quantity),
              unit: Value(ing.unit),
            ),
          );
        }
      }

      return id;
    });

    unawaited(_memory.recordFingerprint(meal.copyWith(id: mealId), items));
    return mealId;
  }

  Future<MealEntry?> getMealById(int id) async {
    final row = await (_db.select(_db.meals)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mealFromRow(row);
  }

  Future<List<MealEntry>> getMealsForDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.meals)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_mealFromRow).toList();
  }

  Future<List<MealEntry>> getAllMeals() async {
    final rows = await (_db.select(_db.meals)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_mealFromRow).toList();
  }

  Future<List<MealEntry>> getMealsInRange({DateTime? from, DateTime? to}) async {
    final start = from != null ? DateTime(from.year, from.month, from.day) : null;
    final end = to != null ? DateTime(to.year, to.month, to.day + 1) : null;
    final query = _db.select(_db.meals);
    if (start != null && end != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end));
    } else if (start != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(start));
    } else if (end != null) {
      query.where((t) => t.date.isSmallerThanValue(end));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
    final rows = await query.get();
    return rows.map(_mealFromRow).toList();
  }

  Future<List<MealEntry>> getMealsForWeek(DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final rows = await (_db.select(_db.meals)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_mealFromRow).toList();
  }

  Future<List<({FoodItem item, List<Ingredient> ingredients})>> getFoodItemsWithIngredients(int mealId) async {
    final items = await getFoodItemsForMeal(mealId);
    return Future.wait(
      items.map((item) async {
        final ings = item.id != null
            ? await getIngredientsForFoodItem(item.id!)
            : <Ingredient>[];
        return (item: item, ingredients: ings);
      }),
    );
  }

  Future<List<FoodItem>> getFoodItemsForMeal(int mealId) async {
    final rows = await (_db.select(_db.foodItems)
          ..where((t) => t.mealId.equals(mealId)))
        .get();
    return rows.map(_foodItemFromRow).toList();
  }

  Future<List<Ingredient>> getIngredientsForFoodItem(int foodItemId) async {
    final rows = await (_db.select(_db.ingredients)
          ..where((t) => t.foodItemId.equals(foodItemId)))
        .get();
    return rows.map(_ingredientFromRow).toList();
  }

  Future<void> updateMealSymptoms(int mealId, String? symptoms) async {
    await (_db.update(_db.meals)..where((t) => t.id.equals(mealId)))
        .write(db.MealsCompanion(overallSymptoms: Value(symptoms)));
  }

  Future<void> updateMeal(
    MealEntry meal,
    List<FoodItem> items,
    List<List<Ingredient>> ingredientsByItem,
  ) async {
    await _db.transaction(() async {
      await (_db.update(_db.meals)..where((t) => t.id.equals(meal.id!))).write(
        db.MealsCompanion(
          date: Value(meal.date),
          time: Value(meal.time),
          mealType: Value(meal.mealType),
          rawInput: Value(meal.rawInput),
          imageData: Value(meal.imageData),
        ),
      );

      final oldItems = await (_db.select(_db.foodItems)
            ..where((t) => t.mealId.equals(meal.id!)))
          .get();
      for (final old in oldItems) {
        await (_db.delete(_db.ingredients)
              ..where((t) => t.foodItemId.equals(old.id)))
            .go();
      }
      await (_db.delete(_db.foodItems)..where((t) => t.mealId.equals(meal.id!))).go();

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final foodItemId = await _db.into(_db.foodItems).insert(
          db.FoodItemsCompanion.insert(
            mealId: meal.id!,
            name: item.name,
            portion: Value(item.portion),
            prep: Value(item.prep),
            calories: Value(item.calories),
            protein: Value(item.protein),
            carbs: Value(item.carbs),
            fat: Value(item.fat),
            reaction: Value(item.reaction.toInt()),
            notes: Value(item.notes),
          ),
        );
        for (final ing in ingredientsByItem[i]) {
          await _db.into(_db.ingredients).insert(
            db.IngredientsCompanion.insert(
              foodItemId: foodItemId,
              name: ing.name,
              quantity: Value(ing.quantity),
              unit: Value(ing.unit),
            ),
          );
        }
      }
    });
  }

  Future<void> deleteMeal(int mealId) async {
    await _db.transaction(() async {
      final items = await (_db.select(_db.foodItems)
            ..where((t) => t.mealId.equals(mealId)))
          .get();
      for (final item in items) {
        await (_db.delete(_db.ingredients)..where((t) => t.foodItemId.equals(item.id))).go();
      }
      await (_db.delete(_db.foodItems)..where((t) => t.mealId.equals(mealId))).go();
      await (_db.delete(_db.reactionLogs)..where((t) => t.mealId.equals(mealId))).go();
      await (_db.delete(_db.meals)..where((t) => t.id.equals(mealId))).go();
    });
  }

  Future<({int cal, double prot, double carbs, double fat})> getMacroTotalsForMeals(
    List<int> mealIds,
  ) async {
    if (mealIds.isEmpty) return (cal: 0, prot: 0.0, carbs: 0.0, fat: 0.0);
    int cal = 0;
    double prot = 0.0, carbs = 0.0, fat = 0.0;
    for (final id in mealIds) {
      final rows = await (_db.select(_db.foodItems)..where((t) => t.mealId.equals(id))).get();
      for (final row in rows) {
        cal += row.calories ?? 0;
        prot += (row.protein ?? 0).toDouble();
        carbs += (row.carbs ?? 0).toDouble();
        fat += (row.fat ?? 0).toDouble();
      }
    }
    return (cal: cal, prot: prot, carbs: carbs, fat: fat);
  }

  // ── Medications ──────────────────────────────────────────────────────────────

  Future<void> updateMedication(Medication med) async {
    await (_db.update(_db.medications)..where((t) => t.id.equals(med.id!))).write(
      db.MedicationsCompanion(
        date: Value(med.date),
        time: Value(med.time),
        name: Value(med.name),
        dose: Value(med.dose),
        unit: Value(med.unit),
        route: Value(med.route),
        checkinDelayMinutes: Value(med.checkinDelayMinutes),
        rawInput: Value(med.rawInput),
        notes: Value(med.notes),
        imageData: Value(med.imageData),
      ),
    );
  }

  Future<void> deleteMedication(int medId) async {
    await (_db.delete(_db.medications)..where((t) => t.id.equals(medId))).go();
  }

  Future<int> saveMedication(Medication med) async {
    return _db.into(_db.medications).insert(
      db.MedicationsCompanion.insert(
        date: med.date,
        time: med.time,
        name: med.name,
        dose: Value(med.dose),
        unit: Value(med.unit),
        route: Value(med.route),
        checkinDelayMinutes: Value(med.checkinDelayMinutes),
        rawInput: Value(med.rawInput),
        notes: Value(med.notes),
        imageData: Value(med.imageData),
        createdAt: med.createdAt,
      ),
    );
  }

  Future<List<Medication>> getAllMedications() async {
    final rows = await (_db.select(_db.medications)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_medicationFromRow).toList();
  }

  Future<Medication?> getMedicationById(int id) async {
    final row = await (_db.select(_db.medications)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _medicationFromRow(row);
  }

  Future<List<Medication>> getMedicationsInRange({DateTime? from, DateTime? to}) async {
    final start = from != null ? DateTime(from.year, from.month, from.day) : null;
    final end = to != null ? DateTime(to.year, to.month, to.day + 1) : null;
    final query = _db.select(_db.medications);
    if (start != null && end != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end));
    } else if (start != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(start));
    } else if (end != null) {
      query.where((t) => t.date.isSmallerThanValue(end));
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.date),
      (t) => OrderingTerm.asc(t.createdAt),
    ]);
    final rows = await query.get();
    return rows.map(_medicationFromRow).toList();
  }

  // ── Reactions ────────────────────────────────────────────────────────────────

  Future<List<ReactionLog>> getStandaloneReactionLogs() async {
    final rows = await (_db.select(_db.reactionLogs)
          ..where((t) => t.mealId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.checkinTime)]))
        .get();
    return rows.map(_reactionLogFromRow).toList();
  }

  Future<List<ReactionLog>> getReactionLogsForMeal(int mealId) async {
    final rows = await (_db.select(_db.reactionLogs)
          ..where((t) => t.mealId.equals(mealId)))
        .get();
    return rows.map(_reactionLogFromRow).toList();
  }

  Future<void> updateReactionLog(ReactionLog log) async {
    await (_db.update(_db.reactionLogs)..where((t) => t.id.equals(log.id!))).write(
      db.ReactionLogsCompanion(
        checkinTime: Value(log.checkinTime),
        symptoms: Value(jsonEncode(log.symptoms)),
        severity: Value(log.severity.toInt()),
        notes: Value(log.notes),
      ),
    );
  }

  Future<void> deleteReactionLog(int logId) async {
    await (_db.delete(_db.reactionLogs)..where((t) => t.id.equals(logId))).go();
  }

  Future<void> saveReactionLog(ReactionLog log) async {
    await _db.into(_db.reactionLogs).insert(
      db.ReactionLogsCompanion.insert(
        mealId: Value(log.mealId),
        checkinTime: log.checkinTime,
        symptoms: jsonEncode(log.symptoms),
        severity: log.severity.toInt(),
        notes: Value(log.notes),
      ),
    );
  }

  // ── Food Memory ──────────────────────────────────────────────────────────────

  Future<Set<String>> getFavoritedFoodNames() async {
    final rows = await (_db.select(_db.foodMemories)
          ..where((t) => t.favorited.equals(true)))
        .get();
    return rows.map((r) => r.foodName.toLowerCase()).toSet();
  }

  Future<List<FoodMemory>> getFoodMemory() async {
    final rows = await _db.select(_db.foodMemories).get();
    return rows.map(_foodMemoryFromRow).toList();
  }

  Future<void> insertFoodMemory(FoodMemory memory) async {
    await _db.into(_db.foodMemories).insert(
      db.FoodMemoriesCompanion.insert(
        foodName: memory.foodName,
        reactionPattern: Value(memory.reactionPattern),
        occurrences: Value(memory.occurrences),
        lastSeen: memory.lastSeen,
        flagged: Value(memory.flagged),
        favorited: Value(memory.favorited),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Returns up to 30 distinct food items matching [query], ordered by most recently logged.
  /// Each result carries the macro snapshot from the most recent log of that item name
  /// and the current [FoodItemDraft.favorited] state from food_memories.
  /// Saved composite items are included in the results (except when [favoritesOnly] is true).
  /// Pass an empty string to get the 30 most recent distinct items.
  /// Set [favoritesOnly] to restrict to items where food_memories.favorited = true.
  Future<List<FoodItemDraft>> searchFoodHistory(String query, {bool favoritesOnly = false}) async {
    final q = query.trim().isEmpty ? '%' : '%${query.trim()}%';
    final favFilter = favoritesOnly ? 'AND COALESCE(fm.favorited, 0) = 1' : '';

    final String sql;
    final List<Variable<Object>> variables;
    final Set<ResultSetImplementation<dynamic, dynamic>> readsFrom;

    if (favoritesOnly) {
      sql = '''
        SELECT fi.name, fi.portion, fi.prep, fi.calories, fi.protein, fi.carbs, fi.fat,
               MAX(m.date) AS last_used,
               COALESCE(fm.favorited, 0) AS is_favorited,
               0 AS is_composite,
               CAST(NULL AS INTEGER) AS saved_item_id
        FROM food_items fi
        JOIN meals m ON fi.meal_id = m.id
        LEFT JOIN food_memories fm ON LOWER(fi.name) = LOWER(fm.food_name)
        WHERE LOWER(fi.name) LIKE LOWER(?) $favFilter
        GROUP BY LOWER(fi.name)
        ORDER BY last_used DESC
        LIMIT 30
      ''';
      variables = [Variable.withString(q)];
      readsFrom = {_db.foodItems, _db.meals, _db.foodMemories};
    } else {
      sql = '''
        SELECT fi.name, fi.portion, fi.prep, fi.calories, fi.protein, fi.carbs, fi.fat,
               MAX(m.date) AS last_used,
               COALESCE(fm.favorited, 0) AS is_favorited,
               0 AS is_composite,
               CAST(NULL AS INTEGER) AS saved_item_id,
               CAST(NULL AS TEXT) AS components_json
        FROM food_items fi
        JOIN meals m ON fi.meal_id = m.id
        LEFT JOIN food_memories fm ON LOWER(fi.name) = LOWER(fm.food_name)
        WHERE LOWER(fi.name) LIKE LOWER(?)
        GROUP BY LOWER(fi.name)
        UNION ALL
        SELECT si.name, NULL, NULL, si.calories, si.protein, si.carbs, si.fat,
               si.created_at, 0, 1, si.id, si.components_json
        FROM saved_items si
        WHERE LOWER(si.name) LIKE LOWER(?)
        ORDER BY last_used DESC
        LIMIT 30
      ''';
      variables = [Variable.withString(q), Variable.withString(q)];
      readsFrom = {_db.foodItems, _db.meals, _db.foodMemories, _db.savedItems};
    }

    final rows = await _db.customSelect(
      sql,
      variables: variables,
      readsFrom: readsFrom,
    ).get();

    return rows.map((row) {
      final isComposite = row.read<int>('is_composite') == 1;
      final componentsRaw = isComposite ? row.readNullable<String>('components_json') : null;
      final components = componentsRaw != null
          ? List<String>.from(jsonDecode(componentsRaw) as List)
          : <String>[];
      return FoodItemDraft(
        name: row.read<String>('name'),
        portion: row.readNullable<String>('portion'),
        prep: row.readNullable<String>('prep'),
        calories: row.readNullable<int>('calories'),
        protein: row.readNullable<int>('protein'),
        carbs: row.readNullable<int>('carbs'),
        fat: row.readNullable<int>('fat'),
        ingredients: components,
        favorited: row.read<int>('is_favorited') == 1,
        isComposite: isComposite,
        savedItemId: row.readNullable<int>('saved_item_id'),
      );
    }).toList();
  }

  Future<void> toggleFoodFavorite(String foodName) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.foodMemories)
            ..where((t) => t.foodName.equals(foodName)))
          .getSingleOrNull();
      if (existing == null) {
        // Food was logged before memory entry existed — create one, already favorited.
        await _db.into(_db.foodMemories).insert(
          db.FoodMemoriesCompanion.insert(
            foodName: foodName,
            lastSeen: DateTime.now(),
            favorited: const Value(true),
          ),
        );
      } else {
        await (_db.update(_db.foodMemories)
              ..where((t) => t.foodName.equals(foodName)))
            .write(db.FoodMemoriesCompanion(favorited: Value(!existing.favorited)));
      }
    });
  }

  Future<void> upsertFoodMemory(String foodName, ReactionLevel reaction) async {
    await _db.transaction(() async {
      final existing = await (_db.select(_db.foodMemories)
            ..where((t) => t.foodName.equals(foodName)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.foodMemories)
              ..where((t) => t.foodName.equals(foodName)))
            .write(
          db.FoodMemoriesCompanion(
            occurrences: Value(existing.occurrences + 1),
            lastSeen: Value(DateTime.now()),
            reactionPattern: Value(reaction.label),
          ),
        );
      } else {
        await _db.into(_db.foodMemories).insert(
          db.FoodMemoriesCompanion.insert(
            foodName: foodName,
            reactionPattern: Value(reaction.label),
            lastSeen: DateTime.now(),
          ),
        );
      }
    });
  }

  // ── Water ────────────────────────────────────────────────────────────────────

  Future<int> saveWaterLog(WaterLog log) async {
    return _db.into(_db.waterLogs).insert(
      db.WaterLogsCompanion.insert(
        date: log.date,
        time: log.time,
        amountMl: log.amountMl,
        notes: Value(log.notes),
        createdAt: log.createdAt,
      ),
    );
  }

  Future<void> updateWaterLog(WaterLog log) async {
    await (_db.update(_db.waterLogs)..where((t) => t.id.equals(log.id!))).write(
      db.WaterLogsCompanion(
        date: Value(log.date),
        time: Value(log.time),
        amountMl: Value(log.amountMl),
        notes: Value(log.notes),
      ),
    );
  }

  Future<void> deleteWaterLog(int id) async {
    await (_db.delete(_db.waterLogs)..where((t) => t.id.equals(id))).go();
  }

  Future<List<WaterLog>> getWaterLogsForDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.waterLogs)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_waterLogFromRow).toList();
  }

  Future<List<WaterLog>> getAllWaterLogs() async {
    final rows = await (_db.select(_db.waterLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_waterLogFromRow).toList();
  }

  // ── Weight ───────────────────────────────────────────────────────────────────

  Future<int> saveWeightLog(WeightLog log) async {
    return _db.into(_db.weightLogs).insert(
      db.WeightLogsCompanion.insert(
        date: log.date,
        time: log.time,
        weightValue: log.weightValue,
        unit: log.unit,
        notes: Value(log.notes),
        createdAt: log.createdAt,
      ),
    );
  }

  Future<void> updateWeightLog(WeightLog log) async {
    await (_db.update(_db.weightLogs)..where((t) => t.id.equals(log.id!))).write(
      db.WeightLogsCompanion(
        date: Value(log.date),
        time: Value(log.time),
        weightValue: Value(log.weightValue),
        unit: Value(log.unit),
        notes: Value(log.notes),
      ),
    );
  }

  Future<void> deleteWeightLog(int id) async {
    await (_db.delete(_db.weightLogs)..where((t) => t.id.equals(id))).go();
  }

  Future<List<WeightLog>> getWeightLogsForDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await (_db.select(_db.weightLogs)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
    return rows.map(_weightLogFromRow).toList();
  }

  Future<List<WeightLog>> getAllWeightLogs() async {
    final rows = await (_db.select(_db.weightLogs)
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
    return rows.map(_weightLogFromRow).toList();
  }

  // ── Saved Items ──────────────────────────────────────────────────────────────

  Future<List<FoodItemDraft>> searchSavedItems(String query) async {
    final rows = await (_db.select(_db.savedItems)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? rows
        : rows.where((r) => r.name.toLowerCase().contains(q)).toList();
    return filtered.map((row) {
      final components = List<String>.from(jsonDecode(row.componentsJson) as List);
      return FoodItemDraft(
        name: row.name,
        calories: row.calories,
        protein: row.protein,
        carbs: row.carbs,
        fat: row.fat,
        ingredients: components,
        isComposite: true,
        savedItemId: row.id,
      );
    }).toList();
  }

  Future<int> saveSavedItem(SavedItem item) async {
    return _db.into(_db.savedItems).insert(
      db.SavedItemsCompanion.insert(
        name: item.name,
        calories: Value(item.calories),
        protein: Value(item.protein),
        carbs: Value(item.carbs),
        fat: Value(item.fat),
        componentsJson: jsonEncode(item.components),
        createdAt: item.createdAt,
      ),
    );
  }

  Future<void> deleteSavedItem(int id) async {
    await (_db.delete(_db.savedItems)..where((t) => t.id.equals(id))).go();
  }

  // ── Misc ─────────────────────────────────────────────────────────────────────

  Future<bool> hasMeals() async {
    final row = await (_db.select(_db.meals)..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.reactionLogs).go();
      await _db.delete(_db.ingredients).go();
      await _db.delete(_db.foodItems).go();
      await _db.delete(_db.meals).go();
      await _db.delete(_db.foodMemories).go();
      await _db.delete(_db.medications).go();
    });
  }

  void dispose() {} // singleton DB — never close

  // ── Mappers ──────────────────────────────────────────────────────────────────

  MealEntry _mealFromRow(db.Meal row) => MealEntry(
        id: row.id,
        date: row.date,
        time: row.time,
        mealType: row.mealType,
        overallSymptoms: row.overallSymptoms,
        rawInput: row.rawInput,
        createdAt: row.createdAt,
        imageData: row.imageData,
      );

  FoodItem _foodItemFromRow(db.FoodItem row) => FoodItem(
        id: row.id,
        mealId: row.mealId,
        name: row.name,
        portion: row.portion,
        prep: row.prep,
        calories: row.calories,
        protein: row.protein,
        carbs: row.carbs,
        fat: row.fat,
        reaction: ReactionLevel.fromInt(row.reaction),
        notes: row.notes,
      );

  Ingredient _ingredientFromRow(db.Ingredient row) => Ingredient(
        id: row.id,
        foodItemId: row.foodItemId,
        name: row.name,
        quantity: row.quantity,
        unit: row.unit,
      );

  ReactionLog _reactionLogFromRow(db.ReactionLog row) => ReactionLog(
        id: row.id,
        mealId: row.mealId,
        checkinTime: row.checkinTime,
        symptoms: List<String>.from(jsonDecode(row.symptoms) as List),
        severity: ReactionLevel.fromInt(row.severity),
        notes: row.notes,
      );

  FoodMemory _foodMemoryFromRow(db.FoodMemory row) => FoodMemory(
        id: row.id,
        foodName: row.foodName,
        reactionPattern: row.reactionPattern,
        occurrences: row.occurrences,
        lastSeen: row.lastSeen,
        flagged: row.flagged,
        favorited: row.favorited,
      );

  Medication _medicationFromRow(db.Medication row) => Medication(
        id: row.id,
        date: row.date,
        time: row.time,
        name: row.name,
        dose: row.dose,
        unit: row.unit,
        route: row.route,
        checkinDelayMinutes: row.checkinDelayMinutes,
        rawInput: row.rawInput,
        notes: row.notes,
        imageData: row.imageData,
        createdAt: row.createdAt,
      );

  WaterLog _waterLogFromRow(db.WaterLog row) => WaterLog(
        id: row.id,
        date: row.date,
        time: row.time,
        amountMl: row.amountMl,
        notes: row.notes,
        createdAt: row.createdAt,
      );

  WeightLog _weightLogFromRow(db.WeightLog row) => WeightLog(
        id: row.id,
        date: row.date,
        time: row.time,
        weightValue: row.weightValue,
        unit: row.unit,
        notes: row.notes,
        createdAt: row.createdAt,
      );
}
