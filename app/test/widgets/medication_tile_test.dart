import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/widgets/home/medication_tile.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => Scaffold(body: child)),
        ),
      ),
    );

Medication _med({
  int? id = 1,
  double? dose,
  String? unit,
  String? route,
  String? notes,
}) =>
    Medication(
      id: id,
      date: DateTime(2026, 5, 14),
      time: '8:00 AM',
      name: 'Aspirin',
      dose: dose,
      unit: unit,
      route: route,
      notes: notes,
      createdAt: DateTime(2026, 5, 14, 8),
    );

void main() {
  // ── Dose formatting ───────────────────────────────────────────────────────

  group('[MFT] MedicationTile dose formatting', () {
    testWidgets('integer dose displays without decimal point', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(dose: 500, unit: 'mg'), onReload: () {}),
      ));
      await tester.pump();
      expect(find.textContaining('500 mg'), findsOneWidget);
      expect(find.textContaining('500.0'), findsNothing);
    });

    testWidgets('fractional dose displays with one decimal place', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(dose: 2.5, unit: 'mL'), onReload: () {}),
      ));
      await tester.pump();
      expect(find.textContaining('2.5 mL'), findsOneWidget);
    });

    testWidgets('renders medication name', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(), onReload: () {}),
      ));
      await tester.pump();
      expect(find.text('Aspirin'), findsOneWidget);
    });
  });

  // ── Null field boundary ───────────────────────────────────────────────────

  group('[BVA] MedicationTile — null fields', () {
    testWidgets('null dose shows only time and route in subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(dose: null, unit: null, route: 'oral'), onReload: () {}),
      ));
      await tester.pump();
      expect(find.textContaining('8:00 AM'), findsOneWidget);
      expect(find.textContaining('oral'), findsOneWidget);
    });

    testWidgets('null route omitted from subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(dose: 100, unit: 'mg', route: null), onReload: () {}),
      ));
      await tester.pump();
      expect(find.textContaining('100 mg'), findsOneWidget);
    });
  });

  // ── Interaction ───────────────────────────────────────────────────────────

  group('[Scenario] MedicationTile — interaction', () {
    testWidgets('shows notes in expanded children', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(
          med: _med(notes: 'take with food'),
          onReload: () {},
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Aspirin'));
      await tester.pumpAndSettle();
      expect(find.text('take with food'), findsOneWidget);
    });

    testWidgets('no notes — children section is empty after expand', (tester) async {
      await tester.pumpWidget(_wrap(
        MedicationTile(med: _med(notes: null), onReload: () {}),
      ));
      await tester.pump();
      await tester.tap(find.text('Aspirin'));
      await tester.pumpAndSettle();
      expect(find.text('take with food'), findsNothing);
    });
  });
}
