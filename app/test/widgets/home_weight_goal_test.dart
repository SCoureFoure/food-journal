import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/goal_estimate.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/screens/home/home_screen.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mutable fake: never touches sqlite.
class _FakeStorage extends StorageService {
  final List<GoalSnapshot> history;
  final List<WeightLog> weightLogs;
  final List<DailyGoals> saved = [];

  _FakeStorage({required this.history, required this.weightLogs});

  @override
  Future<List<MealEntry>> getAllMeals() async => [];

  @override
  Future<List<Medication>> getAllMedications() async => [];

  @override
  Future<List<ReactionLog>> getStandaloneReactionLogs() async => [];

  @override
  Future<List<WaterLog>> getAllWaterLogs() async => [];

  @override
  Future<List<WeightLog>> getAllWeightLogs() async => weightLogs;

  @override
  Future<List<GoalSnapshot>> getGoalHistory() async => history;

  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async =>
          (cal: 0, prot: 0.0, carbs: 0.0, fat: 0.0);

  @override
  Future<int> saveGoals(DailyGoals goals, {DateTime? now}) async {
    final n = DateTime.now();
    history.add(GoalSnapshot(
      id: history.length + 1,
      effectiveDate: _midnight(n),
      goals: goals,
      createdAt: n,
    ));
    saved.add(goals);
    return history.length;
  }
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

WeightLog _weigh(int id, double lb, int daysAgo) => WeightLog(
      id: id,
      date: _midnight(_daysAgo(daysAgo)),
      time: '8:00 AM',
      weightValue: lb,
      unit: 'lbs',
      createdAt: _daysAgo(daysAgo),
    );

_FakeStorage _metFake({double lb = 169}) => _FakeStorage(
      history: [
        GoalSnapshot(
          id: 1,
          effectiveDate: _midnight(_daysAgo(9)),
          goals: const DailyGoals(
            calories: 1800,
            waterMl: 1893,
            targetWeightLb: 170,
            weightDirection: WeightDirection.lose,
          ),
          createdAt: _daysAgo(9),
        ),
      ],
      weightLogs: [_weigh(1, lb, 1)],
    );

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

void _mockPrefs({Map<String, Object> extra = const {}}) {
  SharedPreferences.setMockInitialValues({
    'goal_bars_animated': false,
    ...extra,
  });
}

Future<void> _pumpHome(WidgetTester tester, _FakeStorage fake) async {
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(key: UniqueKey(), storageOverride: fake)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] journal weight-goal prompt (AC25)', () {
    // testTheory: MFT
    // contract: a met goal shows the prompt text with the target weight.
    // implication: if this fails, the user is never told the goal was reached (AC25).
    testWidgets('met goal shows prompt', (tester) async {
      _mockPrefs();
      await _pumpHome(tester, _metFake());

      expect(_anchor('goal-weight-met'), findsOneWidget);
      expect(find.text('You reached 170 lb! Set a new goal?'), findsOneWidget);
    });
  });

  group('[DIR] journal weight-goal dismissal (AC25)', () {
    // testTheory: DIR
    // contract: Not now hides the prompt and persists across a fresh HomeScreen.
    // implication: if this fails, the prompt nags on every reload (AC25).
    testWidgets('Not now persists the dismissal', (tester) async {
      _mockPrefs();
      final fake = _metFake();
      await _pumpHome(tester, fake);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(_anchor('goal-weight-met'), findsNothing);
      expect(await SettingsService().weightGoalDismissedLogId, 1);

      await _pumpHome(tester, fake);
      expect(_anchor('goal-weight-met'), findsNothing);
    });

    // testTheory: DIR
    // contract: a weigh-in logged after dismissal brings the prompt back.
    // implication: if this fails, a dismissal silences the prompt forever (AC25).
    testWidgets('new weigh-in revives the prompt', (tester) async {
      _mockPrefs();
      final fake = _metFake();
      await _pumpHome(tester, fake);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(_anchor('goal-weight-met'), findsNothing);

      fake.weightLogs.add(_weigh(2, 168, 0));
      await _pumpHome(tester, fake);
      expect(_anchor('goal-weight-met'), findsOneWidget);
    });
  });

  group('[INV] journal weight-goal not met (AC25)', () {
    // testTheory: INV
    // contract: a weigh-in on the wrong side of the target never shows the prompt.
    // implication: if this fails, the prompt fires before the goal is reached (AC25).
    testWidgets('171 lb vs 170 target shows nothing', (tester) async {
      _mockPrefs();
      await _pumpHome(tester, _metFake(lb: 171));

      expect(_anchor('goal-weight-met'), findsNothing);
    });
  });

  group('[DIR] journal new weight goal (AC26)', () {
    // testTheory: DIR
    // contract: Set new goal -> calculator -> Use these -> edit dialog (water kept)
    // -> Save stores goals without a target and the prompt disappears.
    // implication: if this fails, the user cannot start a new goal from the prompt (AC26).
    testWidgets('maintain goal clears the target and the prompt', (tester) async {
      const profile = GoalProfile(
        weightLb: 169,
        heightIn: 70,
        age: 30,
        formula: BodyFormula.male,
        activity: ActivityLevel.moderate,
        goal: WeightGoal.maintain,
      );
      _mockPrefs(extra: {'goal_profile': profile.encode()});
      final fake = _metFake();
      await _pumpHome(tester, fake);

      await tester.tap(find.text('Set new goal'));
      await tester.pumpAndSettle();
      expect(_anchor('goal-calculator-dialog'), findsOneWidget);

      await tester.tap(find.text('Use these'));
      await tester.pumpAndSettle();
      expect(_anchor('edit-goals-dialog'), findsOneWidget);
      expect(
        find.descendant(
          of: _anchor('field-goal-water'),
          matching: find.text('64'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fake.saved.last.targetWeightLb, isNull);
      expect(_anchor('goal-weight-met'), findsNothing);
    });
  });

  group('[INV] journal new weight goal cancel (AC26)', () {
    // testTheory: INV
    // contract: cancelling the calculator saves nothing and keeps the prompt.
    // implication: if this fails, backing out silently drops the user's goal (AC26).
    testWidgets('cancel keeps prompt, saves nothing', (tester) async {
      _mockPrefs();
      final fake = _metFake();
      await _pumpHome(tester, fake);

      await tester.tap(find.text('Set new goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(fake.saved, isEmpty);
      expect(_anchor('goal-weight-met'), findsOneWidget);
    });
  });
}
