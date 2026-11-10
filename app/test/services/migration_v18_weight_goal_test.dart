// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

Future<List<String>> _columnNames(AppDatabase db) async {
  final rows = await db.customSelect('PRAGMA table_info(goal_history)').get();
  return rows.map((r) => r.read<String>('name')).toList();
}

void main() {
  group('[INV] v18 goal_history weight goal — upgrade', () {
    // testTheory: invariance — upgrade adds columns and preserves old rows.
    // contract: the from<18 step adds target_weight_lb and weight_direction;
    //   existing rows read them as null and keep their other values.
    // implication: AC19 — existing users keep their goals and gain a weight goal.
    late Directory tmp;
    late File file;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fj_v18_');
      file = File('${tmp.path}${Platform.pathSeparator}db.sqlite');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('AC19: v17 database with one row gains both columns, row reads null',
        () async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement('SELECT 1');
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      rawDb.execute('DROP TABLE goal_history');
      rawDb.execute('''
        CREATE TABLE goal_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          effective_date INTEGER NOT NULL,
          calories INTEGER,
          protein_g INTEGER,
          carbs_g INTEGER,
          fat_g INTEGER,
          water_ml INTEGER,
          created_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        'INSERT INTO goal_history (id, effective_date, calories, created_at) '
        'VALUES (1, 1700000000, 2000, 1700000000)',
      );
      rawDb.execute('PRAGMA user_version = 17');
      rawDb.dispose();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final cols = await _columnNames(db);
      expect(cols, containsAll(['target_weight_lb', 'weight_direction']));

      final h = await StorageService(database: db).getGoalHistory();
      expect(h, hasLength(1));
      expect(h.single.goals.calories, 2000);
      expect(h.single.goals.targetWeightLb, isNull);
      expect(h.single.goals.weightDirection, isNull);
    });

    test('AC19: v16 database upgraded straight to v18 has both columns',
        () async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement('SELECT 1');
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      rawDb.execute('DROP TABLE goal_history');
      rawDb.execute('PRAGMA user_version = 16');
      rawDb.dispose();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final cols = await _columnNames(db);
      expect(cols, containsAll(['target_weight_lb', 'weight_direction']));
    });
  });
}
