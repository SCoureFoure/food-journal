import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_parser.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:food_journal/services/receipt_queue.dart';

const _hannaford = [
  'Hannaford',
  'PRODUCE',
  'LIMES W 0.59',
  'GROCERY',
  'PROG TRD CHK ORZ LMN 2.50',
  'PROG TRD CHK ORZ LMN 2.50',
  'HEALTH & BEAUTY',
  'DVE MEN+CARE CDRWD/T 10.49',
  'BALANCE DUE 16.08',
  'VISA 3319',
];

class _GateReader implements ReceiptReader {
  final List<Uint8List> received = [];
  final List<Completer<List<String>>> gates = [];
  int _current = 0;
  int maxConcurrent = 0;

  @override
  Future<List<String>> readLines(Uint8List bytes) {
    received.add(bytes);
    final gate = Completer<List<String>>();
    gates.add(gate);
    _current++;
    if (_current > maxConcurrent) maxConcurrent = _current;
    return gate.future.whenComplete(() => _current--);
  }

  Future<void> waitForCalls(int n) async {
    while (received.length < n) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

void main() {
  late Directory tmp;
  late _GateReader reader;
  late ReceiptQueue queue;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('rq');
    reader = _GateReader();
    queue = ReceiptQueue(reader: reader, directory: () async => tmp);
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  List<String> names() => tmp.listSync().map((e) => e.path.split(RegExp(r'[\\/]')).last).toList()..sort();

  Future<ReadyReceipt> readOne() async {
    await queue.add(Uint8List.fromList([1]));
    await reader.waitForCalls(1);
    reader.gates.first.complete(_hannaford);
    await queue.whenIdle();
    return queue.ready.single;
  }

  group('[MFT] receipt queue', () {
    test('AC8: photo is queued as a file, read, and becomes a ready receipt', () async {
      // testTheory: minimum functionality — the file lifecycle jpg -> json.
      // contract: add writes <id>.jpg and counts as reading; after the read the
      //   jpg is replaced by <id>.json and the receipt is ready with merged items.
      // implication: spec receipt_queue AC8
      await queue.add(Uint8List.fromList([1]));
      expect(names().single, endsWith('.jpg'));
      expect(queue.readingCount, 1);
      await reader.waitForCalls(1);
      reader.gates.single.complete(_hannaford);
      await queue.whenIdle();

      final id = queue.ready.single.id;
      expect(names(), ['$id.json']);
      expect(queue.readingCount, 0);
      expect(queue.ready, hasLength(1));
      final orzo = queue.ready.single.items.firstWhere((i) => i.raw == 'PROG TRD CHK ORZ LMN');
      expect(orzo.qty, 2);
    });

    test('AC9: ocrText is the item region only', () async {
      // testTheory: minimum functionality — payment lines are not retained.
      // contract: ready ocrText ends at BALANCE DUE and omits later lines.
      // implication: spec receipt_queue AC9
      final r = await readOne();
      expect(r.ocrText.endsWith('BALANCE DUE 16.08'), isTrue);
      expect(r.ocrText, isNot(contains('VISA')));
    });

    test('AC10: photos are read one at a time in add order', () async {
      // testTheory: invariant — sequential worker, FIFO.
      // contract: with three photos queued, reads happen in order and never overlap.
      // implication: spec receipt_queue AC10
      await queue.add(Uint8List.fromList([1]));
      await queue.add(Uint8List.fromList([2]));
      await queue.add(Uint8List.fromList([3]));
      for (var n = 1; n <= 3; n++) {
        await reader.waitForCalls(n);
        reader.gates[n - 1].complete(_hannaford);
      }
      await queue.whenIdle();
      expect(reader.received.map((b) => b.single).toList(), [1, 2, 3]);
      expect(reader.maxConcurrent, 1);
      expect(queue.ready, hasLength(3));
    });

    test('AC11: a failed read leaves no files and is counted', () async {
      // testTheory: failure handling — errors clean up and surface as a count.
      // contract: a reader error deletes the photo, adds no receipt, bumps
      //   failedCount; dismissFailed resets it.
      // implication: spec receipt_queue AC11
      await queue.add(Uint8List.fromList([1]));
      await reader.waitForCalls(1);
      reader.gates.single.completeError(Exception('boom'));
      await queue.whenIdle();
      expect(names(), isEmpty);
      expect(queue.failedCount, 1);
      expect(queue.ready, isEmpty);
      queue.dismissFailed();
      expect(queue.failedCount, 0);
    });

    test('AC12: restart recovery re-enqueues photos and reloads receipts', () async {
      // testTheory: restart recovery — files are the queue.
      // contract: start reads valid .json, deletes corrupt .json, re-reads .jpg.
      // implication: spec receipt_queue AC12
      await File('${tmp.path}/1000.jpg').writeAsBytes([9]);
      final saved = ReadyReceipt(
        id: '2000',
        createdAt: DateTime.fromMicrosecondsSinceEpoch(2000),
        ocrText: 'x',
        items: const [ParsedReceiptItem(raw: 'LIMES')],
      );
      await File('${tmp.path}/2000.json').writeAsString(jsonEncode(saved.toJson()));
      await File('${tmp.path}/3000.json').writeAsString('{not json');

      await queue.start();
      expect(queue.ready.map((r) => r.id).toList(), ['2000']);
      expect(File('${tmp.path}/3000.json').existsSync(), isFalse);
      await reader.waitForCalls(1);
      expect(reader.received, hasLength(1));
      reader.gates.single.complete(_hannaford);
      await queue.whenIdle();
      expect(queue.ready.map((r) => r.id).toList(), ['1000', '2000']);
    });

    test('AC13: remove deletes the receipt and notifies', () async {
      // testTheory: minimum functionality — review completion clears the receipt.
      // contract: remove deletes <id>.json, drops it from ready, notifies listeners.
      // implication: spec receipt_queue AC13
      final r = await readOne();
      var notified = 0;
      queue.addListener(() => notified++);
      await queue.remove(r.id);
      expect(File('${tmp.path}/${r.id}.json').existsSync(), isFalse);
      expect(queue.ready, isEmpty);
      expect(notified, greaterThan(0));
    });

    test('round trip: ReadyReceipt JSON keeps every field', () {
      // testTheory: invariant — fromJson(toJson(x)) == x.
      // contract: id, createdAt, ocrText and items survive a JSON encode/decode.
      // implication: spec receipt_queue AC12
      final r = ReadyReceipt(
        id: '42',
        createdAt: DateTime(2026, 10, 19, 12, 30),
        ocrText: 'a\nb',
        items: const [ParsedReceiptItem(raw: 'LIMES', qty: 2.5, unit: 'lb', food: true, name: 'Lime')],
      );
      final back = ReadyReceipt.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.id, '42');
      expect(back.createdAt, r.createdAt);
      expect(back.ocrText, 'a\nb');
      final i = back.items.single;
      expect([i.raw, i.qty, i.unit, i.food, i.name], ['LIMES', 2.5, 'lb', true, 'Lime']);
    });

    test('start is idempotent under concurrent calls', () async {
      // testTheory: invariant — a second start must not re-enqueue files.
      // contract: two concurrent start() calls read a leftover photo once.
      // implication: spec receipt_queue AC12
      await File('${tmp.path}/1000.jpg').writeAsBytes([9]);
      await Future.wait([queue.start(), queue.start()]);
      await reader.waitForCalls(1);
      reader.gates.single.complete(_hannaford);
      await queue.whenIdle();
      expect(reader.received, hasLength(1));
    });
  });
}
