import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/screens/home/home_screen.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/home/week_summary_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configurable fake: never touches sqlite.
class _FakeStorage extends StorageService {
  final List<MealEntry> meals;
  final Map<int, int> calById;
  final List<GoalSnapshot> history;
  final List<DailyGoals> saved = [];
  int historyCalls = 0;

  _FakeStorage({
    this.meals = const [],
    this.calById = const {},
    List<GoalSnapshot>? history,
  }) : history = history ?? [];

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
  Future<List<GoalSnapshot>> getGoalHistory() async {
    historyCalls++;
    return history;
  }

  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async {
    final cal = mealIds.fold<int>(0, (s, id) => s + (calById[id] ?? 0));
    return (cal: cal, prot: 0.0, carbs: 0.0, fat: 0.0);
  }

  @override
  Future<int> saveGoals(DailyGoals goals, {DateTime? now}) async {
    saved.add(goals);
    return 1;
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

GoalSnapshot _snap(DailyGoals g) => GoalSnapshot(
      id: 1,
      effectiveDate: _midnight(DateTime.now()),
      goals: g,
      createdAt: DateTime.now(),
    );

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Future<void> _pumpHome(WidgetTester tester, _FakeStorage fake) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(storageOverride: fake)),
  );
  // Goal bars animate forever once goals are set: never pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] journal Goals intake (AC11)', () {
    // testTheory: MFT
    // contract: the panel's calories intake sums only today's meals.
    // implication: if this fails, yesterday's meals inflate today's progress.
    testWidgets('today 1450 kcal, yesterday excluded', (tester) async {
      final now = DateTime.now();
      final fake = _FakeStorage(
        meals: [
          _meal(1, now),
          _meal(2, now),
          _meal(3, now.subtract(const Duration(days: 1))),
        ],
        calById: {1: 900, 2: 550, 3: 700},
        history: [_snap(const DailyGoals(calories: 2000))],
      );
      await _pumpHome(tester, fake);

      expect(
        find.descendant(
          of: _anchor('goal-row-calories'),
          matching: find.text('1450 / 2000 kcal'),
        ),
        findsOneWidget,
      );
      expect(find.text('2150 / 2000 kcal'), findsNothing);
    });
  });

  group('[BVA] journal Goals empty state', () {
    // testTheory: BVA
    // contract: with no goals and no entries the panel and empty state both show.
    // implication: if this fails, a new user cannot set goals before logging.
    testWidgets('panel + set button above empty state', (tester) async {
      await _pumpHome(tester, _FakeStorage());

      expect(_anchor('goals-panel'), findsOneWidget);
      expect(_anchor('btn-set-goals'), findsOneWidget);
      expect(_anchor('home-empty-state'), findsOneWidget);
    });
  });

  group('[DIR] journal Goals save path (AC8)', () {
    // testTheory: DIR
    // contract: Set goals -> enter 1800 -> Save saves once and reloads history.
    // implication: if this fails, edits are lost or the panel stays stale.
    testWidgets('save persists once and reloads', (tester) async {
      final fake = _FakeStorage();
      await _pumpHome(tester, fake);

      await tester.tap(_anchor('btn-set-goals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.enterText(
        find.descendant(
          of: _anchor('field-goal-calories'),
          matching: find.byType(TextField),
        ),
        '1800',
      );
      await tester.tap(_anchor('btn-save-goals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.saved, [const DailyGoals(calories: 1800)]);
      expect(fake.historyCalls, greaterThanOrEqualTo(2));
    });
  });

  group('[INV] journal Goals cancel path', () {
    // testTheory: INV
    // contract: cancelling the dialog never saves.
    // implication: if this fails, backing out silently overwrites goals.
    testWidgets('cancel does not save', (tester) async {
      final fake = _FakeStorage();
      await _pumpHome(tester, fake);

      await tester.tap(_anchor('btn-set-goals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(fake.saved, isEmpty);
    });
  });

  group('[INV] journal Goals fixed placement (AC10)', () {
    // testTheory: INV
    // contract: the panel sits outside the list; scrolling never moves it.
    // implication: if this fails, the panel scrolls away with the feed.
    testWidgets('panel stays put while the list scrolls', (tester) async {
      final now = DateTime.now();
      final meals = [
        for (var i = 0; i < 40; i++)
          _meal(i + 1, now.subtract(Duration(days: i))),
      ];
      final fake = _FakeStorage(
        meals: meals,
        calById: {for (var i = 1; i <= 40; i++) i: 100},
        history: [_snap(const DailyGoals(calories: 2000))],
      );
      await _pumpHome(tester, fake);

      final panelBefore = tester.getTopLeft(_anchor('goals-panel'));
      final sectionBefore =
          tester.getTopLeft(find.byType(WeekSummarySection).first);

      await tester.drag(_anchor('home-meal-list'), const Offset(0, -400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.getTopLeft(_anchor('goals-panel')), panelBefore);

      final sections = find.byType(WeekSummarySection);
      final moved = sections.evaluate().isEmpty ||
          tester.getTopLeft(sections.first).dy < sectionBefore.dy;
      expect(moved, isTrue);
    });
  });
}
