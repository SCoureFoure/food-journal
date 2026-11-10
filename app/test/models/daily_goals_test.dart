import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';

GoalSnapshot _snap(int id, DateTime date, int cal) => GoalSnapshot(
      id: id,
      effectiveDate: date,
      goals: DailyGoals(calories: cal),
      createdAt: date,
    );

void main() {
  group('[BVA] goalsForDate — empty history', () {
    // testTheory: boundary — no snapshots at all.
    // contract: empty history yields DailyGoals.none.
    // implication: a user who never set goals sees no goal bars.
    test('returns DailyGoals.none', () {
      expect(goalsForDate(const [], DateTime(2026, 11, 10)), DailyGoals.none);
    });
  });

  group('[MFT] goalsForDate — latest snapshot on or before the day', () {
    // testTheory: minimum functionality — history is applied by date.
    // contract: the snapshot with greatest effectiveDate <= day applies; none before.
    // implication: AC3 — changing goals never rewrites past days.
    final history = [
      _snap(1, DateTime(2026, 11, 1), 2000),
      _snap(2, DateTime(2026, 11, 10), 1800),
    ];

    test('AC3: 11-05 -> 2000, 11-10 -> 1800, 10-31 -> none', () {
      expect(goalsForDate(history, DateTime(2026, 11, 5)),
          const DailyGoals(calories: 2000));
      expect(goalsForDate(history, DateTime(2026, 11, 10)),
          const DailyGoals(calories: 1800));
      expect(goalsForDate(history, DateTime(2026, 10, 31)), DailyGoals.none);
    });
  });

  group('[BVA] goalsForDate — time of day on the boundary day', () {
    // testTheory: boundary — a day argument carrying a time.
    // contract: day is truncated to its date before comparing.
    // implication: "now" can be passed straight in without losing today's goal.
    test('11-10 23:59 still matches the 11-10 snapshot', () {
      final history = [_snap(1, DateTime(2026, 11, 10), 1800)];
      expect(goalsForDate(history, DateTime(2026, 11, 10, 23, 59)),
          const DailyGoals(calories: 1800));
    });
  });

  group('[INV] goalsForDate — input order does not matter', () {
    // testTheory: invariance — permuting the input list.
    // contract: ties on effectiveDate break by greatest id, regardless of order.
    // implication: AC4 — a re-save on the same day wins.
    test('same date, ids 1 and 2 given [2, 1] -> id 2 wins', () {
      final d = DateTime(2026, 11, 10);
      final history = [_snap(2, d, 2100), _snap(1, d, 2000)];
      expect(goalsForDate(history, d), const DailyGoals(calories: 2100));
    });
  });

  group('[MFT] DailyGoals helpers', () {
    // testTheory: minimum functionality of the value type.
    // contract: isEmpty reflects all-null; effectiveWaterMl falls back to 1893.
    // implication: the water bar always has a target.
    test('isEmpty and effectiveWaterMl', () {
      expect(DailyGoals.none.isEmpty, isTrue);
      expect(const DailyGoals(waterMl: 2366).isEmpty, isFalse);
      expect(const DailyGoals().effectiveWaterMl, 1893);
      expect(const DailyGoals(waterMl: 2366).effectiveWaterMl, 2366);
    });
  });
}
