import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pet_nudge.dart';

// A fixed "now" in waking, pre-thirsty hours so a lone hungry case is clean.
final _now = DateTime(2026, 11, 23, 14, 0);

PetNudgeState _state({
  DateTime? lastMealLog,
  int waterToday = 2000,
  int waterGoal = 1893,
  List<DateTime> firedToday = const [],
  bool paused = false,
  bool petEnabled = true,
}) =>
    PetNudgeState(
      lastMealLog: lastMealLog,
      waterToday: waterToday,
      waterGoal: waterGoal,
      firedToday: firedToday,
      paused: paused,
      petEnabled: petEnabled,
    );

void main() {
  group('[DIR] dueNudges — hungry trigger', () {
    test('no meal for 6 h is hungry', () {
      // testTheory: directional — time since the last meal log crosses the threshold.
      // contract: lastMealLog 6 h before now 14:00, water full → [hungry].
      // implication: AC1 — a long gap in logging asks the user to log a meal.
      final s = _state(lastMealLog: _now.subtract(const Duration(hours: 6)));
      expect(dueNudges(s, _now), contains(PetNudgeKind.hungry));
    });

    test('a meal 2 h ago is not hungry', () {
      // testTheory: directional — below the threshold means no nudge.
      // contract: lastMealLog 2 h before now, water full → no hungry.
      // implication: AC1 — recent logging does not nag.
      final s = _state(lastMealLog: _now.subtract(const Duration(hours: 2)));
      expect(dueNudges(s, _now), isNot(contains(PetNudgeKind.hungry)));
    });

    test('never logged is hungry', () {
      // testTheory: boundary value — null last meal is an unbounded gap.
      // contract: lastMealLog null, water full → [hungry].
      // implication: AC1 — a brand-new day with no meal still nudges.
      expect(dueNudges(_state(lastMealLog: null), _now),
          contains(PetNudgeKind.hungry));
    });
  });

  group('[DIR] dueNudges — thirsty trigger', () {
    final afternoon = DateTime(2026, 11, 23, 16, 0);

    test('under half target after 15:00 is thirsty', () {
      // testTheory: directional — water below 50% of target after mid-afternoon.
      // contract: water 20 of 64 oz (591/1893 ml), now 16:00, recent meal → [thirsty].
      // implication: AC2 — a dry day asks the user to log water.
      final s = _state(
        lastMealLog: afternoon.subtract(const Duration(hours: 1)),
        waterToday: 591,
        waterGoal: 1893,
      );
      expect(dueNudges(s, afternoon), contains(PetNudgeKind.thirsty));
    });

    test('at or above half target is not thirsty', () {
      // testTheory: directional — crossing 50% clears the nudge.
      // contract: water 1183 of 1893 ml (>50%), now 16:00 → no thirsty.
      // implication: AC2 — enough water does not nag.
      final s = _state(
        lastMealLog: afternoon.subtract(const Duration(hours: 1)),
        waterToday: 1183,
        waterGoal: 1893,
      );
      expect(dueNudges(s, afternoon), isNot(contains(PetNudgeKind.thirsty)));
    });

    test('before 15:00 is never thirsty', () {
      // testTheory: boundary value — the time-of-day gate holds.
      // contract: water 0 of 1893 ml but now 13:00 → no thirsty.
      // implication: AC2 — no early-day water nagging.
      final s = _state(
        lastMealLog: DateTime(2026, 11, 23, 13).subtract(const Duration(hours: 1)),
        waterToday: 0,
        waterGoal: 1893,
      );
      expect(dueNudges(s, DateTime(2026, 11, 23, 13)),
          isNot(contains(PetNudgeKind.thirsty)));
    });
  });

  group('[BVA] dueNudges — gating', () {
    test('quiet hours suppress everything', () {
      // testTheory: boundary value — inside the quiet window, nothing fires.
      // contract: hungry conditions met but now 23:30 → empty.
      // implication: AC3 — no late-night buzzing.
      final night = DateTime(2026, 11, 23, 23, 30);
      final s = _state(lastMealLog: night.subtract(const Duration(hours: 8)));
      expect(dueNudges(s, night), isEmpty);
      expect(isQuietHour(night), isTrue);
      expect(isQuietHour(DateTime(2026, 11, 23, 8, 0)), isFalse);
    });

    test('daily cap suppresses further nudges', () {
      // testTheory: boundary value — two fires is the day's limit.
      // contract: firedToday has 2 entries → empty despite hunger.
      // implication: AC4 — at most two nudges a day.
      final s = _state(
        lastMealLog: _now.subtract(const Duration(hours: 8)),
        firedToday: [
          _now.subtract(const Duration(hours: 6)),
          _now.subtract(const Duration(hours: 4)),
        ],
      );
      expect(dueNudges(s, _now), isEmpty);
    });

    test('a fire within 3 h blocks a new nudge', () {
      // testTheory: boundary value — minimum spacing between nudges.
      // contract: one fire 1 h ago → empty; the same fire 3 h ago → non-empty.
      // implication: AC5 — nudges stay at least three hours apart.
      final recent = _state(
        lastMealLog: _now.subtract(const Duration(hours: 8)),
        firedToday: [_now.subtract(const Duration(hours: 1))],
      );
      expect(dueNudges(recent, _now), isEmpty);
      final spaced = _state(
        lastMealLog: _now.subtract(const Duration(hours: 8)),
        firedToday: [_now.subtract(const Duration(hours: 3))],
      );
      expect(dueNudges(spaced, _now), isNotEmpty);
    });

    test('paused or pet-off suppresses everything', () {
      // testTheory: invariance — either switch off means silence.
      // contract: hungry conditions met, paused true → empty; petEnabled false → empty.
      // implication: AC6 — pausing or hiding the pet stops nudges.
      final base = _state(lastMealLog: _now.subtract(const Duration(hours: 8)));
      expect(
        dueNudges(
          _state(lastMealLog: base.lastMealLog, paused: true),
          _now,
        ),
        isEmpty,
      );
      expect(
        dueNudges(
          _state(lastMealLog: base.lastMealLog, petEnabled: false),
          _now,
        ),
        isEmpty,
      );
    });
  });

  group('[INV] notification id ranges (Fix A)', () {
    test('meal, medication and nudge ids never collide', () {
      // testTheory: invariance — reserved ranges keep ids distinct.
      // contract: meal id 5, med id 5+offset, and the two nudge ids are all different.
      // implication: AC8 — a meal and medication with the same entry id do not overwrite.
      const mealId = 5;
      const medId = mealId + medCheckinIdOffset;
      final ids = {mealId, medId, nudgeHungryId, nudgeThirstyId};
      expect(ids.length, 4);
      expect(medCheckinIdOffset, 1000000);
    });
  });

  group('[MFT] nudge copy (AC10)', () {
    test('copy is gentle, with no failure framing', () {
      // testTheory: minimum functionality — the user-facing strings are safe.
      // contract: each nudge body excludes failed/over/under/missed and bare deficits.
      // implication: AC10 — nudges never shame the user.
      const banned = ['failed', 'over', 'under', 'missed', 'goal missed'];
      for (final c in petNudgeCopy.values) {
        final text = '${c.title} ${c.body}'.toLowerCase();
        for (final w in banned) {
          expect(text.contains(w), isFalse, reason: '"$w" in "$text"');
        }
      }
      expect(petNudgeCopy[PetNudgeKind.hungry]!.body, 'Log a meal to feed it.');
      expect(
        petNudgeCopy[PetNudgeKind.thirsty]!.body,
        'Log some water to fill its bowl.',
      );
    });
  });

  group('[DIR] planPetNudges — schedule and cancel', () {
    final afternoon = DateTime(2026, 11, 23, 16, 0);

    test('a recent meal reschedules hungry into the future', () {
      // testTheory: directional — logging defers the hungry nudge, not cancels it.
      // contract: lastMealLog 1 h ago → hungry scheduled ~5 h after that meal, after now.
      // implication: AC7 — logging a meal pushes the next hungry reminder out.
      final s = _state(
        lastMealLog: _now.subtract(const Duration(hours: 1)),
        waterToday: 2000,
      );
      final plan = planPetNudges(s, _now);
      expect(plan.schedule.containsKey(PetNudgeKind.hungry), isTrue);
      expect(plan.schedule[PetNudgeKind.hungry]!.isAfter(_now), isTrue);
    });

    test('an overdue meal defers hungry rather than firing now', () {
      // testTheory: boundary value — an already-crossed threshold still fires later.
      // contract: lastMealLog 8 h ago → hungry scheduled at now + defer, after now.
      // implication: AC7 — a stale gap only nags on continued absence.
      final s = _state(lastMealLog: _now.subtract(const Duration(hours: 8)));
      final at = planPetNudges(s, _now).schedule[PetNudgeKind.hungry]!;
      expect(at.isAfter(_now), isTrue);
    });

    test('meeting the water target cancels thirsty', () {
      // testTheory: directional — enough water removes the thirsty nudge.
      // contract: water ≥ target → cancel has thirsty, schedule has none.
      // implication: AC7 — logging enough water clears the thirsty reminder.
      final s = _state(
        lastMealLog: afternoon.subtract(const Duration(hours: 1)),
        waterToday: 1893,
        waterGoal: 1893,
      );
      final plan = planPetNudges(s, afternoon);
      expect(plan.cancel, contains(PetNudgeKind.thirsty));
      expect(plan.schedule.containsKey(PetNudgeKind.thirsty), isFalse);
    });

    test('being under target schedules thirsty', () {
      // testTheory: directional — a dry day keeps a thirsty nudge pending.
      // contract: water < 50% of target → schedule has thirsty.
      // implication: AC7 — an unmet water target leaves the reminder armed.
      final s = _state(
        lastMealLog: afternoon.subtract(const Duration(hours: 1)),
        waterToday: 300,
        waterGoal: 1893,
      );
      expect(planPetNudges(s, afternoon).schedule, contains(PetNudgeKind.thirsty));
    });

    test('paused or pet-off cancels both and schedules nothing', () {
      // testTheory: invariance — either switch off means no pending nudges.
      // contract: paused → empty schedule, cancel both; same for petEnabled false.
      // implication: AC6/AC7 — pausing or hiding the pet clears armed reminders.
      final paused = planPetNudges(
        _state(lastMealLog: _now, paused: true),
        _now,
      );
      expect(paused.schedule, isEmpty);
      expect(paused.cancel, {PetNudgeKind.hungry, PetNudgeKind.thirsty});

      final off = planPetNudges(
        _state(lastMealLog: _now, petEnabled: false),
        _now,
      );
      expect(off.schedule, isEmpty);
      expect(off.cancel, {PetNudgeKind.hungry, PetNudgeKind.thirsty});
    });
  });
}
