import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pantry_item.dart';
import 'package:food_journal/screens/receipt_review/receipt_review_screen.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:food_journal/services/receipt_queue.dart';
import 'package:food_journal/widgets/pantry_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'receipt_scan_fakes.dart';

/// Reader whose reads block until the test completes the matching gate.
class GatedReader implements ReceiptReader {
  final gates = <Completer<List<String>>>[];

  @override
  Future<List<String>> readLines(Uint8List imageBytes) {
    final c = Completer<List<String>>();
    gates.add(c);
    return c.future;
  }

  /// Release every pending and future read so the queue worker finishes.
  Future<void> drain(WidgetTester tester, ReceiptQueue queue) async {
    for (var i = 0; i < 200 && queue.readingCount > 0; i++) {
      for (final g in gates) {
        if (!g.isCompleted) g.complete(const []);
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
  }
}

Finder _id(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

PantryItem _p(int id, String name, double qty, String unit, DateTime at) => PantryItem(
      id: id,
      name: name,
      quantity: qty,
      unit: unit,
      source: 'receipt',
      addedAt: at,
    );

void main() {
  late FakePantryStorage storage;
  late FakeReceiptReader reader;
  late FakeReceiptAi ai;
  late List<Uint8List> picked;
  late Directory tempDir;
  late ReceiptQueue queue;

  setUp(() {
    storage = FakePantryStorage();
    reader = FakeReceiptReader();
    ai = FakeReceiptAi();
    picked = [Uint8List.fromList([1, 2, 3])];
    tempDir = Directory.systemTemp.createTempSync('pc');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Future<void> pump(WidgetTester tester, {ReceiptReader? queueReader}) async {
    queue = ReceiptQueue(reader: queueReader ?? reader, directory: () async => tempDir);
    await tester.runAsync(() => queue.start());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PantryCard(
            storageOverride: storage,
            queueOverride: queue,
            aiOverride: ai,
            aiEnabledOverride: false,
            pickImagesOverride: (_) async => picked,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // File IO needs the real event loop; poll it, pumping so widget state catches up.
  Future<void> until(WidgetTester tester, bool Function() cond) async {
    for (var i = 0; i < 200 && !cond(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(cond(), isTrue, reason: 'condition not reached');
    // The queue may have notified between the last pump and the check.
    await tester.pump();
  }

  Future<void> seedReady(WidgetTester tester) async {
    await tester.runAsync(() async {
      await queue.add(Uint8List.fromList([9]));
      await queue.whenIdle();
    });
    await tester.pump();
  }

  group('[MFT] formatPantryQuantity', () {
    // testTheory: minimum functionality — counts read as multiples, weights keep
    //   their unit; no trailing zeros.
    // contract: ea -> "×n", lb -> "n lb", numbers without trailing zeros.
    // implication: AC17 — quantities must read naturally in the list.

    test('AC17: count and weight labels', () {
      expect(formatPantryQuantity(2, 'ea'), '×2');
      expect(formatPantryQuantity(1, 'ea'), '×1');
      expect(formatPantryQuantity(2.26, 'lb'), '2.26 lb');
      expect(formatPantryQuantity(0.5, 'lb'), '0.5 lb');
      expect(formatPantryQuantity(2.0, 'lb'), '2 lb');
    });
  });

  group('[MFT] pantry card', () {
    // testTheory: minimum functionality — the card lists the pantry and offers
    //   scan and manual add.
    // contract: empty text + both buttons when empty; rows newest first with
    //   quantity labels; delete removes one row.
    // implication: AC17 / AC18 — the pantry is visible and editable.

    testWidgets('AC18: empty state', (tester) async {
      await pump(tester);
      expect(_id('pantry-card'), findsOneWidget);
      expect(find.text('Nothing in the pantry yet.'), findsOneWidget);
      expect(_id('btn-scan-receipt'), findsOneWidget);
      expect(_id('btn-pantry-add'), findsOneWidget);
    });

    testWidgets('AC17: newest first with labels; delete removes one', (tester) async {
      storage.items.addAll([
        _p(1, 'limes', 2, 'ea', DateTime(2026, 10, 1)),
        _p(2, 'sweet potatoes', 2.26, 'lb', DateTime(2026, 10, 19)),
      ]);
      await pump(tester);

      final first = tester.getTopLeft(_id('item-pantry-2')).dy;
      final second = tester.getTopLeft(_id('item-pantry-1')).dy;
      expect(first, lessThan(second));
      expect(find.text('2.26 lb'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);

      await tester.tap(_id('btn-pantry-delete-2'));
      await tester.pumpAndSettle();
      expect(_id('item-pantry-2'), findsNothing);
      expect(_id('item-pantry-1'), findsOneWidget);
      expect(storage.items.map((p) => p.id), [1]);
    });
  });

  group('[MFT] receipt queue on the card', () {
    // testTheory: minimum functionality — the card shows queue state and drives
    //   review from the queue; scanning only enqueues.
    // contract: status text from readingCount/ready; scan always enabled; Review
    //   opens the oldest ready receipt; save/discard remove it, back keeps it;
    //   a failed read is an inline notice, never a SnackBar.
    // implication: spec receipt_queue AC14-AC18.

    testWidgets('AC14: status text and review button follow the queue', (tester) async {
      final gated = GatedReader();
      await pump(tester, queueReader: gated);
      expect(_id('receipt-queue-status'), findsNothing);
      expect(_id('btn-receipt-review-next'), findsNothing);

      picked = [
        Uint8List.fromList([1]),
        Uint8List.fromList([2]),
        Uint8List.fromList([3]),
      ];
      await tester.tap(_id('btn-scan-receipt'));
      await until(tester, () => gated.gates.length == 1 && queue.readingCount == 3);
      expect(find.text('3 reading…'), findsOneWidget);
      expect(_id('btn-receipt-review-next'), findsNothing);

      gated.gates[0].complete(hannafordLines);
      await until(tester, () => queue.ready.length == 1 && gated.gates.length == 2);
      expect(find.text('2 reading… · 1 ready to review'), findsOneWidget);
      expect(_id('btn-receipt-review-next'), findsOneWidget);

      await gated.drain(tester, queue);
    });

    testWidgets('AC15: scan stays enabled while reading; two photos queue two', (tester) async {
      final gated = GatedReader();
      await pump(tester, queueReader: gated);
      picked = [
        Uint8List.fromList([1]),
        Uint8List.fromList([2]),
      ];
      await tester.tap(_id('btn-scan-receipt'));
      await until(tester, () => queue.readingCount + queue.ready.length == 2);
      expect(queue.readingCount + queue.ready.length, 2);

      final button = tester.widget<FilledButton>(
          find.descendant(of: _id('btn-scan-receipt'), matching: find.byWidgetPredicate((w) => w is FilledButton)));
      expect(button.onPressed, isNotNull);

      await gated.drain(tester, queue);
    });

    testWidgets('cancelled pick queues nothing', (tester) async {
      picked = [];
      await pump(tester);
      await tester.tap(_id('btn-scan-receipt'));
      await tester.pumpAndSettle();
      expect(reader.calls, 0);
      expect(_id('receipt-queue-status'), findsNothing);
      expect(find.byType(ReceiptReviewScreen), findsNothing);
    });

    testWidgets('AC16: review shows merged rows; save clears the queue and lists items',
        (tester) async {
      reader.lines = hannafordLines;
      await pump(tester);
      await seedReady(tester);
      expect(queue.ready.length, 1);

      await tester.tap(_id('btn-receipt-review-next'));
      await tester.pumpAndSettle();
      expect(_id('receipt-review-screen'), findsOneWidget);
      final screen = tester.widget<ReceiptReviewScreen>(find.byType(ReceiptReviewScreen));
      expect(screen.items.map((i) => (i.raw, i.qty)).toList(), [
        ('LIMES', 1.0),
        ('PROG TRD CHK ORZ LMN', 2.0),
        ('DVE MEN+CARE CDRWD/T', 1.0),
      ]);
      expect(screen.source, 'receipt');

      await tester.tap(_id('btn-receipt-save'));
      await until(tester, () => queue.ready.isEmpty);
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptReviewScreen), findsNothing);
      expect(queue.ready, isEmpty);
      expect(find.text('LIMES'), findsOneWidget);
      expect(find.text('PROG TRD CHK ORZ LMN'), findsOneWidget);
    });

    testWidgets('AC16: going back keeps the receipt ready', (tester) async {
      reader.lines = hannafordLines;
      await pump(tester);
      await seedReady(tester);

      await tester.tap(_id('btn-receipt-review-next'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptReviewScreen), findsNothing);
      expect(queue.ready.length, 1);
    });

    testWidgets('AC17: discard removes the receipt and saves nothing', (tester) async {
      reader.lines = hannafordLines;
      await pump(tester);
      await seedReady(tester);

      await tester.tap(_id('btn-receipt-review-next'));
      await tester.pumpAndSettle();
      await tester.tap(_id('btn-receipt-discard'));
      await until(tester, () => queue.ready.isEmpty);
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptReviewScreen), findsNothing);
      expect(queue.ready, isEmpty);
      expect(storage.items, isEmpty);
    });

    testWidgets('AC18: failed read is an inline notice, dismissable, no SnackBar',
        (tester) async {
      reader.error = const ReceiptReadException('Could not open that photo.');
      await pump(tester);
      await tester.runAsync(() async {
        await queue.add(Uint8List.fromList([1]));
        await queue.whenIdle();
      });
      await tester.pump();
      expect(find.text("1 receipt couldn't be read"), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(_id('btn-receipt-failed-dismiss'));
      await tester.pump();
      expect(_id('receipt-queue-failed'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('meal_planning AC38: collapse hides rows, keeps actions, shows count',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      storage.items.addAll([
        _p(1, 'limes', 2, 'ea', DateTime(2026, 10, 1)),
        _p(2, 'sweet potatoes', 2.26, 'lb', DateTime(2026, 10, 19)),
      ]);
      await pump(tester);

      await tester.tap(_id('btn-pantry-toggle'));
      await tester.pumpAndSettle();
      expect(_id('item-pantry-1'), findsNothing);
      expect(_id('item-pantry-2'), findsNothing);
      expect(find.text('2 items'), findsOneWidget);
      expect(_id('btn-scan-receipt'), findsOneWidget);
      expect(_id('btn-pantry-add'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('card_collapsed_pantry'), isTrue);

      await tester.tap(_id('btn-pantry-toggle'));
      await tester.pumpAndSettle();
      expect(_id('item-pantry-1'), findsOneWidget);
      expect(find.text('2 items'), findsNothing);
    });

    testWidgets('meal_planning AC40: a saved collapse renders collapsed', (tester) async {
      SharedPreferences.setMockInitialValues({'card_collapsed_pantry': true});
      storage.items.add(_p(1, 'limes', 2, 'ea', DateTime(2026, 10, 1)));
      await pump(tester);
      expect(_id('item-pantry-1'), findsNothing);
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('AC18: add item opens a manual review', (tester) async {
      await pump(tester);
      await tester.tap(_id('btn-pantry-add'));
      await tester.pumpAndSettle();
      final screen = tester.widget<ReceiptReviewScreen>(find.byType(ReceiptReviewScreen));
      expect(screen.source, 'manual');
      expect(screen.items, isEmpty);
    });
  });
}
