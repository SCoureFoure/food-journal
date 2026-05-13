import 'dart:convert';

import 'package:drift/drift.dart';

import '../models/food_item.dart';
import '../models/food_memory.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import '../models/reaction_log.dart';
import 'database/app_database.dart' as db;

class StorageService {
  final _db = db.AppDatabase();

  Future<void> saveMeal(
    MealEntry meal,
    List<FoodItem> items,
    List<List<Ingredient>> ingredientsByItem,
  ) async {
    await _db.transaction(() async {
      final mealId = await _db.into(_db.meals).insert(
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
            mealId: mealId,
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

  Future<List<ReactionLog>> getReactionLogsForMeal(int mealId) async {
    final rows = await (_db.select(_db.reactionLogs)
          ..where((t) => t.mealId.equals(mealId)))
        .get();
    return rows.map(_reactionLogFromRow).toList();
  }

  Future<void> saveReactionLog(ReactionLog log) async {
    await _db.into(_db.reactionLogs).insert(
      db.ReactionLogsCompanion.insert(
        mealId: log.mealId,
        checkinTime: log.checkinTime,
        symptoms: jsonEncode(log.symptoms),
        severity: log.severity.toInt(),
        notes: Value(log.notes),
      ),
    );
  }

  Future<List<FoodMemory>> getFoodMemory() async {
    final rows = await _db.select(_db.foodMemories).get();
    return rows.map(_foodMemoryFromRow).toList();
  }

  Future<void> upsertFoodMemory(
    String foodName,
    ReactionLevel reaction,
  ) async {
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

  Future<void> updateMealSymptoms(int mealId, String? symptoms) async {
    await (_db.update(_db.meals)..where((t) => t.id.equals(mealId)))
        .write(db.MealsCompanion(overallSymptoms: Value(symptoms)));
  }

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
    });
  }

  void dispose() => _db.close();

  // ── mappers ──────────────────────────────────────────────────────────────────

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
      );
}
