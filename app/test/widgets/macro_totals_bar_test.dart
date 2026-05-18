import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/macro_totals_bar.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  // ── Rendering ─────────────────────────────────────────────────────────────

  group('[MFT] MacroTotalsBar — rendering', () {
    testWidgets('renders all four stat labels', (tester) async {
      await tester.pumpWidget(_wrap(
        const MacroTotalsBar(calories: 500, protein: 30, carbs: 60, fat: 15),
      ));
      expect(find.text('Cal'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('displays provided calorie value', (tester) async {
      await tester.pumpWidget(_wrap(
        const MacroTotalsBar(calories: 350, protein: 20, carbs: 45, fat: 10),
      ));
      expect(find.text('350'), findsOneWidget);
    });

    testWidgets('appends g suffix to protein, carbs, fat', (tester) async {
      await tester.pumpWidget(_wrap(
        const MacroTotalsBar(calories: 0, protein: 25, carbs: 50, fat: 8),
      ));
      expect(find.text('25g'), findsOneWidget);
      expect(find.text('50g'), findsOneWidget);
      expect(find.text('8g'), findsOneWidget);
    });
  });

  // ── Boundary ──────────────────────────────────────────────────────────────

  group('[BVA] MacroTotalsBar — boundary', () {
    testWidgets('renders with all-zero values without error', (tester) async {
      await tester.pumpWidget(_wrap(
        const MacroTotalsBar(calories: 0, protein: 0, carbs: 0, fat: 0),
      ));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('0g'), findsNWidgets(3));
    });
  });
}
