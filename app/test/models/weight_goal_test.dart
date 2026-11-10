import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/weight_goal.dart';
import 'package:food_journal/models/weight_log.dart';

final _today = DateTime(2026, 11, 10);

GoalSnapshot _snap(int id, DateTime date, DailyGoals goals) => GoalSnapshot(
      id: id,
      effectiveDate: date,
      goals: goals,
      createdAt: date,
    );

WeightLog _log(int id, DateTime date, double value, String unit) => WeightLog(
      id: id,
      date: date,
      time: '8:00 AM',
      weightValue: value,
      unit: unit,
      createdAt: date,
    );

const _lose170 = DailyGoals(
    targetWeightLb: 170, weightDirection: WeightDirection.lose);
const _gain150 = DailyGoals(
    targetWeightLb: 150, weightDirection: WeightDirection.gain);

void main() {
  group('[MFT] weightGoalMet — lose goal reached', () {
    // testTheory: minimum functionality — a lose target is met by a weigh-in at or below it.
    // contract: lose 170 from 11-01; a 169.5 lb log on 11-08 after a 175 lb log yields met.
    // implication: AC22 — the prompt appears once the user drops past the target.
    test('AC22: 175 then 169.5 lb -> met (170, lose)', () {
      final history = [_snap(1, DateTime(2026, 11, 1), _lose170)];
      final logs = [
        _log(1, DateTime(2026, 11, 3), 175, 'lbs'),
        _log(2, DateTime(2026, 11, 8), 169.5, 'lbs'),
      ];
      expect(weightGoalMet(history, logs, _today),
          const WeightGoalMet(targetWeightLb: 170, direction: WeightDirection.lose));
    });
  });

  group('[BVA] weightGoalMet — lose target boundary', () {
    // testTheory: boundary — 171 is above the target, exactly 170.0 is on it.
    // contract: lose is met when lb <= target; 171 lb does not meet, 170.0 does.
    // implication: AC22 — the boundary weigh-in counts as reaching the goal.
    final history = [_snap(1, DateTime(2026, 11, 1), _lose170)];

    test('AC22: only 171 lb -> null', () {
      final logs = [_log(1, DateTime(2026, 11, 8), 171, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });

    test('AC22: exactly 170.0 lb -> met', () {
      final logs = [_log(1, DateTime(2026, 11, 8), 170.0, 'lbs')];
      expect(weightGoalMet(history, logs, _today),
          const WeightGoalMet(targetWeightLb: 170, direction: WeightDirection.lose));
    });
  });

  group('[DIR] weightGoalMet — weigh-ins before the goal run are ignored', () {
    // testTheory: directional — a log dated before the goal was set cannot satisfy it.
    // contract: a 165 lb log on 10-30 is before the 11-01 run start, so null.
    // implication: AC22 — old weigh-ins do not trigger a newly set goal.
    test('AC22: 165 lb dated 10-30 only -> null', () {
      final history = [_snap(1, DateTime(2026, 11, 1), _lose170)];
      final logs = [_log(1, DateTime(2026, 10, 30), 165, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });
  });

  group('[MFT] weightGoalMet — gain goal and kg conversion', () {
    // testTheory: minimum functionality — gain is met at or above target; kg is converted to lb.
    // contract: gain 150 from 11-01; 68.5 kg (151.0 lb) meets, 67 kg (147.7 lb) does not.
    // implication: AC23 — gain goals and metric entries are both honored.
    final history = [_snap(1, DateTime(2026, 11, 1), _gain150)];

    test('AC23: 68.5 kg on 11-05 -> met (150, gain)', () {
      final logs = [_log(1, DateTime(2026, 11, 5), 68.5, 'kg')];
      expect(weightGoalMet(history, logs, _today),
          const WeightGoalMet(targetWeightLb: 150, direction: WeightDirection.gain));
    });

    test('AC23: 67 kg on 11-05 -> null', () {
      final logs = [_log(1, DateTime(2026, 11, 5), 67, 'kg')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });
  });

  group('[INV] weightGoalMet — calorie-only snapshot keeps the run', () {
    // testTheory: invariance — changing non-weight targets does not restart the goal run.
    // contract: 11-01 and 11-05 share target 170 lose, so the run starts 11-01.
    // implication: AC24 — editing calories mid-goal keeps earlier weigh-ins counting.
    test('AC24: 169 lb on 11-03 -> met', () {
      final history = [
        _snap(1, DateTime(2026, 11, 1),
            const DailyGoals(calories: 1800, targetWeightLb: 170, weightDirection: WeightDirection.lose)),
        _snap(2, DateTime(2026, 11, 5),
            const DailyGoals(calories: 1700, targetWeightLb: 170, weightDirection: WeightDirection.lose)),
      ];
      final logs = [_log(1, DateTime(2026, 11, 3), 169, 'lbs')];
      expect(weightGoalMet(history, logs, _today),
          const WeightGoalMet(targetWeightLb: 170, direction: WeightDirection.lose));
    });
  });

  group('[INV] weightGoalMet — new target starts a new run', () {
    // testTheory: invariance — a changed target restarts the run at its effective date.
    // contract: 11-01 target 170, 11-05 target 165; run starts 11-05.
    // implication: AC24 — a new target is judged only on weigh-ins from its own start.
    final history = [
      _snap(1, DateTime(2026, 11, 1), _lose170),
      _snap(2, DateTime(2026, 11, 5),
          const DailyGoals(targetWeightLb: 165, weightDirection: WeightDirection.lose)),
    ];

    test('169 lb on 11-03 (before run start) -> null', () {
      final logs = [_log(1, DateTime(2026, 11, 3), 169, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });

    test('164 lb on 11-06 -> met with target 165', () {
      final logs = [_log(1, DateTime(2026, 11, 6), 164, 'lbs')];
      expect(weightGoalMet(history, logs, _today),
          const WeightGoalMet(targetWeightLb: 165, direction: WeightDirection.lose));
    });
  });

  group('[INV] weightGoalMet — future weigh-ins ignored', () {
    // testTheory: invariance — a log dated after today does not count.
    // contract: lose 170 from 11-01; only 169 lb dated 11-11 with today 11-10 -> null.
    // implication: AC22 — a future-dated weigh-in cannot trigger the prompt today.
    test('169 lb on 11-11 (after today 11-10) -> null', () {
      final history = [_snap(1, DateTime(2026, 11, 1), _lose170)];
      final logs = [_log(1, DateTime(2026, 11, 11), 169, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });
  });

  group('[INV] weightGoalMet — latest snapshot decides', () {
    // testTheory: invariance — only the latest eligible snapshot's target counts.
    // contract: latest 11-05 has no target, so null even though 11-01 had one.
    // implication: AC24 — clearing the weight goal ends the prompt.
    test('11-05 maintain (no target) after 11-01 target -> null', () {
      final history = [
        _snap(1, DateTime(2026, 11, 1), _lose170),
        _snap(2, DateTime(2026, 11, 5), const DailyGoals(calories: 2000)),
      ];
      final logs = [_log(1, DateTime(2026, 11, 3), 160, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });

    test('snapshot effective after today is ignored', () {
      // testTheory: invariance — future snapshots do not affect today.
      // contract: a 11-20 target snapshot is not eligible for today 11-10.
      // implication: AC22 — future goal edits do not trigger a prompt today.
      final history = [
        _snap(1, DateTime(2026, 11, 1), const DailyGoals(calories: 2000)),
        _snap(2, DateTime(2026, 11, 20), _lose170),
      ];
      final logs = [_log(1, DateTime(2026, 11, 8), 160, 'lbs')];
      expect(weightGoalMet(history, logs, _today), isNull);
    });
  });

  group('[BVA] weightGoalMet — empty inputs', () {
    // testTheory: boundary — no history, or no logs.
    // contract: empty history -> null; target with no logs -> null.
    // implication: AC22 — no prompt without a goal or a weigh-in.
    test('empty history -> null', () {
      expect(weightGoalMet(const [], const [], _today), isNull);
    });

    test('history with target but no logs -> null', () {
      final history = [_snap(1, DateTime(2026, 11, 1), _lose170)];
      expect(weightGoalMet(history, const [], _today), isNull);
    });
  });

  group('[MFT] formatWeightLb', () {
    // testTheory: minimum functionality — whole pounds drop the decimal.
    // contract: 170.0 -> '170'; 169.5 -> '169.5'.
    // implication: AC22 — the prompt shows the target without a trailing ".0".
    test('170.0 -> 170, 169.5 -> 169.5', () {
      expect(formatWeightLb(170.0), '170');
      expect(formatWeightLb(169.5), '169.5');
    });
  });
}
