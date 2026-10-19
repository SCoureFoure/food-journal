// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pantry_item.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

PantryItem _item(String name, {double qty = 1, String unit = 'ea', DateTime? at, String? rawText}) =>
    PantryItem(
      name: name,
      quantity: qty,
      unit: unit,
      source: 'receipt',
      rawText: rawText,
      addedAt: at ?? DateTime(2026, 10, 19, 12),
    );

void main() {
  group('[MFT] pantry storage round trip', () {
    // testTheory: minimum functionality — what the review screen saves is what
    //   the pantry card reads back.
    // contract: addPantryItems stores name, quantity, unit, source, raw text and
    //   addedAt; getPantryItems returns newest addedAt first (id desc on ties);
    //   deletePantryItem removes one row.
    // implication: AC14/AC17 — the pantry is the receipt feature's only output.

    late AppDatabase db;
    late StorageService storage;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storage = StorageService(database: db);
    });
    tearDown(() => db.close());

    test('AC14: saved rows read back with every field', () async {
      await storage.addPantryItems([
        _item('Sweet potatoes', qty: 2.26, unit: 'lb', rawText: 'SWEET POTATOES BULK'),
      ]);
      final rows = await storage.getPantryItems();
      expect(rows, hasLength(1));
      final r = rows.single;
      expect(r.id, isNotNull);
      expect(r.name, 'Sweet potatoes');
      expect(r.quantity, 2.26);
      expect(r.unit, 'lb');
      expect(r.source, 'receipt');
      expect(r.rawText, 'SWEET POTATOES BULK');
      expect(r.addedAt, DateTime(2026, 10, 19, 12));
    });

    test('AC14: canonical name is written for the food ledger', () async {
      await storage.addPantryItems([_item('  Green Onions! ')]);
      final row = await db.customSelect('SELECT canonical_name FROM pantry_items').getSingle();
      expect(row.read<String>('canonical_name'), 'green onions');
    });

    test('AC17: newest first, id desc on ties', () async {
      await storage.addPantryItems([
        _item('old', at: DateTime(2026, 10, 1)),
        _item('tie-a', at: DateTime(2026, 10, 19)),
        _item('tie-b', at: DateTime(2026, 10, 19)),
      ]);
      final names = (await storage.getPantryItems()).map((p) => p.name).toList();
      expect(names, ['tie-b', 'tie-a', 'old']);
    });

    test('AC17: delete removes exactly one row', () async {
      await storage.addPantryItems([_item('a'), _item('b')]);
      final rows = await storage.getPantryItems();
      await storage.deletePantryItem(rows.first.id!);
      expect((await storage.getPantryItems()).map((p) => p.name), [rows.last.name]);
    });

    test('empty add is a no-op', () async {
      await storage.addPantryItems(const []);
      expect(await storage.getPantryItems(), isEmpty);
    });
  });

  group('[MFT] getKnownFoodNames', () {
    // testTheory: minimum functionality — the AI gets the user's own food
    //   names so it reuses them instead of inventing variants.
    // contract: one name per canonical key, most-logged first, then name asc;
    //   capped at [limit].
    // implication: decision 9 — known names keep receipt names consistent
    //   with the journal.

    late AppDatabase db;
    late StorageService storage;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      storage = StorageService(database: db);
      await db.customStatement(
        "INSERT INTO meals (id, date, time, meal_type, created_at) VALUES (1, 1700000000, '12:00', 'lunch', 1700000000)",
      );
      var id = 1;
      for (final (name, canon) in [
        ('Rice', 'rice'),
        ('rice', 'rice'),
        ('RICE', 'rice'),
        ('Eggs', 'eggs'),
        ('eggs', 'eggs'),
        ('Apple', 'apple'),
      ]) {
        await db.customStatement(
          'INSERT INTO food_items (id, meal_id, name, canonical_name) VALUES (?, 1, ?, ?)',
          [id++, name, canon],
        );
      }
    });
    tearDown(() => db.close());

    test('dedupes by canonical key and ranks by count', () async {
      final names = await storage.getKnownFoodNames();
      expect(names.map((n) => n.toLowerCase()), ['rice', 'eggs', 'apple']);
    });

    test('respects the limit', () async {
      expect(await storage.getKnownFoodNames(limit: 2), hasLength(2));
    });
  });

  group('[INV] v16 migration adds pantry_items and keeps journal data', () {
    // testTheory: invariant — an additive migration never touches existing rows.
    // contract: upgrading a v15 file creates pantry_items and sets
    //   user_version to 16; meals survive unchanged.
    // implication: AC16 — schema = contract.

    late Directory tmp;
    late File file;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fj_v16_');
      file = File('${tmp.path}${Platform.pathSeparator}db.sqlite');
    });
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('AC16: fresh install has pantry_items at v16', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(AppDatabase.currentSchemaVersion, 16);
      final t = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='pantry_items'")
          .get();
      expect(t, hasLength(1));
    });

    test('AC16: v15 file upgrades to v16 with data intact', () async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement(
        "INSERT INTO meals (id, date, time, meal_type, created_at) VALUES (1, 1700000000, '08:00', 'breakfast', 1700000000)",
      );
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      rawDb.execute('DROP TABLE pantry_items');
      rawDb.execute('PRAGMA user_version = 15');
      rawDb.dispose();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final storage = StorageService(database: db);
      await storage.addPantryItems([_item('limes')]);
      expect((await storage.getPantryItems()).single.name, 'limes');

      final meal = await db.customSelect('SELECT meal_type FROM meals').getSingle();
      expect(meal.read<String>('meal_type'), 'breakfast');
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 16);
    });
  });
}
