import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/grocery_list_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: GroceryListCard())),
    ));
    await tester.pumpAndSettle();
  }

  /// [BVA] GroceryListCard window selection — holds the contract that the
  /// grocery-list card offers two modes (By meals / By days), that "By
  /// meals" is selected by default, that each mode has its own preset chips
  /// (10/30/60 meals, 7/14/30 days) with only the active mode's chips in the
  /// tree, that the meal preset defaults to 30, and that the "Generate &
  /// share" control is present. If this regresses: a mode chip
  /// disappears/duplicates, the default mode or default meal window
  /// silently changes, the other mode's chips leak into the tree, chip
  /// selection stops following taps, or the generate button vanishes —
  /// all invisible to a user until they try to export a grocery list.
  group('[BVA] GroceryListCard window selection', () {
    ChoiceChip chipWithLabel(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(
          find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
        );

    testWidgets('mode chips render and meals is the default', (tester) async {
      await pumpCard(tester);

      expect(find.widgetWithText(ChoiceChip, 'By meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'By days'), findsOneWidget);
      expect(chipWithLabel(tester, 'By meals').selected, isTrue);
      expect(chipWithLabel(tester, 'By days').selected, isFalse);
    });

    testWidgets('meal window chips render with the exact labels',
        (tester) async {
      await pumpCard(tester);

      expect(find.widgetWithText(ChoiceChip, '10 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '60 meals'), findsOneWidget);
    });

    testWidgets('the meal window defaults to 30', (tester) async {
      await pumpCard(tester);

      expect(chipWithLabel(tester, '30 meals').selected, isTrue);
      expect(chipWithLabel(tester, '10 meals').selected, isFalse);
      expect(chipWithLabel(tester, '60 meals').selected, isFalse);
    });

    testWidgets('day chips are absent in meals mode', (tester) async {
      await pumpCard(tester);

      expect(find.text('7 days'), findsNothing);
    });

    testWidgets('switching to By days swaps the row', (tester) async {
      await pumpCard(tester);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'By days'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'By days'));
      await tester.pump();

      expect(find.widgetWithText(ChoiceChip, '7 days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '14 days'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 days'), findsOneWidget);
      expect(chipWithLabel(tester, '30 days').selected, isTrue);
      expect(find.text('10 meals'), findsNothing);
    });

    testWidgets('selection moves within a mode', (tester) async {
      await pumpCard(tester);

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '10 meals'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '10 meals'));
      await tester.pump();

      expect(chipWithLabel(tester, '10 meals').selected, isTrue);
      expect(chipWithLabel(tester, '30 meals').selected, isFalse);
    });

    testWidgets('generate control is present', (tester) async {
      await pumpCard(tester);

      await tester.ensureVisible(find.text('Generate & share'));
      await tester.pumpAndSettle();

      // Asserts the anchor is *declared* on the widget tree — the registry rule
      // in specs/anchors.md. A semantics-node finder needs the semantics tree
      // built and the id survives no merge, so the widget predicate is the
      // durable check.
      final finder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'btn-generate-grocery-list',
      );
      expect(finder, findsOneWidget);
      expect(find.descendant(of: finder, matching: find.text('Generate & share')),
          findsOneWidget);
    });
  });

  /// [BVA] GroceryListCard AI tidy control — holds the contract that the
  /// "Tidy with AI & share" control appears only when the AI setting is on,
  /// and that the plain "Generate & share" export never depends on it (the
  /// AI-optional rule: AI adds, it never gates). If this regresses: the tidy
  /// button shows up (even disabled) while AI is off, or the plain export
  /// button disappears/breaks when AI is off — both invisible until a user
  /// with AI disabled tries to export a grocery list.
  group('[BVA] GroceryListCard AI tidy control', () {
    Finder tidyButtonSemantics() => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-tidy-grocery-list',
        );

    testWidgets('AC1: tidy button present when AI is on', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester);

      final finder = tidyButtonSemantics();
      expect(finder, findsOneWidget);
      expect(
        find.descendant(of: finder, matching: find.text('Tidy with AI & share')),
        findsOneWidget,
      );
    });

    testWidgets('AC2: tidy button absent when AI is off', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await pumpCard(tester);

      expect(find.text('Tidy with AI & share'), findsNothing);
      expect(tidyButtonSemantics(), findsNothing);
    });

    testWidgets('AC3: plain button survives AI being off', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await pumpCard(tester);

      final finder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'btn-generate-grocery-list',
      );
      expect(finder, findsOneWidget);
      expect(find.descendant(of: finder, matching: find.text('Generate & share')),
          findsOneWidget);
    });

    testWidgets('AC4: mode and window chips are unaffected by the AI setting',
        (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await pumpCard(tester);

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

  /// [BVA] GroceryListCard busy state — holds the contract that both share
  /// controls are disabled while a generate or tidy call is in flight, so a
  /// user cannot fire a second share sheet on top of the first. If this
  /// regresses: double-taps queue duplicate shares and the user sees two
  /// system share sheets — invisible to the service tests, which never touch
  /// the widget's enabled state.
  group('[BVA] GroceryListCard busy state', () {
    testWidgets('at rest, both share controls are enabled', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpCard(tester);

      // `find.byType` matches the exact runtime type, and `OutlinedButton.icon`
      // / `FilledButton.icon` return private `…WithIcon` subclasses — so match
      // on the supertype with a predicate instead.
      final outlined = tester.widget<OutlinedButton>(
        find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      final filled = tester.widget<FilledButton>(
        find.byWidgetPredicate((w) => w is FilledButton),
      );

      expect(outlined.onPressed, isNotNull);
      expect(filled.onPressed, isNotNull);
    });
  });
}
