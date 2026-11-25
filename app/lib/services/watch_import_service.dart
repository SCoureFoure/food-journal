import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../models/watch_sample.dart';
import 'storage_service.dart';

class WatchImportException implements Exception {
  final String message;
  const WatchImportException(this.message);

  @override
  String toString() => message;
}

class WatchImportResult {
  final int changed; // from upsertWatchSamples
  final int read; // samples read from the file
  final DateTime? first, last; // min/max sample time read, null when read == 0

  const WatchImportResult({
    required this.changed,
    required this.read,
    this.first,
    this.last,
  });
}

class WatchImportService {
  WatchImportService(this._storage);

  final StorageService _storage;

  static const _zipMessage = 'That is the zipped export. Pick Gadgetbridge.db instead.';
  static const _notDbMessage = 'Not a Gadgetbridge database.';

  /// Reads steps, sleep and heart-rate samples from a Gadgetbridge.db file.
  /// Throws [WatchImportException] for a zip, a non-SQLite file, or a SQLite file
  /// without the Gadgetbridge sample tables.
  static List<WatchSample> readGadgetbridge(String path) {
    if (path.toLowerCase().endsWith('.zip')) {
      throw const WatchImportException(_zipMessage);
    }
    final file = File(path);
    try {
      if (!file.existsSync()) throw const WatchImportException(_notDbMessage);
      final raf = file.openSync();
      try {
        final head = raf.readSync(2);
        if (head.length == 2 && head[0] == 0x50 && head[1] == 0x4B) {
          throw const WatchImportException(_zipMessage);
        }
      } finally {
        raf.closeSync();
      }
    } on FileSystemException {
      throw const WatchImportException(_notDbMessage);
    }

    final Database dbFile;
    try {
      dbFile = sqlite3.open(path, mode: OpenMode.readOnly);
    } on SqliteException {
      throw const WatchImportException(_notDbMessage);
    }
    try {
      final tables = dbFile
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      final hasActivity = tables.contains('KEEPHEALTH_ACTIVITY_SAMPLE');
      final hasHr = tables.contains('GENERIC_HEART_RATE_SAMPLE');
      if (!hasActivity && !hasHr) throw const WatchImportException(_notDbMessage);

      final out = <WatchSample>[];
      if (hasActivity) {
        for (final r in dbFile.select(
            'SELECT TIMESTAMP, STEPS, RAW_KIND FROM KEEPHEALTH_ACTIVITY_SAMPLE')) {
          final time = _time(r['TIMESTAMP'] as int);
          final steps = (r['STEPS'] as int?) ?? 0;
          final kind = (r['RAW_KIND'] as int?) ?? 0;
          if (steps > 0) {
            out.add(WatchSample(kind: WatchKind.steps, time: time, value: steps));
          }
          if (kind >= 1 && kind <= 5) {
            out.add(WatchSample(kind: WatchKind.sleep, time: time, value: kind));
          }
        }
      }
      if (hasHr) {
        for (final r
            in dbFile.select('SELECT TIMESTAMP, HEART_RATE FROM GENERIC_HEART_RATE_SAMPLE')) {
          final bpm = (r['HEART_RATE'] as int?) ?? 0;
          if (bpm >= 25 && bpm <= 240) {
            out.add(WatchSample(
                kind: WatchKind.hr, time: _time(r['TIMESTAMP'] as int), value: bpm));
          }
        }
      }
      return out;
    } on SqliteException {
      throw const WatchImportException(_notDbMessage);
    } finally {
      dbFile.dispose();
    }
  }

  static DateTime _time(int ts) =>
      DateTime.fromMillisecondsSinceEpoch(ts > 100000000000 ? ts : ts * 1000);

  Future<WatchImportResult> importGadgetbridge(String path) async {
    final samples = readGadgetbridge(path);
    DateTime? first;
    DateTime? last;
    for (final s in samples) {
      if (first == null || s.time.isBefore(first)) first = s.time;
      if (last == null || s.time.isAfter(last)) last = s.time;
    }
    final changed = await _storage.upsertWatchSamples(samples);
    return WatchImportResult(
      changed: changed,
      read: samples.length,
      first: first,
      last: last,
    );
  }
}
