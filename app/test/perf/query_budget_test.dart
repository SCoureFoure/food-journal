// INV (Invariant) perf harness: counts SQL statements issued by StorageService
// operations against a deterministically seeded in-memory database and prints
// PERF / SNAP / PLAN lines for before/after comparison.
//
// SNAP hashes must be identical run to run (no clock, no randomness in the
// seed) and unchanged by any query-count optimisation.

// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';

/// Per-op SQL statement budgets against the 200-meal seed. Values are the
/// measured counts after the v15 batching pass (was 200 / 5 / 1000 / 6 / 13 /
/// 8); a regression back to per-row queries fails here.
const Map<String, int> kQueryBudgets = {
  'macroTotals_all': 1,
  'itemsWithIngredients_one': 2,
  'itemsWithIngredients_all': 400,
  'blameCandidates_48h': 3,
  'updateMeal_one': 10,
  'deleteMeal_one': 5,
};

class _Counter extends d.QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      d.QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
      d.QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(
      d.QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(
      d.QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(
      d.QueryExecutor executor, String statement, List<Object?> args) {
    count++;
    return executor.runCustom(statement, args);
  }

  @override
  Future<void> runBatched(
      d.QueryExecutor executor, d.BatchedStatements statements) {
    count += statements.arguments.length;
    return executor.runBatched(statements);
  }
}

// ─── Canonical-string helpers ────────────────────────────────────────────────

String _s(Object? v) => v == null ? 'null' : '$v';
String _f(double v) => v.toStringAsFixed(6);

String _mealLine(MealEntry m) => [
      _s(m.id),
      m.date.toIso8601String(),
      m.time,
      m.mealType,
      _s(m.overallSymptoms),
      _s(m.rawInput),
    ].join('|');

String _itemLine(FoodItem i) => [
      _s(i.id),
      i.mealId,
      i.name,
      _s(i.portion),
      _s(i.prep),
      _s(i.calories),
      _s(i.protein),
      _s(i.carbs),
      _s(i.fat),
      i.reaction.index,
      _s(i.notes),
      _f(i.servings),
    ].join('|');

String _ingLine(Ingredient i) => [
      _s(i.id),
      i.foodItemId,
      i.name,
      _s(i.quantity),
      _s(i.unit),
    ].join('|');

String _reactionLine(ReactionLog r) => [
      _s(r.id),
      _s(r.mealId),
      r.checkinTime.toIso8601String(),
      r.symptoms.join(','),
      r.symptomLevels.entries.map((e) => '${e.key}=${e.value.index}').join(','),
      r.severity.index,
      _s(r.mood?.index),
      _s(r.notes),
    ].join('|');

List<String> _itemsWithIngLines(
    List<({FoodItem item, List<Ingredient> ingredients})> rows) {
  final out = <String>[];
  for (final r in rows) {
    out.add(_itemLine(r.item));
    out.addAll(r.ingredients.map(_ingLine));
  }
  return out;
}

String _fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

void _snap(String op, List<String> lines) {
  print('SNAP $op rows=${lines.length} hash=${_fnv1a32(lines.join('\n'))}');
}

// ─── Test ────────────────────────────────────────────────────────────────────

void main() {
  late _Counter counter;
  late AppDatabase db;
  late StorageService storage;

  Future<int> countRows(String table) async {
    final rows = await db.customSelect('SELECT count(*) AS c FROM $table').get();
    return rows.first.read<int>('c');
  }

  setUpAll(() async {
    print(jsonEncode(<String, Object?>{
      'type': 'test_group_header',
      'testTheory': 'INV',
      'contract':
          'StorageService ops stay within their SQL statement budget and return identical results (SNAP hash) before and after optimisation',
      'implication':
          'an N+1 query pattern grows with data size, or an optimisation silently changes returned rows/order — slow screens or wrong data',
    }));

    counter = _Counter();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(counter));
    storage = StorageService(database: db);

    final base = DateTime(2026, 1, 1);
    for (var idx = 0; idx < 200; idx++) {
      final day = idx ~/ 2;
      final isBreakfast = idx.isEven;
      final mealId = await storage.saveMeal(
        MealEntry(
          date: DateTime(2026, 1, 1 + day),
          time: isBreakfast ? '08:00' : '18:30',
          mealType: isBreakfast ? 'breakfast' : 'dinner',
          createdAt: base.add(Duration(minutes: idx)),
        ),
        [
          for (var j = 0; j < 4; j++)
            FoodItem(
              mealId: 0,
              name: 'food ${idx % 37}-$j',
              calories: 100 + j * 10,
              protein: 5 + j,
              carbs: 10 + j,
              fat: 2 + j,
              servings: j == 3 ? 0.5 : 1.0,
            ),
        ],
        [
          for (var j = 0; j < 4; j++)
            [
              for (var k = 0; k < 3; k++)
                Ingredient(foodItemId: 0, name: 'ing $j-$k'),
            ],
        ],
      );
      if (idx % 5 == 0) {
        await storage.saveReactionLog(ReactionLog(
          mealId: mealId,
          checkinTime: DateTime(2026, 1, 1 + day, 20, 0),
          symptoms: const ['Bloating'],
          symptomLevels: const {'Bloating': ReactionLevel.mild},
          severity: ReactionLevel.mild,
        ));
      }
    }
    for (var i = 0; i < 10; i++) {
      await storage.saveReactionLog(ReactionLog(
        checkinTime: DateTime(2026, 3, 1 + i, 12, 0),
        symptoms: const ['Nausea'],
        symptomLevels: const {'Nausea': ReactionLevel.moderate},
        severity: ReactionLevel.moderate,
      ));
    }
    for (var i = 0; i < 20; i++) {
      await storage.saveMedication(Medication(
        date: DateTime(2026, 1, 1 + i * 5),
        time: '09:00',
        name: 'med ${i % 4}',
        dose: 10,
        unit: 'mg',
        route: 'oral',
        checkinDelayMinutes: 90,
        createdAt: base.add(Duration(minutes: i)),
      ));
    }

    // saveMeal fires recordFingerprint unawaited; let all 200 land so they
    // neither pollute the counted ops nor race the close.
    for (var attempt = 0; attempt < 200; attempt++) {
      if (await countRows('meal_fingerprints') >= 200) break;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  });

  tearDownAll(() async {
    await db.close();
  });

  test('query budget + snapshot per StorageService op', () async {
    Future<T> perf<T>(String op, Future<T> Function() action) async {
      counter.count = 0;
      final sw = Stopwatch()..start();
      final result = await action();
      sw.stop();
      final n = counter.count;
      print('PERF $op queries=$n ms=${sw.elapsedMilliseconds}');
      final budget = kQueryBudgets[op];
      if (budget != null) {
        expect(n, lessThanOrEqualTo(budget),
            reason: '$op issued $n statements, budget $budget');
      }
      return result;
    }

    final ids = (await storage.getAllMeals()).map((m) => m.id!).toList();

    // 1
    final totals = await perf('macroTotals_all',
        () => storage.getMacroTotalsForMeals(ids));
    _snap('macroTotals_all', [
      '${totals.cal}|${_f(totals.prot)}|${_f(totals.carbs)}|${_f(totals.fat)}',
    ]);

    // 2
    final one = await perf('itemsWithIngredients_one',
        () => storage.getFoodItemsWithIngredients(ids.first));
    _snap('itemsWithIngredients_one', _itemsWithIngLines(one));

    // 3
    final all = await perf('itemsWithIngredients_all', () async {
      final out = <({FoodItem item, List<Ingredient> ingredients})>[];
      for (final id in ids) {
        out.addAll(await storage.getFoodItemsWithIngredients(id));
      }
      return out;
    });
    _snap('itemsWithIngredients_all', _itemsWithIngLines(all));

    // 4
    final blame = await perf(
        'blameCandidates_48h',
        () => storage.getBlameCandidates(
              anchor: DateTime(2026, 2, 15, 12, 0),
              window: const Duration(hours: 48),
            ));
    _snap('blameCandidates_48h', [
      for (final c in blame)
        [
          c.type.name,
          c.targetId,
          c.name,
          _s(c.canonicalName),
          c.timestamp.toIso8601String(),
          _s(c.subtitle),
        ].join('|'),
    ]);

    // 5
    final range = await perf(
        'mealsInRange_7d',
        () => storage.getMealsInRange(
              from: DateTime(2026, 2, 1),
              to: DateTime(2026, 2, 7),
            ));
    _snap('mealsInRange_7d', range.map(_mealLine).toList());

    // 6
    final allMeals = await perf('allMeals', () => storage.getAllMeals());
    _snap('allMeals', allMeals.map(_mealLine).toList());

    // 7
    final perMeal = await perf('reactionLogsForMeal_all', () async {
      final out = <ReactionLog>[];
      for (final id in ids) {
        out.addAll(await storage.getReactionLogsForMeal(id));
      }
      return out;
    });
    _snap('reactionLogsForMeal_all', perMeal.map(_reactionLine).toList());

    // 8
    final standalone = await perf('standaloneReactionLogs',
        () => storage.getStandaloneReactionLogs());
    _snap('standaloneReactionLogs', standalone.map(_reactionLine).toList());

    // Seed sanity, before the mutating ops.
    expect(allMeals.length, 200, reason: 'seed meals');
    expect(await countRows('food_items'), 800, reason: 'seed food items');
    expect(await countRows('ingredients'), 2400, reason: 'seed ingredients');

    // 9
    final target = (await storage.getMealById(ids[10]))!;
    await perf(
        'updateMeal_one',
        () => storage.updateMeal(
              target,
              [
                for (var j = 0; j < 2; j++)
                  FoodItem(mealId: target.id!, name: 'updated-$j'),
              ],
              [
                for (var j = 0; j < 2; j++)
                  [
                    for (var k = 0; k < 2; k++)
                      Ingredient(foodItemId: 0, name: 'updated-ing $j-$k'),
                  ],
              ],
            ));
    _snap('updateMeal_one',
        _itemsWithIngLines(await storage.getFoodItemsWithIngredients(ids[10])));

    // 10
    await perf('deleteMeal_one', () => storage.deleteMeal(ids[20]));
    _snap('deleteMeal_one', [
      for (final t in ['meals', 'food_items', 'ingredients', 'reaction_logs'])
        '${await countRows(t)}',
    ]);

    // Query plans (not counted).
    const plans = <String, String>{
      'foodItemsByMeal': 'SELECT * FROM food_items WHERE meal_id = 1',
      'ingredientsByItem': 'SELECT * FROM ingredients WHERE food_item_id = 1',
      'mealsByDate':
          'SELECT * FROM meals WHERE date >= 0 AND date < 9999999999 ORDER BY date DESC',
      'reactionsByMeal': 'SELECT * FROM reaction_logs WHERE meal_id = 1',
      'standaloneReactions':
          'SELECT * FROM reaction_logs WHERE meal_id IS NULL ORDER BY checkin_time DESC',
    };
    for (final e in plans.entries) {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN ${e.value}').get();
      print('PLAN ${e.key} ${rows.map((r) => r.data['detail']).join(' ; ')}');
    }
  });
}
