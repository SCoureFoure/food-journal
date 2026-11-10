import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/widgets/day_totals_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  // ── Zero threshold boundary ───────────────────────────────────────────────

  group('[BVA] DayTotalsBar — zero threshold', () {
    testWidgets('collapses to SizedBox.shrink when all values are zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 0, prot: 0, carbs: 0, fat: 0),
      ));
      expect(find.text('DAY TOTALS'), findsNothing);
      expect(find.text('CAL'), findsNothing);
    });

    testWidgets('renders DAY TOTALS header when cal is non-zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 1800, prot: 0, carbs: 0, fat: 0),
      ));
      expect(find.text('DAY TOTALS'), findsOneWidget);
    });

    testWidgets('shows CAL cell when cal > 0', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 500, prot: 0, carbs: 0, fat: 0),
      ));
      expect(find.text('CAL'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('hides CAL cell when cal is zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 0, prot: 30, carbs: 50, fat: 10),
      ));
      expect(find.text('CAL'), findsNothing);
    });
  });

  // ── Rendering ─────────────────────────────────────────────────────────────

  group('[MFT] DayTotalsBar — rendering', () {
    testWidgets('shows PROT, CARBS, FAT cells only when each > 0', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 0, prot: 25.0, carbs: 60.0, fat: 0),
      ));
      expect(find.text('PROT'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsNothing);
    });

    testWidgets('truncates double values to int for display', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 0, prot: 25.9, carbs: 60.1, fat: 10.5),
      ));
      expect(find.text('25g'), findsOneWidget);
      expect(find.text('60g'), findsOneWidget);
      expect(find.text('10g'), findsOneWidget);
    });

    testWidgets('renders all four cells when all values are non-zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 2000, prot: 80.0, carbs: 250.0, fat: 70.0),
      ));
      expect(find.text('CAL'), findsOneWidget);
      expect(find.text('PROT'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FAT'), findsOneWidget);
    });
  });

  group('[MFT] DayTotalsBar — goals', () {
    // testTheory: MFT
    // contract: a set goal renders as "value / goal"; a null goal leaves the value bare.
    // implication: if this fails, the day's totals lose their target or show a wrong one.
    testWidgets('cells with a goal show "value / goal", CARBS hidden when unset and zero', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(
          cal: 1450,
          prot: 98,
          carbs: 0,
          fat: 0,
          goals: DailyGoals(calories: 2000, fatG: 70),
        ),
      ));
      expect(find.text('1450 / 2000'), findsOneWidget);
      expect(find.text('98g'), findsOneWidget);
      expect(find.text('0 / 70g'), findsOneWidget);
      expect(find.text('CARBS'), findsNothing);
    });

    // testTheory: INV
    // contract: with no goals the totals render exactly as before (no " / ").
    // implication: if this fails, users without goals see changed day totals.
    testWidgets('no goals arg renders bare totals with no " / "', (tester) async {
      await tester.pumpWidget(_wrap(
        const DayTotalsBar(cal: 1450, prot: 98, carbs: 0, fat: 0),
      ));
      expect(find.text('1450'), findsOneWidget);
      expect(find.text('98g'), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
    });

    // testTheory: BVA
    // contract: all four goal cells fit a 320-px-wide surface without overflow.
    // implication: if this fails, narrow phones clip or throw on the day totals row.
    testWidgets('all four goal cells fit 320 px wide with no overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(
        const DayTotalsBar(
          cal: 1450,
          prot: 98,
          carbs: 180,
          fat: 60,
          goals: DailyGoals(calories: 2000, proteinG: 140, carbsG: 250, fatG: 70),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('1450 / 2000'), findsOneWidget);
      expect(find.text('98 / 140g'), findsOneWidget);
      expect(find.text('180 / 250g'), findsOneWidget);
      expect(find.text('60 / 70g'), findsOneWidget);
    });
  });
}
