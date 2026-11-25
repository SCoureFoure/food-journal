import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/pet_feed.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/watch_sample.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/screens/home/home_screen.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurable fake: never touches sqlite.
class _FakeStorage extends StorageService {
  final List<MealEntry> meals;
  final List<WaterLog> water;
  final Map<int, int> calById;
  final List<GoalSnapshot> history;

  _FakeStorage({
    this.meals = const [],
    this.water = const [],
    this.calById = const {},
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
  Future<List<WatchSample>> getWatchSamples(
          {required DateTime from, required DateTime to}) async =>
      const [];

  @override
  Future<List<GoalSnapshot>> getGoalHistory() async => history;

  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async {
    final cal = mealIds.fold<int>(0, (s, id) => s + (calById[id] ?? 0));
    return (cal: cal, prot: 0.0, carbs: 0.0, fat: 0.0);
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

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Future<void> _pumpHome(
  WidgetTester tester,
  _FakeStorage fake, {
  ValueNotifier<PetFeed?>? notifier,
}) async {
  SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(storageOverride: fake, petFeed: notifier),
    ),
  );
  // Goal bars animate forever once goals are set: never pumpAndSettle.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] home publishes today\'s PetFeed (AC4)', () {
    // testTheory: MFT
    // contract: publishes meals, water and calories for today only, with the default water goal when none is saved.
    // implication: AC4 — if this fails, the pet reports yesterday's meals or the wrong water or calorie total.
    testWidgets('2 meals today, 1 yesterday, water 500+446 today', (tester) async {
      final now = DateTime.now();
      final notifier = ValueNotifier<PetFeed?>(null);
      final fake = _FakeStorage(
        meals: [
          _meal(1, now),
          _meal(2, now),
          _meal(3, now.subtract(const Duration(days: 1))),
        ],
        water: [
          _water(1, now, 500),
          _water(2, now, 446),
        ],
        calById: {1: 400, 2: 250, 3: 900},
      );
      await _pumpHome(tester, fake, notifier: notifier);

      expect(
        notifier.value,
        const PetFeed(
          mealsToday: 2,
          waterMl: 946,
          waterGoalMl: 1893,
          caloriesToday: 650,
        ),
      );
    });
  });

  group('[DIR] home publishes the goals in effect today', () {
    // testTheory: DIR
    // contract: waterGoalMl and calorieGoal are the effective targets from goal history for today.
    // implication: AC4 — if this fails, the pet's bars fill toward the wrong targets.
    testWidgets('snapshot effective today sets waterGoalMl and calorieGoal', (tester) async {
      final now = DateTime.now();
      final notifier = ValueNotifier<PetFeed?>(null);
      final fake = _FakeStorage(
        history: [
          GoalSnapshot(
            id: 1,
            effectiveDate: _midnight(now),
            goals: const DailyGoals(calories: 2000, waterMl: 2366),
            createdAt: now,
          ),
        ],
      );
      await _pumpHome(tester, fake, notifier: notifier);

      expect(notifier.value?.calorieGoal, 2000);
      expect(notifier.value?.waterGoalMl, 2366);
    });
  });

  group('[INV] home publishes only today\'s water', () {
    // testTheory: INV
    // contract: water logged yesterday is not counted in waterMl.
    // implication: AC4 — if this fails, yesterday's water fills today's pet.
    testWidgets('only-yesterday water yields waterMl 0', (tester) async {
      final now = DateTime.now();
      final notifier = ValueNotifier<PetFeed?>(null);
      final fake = _FakeStorage(
        water: [_water(1, now.subtract(const Duration(days: 1)), 300)],
      );
      await _pumpHome(tester, fake, notifier: notifier);

      expect(notifier.value?.waterMl, 0);
    });
  });

  group('[INV] home loads without a PetFeed notifier', () {
    // testTheory: INV
    // contract: HomeScreen without petFeed loads normally and throws nothing.
    // implication: AC4 — if this fails, the optional shell hook breaks standalone home.
    testWidgets('no petFeed passed loads without exception', (tester) async {
      await _pumpHome(tester, _FakeStorage());

      expect(tester.takeException(), isNull);
    });
  });

  group('[MFT] pet sheet can open the goals dialog (AC4)', () {
    // testTheory: MFT
    // contract: HomeScreenState.editGoals() opens the edit-goals dialog.
    // implication: AC4 — if this fails, the pet's set-calorie-goal action does nothing.
    testWidgets('editGoals opens edit-goals-dialog', (tester) async {
      await _pumpHome(tester, _FakeStorage());

      unawaited(tester
          .state<HomeScreenState>(find.byType(HomeScreen))
          .editGoals());
      await tester.pumpAndSettle();

      expect(_anchor('edit-goals-dialog'), findsOneWidget);
    });
  });
}
