import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
