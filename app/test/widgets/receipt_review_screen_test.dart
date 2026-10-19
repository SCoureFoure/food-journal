import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/receipt_parser.dart';
import 'package:food_journal/screens/receipt_review/receipt_review_screen.dart';
import 'package:food_journal/services/ai_service.dart';

import 'receipt_scan_fakes.dart';

Finder _id(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

Finder _rowField(int row, int index) =>
    find.descendant(of: _id('item-receipt-row-$row'), matching: find.byType(TextField)).at(index);

Finder _rowCheckbox(int row) =>
    find.descendant(of: _id('item-receipt-row-$row'), matching: find.byType(Checkbox));

bool _checked(WidgetTester t, int row) => t.widget<Checkbox>(_rowCheckbox(row)).value!;

String _text(WidgetTester t, int row, int index) =>
    t.widget<TextField>(_rowField(row, index)).controller!.text;

void main() {
  late FakePantryStorage storage;
  late FakeReceiptAi ai;
  final now = DateTime(2026, 10, 19, 9, 30);

  setUp(() {
    storage = FakePantryStorage();
    ai = FakeReceiptAi();
  });

  /// Pushes the screen from a host route so `pop(true)` can be observed.
  Future<List<bool?>> pump(
    WidgetTester tester, {
    List<ParsedReceiptItem>? items,
    String? ocrText,
    String source = 'receipt',
    bool aiEnabled = true,
    bool showDiscard = false,
  }) async {
    final results = <bool?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
                builder: (_) => ReceiptReviewScreen(
                  items: items ?? hannafordItems(),
                  ocrText: ocrText ?? hannafordLines.join('\n'),
                  source: source,
                  showDiscard: showDiscard,
                  storageOverride: storage,
                  aiOverride: ai,
                  aiEnabledOverride: aiEnabled,
                  clock: () => now,
                ),
              ));
              results.add(r);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  group('[MFT] review rows', () {
    // testTheory: minimum functionality — every parsed item becomes an editable,
    //   includable row; known non-food starts excluded.
    // contract: name defaults to the AI name or the raw text; quantity shows
    //   without trailing zeros; include = food != false.
    // implication: AC13 — the user reviews before anything is saved.

    testWidgets('AC13: rows, defaults and non-food unchecked', (tester) async {
      await pump(tester);
      expect(_id('receipt-review-screen'), findsOneWidget);
      expect(_text(tester, 0, 0), 'LIMES');
      expect(_text(tester, 1, 0), 'PROG TRD CHK ORZ LMN');
      expect(_text(tester, 1, 1), '2');
      expect(_text(tester, 2, 0), 'DVE MEN+CARE CDRWD/T');
      expect(_checked(tester, 0), isTrue);
      expect(_checked(tester, 1), isTrue);
      expect(_checked(tester, 2), isFalse);
    });

    testWidgets('AC13: unknown food status starts checked', (tester) async {
      await pump(tester, items: const [ParsedReceiptItem(raw: 'BANANAS')]);
      expect(_checked(tester, 0), isTrue);
    });
  });

  group('[MFT] save', () {
    // testTheory: minimum functionality — Save writes exactly the checked,
    //   named rows and closes with true.
    // contract: PantryItem per checked row with a non-empty name; source and raw
    //   text carried; invalid quantity becomes 1.
    // implication: AC14 — the pantry gets what the user approved, nothing more.

    testWidgets('AC14: saves checked rows and pops true', (tester) async {
      final results = await pump(tester);
      await tester.enterText(_rowField(0, 0), 'limes');
      await tester.enterText(_rowField(1, 1), 'abc');
      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();

      expect(results, [true]);
      expect(storage.items.map((p) => (p.name, p.quantity, p.unit, p.source, p.rawText)).toList(), [
        ('limes', 1.0, 'ea', 'receipt', 'LIMES'),
        ('PROG TRD CHK ORZ LMN', 1.0, 'ea', 'receipt', 'PROG TRD CHK ORZ LMN'),
      ]);
      expect(storage.items.every((p) => p.addedAt == now), isTrue);
    });

    testWidgets('AC14: a checked row with a blank name is skipped', (tester) async {
      await pump(tester);
      await tester.enterText(_rowField(0, 0), '   ');
      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();
      expect(storage.items.map((p) => p.name), ['PROG TRD CHK ORZ LMN']);
    });

    testWidgets('AC14: a storage failure keeps the screen open', (tester) async {
      storage.addError = Exception('disk full');
      final results = await pump(tester);
      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();
      expect(results, isEmpty);
      expect(_id('receipt-review-screen'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('[MFT] discard from the queue', () {
    // testTheory: minimum functionality — Discard is offered only for queued
    //   receipts and leaves the pantry untouched.
    // contract: showDiscard true → btn-receipt-discard pops false with no
    //   storage writes; showDiscard default → control absent.
    // implication: AC17 — a queued receipt can be dropped without saving anything.

    testWidgets('AC17: discard pops false and saves nothing', (tester) async {
      final results = await pump(tester, showDiscard: true);
      await tester.tap(_id('btn-receipt-discard'));
      await tester.pumpAndSettle();
      expect(results, [false]);
      expect(storage.items, isEmpty);
    });

    testWidgets('AC17: no discard control by default', (tester) async {
      await pump(tester);
      expect(_id('btn-receipt-discard'), findsNothing);
    });
  });

  group('[BVA] empty receipt and manual add', () {
    // testTheory: boundary — zero parsed items is a state, not an error.
    // contract: empty receipt shows receipt-review-empty; Add item appends a
    //   blank row; manual mode starts with one blank row and saves as manual.
    // implication: AC15 / AC18 — the user can always type their shopping in.

    testWidgets('AC15: empty message and add-row', (tester) async {
      await pump(tester, items: const []);
      expect(_id('receipt-review-empty'), findsOneWidget);
      await tester.tap(_id('btn-receipt-add-row'));
      await tester.pumpAndSettle();
      expect(_id('item-receipt-row-0'), findsOneWidget);
      expect(_id('receipt-review-empty'), findsNothing);
    });

    testWidgets('manual source starts with a blank row and saves as manual', (tester) async {
      await pump(tester, items: const [], ocrText: '', source: 'manual');
      expect(_id('item-receipt-row-0'), findsOneWidget);
      expect(_id('receipt-review-empty'), findsNothing);
      expect(_id('btn-receipt-ai-names'), findsNothing);
      await tester.enterText(_rowField(0, 0), 'oat milk');
      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();
      expect(storage.items.single.source, 'manual');
      expect(storage.items.single.rawText, isNull);
    });
  });

  group('[INV] AI clean-up never overrides the user', () {
    // testTheory: invariant — user edits win over AI suggestions.
    // contract: AI result applies to unedited rows only (name, quantity, food
    //   -> include); AI items with no matching row are appended; the request
    //   carries the user's known food names; failure is a SnackBar.
    // implication: AC11 / AC12 — AI is optional and advisory.

    testWidgets('AC11: AI off hides the button, save still works', (tester) async {
      final results = await pump(tester, aiEnabled: false);
      expect(_id('btn-receipt-ai-names'), findsNothing);
      await tester.tap(_id('btn-receipt-save'));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });

    testWidgets('AC12: edited row keeps user name and checkbox', (tester) async {
      storage.knownFoods = const ['limes', 'chicken orzo soup'];
      ai.result = ReceiptParseResult(success: true, items: const [
        ParsedReceiptItem(raw: 'LIMES', qty: 3, food: true, name: 'limes'),
        ParsedReceiptItem(raw: 'PROG TRD CHK ORZ LMN', qty: 2, food: true, name: 'chicken orzo soup'),
        ParsedReceiptItem(raw: 'DVE MEN+CARE CDRWD/T', food: false),
        ParsedReceiptItem(raw: 'SHALLOTS', qty: 0.25, unit: 'lb', food: true, name: 'shallots'),
      ]);
      await pump(tester);

      await tester.enterText(_rowField(0, 0), 'key limes');
      await tester.tap(_rowCheckbox(0));
      await tester.pump();

      await tester.tap(_id('btn-receipt-ai-names'));
      await tester.pumpAndSettle();

      expect(ai.calls, 1);
      expect(ai.lastKnown, ['limes', 'chicken orzo soup']);
      expect(ai.lastText, hannafordLines.join('\n'));

      expect(_text(tester, 0, 0), 'key limes');
      expect(_text(tester, 0, 1), '1');
      expect(_checked(tester, 0), isFalse);

      expect(_text(tester, 1, 0), 'chicken orzo soup');
      expect(_text(tester, 1, 1), '2');
      expect(_checked(tester, 1), isTrue);

      expect(_text(tester, 2, 0), 'DVE MEN+CARE CDRWD/T');
      expect(_checked(tester, 2), isFalse);

      expect(_text(tester, 3, 0), 'shallots');
      expect(_text(tester, 3, 1), '0.25');
    });

    testWidgets('AC10: AI failure shows a SnackBar and keeps rows', (tester) async {
      ai.result = ReceiptParseResult(success: false, errorMessage: 'Worker error 429');
      await pump(tester);
      await tester.tap(_id('btn-receipt-ai-names'));
      await tester.pumpAndSettle();
      expect(find.textContaining('429'), findsOneWidget);
      expect(_text(tester, 0, 0), 'LIMES');
    });
  });
}
