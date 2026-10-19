// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

const _newIndexes = [
  'idx_food_items_meal',
  'idx_ingredients_food_item',
  'idx_meals_date',
  'idx_reaction_logs_meal',
  'idx_reaction_logs_checkin',
  'idx_medications_date',
];

const _olderIndexes = [
  'idx_fingerprints_date',
  'idx_fingerprints_type',
  'idx_suspicion_target',
  'idx_suspicion_log',
  'idx_exclusion_log',
];

Future<Set<String>> _indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('[INV] v15 lookup indexes — fresh install', () {
    test('onCreate creates the six new indexes and every older index', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final names = await _indexNames(db);
      expect(names, containsAll(_newIndexes));
      expect(names, containsAll(_olderIndexes));
    });
  });

  group('[INV] v15 lookup indexes — upgrade 14 -> 15', () {
    late Directory tmp;
    late File file;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fj_v15_');
      file = File('${tmp.path}${Platform.pathSeparator}db.sqlite');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('preserves data, adds indexes, bumps user_version to current', () async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement(
        'INSERT INTO meals (id, date, time, meal_type, created_at) '
        "VALUES (1, 1700000000, '12:30', 'lunch', 1700000000)",
      );
      await seed.customStatement(
        "INSERT INTO food_items (id, meal_id, name) VALUES (1, 1, 'rice')",
      );
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      for (final n in _newIndexes) {
        rawDb.execute('DROP INDEX $n');
      }
      rawDb.execute('PRAGMA user_version = 14');
      rawDb.dispose();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final names = await _indexNames(db);
      expect(names, containsAll(_newIndexes));

      final meal = await db
          .customSelect('SELECT id, time, meal_type FROM meals')
          .get();
      expect(meal, hasLength(1));
      expect(meal.single.read<int>('id'), 1);
      expect(meal.single.read<String>('time'), '12:30');
      expect(meal.single.read<String>('meal_type'), 'lunch');

      final item = await db
          .customSelect('SELECT id, meal_id, name FROM food_items')
          .get();
      expect(item, hasLength(1));
      expect(item.single.read<int>('meal_id'), 1);
      expect(item.single.read<String>('name'), 'rice');

      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), AppDatabase.currentSchemaVersion);
    });
  });
}
