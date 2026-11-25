// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/watch_sample.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

void main() {
  group('[INV] v19 watch_samples — upgrade', () {
    // testTheory: invariance — upgrade adds the table and preserves old rows.
    // contract: the from<19 step creates watch_samples with a unique (kind, timestamp);
    //   existing rows in other tables are untouched.
    // implication: AC8 — existing users keep their journal and gain watch import.
    late Directory tmp;
    late File file;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fj_v19_');
      file = File('${tmp.path}${Platform.pathSeparator}db.sqlite');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('AC8: v18 database gains watch_samples, unique key holds, water row intact',
        () async {
      final seed = AppDatabase.forTesting(NativeDatabase(file));
      await seed.customStatement('SELECT 1');
      await seed.close();

      final rawDb = raw.sqlite3.open(file.path);
      rawDb.execute('DROP TABLE watch_samples');
      rawDb.execute(
        'INSERT INTO water_logs (id, date, time, amount_ml, created_at) '
        "VALUES (1, 1700000000, '08:00', 250, 1700000000)",
      );
      rawDb.execute('PRAGMA user_version = 18');
      rawDb.dispose();

      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(tables.map((r) => r.read<String>('name')), contains('watch_samples'));

      // A raw duplicate (kind, timestamp) insert must fail on the unique key.
      await db.customStatement(
        'INSERT INTO watch_samples (kind, timestamp, value, imported_at) '
        "VALUES ('hr', 1700000000, 70, 1700000000)",
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO watch_samples (kind, timestamp, value, imported_at) '
          "VALUES ('hr', 1700000000, 71, 1700000000)",
        ),
        throwsA(anything),
      );

      // Upsert over the same slot keeps one row with the new value.
      final storage = StorageService(database: db);
      final t = DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000);
      expect(
        await storage.upsertWatchSamples([
          WatchSample(kind: WatchKind.hr, time: t, value: 90),
        ]),
        1,
      );
      final rows = await storage.getWatchSamples(
          from: DateTime(2000), to: DateTime(2100));
      expect(rows, [WatchSample(kind: WatchKind.hr, time: t, value: 90)]);

      final water = await storage.getAllWaterLogs();
      expect(water, hasLength(1));
      expect(water.single.amountMl, 250);
    });
  });
}
