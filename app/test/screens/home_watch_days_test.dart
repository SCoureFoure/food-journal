import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
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
  final List<WatchSample> watch;

  _FakeStorage({this.meals = const [], this.watch = const []});

  @override
  Future<List<MealEntry>> getAllMeals() async => meals;

  @override
  Future<List<Medication>> getAllMedications() async => [];

  @override
  Future<List<ReactionLog>> getStandaloneReactionLogs() async => [];

  @override
  Future<List<WaterLog>> getAllWaterLogs() async => [];

  @override
  Future<List<WeightLog>> getAllWeightLogs() async => [];

  @override
  Future<List<GoalSnapshot>> getGoalHistory() async => [];

  @override
  Future<List<WatchSample>> getWatchSamples(
          {required DateTime from, required DateTime to}) async =>
      watch;

  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async =>
          (cal: 0, prot: 0.0, carbs: 0.0, fat: 0.0);
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

MealEntry _meal(int id, DateTime day) => MealEntry(
      id: id,
      date: _midnight(day),
      time: '12:00 PM',
      mealType: 'lunch',
      createdAt: day,
    );

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

String _key(DateTime d) => d.toIso8601String().substring(0, 10);

Future<void> _pumpHome(WidgetTester tester, _FakeStorage fake) async {
  SharedPreferences.setMockInitialValues({'goal_bars_animated': false});
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(storageOverride: fake)),
  );
  // Goal bars animate forever once goals are set: never pumpAndSettle.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] watch data creates journal days (AC7)', () {
    // testTheory: MFT
    // contract: a day with watch samples but no journal entries gets a date section whose subtitle is Biometrics.
    // implication: AC7 — if this fails, passively logged watch days never appear in the feed.
    testWidgets('meal today, steps yesterday: both days have sections', (tester) async {
      final now = DateTime.now();
      final today = _midnight(now);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final fake = _FakeStorage(
        meals: [_meal(1, now)],
        watch: [
          WatchSample(
              kind: WatchKind.steps,
              time: yesterday.add(const Duration(hours: 10)),
              value: 500),
          WatchSample(
              kind: WatchKind.steps,
              time: today.add(const Duration(hours: 1)),
              value: 300),
        ],
      );
      await _pumpHome(tester, fake);

      // The week section is collapsed; its day sections are built only once expanded.
      // Yesterday may fall in the previous week: expand each distinct week found.
      final mondays = {
        for (final d in [today, yesterday])
          DateTime(d.year, d.month, d.day - (d.weekday - 1)),
      };
      for (final monday in mondays) {
        final weekHeader = find.descendant(
          of: _anchor('week-section-${_key(monday)}'),
          matching: find.byType(ExpansionTile),
        );
        expect(weekHeader, findsWidgets);
        await tester.tap(weekHeader.first);
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(_anchor('date-section-${_key(today)}'), findsOneWidget);
      expect(_anchor('date-section-${_key(yesterday)}'), findsOneWidget);
      expect(find.text('Biometrics'), findsOneWidget);
    });
  });
}
