import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] goal bars animation setting', () {
    test('no saved value → moving goal bars on', () async {
      // testTheory: minimum functionality — default is ON until the user flips it.
      // contract: isGoalBarsAnimated with no stored pref → true.
      // implication: S8 — existing wavy look is unchanged for every user today.
      SharedPreferences.setMockInitialValues({});
      expect(await SettingsService().isGoalBarsAnimated, isTrue);
    });

    test('setGoalBarsAnimated(false) then (true) round-trips', () async {
      // testTheory: minimum functionality — the setter writes what the getter reads.
      // contract: after set(false) → false; after set(true) → true.
      // implication: S8 — the Settings switch persists in both directions.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      await settings.setGoalBarsAnimated(false);
      expect(await settings.isGoalBarsAnimated, isFalse);

      await settings.setGoalBarsAnimated(true);
      expect(await settings.isGoalBarsAnimated, isTrue);
    });
  });
}
