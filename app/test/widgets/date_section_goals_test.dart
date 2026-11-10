import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/home/date_section.dart';

/// Configurable fake: never touches sqlite.
class _FakeStorage extends StorageService {
  @override
  Future<({int cal, double prot, double carbs, double fat})>
      getMacroTotalsForMeals(List<int> mealIds) async {
    return (cal: 1450, prot: 0.0, carbs: 0.0, fat: 0.0);
  }
}

final _history = [
  GoalSnapshot(
    id: 1,
    effectiveDate: DateTime(2026, 11, 1),
    goals: const DailyGoals(calories: 2000),
    createdAt: DateTime(2026, 11, 1),
  ),
  GoalSnapshot(
    id: 2,
    effectiveDate: DateTime(2026, 11, 10),
    goals: const DailyGoals(calories: 1800),
    createdAt: DateTime(2026, 11, 10),
  ),
];

Widget _wrap(DateSection section) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: section),
      ),
    );

DateSection _section({
  required DateTime day,
  required DailyGoals goals,
  required _FakeStorage storage,
}) {
  final meal = MealEntry(
    id: 1,
    date: day,
    time: '12:00 PM',
    mealType: 'lunch',
    createdAt: DateTime(day.year, day.month, day.day, 12),
  );
  return DateSection(
    date: day,
    meals: [meal],
    medications: const <Medication>[],
    feelings: const <ReactionLog>[],
    waterLogs: const <WaterLog>[],
    weightLogs: const <WeightLog>[],
    storage: storage,
    isToday: false,
    onReload: () {},
    goals: goals,
  );
}

void main() {
  group('[MFT] DateSection — day goal (AC18)', () {
    // testTheory: MFT
    // contract: a past day shows the goal that applied on that day, not today's.
    // implication: if this fails, past days show a target the user never had.
    testWidgets('2026-11-05 shows its own 2000 goal, not today\'s 1800', (tester) async {
      final day = DateTime(2026, 11, 5);
      await tester.pumpWidget(_wrap(_section(
        day: day,
        goals: goalsForDate(_history, day),
        storage: _FakeStorage(),
      )));

      await tester.tap(find.textContaining('November 5'));
      await tester.pumpAndSettle();

      expect(find.text('1450 / 2000'), findsOneWidget);
      expect(find.text('1450 / 1800'), findsNothing);
    });

    // testTheory: BVA
    // contract: a day before any snapshot has no goal, so totals show with no " / ".
    // implication: if this fails, days before the first saved goal show a made-up target.
    testWidgets('2026-10-30 before any snapshot shows bare totals', (tester) async {
      final day = DateTime(2026, 10, 30);
      await tester.pumpWidget(_wrap(_section(
        day: day,
        goals: goalsForDate(_history, day),
        storage: _FakeStorage(),
      )));

      await tester.tap(find.textContaining('October 30'));
      await tester.pumpAndSettle();

      expect(find.text('1450'), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
    });
  });
}
