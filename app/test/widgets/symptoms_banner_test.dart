import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/symptoms_banner.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  // ── Rendering ─────────────────────────────────────────────────────────────

  group('[MFT] SymptomsBanner', () {
    testWidgets('prepends After-meal: to the symptoms text', (tester) async {
      await tester.pumpWidget(_wrap(
        const SymptomsBanner(symptoms: 'Bloating, Fatigue'),
      ));
      expect(find.text('After-meal: Bloating, Fatigue'), findsOneWidget);
    });

    testWidgets('renders flag icon', (tester) async {
      await tester.pumpWidget(_wrap(
        const SymptomsBanner(symptoms: 'Nausea'),
      ));
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('custom margin is accepted without error', (tester) async {
      await tester.pumpWidget(_wrap(
        const SymptomsBanner(
          symptoms: 'Heartburn',
          margin: EdgeInsets.all(16),
        ),
      ));
      expect(find.text('After-meal: Heartburn'), findsOneWidget);
    });
  });

  // ── Boundary ──────────────────────────────────────────────────────────────

  group('[BVA] SymptomsBanner — boundary', () {
    testWidgets('renders with empty symptoms string without error', (tester) async {
      await tester.pumpWidget(_wrap(const SymptomsBanner(symptoms: '')));
      expect(find.text('After-meal: '), findsOneWidget);
    });
  });
}
