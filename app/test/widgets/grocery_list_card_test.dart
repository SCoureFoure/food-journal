import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/grocery.dart';
import 'package:food_journal/services/export_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/grocery_list_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// StorageService requires native sqlite3, but its DB handle is lazy — a
// subclass that never touches it costs nothing.
class _FakeStorage extends StorageService {}

// Records every call the widget makes so the "generating never shares" /
// "tidy never regenerates" invariants can be asserted directly, and lets
// each method be set to throw to exercise the error paths.
class _FakeExportService extends ExportService {
  _FakeExportService() : super(_FakeStorage());

  String buildResult = '';
  Object? buildError;
  int buildCalls = 0;
  GroceryWindowMode? lastMode;
  int? lastSize;

  /// When set, `buildGroceryListText` blocks on this until the test completes
  /// it — which is how the in-flight (busy) state is held still long enough
  /// to assert on.
  Completer<String>? buildGate;

  /// When set, `tidyGroceryListText` blocks on this until the test completes
  /// it — which is how the in-flight (busy) state is held still long enough to
  /// assert on.
  Completer<String>? tidyGate;

  String tidyResult = '';
  Object? tidyError;
  int tidyCalls = 0;
  String? lastTidyInput;

  int shareCalls = 0;
  String? lastSharedText;

  int exportGroceryListCalls = 0;

  @override
  Future<String> buildGroceryListText({
    required GroceryWindowMode mode,
    required int size,
    DateTime? now,
  }) async {
    buildCalls++;
    lastMode = mode;
    lastSize = size;
    if (buildGate != null) return buildGate!.future;
    if (buildError != null) throw buildError!;
    return buildResult;
  }

  @override
  Future<String> tidyGroceryListText(String rawText, {DateTime? now}) async {
    tidyCalls++;
    lastTidyInput = rawText;
    if (tidyGate != null) return tidyGate!.future;
    if (tidyError != null) throw tidyError!;
    return tidyResult;
  }

  @override
  Future<void> shareText(String text) async {
    shareCalls++;
    lastSharedText = text;
  }

  @override
  Future<void> exportGroceryList({
    required GroceryWindowMode mode,
    required int size,
  }) async {
    exportGroceryListCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // `find.bySemanticsIdentifier` does not work in widget tests — the
  // semantics tree is not built — so anchors are found on the declared
  // `Semantics` widget instead.
  Finder byId(String id) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      );

