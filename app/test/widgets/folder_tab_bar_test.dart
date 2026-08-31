import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/folder_tab_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [BVA] FolderTabBar selection rendering — holds the contract that exactly one tab
  /// renders in the selected treatment (cream fill, 44px tall, w600) and every other
  /// tab renders recessed (manila fill, 36px tall, w500). If this regresses: both tabs
  /// look active or none does, and the user cannot tell which surface they are on —
  /// invisible to every other test in the suite because nothing else reads these colors.
  group('[BVA] FolderTabBar selection rendering', () {
    testWidgets('AC1: both tabs render their labels', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(find.text('Food Journal'), findsOneWidget);
      expect(find.text('Meal Planning'), findsOneWidget);
    });

    testWidgets('AC2: semantics identifiers are set correctly', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.identifier == 'tab-food-journal'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.identifier == 'tab-meal-planning'),
        findsOneWidget,
      );
    });

    testWidgets('AC5: with selectedIndex 0, colors and heights match states',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));

      // Food Journal (selected)
      final foodJournalContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(Container),
        ).first,
      );
      expect(foodJournalContainer.color, kFolderTabSelected);
      final foodJournalHeight = tester.getSize(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(foodJournalHeight, 44);

      // Meal Planning (unselected)
      final mealPlanningContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(Container),
        ).first,
      );
      expect(mealPlanningContainer.color, kFolderTabUnselected);
      final mealPlanningHeight = tester.getSize(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(mealPlanningHeight, 36);
    });

    testWidgets('AC6: with selectedIndex 1, colors and heights are mirrored',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      ));

      // Food Journal (unselected)
      final foodJournalContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(Container),
        ).first,
      );
      expect(foodJournalContainer.color, kFolderTabUnselected);
      final foodJournalHeight = tester.getSize(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(foodJournalHeight, 36);

      // Meal Planning (selected)
      final mealPlanningContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(Container),
        ).first,
      );
      expect(mealPlanningContainer.color, kFolderTabSelected);
      final mealPlanningHeight = tester.getSize(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(mealPlanningHeight, 44);
    });

    testWidgets('AC7: does not use Material TabBar or Tab widgets', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(Tab), findsNothing);
    });

    testWidgets('AC8: single tab renders without separators', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Solo', semanticsId: 'tab-solo'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(find.text('Solo'), findsOneWidget);
      // The bar's own root is a SizedBox(height: 44), so assert on the
      // separator specifically — a 3px-wide spacer — not on SizedBox at large.
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 3),
        findsNothing,
      );
    });

    testWidgets('AC8 control: two tabs do render one separator', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [
            FolderTab(label: 'One', semanticsId: 'tab-one'),
            FolderTab(label: 'Two', semanticsId: 'tab-two'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 3),
        findsOneWidget,
      );
    });
  });

  /// [DIR] FolderTabBar tap callbacks — holds the contract that tapping a tab fires
  /// onSelected with the exact index, even if that index is already selected. If this
  /// regresses: silent tap-to-switch will fail, and the caller cannot respond to
  /// redundant selections (which may be needed for scroll-to-top or refresh patterns).
  group('[DIR] FolderTabBar tap callbacks', () {
    testWidgets('AC3: tapping Meal Planning calls onSelected(1)', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (i) => tapped.add(i),
        ),
      ));
      await tester.tap(find.text('Meal Planning'));
      expect(tapped, [1]);
    });

    testWidgets(
        'AC4: tapping already-selected tab still calls onSelected with its index',
        (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: [
            const FolderTab(label: 'Food Journal', semanticsId: 'tab-food-journal'),
            const FolderTab(label: 'Meal Planning', semanticsId: 'tab-meal-planning'),
          ],
          selectedIndex: 0,
          onSelected: (i) => tapped.add(i),
        ),
      ));
      await tester.tap(find.text('Food Journal'));
      expect(tapped, [0]);
    });
  });
}
