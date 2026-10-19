import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pantry_item.dart';
import 'package:food_journal/screens/receipt_review/receipt_review_screen.dart';
import 'package:food_journal/services/receipt_ocr_service.dart';
import 'package:food_journal/widgets/pantry_card.dart';

import 'receipt_scan_fakes.dart';

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
  Uint8List? picked;

  setUp(() {
    storage = FakePantryStorage();
    reader = FakeReceiptReader();
    ai = FakeReceiptAi();
    picked = Uint8List.fromList([1, 2, 3]);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PantryCard(
            storageOverride: storage,
            readerOverride: reader,
            aiOverride: ai,
            aiEnabledOverride: false,
            pickImageOverride: (_) async => picked,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
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

  group('[MFT] scan flow', () {
    // testTheory: minimum functionality — scan reads, parses, merges and opens
    //   review; saving reloads the card.
    // contract: picked bytes -> ReceiptReader -> parseReceiptText ->
    //   mergeReceiptItems -> ReceiptReviewScreen(source receipt); a cancelled
    //   pick does nothing; a read failure is a SnackBar.
    // implication: AC9/AC13/AC14 wired end to end with fakes.

    testWidgets('scan opens review with merged rows; save reloads card', (tester) async {
      reader.lines = hannafordLines;
      await pump(tester);
      await tester.tap(_id('btn-scan-receipt'));
      await tester.pumpAndSettle();

      expect(reader.calls, 1);
      expect(find.byType(ReceiptReviewScreen), findsOneWidget);
      final screen = tester.widget<ReceiptReviewScreen>(find.byType(ReceiptReviewScreen));
      expect(screen.items.map((i) => (i.raw, i.qty)).toList(), [
        ('LIMES', 1.0),
        ('PROG TRD CHK ORZ LMN', 2.0),
        ('DVE MEN+CARE CDRWD/T', 1.0),
      ]);
      expect(screen.source, 'receipt');
      expect(screen.ocrText, hannafordLines.join('\n'));

      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();
      expect(find.byType(ReceiptReviewScreen), findsNothing);
      expect(find.text('LIMES'), findsOneWidget);
      expect(find.text('PROG TRD CHK ORZ LMN'), findsOneWidget);
    });

    testWidgets('cancelled pick does nothing', (tester) async {
      picked = null;
      await pump(tester);
      await tester.tap(_id('btn-scan-receipt'));
      await tester.pumpAndSettle();
      expect(reader.calls, 0);
      expect(find.byType(ReceiptReviewScreen), findsNothing);
    });

    testWidgets('read failure shows a SnackBar and no review', (tester) async {
      reader.error = const ReceiptReadException('Could not open that photo.');
      await pump(tester);
      await tester.tap(_id('btn-scan-receipt'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open that photo.'), findsOneWidget);
      expect(find.byType(ReceiptReviewScreen), findsNothing);
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
