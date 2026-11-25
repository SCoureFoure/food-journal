// ignore_for_file: depend_on_referenced_packages
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/services/watch_folder.dart';
import 'package:food_journal/services/watch_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

class _FakeAccess implements WatchFolderAccess {
  WatchFileStat? statResult;
  String? copyResult;
  bool lost = false;
  int statCalls = 0;
  int copyCalls = 0;

  @override
  Future<WatchFolderLink?> pickFolder() async => null;

  @override
  Future<WatchFileStat?> stat(String uri, String name) async {
    statCalls++;
    if (lost) throw const WatchFolderAccessLost();
    return statResult;
  }

  @override
  Future<String?> copy(String uri, String name) async {
    copyCalls++;
    if (lost) throw const WatchFolderAccessLost();
    return copyResult;
  }
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late StorageService storage;
  late SettingsService settings;
  late _FakeAccess access;
  late WatchSyncService sync;

  String makeDb(String name) {
    final p = '${tmp.path}${Platform.pathSeparator}$name';
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
    final sec = DateTime(2026, 11, 22, 8).millisecondsSinceEpoch ~/ 1000;
    f.execute(
        'INSERT INTO KEEPHEALTH_ACTIVITY_SAMPLE VALUES (?, 1, 1, 120, 0, 0)', [sec]);
    f.dispose();
    return p;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('fj_sync_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = StorageService(database: db);
    settings = SettingsService();
    access = _FakeAccess()
      ..statResult = const WatchFileStat(1000, 10)
      ..copyResult = makeDb('good.db');
    sync = WatchSyncService(storage: storage, settings: settings, access: access);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('[MFT] auto import only when newer (AC11)', () {
    // testTheory: MFT
    // contract: a first sync imports and stores the file time; the same time copies nothing; a changed time imports again; force ignores the stored time.
    // implication: AC11 — if this fails, the app re-imports on every resume or never picks up a fresh export.
    test('imports, skips unchanged, re-imports when changed, force overrides', () async {
      await settings.setWatchFolder(const WatchFolderLink('content://x', 'Internal storage/Documents/Gadgetbridge'));

      final first = await sync.syncIfNewer();
      expect(first.state, WatchSyncState.imported);
      expect(first.result!.changed, 1);
      expect(await settings.watchDbLastModified, 1000);
      expect(access.copyCalls, 1);

      final second = await sync.syncIfNewer();
      expect(second.state, WatchSyncState.unchanged);
      expect(access.copyCalls, 1);

      access.statResult = const WatchFileStat(2000, 10);
      final third = await sync.syncIfNewer();
      expect(third.state, WatchSyncState.imported);
      expect(access.copyCalls, 2);
      expect(await settings.watchDbLastModified, 2000);

      final forced = await sync.syncIfNewer(force: true);
      expect(forced.state, WatchSyncState.imported);
      expect(access.copyCalls, 3);
    });
  });

  group('[MFT] silent failure states (AC12)', () {
    // testTheory: MFT
    // contract: no folder, a missing file, a lost grant or a bad file each return their state without throwing and never store a new time.
    // implication: AC12 — if this fails, a missing export crashes app start or poisons the stored time so good data is skipped.
    test('no uri -> notLinked', () async {
      final o = await sync.syncIfNewer();
      expect(o.state, WatchSyncState.notLinked);
      expect(access.statCalls, 0);
    });

    test('stat null -> missing', () async {
      await settings.setWatchFolder(const WatchFolderLink('content://x', 'l'));
      access.statResult = null;
      final o = await sync.syncIfNewer();
      expect(o.state, WatchSyncState.missing);
      expect(await settings.watchDbLastModified, isNull);
    });

    test('access lost -> noAccess', () async {
      await settings.setWatchFolder(const WatchFolderLink('content://x', 'l'));
      access.lost = true;
      final o = await sync.syncIfNewer();
      expect(o.state, WatchSyncState.noAccess);
      expect(await settings.watchDbLastModified, isNull);
    });

    test('non-SQLite copy -> failed, time not stored', () async {
      await settings.setWatchFolder(const WatchFolderLink('content://x', 'l'));
      final bad = '${tmp.path}${Platform.pathSeparator}bad.db';
      File(bad).writeAsStringSync('this is not sqlite');
      access.copyResult = bad;
      final o = await sync.syncIfNewer();
      expect(o.state, WatchSyncState.failed);
      expect(o.error, isNotNull);
      expect(await settings.watchDbLastModified, isNull);
    });
  });
}
