// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

Future<List<String>> _columns(AppDatabase db) async {
  final rows = await db.customSelect('PRAGMA table_info(goal_history)').get();
  return rows
      .map((r) => '${r.read<String>('name')}:${r.read<String>('type')}')
      .toList();
}

void main() {
  group('[INV] v17 goal_history — fresh install', () {
    // testTheory: invariance — onCreate and onUpgrade reach the same schema.
    // contract: a fresh database contains the goal_history table.
    // implication: AC1 — new installs can store goals.
    test('goal_history exists in sqlite_master', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final rows = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'goal_history'")
          .get();
      expect(rows, hasLength(1));
    });
  });

  group('[INV] v17 goal_history — upgrade 16 -> 17', () {
    // testTheory: invariance — upgrade preserves data and matches fresh schema.
    // contract: the from<17 step creates goal_history, keeps existing rows, and
    //   bumps user_version; columns equal a fresh install's.
    // implication: AC1 — existing users keep their journal and gain goals.
    late Directory tmp;
    late File file;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fj_v17_');
      file = File('${tmp.path}${Platform.pathSeparator}db.sqlite');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<void> seedAndDowngrade() async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement(
        'INSERT INTO meals (id, date, time, meal_type, created_at) '
        "VALUES (1, 1700000000, '12:30', 'lunch', 1700000000)",
      );
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      rawDb.execute('DROP TABLE goal_history');
      rawDb.execute('PRAGMA user_version = 16');
      rawDb.dispose();
    }

    test('creates table, keeps data, bumps version, saves work', () async {
      await seedAndDowngrade();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final tables = await db
          .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'goal_history'")
          .get();
      expect(tables, hasLength(1));

      final meal = await db.customSelect('SELECT id, time, meal_type FROM meals').get();
      expect(meal, hasLength(1));
      expect(meal.single.read<int>('id'), 1);
      expect(meal.single.read<String>('time'), '12:30');
      expect(meal.single.read<String>('meal_type'), 'lunch');

      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), AppDatabase.currentSchemaVersion);

      final storage = StorageService(database: db);
      await storage.saveGoals(const DailyGoals(calories: 2000),
          now: DateTime(2026, 11, 10, 12));
      final h = await storage.getGoalHistory();
      expect(h, hasLength(1));
      expect(h.single.goals, const DailyGoals(calories: 2000));
    });

    test('upgraded and fresh column names and types match', () async {
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshCols = await _columns(fresh);
      expect(freshCols, isNotEmpty);

      await seedAndDowngrade();
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      expect(await _columns(upgraded), freshCols);
    });
  });
}
