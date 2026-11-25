// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/watch_sample.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/services/watch_import_service.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

void main() {
  late Directory tmp;
  late AppDatabase db;
  late StorageService storage;
  late WatchImportService service;

  String path(String name) => '${tmp.path}${Platform.pathSeparator}$name';

  /// Builds a Gadgetbridge-shaped SQLite file. [activity] rows are
  /// (TIMESTAMP, STEPS, RAW_KIND); [hr] rows are (TIMESTAMP, HEART_RATE).
  String makeDb(
    String name, {
    List<List<int>> activity = const [],
    List<List<int>> hr = const [],
  }) {
    final p = path(name);
    final f = raw.sqlite3.open(p);
    f.execute('''
      CREATE TABLE KEEPHEALTH_ACTIVITY_SAMPLE (
        TIMESTAMP INTEGER NOT NULL, DEVICE_ID INTEGER NOT NULL, USER_ID INTEGER NOT NULL,
        STEPS INTEGER NOT NULL, HEART_RATE INTEGER NOT NULL, RAW_KIND INTEGER NOT NULL
      )
    ''');
    f.execute('''
      CREATE TABLE GENERIC_HEART_RATE_SAMPLE (
        TIMESTAMP INTEGER NOT NULL, DEVICE_ID INTEGER NOT NULL, USER_ID INTEGER NOT NULL,
        HEART_RATE INTEGER NOT NULL
      )
    ''');
    for (final a in activity) {
      f.execute(
        'INSERT INTO KEEPHEALTH_ACTIVITY_SAMPLE VALUES (?, 1, 1, ?, 0, ?)',
        [a[0], a[1], a[2]],
      );
    }
    for (final h in hr) {
      f.execute('INSERT INTO GENERIC_HEART_RATE_SAMPLE VALUES (?, 1, 1, ?)', [h[0], h[1]]);
    }
    f.dispose();
    return p;
  }

  Future<List<WatchSample>> stored() =>
      storage.getWatchSamples(from: DateTime(2000), to: DateTime(2100));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fj_watch_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = StorageService(database: db);
    service = WatchImportService(storage);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  // 2026-11-22 08:00 local.
  final t0 = DateTime(2026, 11, 22, 8);
  final sec0 = t0.millisecondsSinceEpoch ~/ 1000;
  final ms0 = t0.millisecondsSinceEpoch;

  group('[MFT] import lands samples (AC1)', () {
    // testTheory: MFT
    // contract: one steps/sleep/hr row per non-zero slot with the correct local time; seconds and milliseconds timestamps both decode; zero rows are absent.
    // implication: AC1 — if this fails, the journal shows shifted or phantom watch data.
    test('seconds activity rows and ms hr rows land; zero rows absent', () async {
      final p = makeDb(
        'a.db',
        activity: [
          [sec0, 120, 0], // steps only
          [sec0 + 600, 0, 3], // sleep only
          [sec0 + 1200, 50, 2], // both
          [sec0 + 1800, 0, 0], // zero row
        ],
        hr: [
          [ms0, 70],
          [ms0 + 900000, 0],
        ],
      );
      final r = await service.importGadgetbridge(p);
      expect(r.read, 5);
      expect(r.changed, 5);
      expect(r.first, t0);
      expect(r.last, t0.add(const Duration(minutes: 20)));

      final rows = await stored();
      expect(rows, hasLength(5));
      expect(
        rows,
        containsAll([
          WatchSample(kind: WatchKind.steps, time: t0, value: 120),
          WatchSample(
              kind: WatchKind.sleep, time: t0.add(const Duration(minutes: 10)), value: 3),
          WatchSample(
              kind: WatchKind.steps, time: t0.add(const Duration(minutes: 20)), value: 50),
          WatchSample(
              kind: WatchKind.sleep, time: t0.add(const Duration(minutes: 20)), value: 2),
          WatchSample(kind: WatchKind.hr, time: t0, value: 70),
        ]),
      );
    });
  });

  group('[INV] re-import is idempotent (AC2)', () {
    // testTheory: INV
    // contract: importing the same file twice changes nothing; a changed slot value replaces the stored one and counts as 1.
    // implication: AC2 — if this fails, re-imports duplicate rows or keep stale values.
    test('second import changed 0; edited value changed 1 and stored', () async {
      final p = makeDb('b.db', activity: [
        [sec0, 100, 0],
        [sec0 + 600, 200, 0],
      ]);
      expect((await service.importGadgetbridge(p)).changed, 2);
      expect((await service.importGadgetbridge(p)).changed, 0);
      expect(await stored(), hasLength(2));

      final f = raw.sqlite3.open(p);
      f.execute('UPDATE KEEPHEALTH_ACTIVITY_SAMPLE SET STEPS = 250 WHERE TIMESTAMP = ?',
          [sec0 + 600]);
      f.dispose();

      expect((await service.importGadgetbridge(p)).changed, 1);
      final rows = await stored();
      expect(rows, hasLength(2));
      expect(rows.last.value, 250);
    });
  });

  group('[MFT] invalid files are rejected (AC3)', () {
    // testTheory: MFT
    // contract: non-SQLite, SQLite without Gadgetbridge tables, and .zip paths throw WatchImportException and write nothing.
    // implication: AC3 — if this fails, a wrong file pick corrupts or silently no-ops the import.
    test('text file throws and table stays empty', () async {
      final p = path('c.db');
      File(p).writeAsStringSync('this is not a database');
      await expectLater(
        service.importGadgetbridge(p),
        throwsA(isA<WatchImportException>()
            .having((e) => e.message, 'message', 'Not a Gadgetbridge database.')),
      );
      expect(await stored(), isEmpty);
    });

    test('SQLite with unrelated table throws and table stays empty', () async {
      final p = path('d.db');
      final f = raw.sqlite3.open(p);
      f.execute('CREATE TABLE other (x INTEGER)');
      f.dispose();
      await expectLater(
        service.importGadgetbridge(p),
        throwsA(isA<WatchImportException>()),
      );
      expect(await stored(), isEmpty);
    });

    test('.zip path throws the zip message', () async {
      final p = path('Gadgetbridge.ZIP');
      File(p).writeAsBytesSync([0x50, 0x4B, 3, 4]);
      await expectLater(
        service.importGadgetbridge(p),
        throwsA(isA<WatchImportException>().having((e) => e.message, 'message',
            'That is the zipped export. Pick Gadgetbridge.db instead.')),
      );
      expect(await stored(), isEmpty);
    });
  });

  group('[BVA] heart-rate range filter (AC4)', () {
    // testTheory: BVA
    // contract: hr rows of 0, 12 and 300 bpm are not stored; 25 and 240 are.
    // implication: AC4 — if this fails, sensor garbage skews the day's heart-rate range.
    test('0, 12, 300 absent; 25 and 240 kept', () async {
      final p = makeDb('e.db', hr: [
        [ms0, 0],
        [ms0 + 900000, 12],
        [ms0 + 1800000, 300],
        [ms0 + 2700000, 25],
        [ms0 + 3600000, 240],
      ]);
      await service.importGadgetbridge(p);
      final rows = await stored();
      expect(rows.map((s) => s.value), [25, 240]);
    });
  });
}
