import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/widgets/settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder anchor(String id) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      );

  SwitchListTile pauseSwitch(WidgetTester tester) =>
      tester.widget<SwitchListTile>(
        find.descendant(
          of: anchor('switch-pet-nudges-paused'),
          matching: find.byType(SwitchListTile),
        ),
      );

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SettingsDialog(settings: SettingsService())),
    ));
    await tester.pumpAndSettle();
  }

  group('[MFT] Pause pet reminders default', () {
    test('isPetNudgesPaused defaults to false when unset', () async {
      // testTheory: minimum functionality — default preference value.
      // contract: with no stored value, isPetNudgesPaused resolves false.
      // implication: AC11 — reminders are active until the user pauses them.
      SharedPreferences.setMockInitialValues({});
      expect(await SettingsService().isPetNudgesPaused, isFalse);
    });

    testWidgets('the switch renders off when unset', (tester) async {
      // testTheory: minimum functionality — the switch matches the default.
      // contract: with no stored value, the Pause switch renders off.
      // implication: AC11 — the toggle shows reminders are active by default.
      SharedPreferences.setMockInitialValues({});
      await pumpDialog(tester);
      expect(anchor('switch-pet-nudges-paused'), findsOneWidget);
      expect(pauseSwitch(tester).value, isFalse);
    });
  });

  group('[DIR] Pause pet reminders toggle', () {
    testWidgets('tapping it pauses and persists', (tester) async {
      // testTheory: directional — toggling sets and stores the pause flag.
      // contract: tapping Pause pet reminders turns it on and persists true.
      // implication: AC11 — the user can mute nudges and the choice survives a restart.
      SharedPreferences.setMockInitialValues({});
      await pumpDialog(tester);

      await tester.tap(find.text('Pause pet reminders'));
      await tester.pumpAndSettle();

      expect(pauseSwitch(tester).value, isTrue);
      expect(await SettingsService().isPetNudgesPaused, isTrue);
    });

    testWidgets('stored true renders the switch on', (tester) async {
      // testTheory: directional — the stored flag drives the rendered switch.
      // contract: a stored pet_nudges_paused=true renders the switch on.
      // implication: AC11 — a paused state is reflected after a rebuild.
      SharedPreferences.setMockInitialValues({'pet_nudges_paused': true});
      await pumpDialog(tester);
      expect(pauseSwitch(tester).value, isTrue);
    });
  });
}