  Future<void> pumpCard(WidgetTester tester, {required ExportService export}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: GroceryListCard(exportOverride: export)),
      ),
    ));
    await tester.pumpAndSettle();
  }

  // `find.byType` matches the exact runtime type, and `FilledButton.icon` /
  // `OutlinedButton.icon` return private `…WithIcon` subclasses, so taps go
  // through the visible label text instead.
  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  TextField groceryField(WidgetTester tester) => tester.widget<TextField>(
        find.descendant(of: byId('grocery-list-field'), matching: find.byType(TextField)),
      );

  /// [BVA] GroceryListCard empty vs list state — holds the contract that
  /// `_controller.text.trim().isEmpty` is the single source of truth for
  /// which state renders: empty shows Generate only, a non-empty box shows
  /// the field plus Copy/Share/Tidy/Retry/Clear, and Clear returns to empty.
  /// If this regresses: a doer renders Generate next to the action row (the
  /// exact redundancy this slice exists to remove), or a saved draft is
  /// dropped and the user's list silently disappears on next launch.
  group('[BVA] GroceryListCard empty vs list state', () {
    testWidgets('AC1: empty state shows only Generate, no redundant controls',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      final generate = byId('btn-generate-grocery-list');
      expect(generate, findsOneWidget);
      expect(
        find.descendant(of: generate, matching: find.text('Generate list')),
        findsOneWidget,
      );

      expect(byId('grocery-list-field'), findsNothing);
      expect(byId('btn-copy-grocery-list'), findsNothing);
      expect(byId('btn-share-grocery-list'), findsNothing);
      expect(byId('btn-tidy-grocery-list'), findsNothing);
      expect(byId('btn-retry-grocery-list'), findsNothing);
      expect(byId('btn-clear-grocery-list'), findsNothing);
    });

    testWidgets('AC2: a saved draft restores the list state', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      await pumpCard(tester, export: _FakeExportService());

      expect(byId('grocery-list-field'), findsOneWidget);
      expect(groceryField(tester).controller!.text, '- salt\n- eggs');
      expect(byId('btn-generate-grocery-list'), findsNothing);
    });

    testWidgets('AC10: Clear empties the box and returns to the empty state',
        (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      await pumpCard(tester, export: _FakeExportService());

      await tapText(tester, 'Clear');

      expect(byId('grocery-list-field'), findsNothing);
      expect(byId('btn-generate-grocery-list'), findsOneWidget);
    });
  });

  /// [MFT] GroceryListCard generate/retry/tidy/copy/share flow — holds the
  /// contract that generating and retrying render fresh journal-built text
  /// into the box, tidy transforms whatever is currently in the box, copy
  /// puts the box's current text (edits included) on the clipboard with a
  /// confirmation, and share hands the box's current text to the OS share
  /// sheet only on request. If this regresses: the wrong text reaches the
  /// clipboard/share sheet, or hand edits get clobbered by a background
  /// regenerate.
  group('[MFT] GroceryListCard generate/retry/tidy/copy/share flow', () {
    testWidgets('AC3: generating fills the box and shows the action row',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeExportService()
        ..buildResult = 'Grocery list\nGenerated 2026-08-30\n\n- salt (x6)';
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Generate list');

      expect(groceryField(tester).controller!.text,
          'Grocery list\nGenerated 2026-08-30\n\n- salt (x6)');
      expect(byId('btn-copy-grocery-list'), findsOneWidget);
      expect(byId('btn-share-grocery-list'), findsOneWidget);
      expect(byId('btn-retry-grocery-list'), findsOneWidget);
      expect(byId('btn-clear-grocery-list'), findsOneWidget);
    });

    testWidgets('AC11: Retry replaces the box from the journal', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- old'});
      final fake = _FakeExportService()..buildResult = '- new (x2)';
      await pumpCard(tester, export: fake);

      await tester.enterText(
        find.descendant(of: byId('grocery-list-field'), matching: find.byType(TextField)),
        '- old, edited',
      );
      await tester.pumpAndSettle();

      await tapText(tester, 'Retry');

      expect(fake.buildCalls, 1);
      expect(groceryField(tester).controller!.text, '- new (x2)');
    });

    testWidgets('AC8: Tidy transforms the box', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      final fake = _FakeExportService()
        ..tidyResult = 'Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt';
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Tidy with AI');

      expect(groceryField(tester).controller!.text,
          'Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt');
      expect(fake.lastTidyInput, '- salt\n- eggs');
    });

    testWidgets('AC6: Share calls the service exactly once with the box text',
        (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      final fake = _FakeExportService();
      await pumpCard(tester, export: fake);

      expect(fake.shareCalls, 0);

      await tapText(tester, 'Share');

      expect(fake.shareCalls, 1);
      expect(fake.lastSharedText, '- salt\n- eggs');
    });

    testWidgets('AC5: Copy puts the box text on the clipboard', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      final fake = _FakeExportService();
      await pumpCard(tester, export: fake);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tapText(tester, 'Copy');

      expect(copied, groceryField(tester).controller!.text);
      await tester.pump();
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('AC7: edits reach the clipboard, not the original text',
        (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      final fake = _FakeExportService();
      await pumpCard(tester, export: fake);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.enterText(
        find.descendant(of: byId('grocery-list-field'), matching: find.byType(TextField)),
        '- salt\n- eggs\nmilk',
      );
      await tester.pumpAndSettle();

      await tapText(tester, 'Copy');

      expect(copied, '- salt\n- eggs\nmilk');
    });
  });

  /// [INV] GroceryListCard generate never shares, tidy never regenerates —
  /// holds the two invariants this whole slice exists to enforce. If this
  /// regresses: generating a list fires the OS share sheet again (a bad list
  /// costs a full share round trip to discover), or a tidy pass silently
  /// re-reads the journal and clobbers the user's hand edits.
  group('[INV] GroceryListCard invariants', () {
    testWidgets('AC4: generating does not share', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeExportService()
        ..buildResult = 'Grocery list\nGenerated 2026-08-30\n\n- salt (x6)';
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Generate list');

      expect(fake.shareCalls, 0);
      expect(fake.exportGroceryListCalls, 0);
    });

    testWidgets('AC9: tidy does not regenerate from the journal', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt\n- eggs'});
      final fake = _FakeExportService()
        ..tidyResult = 'Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt';
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Tidy with AI');

      expect(fake.buildCalls, 0);
    });
  });

  /// [BVA] GroceryListCard generate failure — holds the contract that a
  /// thrown error surfaces as a SnackBar (never inline text, which reads
  /// below the fold on a long scrolling screen as a no-op) and the box stays
  /// empty rather than showing a half-built list. If this regresses: a
  /// failed generate silently fails or crashes the widget instead of telling
  /// the user what happened.
  group('[BVA] GroceryListCard generate failure', () {
    testWidgets('AC14: a generate failure surfaces as a SnackBar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeExportService()..buildError = Exception('boom');
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Generate list');

      expect(find.textContaining('boom'), findsOneWidget);
      expect(byId('grocery-list-field'), findsNothing);
      expect(byId('btn-generate-grocery-list'), findsOneWidget);
    });
  });

  /// [BVA] GroceryListCard window selection — holds the contract that the
  /// grocery-list card offers two modes (By meals / By days), that "By
  /// meals" is selected by default, that each mode has its own preset chips
  /// (10/30/60 meals, 7/14/30 days) with only the active mode's chips in the
  /// tree, that the meal preset defaults to 30, and that the generate
  /// control is present. If this regresses: a mode chip disappears/
  /// duplicates, the default mode or default meal window silently changes,
  /// the other mode's chips leak into the tree, chip selection stops
  /// following taps, or the generate button vanishes — all invisible to a
  /// user until they try to build a grocery list.
  group('[BVA] GroceryListCard window selection', () {
    ChoiceChip chipWithLabel(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(
          find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
        );

    testWidgets('mode chips render and meals is the default', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.widgetWithText(ChoiceChip, 'By meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'By days'), findsOneWidget);
      expect(chipWithLabel(tester, 'By meals').selected, isTrue);
      expect(chipWithLabel(tester, 'By days').selected, isFalse);
    });

    testWidgets('meal window chips render with the exact labels',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.widgetWithText(ChoiceChip, '10 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '60 meals'), findsOneWidget);
    });

    testWidgets('the meal window defaults to 30', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      expect(chipWithLabel(tester, '30 meals').selected, isTrue);
      expect(chipWithLabel(tester, '10 meals').selected, isFalse);
      expect(chipWithLabel(tester, '60 meals').selected, isFalse);
    });

    testWidgets('day chips are absent in meals mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.text('7 days'), findsNothing);
    });

    testWidgets('AC13: switching to By days swaps the row', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      await tapText(tester, 'By days');

      expect(find.widgetWithText(ChoiceChip, '7 days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '14 days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 days'), findsOneWidget);
      expect(chipWithLabel(tester, '30 days').selected, isTrue);
      expect(find.text('10 meals'), findsNothing);
    });

    testWidgets('selection moves within a mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      await tapText(tester, '10 meals');

      expect(chipWithLabel(tester, '10 meals').selected, isTrue);
      expect(chipWithLabel(tester, '30 meals').selected, isFalse);
    });

    testWidgets('generate control is present', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester, export: _FakeExportService());

      await tester.ensureVisible(find.text('Generate list'));
      await tester.pumpAndSettle();

      final finder = byId('btn-generate-grocery-list');
      expect(finder, findsOneWidget);
      expect(find.descendant(of: finder, matching: find.text('Generate list')),
          findsOneWidget);
    });
  });

  /// [BVA] GroceryListCard AI tidy control — holds the contract that the
  /// "Tidy with AI" control appears only when both a list exists and the AI
  /// setting is on, is absent (not disabled) when AI is off, and that
  /// Copy/Share/Retry/Clear never depend on it (the AI-optional rule: AI
  /// adds, it never gates). If this regresses: the tidy button shows up
  /// (even disabled) while AI is off, or the manual actions disappear/break
  /// when AI is off — both invisible until a user with AI disabled tries to
  /// build a grocery list.
  group('[BVA] GroceryListCard AI tidy control', () {
    testWidgets('AC1: tidy button present when AI is on and a list exists',
        (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      await pumpCard(tester, export: _FakeExportService());

      final finder = byId('btn-tidy-grocery-list');
      expect(finder, findsOneWidget);
      expect(find.descendant(of: finder, matching: find.text('Tidy with AI')),
          findsOneWidget);
    });

    testWidgets('AC12: tidy button absent when AI is off', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'ai_enabled': false, 'grocery_draft': '- salt'});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.text('Tidy with AI'), findsNothing);
      expect(byId('btn-tidy-grocery-list'), findsNothing);
    });

    testWidgets('AC12: Copy/Share/Retry/Clear survive AI being off and the '
        'box keeps its text', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'ai_enabled': false, 'grocery_draft': '- salt'});
      await pumpCard(tester, export: _FakeExportService());

      expect(byId('btn-copy-grocery-list'), findsOneWidget);
      expect(byId('btn-share-grocery-list'), findsOneWidget);
      expect(byId('btn-retry-grocery-list'), findsOneWidget);
      expect(byId('btn-clear-grocery-list'), findsOneWidget);
      expect(groceryField(tester).controller!.text, '- salt');
    });

    testWidgets('mode and window chips are unaffected by the AI setting',
        (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.widgetWithText(ChoiceChip, 'By meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'By days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 meals'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('30 meals'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
    });
  });

  /// [INV] GroceryListCard busy state — holds the invariant that every action
  /// is disabled while a call is in flight, so a second tap cannot fire a
  /// duplicate tidy request or throw a share sheet on top of one already
  /// opening. If this regresses: an impatient double-tap costs a second AI
  /// round trip and can land two share sheets, and nothing in the service
  /// tests would notice — they never touch the widget's enabled state.
  group('[INV] GroceryListCard busy state', () {
    FilledButton filledWithText(WidgetTester tester, String text) =>
        tester.widget<FilledButton>(find.ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ));

    testWidgets('at rest every action is enabled', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      await pumpCard(tester, export: _FakeExportService());

      expect(filledWithText(tester, 'Copy').onPressed, isNotNull);
    });

    testWidgets(
        'while a tidy is in flight the actions and field are disabled and '
        'the tidy button shows its spinner (AC2/AC3/AC4/AC5)', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      final fake = _FakeExportService()..tidyGate = Completer<String>();
      await pumpCard(tester, export: fake);

      final tidy = find.text('Tidy with AI');
      await tester.ensureVisible(tidy);
      await tester.pumpAndSettle();
      await tester.tap(tidy);
      await tester.pump(); // start the call; do NOT settle — it is still open

      expect(fake.tidyCalls, 1);
      expect(filledWithText(tester, 'Copy').onPressed, isNull); // AC4

      // AC2: the spinner and "…ing" label land on the button that started it.
      expect(find.text('Tidying…'), findsOneWidget);
      expect(
        find.descendant(
          of: byId('btn-tidy-grocery-list'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      // AC5: the field is locked while the tidy pass could replace its text.
      expect(groceryField(tester).enabled, isFalse);

      fake.tidyGate!.complete('Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt');
      await tester.pumpAndSettle();

      // AC3: ...and enabled again once it lands, so the card cannot get stuck.
      expect(filledWithText(tester, 'Copy').onPressed, isNotNull);
      expect(fake.tidyCalls, 1);
      expect(find.text('Tidying…'), findsNothing);
      expect(find.text('Tidy with AI'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(groceryField(tester).enabled, isTrue);
      expect(groceryField(tester).controller!.text,
          'Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt');
    });
  });

  /// [DIR] GroceryListCard progress feedback — holds the contract that the
  /// spinner and the "…ing" label land on the button whose call is actually
  /// in flight, and clear again when it lands or fails. If this regresses:
  /// the tidy pass, which crosses the network and waits on the model, gives
  /// no sign it is running, so the card looks frozen and the user taps again
  /// — or worse, the card is left permanently disabled after an error.
  group('[DIR] GroceryListCard progress feedback', () {
    FilledButton filledWithText(WidgetTester tester, String text) =>
        tester.widget<FilledButton>(find.ancestor(
          of: find.text(text),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ));

    testWidgets('AC1: at rest the tidy button shows no spinner', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      await pumpCard(tester, export: _FakeExportService());

      expect(find.text('Tidy with AI'), findsOneWidget);
      expect(find.text('Tidying…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
        'AC6: the spinner lands only on the button that started the call',
        (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      final fake = _FakeExportService()..tidyGate = Completer<String>();
      await pumpCard(tester, export: fake);

      final tidy = find.text('Tidy with AI');
      await tester.ensureVisible(tidy);
      await tester.pumpAndSettle();
      await tester.tap(tidy);
      await tester.pump();

      expect(find.text('Generating…'), findsNothing);

      fake.tidyGate!.complete('Grocery list\nGenerated 2026-08-30\n\nPantry\n- Salt');
      await tester.pumpAndSettle();
    });

    // The symmetric half lives in its own test on purpose: pumping a second
    // GroceryListCard into the same tester reuses the existing State (same
    // widget type, no key), so initState never re-reads the draft and the card
    // stays in whichever state the first half left it in.
    testWidgets('AC6 control: mid-generate only the generate button says so',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakeExportService()..buildGate = Completer<String>();
      await pumpCard(tester, export: fake);

      final generate = find.text('Generate list');
      await tester.ensureVisible(generate);
      await tester.pumpAndSettle();
      await tester.tap(generate);
      await tester.pump(); // start the call; do NOT settle — it is still open

      expect(find.text('Generating…'), findsOneWidget);
      expect(find.text('Tidying…'), findsNothing);

      fake.buildGate!.complete('- salt (x1)');
      await tester.pumpAndSettle();

      expect(find.text('Generating…'), findsNothing);
    });

    testWidgets('AC7: a tidy failure clears the busy state', (tester) async {
      SharedPreferences.setMockInitialValues({'grocery_draft': '- salt'});
      final fake = _FakeExportService()..tidyError = Exception('tidy boom');
      await pumpCard(tester, export: fake);

      await tapText(tester, 'Tidy with AI');

      expect(find.textContaining('tidy boom'), findsOneWidget);
      expect(find.text('Tidy with AI'), findsOneWidget);
      expect(find.text('Tidying…'), findsNothing);
      expect(filledWithText(tester, 'Copy').onPressed, isNotNull);
    });
  });
}
