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

  SwitchListTile petSwitch(WidgetTester tester) => tester.widget<SwitchListTile>(
        find.descendant(
          of: anchor('switch-pet-enabled'),
          matching: find.byType(SwitchListTile),
        ),
      );

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SettingsDialog(settings: SettingsService())),
    ));
    await tester.pumpAndSettle();
  }

  /// [MFT] Pet default — holds the contract that the pet is shown until the
  /// user turns it off. If this regresses: first-run users lose the companion.
  group('[MFT] Show pet default', () {
    // testTheory: Minimum functionality — default preference value
    // contract: with no stored value, isPetEnabled resolves true
    // implication: AC9 — pet is visible by default on a fresh install
    test('isPetEnabled defaults to true when unset', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SettingsService().isPetEnabled, isTrue);
    });

    // testTheory: Minimum functionality — switch reflects default
    // contract: with no stored value, the Show pet switch renders on
    // implication: AC9 — the settings toggle matches the actual default
    testWidgets('Show pet switch is on when unset', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDialog(tester);

      expect(anchor('switch-pet-enabled'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Show pet'),
      );
      expect(tile.value, isTrue);
    });
  });

  /// [DIR] Show pet toggle — holds the contract that flipping the switch both
  /// updates the UI and persists the new value. If this regresses: the pet
  /// setting looks changed but reverts on next launch.
  group('[DIR] Show pet toggle', () {
    // testTheory: Directional — toggling changes state in the expected direction
    // contract: tapping Show pet when on turns it off and persists false
    // implication: AC9 — user can hide the pet and the choice is stored
    testWidgets('tapping Show pet turns it off and persists', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDialog(tester);

      await tester.tap(find.text('Show pet'));
      await tester.pumpAndSettle();

      expect(petSwitch(tester).value, isFalse);
      expect(await SettingsService().isPetEnabled, isFalse);
    });

    // testTheory: Directional — stored preference drives the rendered switch
    // contract: a stored pet_enabled=false renders the switch off
    // implication: AC9 — a previously hidden pet stays hidden in the settings UI
    testWidgets('stored false renders switch off', (tester) async {
      SharedPreferences.setMockInitialValues({'pet_enabled': false});
      await pumpDialog(tester);

      expect(petSwitch(tester).value, isFalse);
    });
  });
}
