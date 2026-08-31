import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/screens/meal_planning/meal_planning_screen.dart';
import 'package:food_journal/widgets/folder_palette.dart';
import 'package:food_journal/widgets/home/week_summary_section.dart';
import 'package:food_journal/widgets/panel_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// [INV] Panel width parity across tabs — holds the contract that a top-level
  /// section renders at the same width and with the same accent edge whichever
  /// tab it sits on. Journal week panels and planning cards are laid out by the
  /// same [PanelContainer], and the hosting scroll view contributes no
  /// horizontal padding of its own, so the two tabs cannot drift apart. If this
  /// regresses: switching tabs jumps the content edge sideways and the planning
  /// cards lose the coloured spine — the shell reads as two different apps, a
  /// defect no functional test in the suite would catch.
  group('[INV] Panel width parity across tabs', () {
    /// Left edge of a panel's painted surface. [PanelContainer]'s own render
    /// box spans the full width (the margin lives inside it), so the surface is
    /// measured on the box the decoration paints into.
    Finder surfaceOf(Finder panel) =>
        find.descendant(of: panel, matching: find.byType(DecoratedBox)).first;

    testWidgets('planning panels sit at the shared horizontal margin',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final panels = find.byType(PanelContainer);
      expect(panels, findsWidgets);
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      for (var i = 0; i < tester.widgetList(panels).length; i++) {
        final surface = surfaceOf(panels.at(i));
        expect(tester.getTopLeft(surface).dx, PanelContainer.horizontalMargin);
        expect(tester.getSize(surface).width,
            width - 2 * PanelContainer.horizontalMargin);
      }
    });

    testWidgets('planning panels carry the accent edge like journal weeks',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final panels =
          tester.widgetList<PanelContainer>(find.byType(PanelContainer));
      expect(panels, isNotEmpty);
      for (final panel in panels) {
        expect(panel.accentColor, kTabMealPlanning);
        expect(panel.margin, PanelContainer.sectionMargin);
      }
    });

    testWidgets('journal week panel uses the same margin as planning panels',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 100),
            children: [
              WeekSummarySection(
                weekStart: DateTime(2026, 6, 1),
                dates: [DateTime(2026, 6, 1)],
                mealsByDate: const {},
                medsByDate: const {},
                feelingsByDate: const {},
                waterByDate: const {},
                weightByDate: const {},
                macroFetcher: (_) async =>
                    (cal: 0, prot: 0.0, carbs: 0.0, fat: 0.0),
                isToday: (_) => false,
                onReload: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final panel = tester.widget<PanelContainer>(find.byType(PanelContainer));
      expect(panel.margin, PanelContainer.sectionMargin);
      expect(panel.accentColor, kTabFoodJournal);
      final surface = surfaceOf(find.byType(PanelContainer));
      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getTopLeft(surface).dx, PanelContainer.horizontalMargin);
      expect(tester.getSize(surface).width,
          width - 2 * PanelContainer.horizontalMargin);
    });
  });

  /// [INV] Spine colour follows the tab — holds the contract that a panel's
  /// left edge is painted in its own tab's folder colour, never in a theme
  /// colour that drifts independently. Journal panels are green, planning
  /// panels are slate, and both are the exact constants the tabs and the folder
  /// body behind them use. If this regresses: a page's panels stop belonging to
  /// the tab above them and the folder metaphor collapses into arbitrary
  /// stripes — invisible to every functional test in the suite.
  group('[INV] Spine colour follows the tab', () {
    test('each tab colour resolves to readable label ink', () {
      // The journal tab is dark enough to need light ink; the planning tab is
      // pale enough to need dark ink. The bar must not hard-code either.
      final journalInk =
          folderTabInk(folderTabFill(kTabFoodJournal, selected: true), selected: true);
      final planningInk =
          folderTabInk(folderTabFill(kTabMealPlanning, selected: true), selected: true);

      expect(ThemeData.estimateBrightnessForColor(kTabFoodJournal),
          Brightness.dark);
      expect(ThemeData.estimateBrightnessForColor(journalInk), Brightness.light);
      expect(ThemeData.estimateBrightnessForColor(kTabMealPlanning),
          Brightness.light);
      expect(ThemeData.estimateBrightnessForColor(planningInk), Brightness.dark);
    });

    test('recessed tabs stay readable too', () {
      for (final base in [kTabFoodJournal, kTabMealPlanning]) {
        final fill = folderTabFill(base, selected: false);
        final ink = folderTabInk(fill, selected: false);
        expect(ThemeData.estimateBrightnessForColor(ink),
            isNot(ThemeData.estimateBrightnessForColor(fill)));
      }
    });
  });
}
