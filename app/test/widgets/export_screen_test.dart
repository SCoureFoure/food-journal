import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/screens/export/export_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// export_import_size AC2 — the Export screen defaults to a data-only export:
/// the "Photos" switch is off, so a default export embeds no image bytes.
/// (The payload-exclusion behaviour itself is proven by the includeImages:false
/// unit tests in export_import_test.dart.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('[BVA] ExportScreen photo toggle default', () {
    SwitchListTile tileWithTitle(WidgetTester tester, String title) {
      return tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      );
    }

    testWidgets('Photos switch defaults off', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(tileWithTitle(tester, 'Photos').value, isFalse);
    });

    testWidgets('Meals switch defaults on (control)', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(tileWithTitle(tester, 'Meals').value, isTrue);
    });
  });

  /// [BVA] ExportScreen grocery-list section — holds the contract that the
  /// grocery-list card offers two modes (By meals / By days), that "By
  /// meals" is selected by default, that each mode has its own preset chips
  /// (10/30/60 meals, 7/14/30 days) with only the active mode's chips in the
  /// tree, that the meal preset defaults to 30, and that the "Generate &
  /// share" control is present. If this regresses: a mode chip
  /// disappears/duplicates, the default mode or default meal window
  /// silently changes, the other mode's chips leak into the tree, chip
  /// selection stops following taps, or the generate button vanishes —
  /// all invisible to a user until they try to export a grocery list.
  group('[BVA] ExportScreen grocery-list section', () {
    ChoiceChip chipWithLabel(WidgetTester tester, String label) =>
        tester.widget<ChoiceChip>(
          find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
        );

    testWidgets('mode chips render and meals is the default', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, 'By meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'By days'), findsOneWidget);
      expect(chipWithLabel(tester, 'By meals').selected, isTrue);
      expect(chipWithLabel(tester, 'By days').selected, isFalse);
    });

    testWidgets('meal window chips render with the exact labels',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ChoiceChip, '10 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '30 meals'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '60 meals'), findsOneWidget);
    });

    testWidgets('the meal window defaults to 30', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(chipWithLabel(tester, '30 meals').selected, isTrue);
      expect(chipWithLabel(tester, '10 meals').selected, isFalse);
      expect(chipWithLabel(tester, '60 meals').selected, isFalse);
    });

    testWidgets('day chips are absent in meals mode', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('7 days'), findsNothing);
    });

    testWidgets('switching to By days swaps the row', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '10 meals'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '10 meals'));
      await tester.pump();

      expect(chipWithLabel(tester, '10 meals').selected, isTrue);
      expect(chipWithLabel(tester, '30 meals').selected, isFalse);
    });

    testWidgets('generate control is present', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

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

  /// [BVA] ExportScreen AI tidy control — holds the contract that the
  /// "Tidy with AI & share" control appears only when the AI setting is on,
  /// and that the plain "Generate & share" export never depends on it (the
  /// AI-optional rule: AI adds, it never gates). If this regresses: the tidy
  /// button shows up (even disabled) while AI is off, or the plain export
  /// button disappears/breaks when AI is off — both invisible until a user
  /// with AI disabled tries to export a grocery list.
  group('[BVA] ExportScreen AI tidy control', () {
    Finder tidyButtonSemantics() => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-tidy-grocery-list',
        );

    testWidgets('AC1: tidy button present when AI is on', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      final finder = tidyButtonSemantics();
      expect(finder, findsOneWidget);
      expect(
        find.descendant(of: finder, matching: find.text('Tidy with AI & share')),
        findsOneWidget,
      );
    });

    testWidgets('AC2: tidy button absent when AI is off', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Tidy with AI & share'), findsNothing);
      expect(tidyButtonSemantics(), findsNothing);
    });

    testWidgets('AC3: plain button survives AI being off', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_enabled': false});
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

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
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();

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
}
