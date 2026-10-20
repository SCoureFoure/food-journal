// Pure-logic tests for the blame suspects ranking (specs/blame_suspects.spec.md).
//
// buildSuspects is pure: threshold on distinct check-ins, dismissal filter,
// food/medication merge, rate = score ÷ times eaten, and symptom/rate/episode/name
// ordering. The DB-bound getSuspects read is covered on device (AC9).

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_suspicion.dart';

FoodSuspicion _row(int logId, String symptom, String name,
        {double weight = 1, SuspicionSource source = SuspicionSource.auto,
        SuspicionTargetType type = SuspicionTargetType.food}) =>
    FoodSuspicion(
      reactionLogId: logId, symptom: symptom, targetType: type, targetId: logId,
      targetName: name, baseWeight: weight, source: source,
      createdAt: DateTime(2026, 10, 1),
    );

void main() {
  // ── AC1 / AC7 / AC8: threshold, empty, food+medication merge ───────────────
  group('[MFT] buildSuspects — threshold and listing', () {
    // testTheory: MFT — an item is listed only when blamed in >= minEpisodes
    // distinct check-ins for a symptom; empty input yields nothing.
    // contract: buildSuspects keeps groups with episodeCount >= minEpisodes.
    // implication: one-off or two-off foods never appear as suspects.
    test('AC1: milk (3 check-ins) listed, bread (2 check-ins) not', () {
      final result = buildSuspects(
        rows: [
          _row(1, 'Bloating', 'milk'),
          _row(2, 'Bloating', 'milk'),
          _row(3, 'Bloating', 'milk'),
          _row(1, 'Bloating', 'bread'),
          _row(2, 'Bloating', 'bread'),
        ],
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result.map((e) => e.targetName).toList(), ['milk']);
    });

    test('AC7: no rows → empty list', () {
      final result = buildSuspects(
        rows: const [],
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result, isEmpty);
    });

    test('AC8: iron as food (log 1) and medication (logs 2, 3) merges to one entry', () {
      final result = buildSuspects(
        rows: [
          _row(1, 'Bloating', 'iron', type: SuspicionTargetType.food),
          _row(2, 'Bloating', 'iron', type: SuspicionTargetType.medication),
          _row(3, 'Bloating', 'iron', type: SuspicionTargetType.medication),
        ],
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result, hasLength(1));
      expect(result.single.episodeCount, 3);
    });
  });

  // ── AC2 / AC3: distinct check-ins and dismissal ────────────────────────────
  group('[INV] buildSuspects — episodes are distinct non-dismissed check-ins', () {
    // testTheory: invariant — episodeCount counts distinct reactionLogIds, and
    // a dismissed (log, symptom) pair contributes to neither count nor score.
    // contract: episodeCount/score exclude dismissed rows; rows from the same
    // log count once toward the threshold.
    // implication: double-blaming one check-in can't fake a suspect, and
    // dismissing an episode immediately lowers the suspect's numbers.
    test('AC2: two rows in log 1 + one in log 2 → 2 episodes, not listed at default threshold', () {
      final rows = [
        _row(1, 'Bloating', 'milk'),
        _row(1, 'Bloating', 'milk'),
        _row(2, 'Bloating', 'milk'),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result, isEmpty);

      final relaxed = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {},
        minEpisodes: 2,
      );
      expect(relaxed, hasLength(1));
      expect(relaxed.single.episodeCount, 2);
      expect(relaxed.single.score, closeTo(3.0, 1e-9));
    });

    test('AC3: dismissing 4:Bloating drops log 4 (3 episodes, score 3); 4:Nausea changes nothing for Bloating', () {
      final rows = [
        _row(1, 'Bloating', 'milk'),
        _row(2, 'Bloating', 'milk'),
        _row(3, 'Bloating', 'milk'),
        _row(4, 'Bloating', 'milk'),
      ];
      final dismissedBloating = buildSuspects(
        rows: rows,
        dismissedKeys: const {'4:Bloating'},
        timesEatenByName: const {},
      );
      expect(dismissedBloating, hasLength(1));
      expect(dismissedBloating.single.episodeCount, 3);
      expect(dismissedBloating.single.score, closeTo(3.0, 1e-9));

      final dismissedNausea = buildSuspects(
        rows: rows,
        dismissedKeys: const {'4:Nausea'},
        timesEatenByName: const {},
      );
      expect(dismissedNausea.single.episodeCount, 4);
      expect(dismissedNausea.single.score, closeTo(4.0, 1e-9));
    });
  });

  // ── AC4 / AC6: ordering by rate, symptom, episodes, name ───────────────────
  group('[DIR] buildSuspects — ordering is rate, not score', () {
    // testTheory: directional — a higher rate ranks first even with a lower
    // score; symptoms sort ascending; rate ties break on episodes desc, then
    // name asc.
    // contract: sort symptom asc, then rate desc, episodeCount desc, targetName asc.
    // implication: a food eaten rarely but always blamed outranks a staple that
    // is blamed in proportion to how often it is eaten.
    test('AC4: Bloating cheese (rate 1.0) > milk (0.3) > coffee (0.2), despite coffee having the highest score', () {
      final rows = [
        _row(1, 'Bloating', 'milk'),
        _row(2, 'Bloating', 'milk'),
        _row(3, 'Bloating', 'milk'),
        _row(1, 'Bloating', 'cheese'),
        _row(2, 'Bloating', 'cheese'),
        _row(3, 'Bloating', 'cheese', source: SuspicionSource.manual),
        _row(1, 'Bloating', 'coffee', weight: 2),
        _row(2, 'Bloating', 'coffee', weight: 2),
        _row(3, 'Bloating', 'coffee', weight: 2),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {'milk': 10, 'cheese': 5, 'coffee': 30},
      );
      expect(result.map((e) => e.targetName).toList(), ['cheese', 'milk', 'coffee']);
      expect(result[0].rate, closeTo(1.0, 1e-9));
      expect(result[1].rate, closeTo(0.3, 1e-9));
      expect(result[2].rate, closeTo(0.2, 1e-9));
      expect(result[0].score, closeTo(5.0, 1e-9));
      expect(result[1].score, closeTo(3.0, 1e-9));
      expect(result[2].score, closeTo(6.0, 1e-9));
    });

    test('AC6: symptoms ascending → Bloating section before Nausea section', () {
      final rows = [
        _row(1, 'Nausea', 'zinc'),
        _row(2, 'Nausea', 'zinc'),
        _row(3, 'Nausea', 'zinc'),
        _row(1, 'Bloating', 'milk'),
        _row(2, 'Bloating', 'milk'),
        _row(3, 'Bloating', 'milk'),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result.map((e) => e.symptom).toList(), ['Bloating', 'Nausea']);
    });

    test('AC6: rate tie → more episodes first, then name asc', () {
      final rows = [
        _row(1, 'Bloating', 'apple'),
        _row(2, 'Bloating', 'apple'),
        _row(3, 'Bloating', 'apple'),
        _row(1, 'Bloating', 'avocado'),
        _row(2, 'Bloating', 'avocado'),
        _row(3, 'Bloating', 'avocado'),
        _row(1, 'Bloating', 'banana'),
        _row(2, 'Bloating', 'banana'),
        _row(3, 'Bloating', 'banana'),
        _row(4, 'Bloating', 'banana'),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {'apple': 3, 'avocado': 3, 'banana': 4},
      );
      expect(result.map((e) => e.targetName).toList(),
          ['banana', 'apple', 'avocado']);
      expect(result.every((e) => (e.rate - 1.0).abs() < 1e-9), isTrue);
    });
  });

  // ── AC5: missing denominator ───────────────────────────────────────────────
  group('[DIR] buildSuspects — missing times-eaten uses denominator 1', () {
    // testTheory: directional — an item with no times-eaten entry (deleted from
    // history) has timesEaten 0 and rate equal to its score.
    // contract: rate = score / max(timesEaten, 1); timesEaten defaults to 0.
    // implication: a deleted food still shows its raw blame instead of dividing
    // by zero or vanishing from the list.
    test('AC5: pill with no map entry → timesEaten 0, rate = score 3.0', () {
      final rows = [
        _row(1, 'Bloating', 'pill'),
        _row(2, 'Bloating', 'pill'),
        _row(3, 'Bloating', 'pill'),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {},
      );
      expect(result.single.timesEaten, 0);
      expect(result.single.rate, closeTo(3.0, 1e-9));
    });

    test('AC5: pill with explicit map entry 0 → same timesEaten 0, rate 3.0', () {
      final rows = [
        _row(1, 'Bloating', 'pill'),
        _row(2, 'Bloating', 'pill'),
        _row(3, 'Bloating', 'pill'),
      ];
      final result = buildSuspects(
        rows: rows,
        dismissedKeys: const {},
        timesEatenByName: const {'pill': 0},
      );
      expect(result.single.timesEaten, 0);
      expect(result.single.rate, closeTo(3.0, 1e-9));
    });
  });
}
