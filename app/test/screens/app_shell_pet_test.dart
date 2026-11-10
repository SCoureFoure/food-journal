import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/screens/shell/app_shell.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurable fake: never touches sqlite.
class _FakeStorage extends StorageService {
  final List<MealEntry> meals;
  final List<WaterLog> water;
  final List<GoalSnapshot> history;

  _FakeStorage({
    this.meals = const [],
    this.water = const [],
    this.history = const [],
  });

  @override
  Future<List<MealEntry>> getAllMeals() async => meals;

  @override
  Future<List<Medication>> getAllMedications() async => [];

  @override
  Future<List<ReactionLog>> getStandaloneReactionLogs() async => [];

  @override
  Future<List<WaterLog>> getAllWaterLogs() async => water;

  @override
  Future<List<WeightLog>> getAllWeightLogs() async => [];

  @override
  Future<List<GoalSnapshot>> getGoalHistory() async => history;

  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async {
    return (cal: 0, prot: 0.0, carbs: 0.0, fat: 0.0);
  }
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

MealEntry _meal(int id, DateTime day) => MealEntry(
      id: id,
      date: _midnight(day),
      time: '12:00 PM',
      mealType: 'lunch',
      createdAt: day,
    );

WaterLog _water(int id, DateTime day, int ml) => WaterLog(
      id: id,
      date: _midnight(day),
      time: '9:00 AM',
      amountMl: ml,
      createdAt: DateTime.now(),
    );

Widget _shell([_FakeStorage? fake]) =>
    MaterialApp(home: AppShell(journalStorageOverride: fake ?? _FakeStorage()));

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Future<void> _openMealPlanning(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Meal Planning'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Meal Planning'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] pet avatar placement (AC5)', () {
    // testTheory: MFT
    // contract: with default prefs the avatar shows once, bottom-left, on both tabs at the same spot.
    // implication: AC5 — if this fails, the pet is missing, duplicated, or jumps between tabs.
    testWidgets('bottom-left on journal and meal planning', (tester) async {
      SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppShell));
      expect(_anchor('pet-avatar'), findsOneWidget);
      final c = tester.getCenter(_anchor('pet-avatar'));
      expect(c.dx, lessThan(size.width / 2));
      expect(c.dy, greaterThan(size.height / 2));

      await _openMealPlanning(tester);
      expect(_anchor('pet-avatar'), findsOneWidget);
      expect(tester.getCenter(_anchor('pet-avatar')), c);
    });
  });

  group('[DIR] pet avatar flips in left-handed mode (AC5)', () {
    // testTheory: DIR
    // contract: left_handed moves the avatar to the bottom-right corner.
    // implication: AC5 — if this fails, the avatar collides with the journal's + button.
    testWidgets('left_handed puts the avatar bottom-right', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'goal_bars_animated': false, 'left_handed': true});
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppShell));
      final c = tester.getCenter(_anchor('pet-avatar'));
      expect(c.dx, greaterThan(size.width / 2));
      expect(c.dy, greaterThan(size.height / 2));
    });
  });

  group('[MFT] pet sheet opens with today\'s feed (AC6)', () {
    // testTheory: MFT
    // contract: tapping the avatar opens the sheet showing meals and water from the journal's feed.
    // implication: AC6 — if this fails, the shell's feed never reaches the sheet.
    testWidgets('2 meals and 946 ml show as 2 / 3 meals and 32 / 64 oz',
        (tester) async {
      SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
      final now = DateTime.now();
      await tester.pumpWidget(_shell(_FakeStorage(
        meals: [_meal(1, now), _meal(2, now)],
        water: [_water(1, now, 946)],
      )));
      await tester.pumpAndSettle();

      await tester.tap(_anchor('pet-avatar'));
      await tester.pumpAndSettle();

      expect(_anchor('pet-sheet'), findsWidgets);
      expect(find.text('2 / 3 meals'), findsOneWidget);
      expect(find.text('32 / 64 oz'), findsOneWidget);
    });
  });

  group('[INV] water goal row and meter coexist (AC7)', () {
    // testTheory: INV
    // contract: with a water goal in effect today the sheet shows exactly one goal row and one meter for water.
    // implication: AC7 — if this fails, the water goal is duplicated or its meter is lost.
    testWidgets('goal-row-water and pet-meter-water each appear once',
        (tester) async {
      SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
      final now = DateTime.now();
      await tester.pumpWidget(_shell(_FakeStorage(
        history: [
          GoalSnapshot(
            id: 1,
            effectiveDate: _midnight(now),
            goals: const DailyGoals(waterMl: 1893),
            createdAt: now,
          ),
        ],
      )));
      await tester.pumpAndSettle();

      await tester.tap(_anchor('pet-avatar'));
      await tester.pumpAndSettle();

      expect(_anchor('goal-row-water'), findsOneWidget);
      expect(_anchor('pet-meter-water'), findsOneWidget);
    });
  });

  group('[DIR] hiding the pet from settings persists (AC9)', () {
    // testTheory: DIR
    // contract: toggling Show pet off removes the avatar immediately, on both tabs, and a fresh shell stays without it.
    // implication: AC9 — if this fails, the setting is ignored live or not persisted.
    testWidgets('Show pet off hides the avatar and survives a remount',
        (tester) async {
      SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();
      expect(_anchor('pet-avatar'), findsOneWidget);

      await tester.tap(_anchor('btn-settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show pet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(_anchor('pet-avatar'), findsNothing);
      await _openMealPlanning(tester);
      expect(_anchor('pet-avatar'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();
      expect(_anchor('pet-avatar'), findsNothing);
    });
  });

  group('[INV] pet disabled by preference', () {
    // testTheory: INV
    // contract: pet_enabled false means no avatar is ever built.
    // implication: AC9 — if this fails, users who turned the pet off still see it.
    testWidgets('pet_enabled false shows no avatar', (tester) async {
      SharedPreferences.setMockInitialValues(
          {'pet_enabled': false, 'goal_bars_animated': false});
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      expect(_anchor('pet-avatar'), findsNothing);
    });
  });
}
