import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/goal_fill_bar.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

// bySemanticsIdentifier does not work in widget tests (semantics tree not built),
// so anchors are found on the declared Semantics widget.
Finder _id(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

LiquidLinearProgressIndicator _indicator(WidgetTester tester) =>
    tester.widget<LiquidLinearProgressIndicator>(find.byType(LiquidLinearProgressIndicator));

void main() {
  // ── Fill value ────────────────────────────────────────────────────────────

  group('[MFT] GoalFillBar — fill value', () {
    testWidgets('renders 1450 / 2000 kcal and fills to 0.725', (tester) async {
      // testTheory: minimum functionality — a partial goal shows its ratio.
      // contract: text reads "<current> / <target> <unit>"; indicator value == current/target.
      // implication: AC5 — the bar reflects intake against the calorie goal.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 1450, target: 2000, unit: 'kcal'),
      ));
      expect(find.text('1450 / 2000 kcal'), findsOneWidget);
      expect(_indicator(tester).value, closeTo(0.725, 1e-9));
    });

    testWidgets('over target clamps fill to 1.0 and still shows the real numbers', (tester) async {
      // testTheory: boundary value — current above target.
      // contract: value clamped to 1.0; text shows unclamped current.
      // implication: AC5 — over-target intake fills the bar without overflowing it.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 2150, target: 2000, unit: 'kcal'),
      ));
      expect(_indicator(tester).value, 1.0);
      expect(find.text('2150 / 2000 kcal'), findsOneWidget);
    });

    testWidgets('zero current gives fill 0.0 and text "0 / 140 g"', (tester) async {
      // testTheory: boundary value — empty goal.
      // contract: current 0 → value 0.0; text "0 / 140 g".
      // implication: AC5 — an empty day shows an empty bar.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'protein', label: 'Protein', current: 0, target: 140, unit: 'g'),
      ));
      expect(_indicator(tester).value, 0.0);
      expect(find.text('0 / 140 g'), findsOneWidget);
    });

    testWidgets('target 0 yields progress 0.0 and builds without exception', (tester) async {
      // testTheory: boundary value — zero target must not divide by zero.
      // contract: target <= 0 → progress == 0.0; no exception on build.
      // implication: AC5 — an unset goal cannot crash the day view.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 500, target: 0, unit: 'kcal'),
      ));
      final widget = tester.widget<GoalFillBar>(find.byType(GoalFillBar));
      expect(widget.progress, 0.0);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Over-target styling ───────────────────────────────────────────────────

  group('[INV] GoalFillBar — neutral over-target', () {
    testWidgets('value text colour is the same over target as under target', (tester) async {
      // testTheory: invariance — exceeding the goal must not change text colour.
      // contract: style.color for "2150 / 2000 kcal" == style.color for "1450 / 2000 kcal".
      // implication: AC5 — over-target is shown neutrally, not as an error.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 1450, target: 2000, unit: 'kcal'),
      ));
      final underColor = tester.widget<Text>(find.text('1450 / 2000 kcal')).style?.color;

      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 2150, target: 2000, unit: 'kcal'),
      ));
      final overColor = tester.widget<Text>(find.text('2150 / 2000 kcal')).style?.color;

      expect(overColor, underColor);
    });
  });

  // ── Fill colour ───────────────────────────────────────────────────────────

  group('[MFT] GoalFillBar — fill colour', () {
    testWidgets('default fill colour is greenFill', (tester) async {
      // testTheory: minimum functionality — default colour.
      // contract: no fillColor → indicator valueColor == GoalFillBar.greenFill.
      // implication: AC5 — under-goal bars use the default green fill.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 1000, target: 2000, unit: 'kcal'),
      ));
      expect(_indicator(tester).valueColor?.value, GoalFillBar.greenFill);
    });

    testWidgets('explicit fillColor overrides the default', (tester) async {
      // testTheory: minimum functionality — caller-supplied colour is used.
      // contract: fillColor: blueFill → indicator valueColor == blueFill.
      // implication: AC5 — callers can select the fill colour.
      await tester.pumpWidget(_wrap(
        GoalFillBar(
          metric: 'calories',
          label: 'Calories',
          current: 1000,
          target: 2000,
          unit: 'kcal',
          fillColor: GoalFillBar.blueFill,
        ),
      ));
      expect(_indicator(tester).valueColor?.value, GoalFillBar.blueFill);
    });
  });

  // ── Semantics anchor ──────────────────────────────────────────────────────

  group('[MFT] GoalFillBar — semantics anchor', () {
    testWidgets('goal-row-protein anchor is found once for metric protein', (tester) async {
      // testTheory: minimum functionality — explorer foothold exists.
      // contract: Semantics(identifier: 'goal-row-<metric>') wraps the row.
      // implication: AC5 — the goal row is reachable by the explore rig.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'protein', label: 'Protein', current: 50, target: 140, unit: 'g'),
      ));
      expect(_id('goal-row-protein'), findsOneWidget);
    });
  });

  // ── Still mode ────────────────────────────────────────────────────────────

  group('[MFT] GoalFillBar — still mode', () {
    testWidgets('animated: false draws a static fill at 0.725 with no liquid wave', (tester) async {
      // testTheory: minimum functionality — still mode replaces the wave with a plain fill.
      // contract: animated false → no LiquidLinearProgressIndicator; FractionallySizedBox
      //   widthFactor == current/target; text "1450 / 2000 kcal"; pumpAndSettle completes.
      // implication: S8 — the moving-bars setting off gives a straight-edged fill.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(
          metric: 'calories',
          label: 'Calories',
          current: 1450,
          target: 2000,
          unit: 'kcal',
          animated: false,
        ),
      ));
      expect(find.byType(LiquidLinearProgressIndicator), findsNothing);
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor,
        closeTo(0.725, 1e-9),
      );
      expect(find.text('1450 / 2000 kcal'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('animated: false over target clamps widthFactor to 1.0', (tester) async {
      // testTheory: boundary value — still fill over target.
      // contract: animated false, current 2150 / target 2000 → widthFactor 1.0.
      // implication: S8 — the still fill never overflows its track.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(
          metric: 'calories',
          label: 'Calories',
          current: 2150,
          target: 2000,
          unit: 'kcal',
          animated: false,
        ),
      ));
      expect(
        tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor,
        1.0,
      );
    });

    testWidgets('animated: false with fillColor paints a ColoredBox in that colour', (tester) async {
      // testTheory: minimum functionality — caller colour reaches the still fill.
      // contract: animated false, fillColor blueFill → ColoredBox with color blueFill found.
      // implication: S8 — still mode keeps the caller-selected fill colour.
      await tester.pumpWidget(_wrap(
        GoalFillBar(
          metric: 'calories',
          label: 'Calories',
          current: 1000,
          target: 2000,
          unit: 'kcal',
          fillColor: GoalFillBar.blueFill,
          animated: false,
        ),
      ));
      expect(
        find.byWidgetPredicate((w) => w is ColoredBox && w.color == GoalFillBar.blueFill),
        findsOneWidget,
      );
    });
  });

  group('[INV] GoalFillBar — animated default', () {
    testWidgets('no animated argument keeps the liquid wave', (tester) async {
      // testTheory: invariance — omitting the flag leaves existing behaviour unchanged.
      // contract: default animated → LiquidLinearProgressIndicator findsOneWidget.
      // implication: S8 — default ON, no change until the user flips the setting.
      await tester.pumpWidget(_wrap(
        const GoalFillBar(metric: 'calories', label: 'Calories', current: 1450, target: 2000, unit: 'kcal'),
      ));
      expect(find.byType(LiquidLinearProgressIndicator), findsOneWidget);
    });
  });
}
