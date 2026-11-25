import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/watch_sample.dart';
import 'package:food_journal/screens/export/export_screen.dart';
import 'package:food_journal/widgets/home/biometrics_tile.dart';
import 'package:food_journal/widgets/home/date_section.dart';

final _day = DateTime(2026, 11, 23);

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Widget _wrapTile(WatchDaySummary summary) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: BiometricsTile(date: _day, summary: summary)),
      ),
    );

Widget _wrapSection(WatchDaySummary? summary) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DateSection(
            date: _day,
            meals: const [],
            medications: const [],
            feelings: const [],
            waterLogs: const [],
            weightLogs: const [],
            isToday: false,
            onReload: () {},
            watchSummary: summary,
          ),
        ),
      ),
    );

final _full = WatchDaySummary(
  steps: 3360,
  sleep: const Duration(hours: 7, minutes: 10),
  hrMin: 62,
  hrMax: 109,
  asleepAt: DateTime(2026, 11, 22, 23, 20),
  awakeAt: DateTime(2026, 11, 23, 6, 30),
  light: const Duration(hours: 3, minutes: 10),
  deep: const Duration(hours: 1),
  rem: const Duration(hours: 1, minutes: 30),
  awake: const Duration(minutes: 20),
  busiestHour: DateTime(2026, 11, 23, 8),
  busiestHourSteps: 410,
  hrAvg: 78,
  hrCount: 24,
);

void main() {
  group('[MFT] BiometricsTile collapsed and expanded (AC6)', () {
    // testTheory: MFT
    // contract: title Biometrics, subtitle = summary line; expanding shows only the sections that have data.
    // implication: AC6 — if this fails, the journal shows wrong or missing watch numbers.
    testWidgets('full summary: anchor, title, subtitle, then all sections', (tester) async {
      await tester.pumpWidget(_wrapTile(_full));

      expect(_anchor('biometrics-tile-2026-11-23'), findsOneWidget);
      expect(find.text('Biometrics'), findsOneWidget);
      expect(find.text('👣 3,360 · 😴 7h 10m · ♥ 62–109'), findsOneWidget);

      await tester.tap(_anchor('biometrics-tile-header-2026-11-23'));
      await tester.pumpAndSettle();

      expect(find.text('SLEEP'), findsOneWidget);
      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('HEART RATE'), findsOneWidget);
      expect(find.text('avg 78 · 24 readings'), findsOneWidget);
    });

    testWidgets('steps-only summary shows only the STEPS section', (tester) async {
      await tester.pumpWidget(_wrapTile(const WatchDaySummary(steps: 3360)));
      await tester.tap(_anchor('biometrics-tile-header-2026-11-23'));
      await tester.pumpAndSettle();

      expect(find.text('STEPS'), findsOneWidget);
      expect(find.text('SLEEP'), findsNothing);
      expect(find.text('HEART RATE'), findsNothing);
    });
  });

  group('[BVA] BiometricsTile with no data (AC6)', () {
    // testTheory: BVA
    // contract: an empty summary builds nothing and registers no anchor.
    // implication: AC6 — if this fails, days without watch data show an empty row.
    testWidgets('empty summary renders no anchor', (tester) async {
      await tester.pumpWidget(_wrapTile(const WatchDaySummary()));

      expect(_anchor('biometrics-tile-2026-11-23'), findsNothing);
    });
  });

  group('[MFT] DateSection shows the tile only when expanded with data (AC6)', () {
    // testTheory: MFT
    // contract: watchSummary non-empty puts the tile inside the expanded section; null puts none.
    // implication: AC6 — if this fails, watch data never surfaces in the journal or shows on empty days.
    testWidgets('with watchSummary the anchor appears after expanding', (tester) async {
      await tester.pumpWidget(_wrapSection(const WatchDaySummary(steps: 3360)));
      await tester.tap(find.text('Monday, November 23'));
      await tester.pumpAndSettle();

      expect(_anchor('biometrics-tile-2026-11-23'), findsOneWidget);
    });

    testWidgets('without watchSummary no anchor appears', (tester) async {
      await tester.pumpWidget(_wrapSection(null));
      await tester.tap(find.text('Monday, November 23'));
      await tester.pumpAndSettle();

      expect(_anchor('biometrics-tile-2026-11-23'), findsNothing);
    });
  });

  group('[MFT] Export screen offers the watch import (AC9)', () {
    // testTheory: MFT
    // contract: the Export / Import screen carries the btn-import-watch anchor.
    // implication: AC9 — if this fails, the user has no way to start a watch import.
    testWidgets('btn-import-watch is present', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));

      expect(_anchor('btn-import-watch'), findsOneWidget);
    });
  });
}
