import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/receipt_parser.dart';
import 'receipt_ocr_service.dart';

/// A read receipt waiting for review. [ocrText] is the item region only.
class ReadyReceipt {
  final String id;
  final DateTime createdAt;
  final String ocrText;
  final List<ParsedReceiptItem> items;

  const ReadyReceipt({
    required this.id,
    required this.createdAt,
    required this.ocrText,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'ocrText': ocrText,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory ReadyReceipt.fromJson(Map<String, dynamic> j) {
    try {
      return ReadyReceipt(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        ocrText: j['ocrText'] as String,
        items: (j['items'] as List)
            .map((e) => ParsedReceiptItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Bad ReadyReceipt shape: $e');
    }
  }
}

/// Receipt photos waiting to be read, read one at a time, plus read receipts waiting
/// for review. Files are the queue: `<dir>/<id>.jpg` waits to be read, `<dir>/<id>.json`
/// waits for review.
class ReceiptQueue extends ChangeNotifier {
  ReceiptQueue({
    required ReceiptReader reader,
    required Future<Directory> Function() directory,
    DateTime Function()? clock,
  })  : _reader = reader,
        _directory = directory,
        _clock = clock ?? DateTime.now;

  /// App-wide queue: OnnxReceiptReader, `<getApplicationCacheDirectory()>/receipt_queue`.
  static final ReceiptQueue shared = ReceiptQueue(
    reader: OnnxReceiptReader(),
    directory: () async {
      final base = await getApplicationCacheDirectory();
      return Directory('${base.path}${Platform.pathSeparator}receipt_queue');
    },
  );

  final ReceiptReader _reader;
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  late Directory _dir;
  Future<void>? _started;
  final List<String> _waiting = [];
  final Map<String, DateTime> _createdAt = {};
  final List<ReadyReceipt> _ready = [];
  final List<Completer<void>> _idleWaiters = [];
  int _failed = 0;
  int _lastId = 0;
  bool _running = false;

  int get readingCount => _waiting.length;
  List<ReadyReceipt> get ready => List.unmodifiable(_ready);
  int get failedCount => _failed;

  String _path(String id, String ext) => '${_dir.path}${Platform.pathSeparator}$id$ext';

  String _basename(FileSystemEntity e, String ext) {
    final name = e.path.split(RegExp(r'[\\/]')).last;
    return name.substring(0, name.length - ext.length);
  }

  Future<void> start() => _started ??= _start();

  Future<void> _start() async {
    _dir = await _directory();
    await _dir.create(recursive: true);
    final entries = await _dir.list().where((e) => e is File).toList();

    for (final e in entries) {
      if (e.path.endsWith('.json.tmp')) {
        await _tryDelete(e);
      } else if (e.path.endsWith('.json')) {
        try {
          final decoded = jsonDecode(await (e as File).readAsString());
          _ready.add(ReadyReceipt.fromJson(decoded as Map<String, dynamic>));
        } catch (_) {
          await _tryDelete(e);
        }
      }
    }
    _ready.sort((a, b) => a.id.compareTo(b.id));

    final photos = <String>[];
    for (final e in entries) {
      if (!e.path.endsWith('.jpg')) continue;
      final id = _basename(e, '.jpg');
      final micros = int.tryParse(id);
      if (micros == null) {
        await _tryDelete(e);
        continue;
      }
      photos.add(id);
      _createdAt[id] = DateTime.fromMicrosecondsSinceEpoch(micros);
    }
    photos.sort();
    _waiting.addAll(photos);

    notifyListeners();
    if (_waiting.isNotEmpty) _kick();
  }

  Future<void> add(Uint8List photo) async {
    await start();
    final now = _clock();
    var micros = now.microsecondsSinceEpoch;
    if (micros <= _lastId) micros = _lastId + 1;
    _lastId = micros;
    final id = micros.toString();
    final file = File(_path(id, '.jpg'));
    await file.writeAsBytes(photo, flush: true);
    _createdAt[id] = now;
    _waiting.add(id);
    notifyListeners();
    _kick();
  }

  Future<void> remove(String id) async {
    await _tryDelete(File(_path(id, '.json')));
    _ready.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void dismissFailed() {
    _failed = 0;
    notifyListeners();
  }

  Future<void> whenIdle() {
    if (_waiting.isEmpty) return Future.value();
    final c = Completer<void>();
    _idleWaiters.add(c);
    return c.future;
  }

  void _kick() {
    if (_running) return;
    _running = true;
    unawaited(_work());
  }

  Future<void> _work() async {
    while (_waiting.isNotEmpty) {
      final id = _waiting.first;
      try {
        final bytes = await File(_path(id, '.jpg')).readAsBytes();
        final lines = await _reader.readLines(bytes);
        final text = lines.join('\n');
        final receipt = ReadyReceipt(
          id: id,
          createdAt: _createdAt[id] ?? DateTime.fromMicrosecondsSinceEpoch(int.parse(id)),
          ocrText: receiptItemRegion(text),
          items: mergeReceiptItems(parseReceiptText(text)),
        );
        final tmp = File(_path(id, '.json.tmp'));
        await tmp.writeAsString(jsonEncode(receipt.toJson()), flush: true);
        await tmp.rename(_path(id, '.json'));
        await File(_path(id, '.jpg')).delete();
        _ready
          ..add(receipt)
          ..sort((a, b) => a.id.compareTo(b.id));
      } catch (_) {
        await _tryDelete(File(_path(id, '.jpg')));
        await _tryDelete(File(_path(id, '.json.tmp')));
        _failed++;
      } finally {
        _waiting.remove(id);
        _createdAt.remove(id);
        notifyListeners();
      }
    }
    _running = false;
    final waiters = List<Completer<void>>.of(_idleWaiters);
    _idleWaiters.clear();
    for (final c in waiters) {
      c.complete();
    }
  }

  Future<void> _tryDelete(FileSystemEntity e) async {
    try {
      if (await e.exists()) await e.delete();
    } catch (_) {}
  }
}
