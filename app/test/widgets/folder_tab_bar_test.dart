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

  /// [MFT] FolderTabBar pop animation — holds the contract that a tab RISES out
  /// of the folder over [kTabPopDuration] instead of snapping to its new height.
  /// The folder's leading edge is painted over the tab bases, so a snap reads as
  /// the label teleporting out from under the card; the interpolation is what
  /// makes it read as a tab being pulled forward. If this regresses the tabs
  /// still end up the right size, so every other test in this file stays green
  /// and only the motion is lost.
  group('[MFT] FolderTabBar pop animation', () {
    double heightOf(WidgetTester tester, String label) => tester
        .getSize(find
            .ancestor(of: find.text(label), matching: find.byType(ClipPath))
            .first)
        .height;

    Widget switchable() => _wrap(const _SwitchableBar());

    testWidgets('a newly selected tab passes through intermediate heights',
        (tester) async {
      await tester.pumpWidget(switchable());
      await tester.pumpAndSettle();
      expect(heightOf(tester, 'Meal Planning'), kTabRecessedHeight);

      await tester.tap(find.text('Meal Planning'));
      await tester.pump();
      await tester.pump(kTabPopDuration ~/ 2);

      final midRise = heightOf(tester, 'Meal Planning');
      final midFall = heightOf(tester, 'Food Journal');
      expect(midRise, greaterThan(kTabRecessedHeight));
      expect(midRise, lessThan(kTabRaisedHeight));
      expect(midFall, greaterThan(kTabRecessedHeight));
      expect(midFall, lessThan(kTabRaisedHeight));

      await tester.pumpAndSettle();
      expect(heightOf(tester, 'Meal Planning'), kTabRaisedHeight);
      expect(heightOf(tester, 'Food Journal'), kTabRecessedHeight);
    });

    testWidgets('the animation lands on exactly the declared fills',
        (tester) async {
      await tester.pumpWidget(switchable());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      Container tabBox(String label) => tester.widget<Container>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Container))
                .first,
          );

      // Endpoint exactness matters: a float lerp that lands a bit off would
      // paint a colour that is not in the palette at all.
      expect(tabBox('Meal Planning').color, kTabMealPlanning);
      expect(tabBox('Food Journal').color,
          folderTabFill(kTabFoodJournal, selected: false));
    });

    testWidgets('a tab renders at its final size on first build, unanimated',
        (tester) async {
      await tester.pumpWidget(switchable());
      await tester.pump();

      expect(heightOf(tester, 'Food Journal'), kTabRaisedHeight);
      expect(heightOf(tester, 'Meal Planning'), kTabRecessedHeight);
    });
  });
}

/// A two-tab bar that owns its own selection, so a test can tap one tab and
/// watch the other settle.
class _SwitchableBar extends StatefulWidget {
  const _SwitchableBar();

  @override
  State<_SwitchableBar> createState() => _SwitchableBarState();
}

class _SwitchableBarState extends State<_SwitchableBar> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => FolderTabBar(
        tabs: const [_foodJournalTab, _mealPlanningTab],
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
      );
}
