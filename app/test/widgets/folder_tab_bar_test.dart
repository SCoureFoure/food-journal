import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/folder_tab_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

const _foodJournalTab = FolderTab(
  label: 'Food Journal',
  semanticsId: 'tab-food-journal',
  color: kTabFoodJournal,
);
const _mealPlanningTab = FolderTab(
  label: 'Meal Planning',
  semanticsId: 'tab-meal-planning',
  color: kTabMealPlanning,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// [BVA] FolderTabBar selection rendering — holds the contract that exactly one tab
  /// renders in the selected treatment (its own full-strength color, 44px tall, w600) and
  /// every other tab renders recessed (its own color mixed 55% toward kFolderTabRecess,
  /// 36px tall, w500). If this regresses: both tabs look active or none does, or every
  /// tab paints the same shared color instead of its own hue — invisible to every other
  /// test in the suite because nothing else reads these colors.
  group('[BVA] FolderTabBar selection rendering', () {
    testWidgets('AC1: both tabs render their labels', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));
      expect(find.text('Food Journal'), findsOneWidget);
      expect(find.text('Meal Planning'), findsOneWidget);
    });

    testWidgets('AC1: both semantics anchors are declared', (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
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

    testWidgets('AC2: with selectedIndex 0, each tab paints its own fill',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));

      final foodJournalContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(Container),
        ).first,
      );
      expect(foodJournalContainer.color, kTabFoodJournal);

      final mealPlanningContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(Container),
        ).first,
      );
      expect(mealPlanningContainer.color,
          folderTabFill(kTabMealPlanning, selected: false));
    });

    testWidgets('AC3: with selectedIndex 1, the fills from AC2 are mirrored',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 1,
          onSelected: (_) {},
        ),
      ));

      final foodJournalContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(Container),
        ).first,
      );
      expect(foodJournalContainer.color,
          folderTabFill(kTabFoodJournal, selected: false));

      final mealPlanningContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(Container),
        ).first,
      );
      expect(mealPlanningContainer.color, kTabMealPlanning);
    });

    testWidgets('AC6: selected tab is 44px tall, unselected is 36px tall',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));

      final foodJournalHeight = tester.getSize(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(foodJournalHeight, 44);

      final mealPlanningHeight = tester.getSize(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(ClipPath),
        ).first,
      ).height;
      expect(mealPlanningHeight, 36);
    });

    testWidgets('AC9: does not use Material TabBar or Tab widgets',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
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
          tabs: const [
            FolderTab(
                label: 'Solo', semanticsId: 'tab-solo', color: kTabFoodJournal),
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
          tabs: const [_foodJournalTab, _mealPlanningTab],
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
    testWidgets('AC7: tapping Meal Planning calls onSelected(1)', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (i) => tapped.add(i),
        ),
      ));
      await tester.tap(find.text('Meal Planning'));
      expect(tapped, [1]);
    });

    testWidgets(
        'AC7: tapping already-selected tab still calls onSelected with its index',
        (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (i) => tapped.add(i),
        ),
      ));
      await tester.tap(find.text('Food Journal'));
      expect(tapped, [0]);
    });
  });

  /// [MFT] FolderTabBar per-tab colour identity — holds the contract that each tab paints
  /// ITS OWN hue via `tab.color`, not a shared selected/unselected pair. If this regresses:
  /// a doer that keeps one global color pair and ignores `tab.color` would pass every other
  /// colour assertion in this file but silently lose the per-tab identity that is the whole
  /// point of this slice — every folder tab would look identical again.
  group('[MFT] FolderTabBar per-tab colour identity', () {
    testWidgets('AC4: the two tabs paint different fills, not a shared pair',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));

      final foodJournalContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Food Journal'),
          matching: find.byType(Container),
        ).first,
      );
      final mealPlanningContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('Meal Planning'),
          matching: find.byType(Container),
        ).first,
      );

      expect(foodJournalContainer.color, isNot(mealPlanningContainer.color));
      expect(mealPlanningContainer.color,
          isNot(folderTabFill(kTabFoodJournal, selected: false)));
    });

    test('AC5: folderTabFill is identity when selected, mixed when not', () {
      const c = kTabFoodJournal;
      expect(folderTabFill(c, selected: true), c);
      expect(folderTabFill(c, selected: false), isNot(c));
    });
  });

  /// [INV] FolderTabBar overflow guard — holds the contract that the horizontal
  /// SingleChildScrollView safety valve from bdd09f3 survives any restyling. If this
  /// regresses: the bar can silently drop the scroll view and bring back the app-bar
  /// overflow stripe that shipped and was fixed in that commit.
  group('[INV] FolderTabBar overflow guard', () {
    testWidgets('AC10: a horizontal SingleChildScrollView wraps the tabs',
        (tester) async {
      await tester.pumpWidget(_wrap(
        FolderTabBar(
          tabs: const [_foodJournalTab, _mealPlanningTab],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final scrollView =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(scrollView.scrollDirection, Axis.horizontal);
    });
  });
}
