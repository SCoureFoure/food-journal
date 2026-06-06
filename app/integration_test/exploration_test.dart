import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/main.dart' as app;
import 'package:integration_test/integration_test.dart';

// ---------------------------------------------------------------------------
// Exploration rig — edit the active scenario and run test_explore.bat
// Screenshots: run `adb exec-out screencap -p > screenshots\<name>.png`
// Logs:        see terminal (adb logcat -s flutter filtered by test_explore.bat)
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── SCENARIO: home screen ────────────────────────────────────────────────
  testWidgets('scenario: home screen', (tester) async {
    unawaited(app.main());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    _log('HOME', {
      'meal_cards': find.byType(Card).evaluate().length,
      'fab_visible': find.byType(FloatingActionButton).evaluate().isNotEmpty,
      'loading': find.byType(CircularProgressIndicator).evaluate().isNotEmpty,
    });

    // Pause here — grab screenshot with adb externally
    await _pause(2);
  });

  // ── SCENARIO: log meal screen ────────────────────────────────────────────
  testWidgets('scenario: log meal screen', (tester) async {
    unawaited(app.main());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    _log('LOG_MEAL', {
      'route': '/log',
      'widgets': _widgetSummary(tester),
    });

    await _pause(2);
  });

  // ── SCENARIO: meal detail (requires seeded data) ─────────────────────────
  testWidgets('scenario: meal detail', (tester) async {
    unawaited(app.main());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    final cards = find.byType(Card);
    if (cards.evaluate().isEmpty) {
      _log('MEAL_DETAIL', {'skip': 'no meals on home screen — enable DEV_MODE=true in .env'});
      return;
    }

    await tester.tap(cards.first);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    _log('MEAL_DETAIL', {'widgets': _widgetSummary(tester)});
    await _pause(2);
  });
}

// ---------------------------------------------------------------------------

void _log(String scenario, Map<String, dynamic> data) {
  debugPrint('[EXPLORE:$scenario] $data');
}

Future<void> _pause(int seconds) async {
  await Future.delayed(Duration(seconds: seconds));
}

Map<String, int> _widgetSummary(WidgetTester tester) => {
      'Text': find.byType(Text).evaluate().length,
      'TextField': find.byType(TextField).evaluate().length,
      'ElevatedButton': find.byType(ElevatedButton).evaluate().length,
      'IconButton': find.byType(IconButton).evaluate().length,
    };
