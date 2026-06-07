// Pure-logic tests for the blame ledger (specs/food_blame.spec.md).
//
// The DB-bound parts (window query SQL, FK cascade, migration SQL) need native
// sqlite3 and are covered by on-device integration tests — same split as
// migration_order_test.dart. Here we test the extracted pure logic that carries
// the actual behavior: window boundary, severity weighting, auto/manual fan-out,
// and aggregation math.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/food_suspicion.dart';

BlameCandidate _food(int id, String name, {DateTime? ts}) => BlameCandidate(
      type: SuspicionTargetType.food,
      targetId: id,
      name: name,
      timestamp: ts ?? DateTime(2026, 6, 2, 12),
    );

BlameCandidate _med(int id, String name, {DateTime? ts}) => BlameCandidate(
      type: SuspicionTargetType.medication,
      targetId: id,
      name: name,
      timestamp: ts ?? DateTime(2026, 6, 2, 12),
    );

final _now = DateTime(2026, 6, 2, 20);

void main() {
  // ── AC3: window boundary (pure) ─────────────────────────────────────────────
  group('[BVA] isWithinBlameWindow — half-open [anchor−window, anchor)', () {
    final anchor = DateTime(2026, 6, 2, 20, 0); // 8pm check-in
    const w = kAutoBlameWindow; // 16h → from = 4am same day

    test('item 15h before is in window', () {
      expect(
        isWithinBlameWindow(
            timestamp: anchor.subtract(const Duration(hours: 15)),
            anchor: anchor,
            window: w),
        isTrue,
      );
    });

    test('item 17h before is outside window', () {
      expect(
        isWithinBlameWindow(
            timestamp: anchor.subtract(const Duration(hours: 17)),
            anchor: anchor,
            window: w),
        isFalse,
      );
    });

    test('item exactly at far edge (16h) is excluded (half-open)', () {
      expect(
        isWithinBlameWindow(
            timestamp: anchor.subtract(w), anchor: anchor, window: w),
        isFalse,
      );
    });

    test('the check-in instant itself is excluded', () {
      expect(
        isWithinBlameWindow(timestamp: anchor, anchor: anchor, window: w),
        isFalse,
      );
    });

    test('manual 24h window reaches an item the 16h auto window misses', () {
      final ts = anchor.subtract(const Duration(hours: 20));
      expect(isWithinBlameWindow(timestamp: ts, anchor: anchor, window: kAutoBlameWindow), isFalse);
      expect(isWithinBlameWindow(timestamp: ts, anchor: anchor, window: kManualBlameWindow), isTrue);
    });
  });

  // ── weight mapping ──────────────────────────────────────────────────────────
  group('[MFT] suspicionWeightFor — normalized severity weight', () {
    test('mild=1, moderate=2, bad=3', () {
      expect(suspicionWeightFor(ReactionLevel.mild), 1.0);
      expect(suspicionWeightFor(ReactionLevel.moderate), 2.0);
      expect(suspicionWeightFor(ReactionLevel.bad), 3.0);
    });

    test('none/pending weigh 0 or below (never positive signal)', () {
      expect(suspicionWeightFor(ReactionLevel.none), 0.0);
      expect(suspicionWeightFor(ReactionLevel.pending), lessThan(0));
    });
  });

  group('[MFT] effectiveSuspicionWeight — manual heavier than auto', () {
    test('auto = base × 1', () {
      expect(
          effectiveSuspicionWeight(baseWeight: 1, source: SuspicionSource.auto),
          1.0);
    });
    test('manual = base × kManualWeightMultiplier', () {
      expect(
          effectiveSuspicionWeight(
              baseWeight: 1, source: SuspicionSource.manual),
          kManualWeightMultiplier);
    });
  });

  // ── AC2: auto happy path ────────────────────────────────────────────────────
  group('[MFT] buildSuspicionRows — auto fan-out', () {
    test('AC2: one food + one med, Bloating(mild) → two auto rows', () {
      final rows = buildSuspicionRows(
        reactionLogId: 7,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.source == SuspicionSource.auto), isTrue);
      expect(rows.every((r) => r.symptom == 'Bloating'), isTrue);
      expect(rows.every((r) => r.baseWeight == 1.0), isTrue);
      expect(rows.every((r) => r.reactionLogId == 7), isTrue);

      final food = rows.firstWhere((r) => r.targetType == SuspicionTargetType.food);
      expect(food.targetId, 1);
      expect(food.targetName, 'hamburger'); // lowercased for aggregation
      final med = rows.firstWhere((r) => r.targetType == SuspicionTargetType.medication);
      expect(med.targetId, 2);
      expect(med.targetName, 'ibuprofen');
    });

    // ── AC4: multi-symptom fan-out, per-symptom weight ──────────────────────────
    test('AC4: 2 candidates × {Bloating:mild, Nausea:bad} → 4 rows, own weights', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild, 'Nausea': ReactionLevel.bad},
        autoCandidates: [_food(1, 'Milk'), _food(2, 'Toast')],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(rows, hasLength(4));
      expect(rows.where((r) => r.symptom == 'Bloating').every((r) => r.baseWeight == 1.0), isTrue);
      expect(rows.where((r) => r.symptom == 'Nausea').every((r) => r.baseWeight == 3.0), isTrue);
    });

    // ── AC5: no symptoms → no rows ──────────────────────────────────────────────
    test('AC5: empty symptom map → no rows', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: const {},
        autoCandidates: [_food(1, 'Milk')],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(rows, isEmpty);
    });

    test('AC5: symptom present but level none → no rows for it', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.none},
        autoCandidates: [_food(1, 'Milk')],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(rows, isEmpty);
    });

    // ── AC8: manual reaches past auto window ────────────────────────────────────
    test('AC8: manual selection not in auto candidates still gets a manual row', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: const [], // auto window missed everything
        manualSelections: [_food(9, 'Yesterday Milk')],
        createdAt: _now,
      );
      expect(rows, hasLength(1));
      expect(rows.single.source, SuspicionSource.manual);
      expect(rows.single.targetId, 9);
    });

    test('AC7: same item auto + manual → both rows (separate sources)', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [_food(1, 'Burger')],
        manualSelections: [_food(1, 'Burger')],
        createdAt: _now,
      );
      expect(rows, hasLength(2));
      expect(rows.map((r) => r.source).toSet(),
          {SuspicionSource.auto, SuspicionSource.manual});
    });
  });

  // ── AC11: aggregation ───────────────────────────────────────────────────────
  group('[MFT] aggregateSuspicions — sum effective weight by (target, symptom)', () {
    test('AC11: same item blamed auto(1) + manual(1×3) → score 4', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [_food(1, 'Burger')],
        manualSelections: [_food(1, 'Burger')],
        createdAt: _now,
      );
      final scores = aggregateSuspicions(rows);
      expect(scores, hasLength(1));
      expect(scores.single.targetName, 'burger');
      expect(scores.single.symptom, 'Bloating');
      expect(scores.single.score, 1.0 + 1.0 * kManualWeightMultiplier);
    });

    test('groups distinct (target, symptom) pairs separately, sorted desc', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Bloating': ReactionLevel.bad},
          autoCandidates: [_food(1, 'Cheese')],
          manualSelections: const [],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Nausea': ReactionLevel.mild},
          autoCandidates: [_food(2, 'Eggs')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final scores = aggregateSuspicions(rows);
      expect(scores, hasLength(2));
      // Cheese/Bloating (3) sorts above Eggs/Nausea (1)
      expect(scores.first.targetName, 'cheese');
      expect(scores.first.score, 3.0);
      expect(scores.last.targetName, 'eggs');
    });

    test('empty ledger → empty scores', () {
      expect(aggregateSuspicions(const []), isEmpty);
    });
  });

  // ── entity_resolution: canonical key collapses format variants ──────────────
  // Cross-ref specs/food_entity_resolution.spec.md (AC8, AC9). Verifies the
  // blame ledger groups on the canonical identity, not the raw name — so the
  // same food re-entered with different casing/punctuation accumulates.
  group('[INV] entity_resolution — blame buckets by canonical identity', () {
    // testTheory: invariant — two raw names that canonicalize equal must land in
    // ONE (targetName, symptom) bucket regardless of casing/whitespace/punct.
    // contract: BlameCandidate.canonicalKey (← canonical_name, else canonicalize)
    //   is the ledger grouping key.
    // implication: "what bloats me most" reflects the true entity, not fragments.
    test('AC8: "Turkey Sandwich" + "turkey-sandwich" → one summed bucket', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Bloating': ReactionLevel.mild}, // weight 1
          autoCandidates: [_food(1, 'Turkey Sandwich')],
          manualSelections: const [],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Bloating': ReactionLevel.mild}, // weight 1
          autoCandidates: [_food(2, 'turkey-sandwich')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final scores = aggregateSuspicions(rows);
      expect(scores, hasLength(1), reason: 'variants must not split');
      expect(scores.single.targetName, 'turkey sandwich');
      expect(scores.single.score, 2.0, reason: 'summed, not two halves');
    });

    test('AC8: explicit canonical_name on candidate overrides raw name', () {
      // Stored canonical wins even if the raw display name differs in wording.
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [
          BlameCandidate(
            type: SuspicionTargetType.food,
            targetId: 1,
            name: 'Turkey Sandwich w/ Mayo',
            canonicalName: 'turkey sandwich',
            timestamp: _now,
          ),
        ],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(rows.single.targetName, 'turkey sandwich');
    });

    test('AC9: distinct foods stay in separate buckets', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Bloating': ReactionLevel.mild},
          autoCandidates: [_food(1, 'Turkey Sandwich')],
          manualSelections: const [],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Bloating': ReactionLevel.mild},
          autoCandidates: [_food(2, 'Tuna Sandwich')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final scores = aggregateSuspicions(rows);
      expect(scores, hasLength(2));
      expect(
        scores.map((s) => s.targetName).toSet(),
        {'turkey sandwich', 'tuna sandwich'},
      );
    });
  });

  // ── blame_history: dismissal filter (specs/blame_history.spec.md) ──────────
  group('[MFT] excludeDismissedSuspicions — drops a whole (log, symptom) episode', () {
    // testTheory: invariant — dismissing (log, symptom) removes EVERY row for
    // that pair regardless of source/target, leaves siblings (same log, other
    // symptom; other logs, same symptom) untouched.
    // contract: excludeDismissedSuspicions mirrors getSuspicionScores' anti-join.
    // implication: dismissing "Nausea" from a flu episode can't accidentally
    // also suppress that log's real "Bloating" signal, or another day's Nausea.
    test('AC3: dismissing (logA, Nausea) drops auto+manual rows for it only', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Nausea': ReactionLevel.bad, 'Bloating': ReactionLevel.mild},
          autoCandidates: [_food(1, 'Salad')],
          manualSelections: [_food(2, 'Yogurt')],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Nausea': ReactionLevel.mild},
          autoCandidates: [_food(3, 'Soup')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final filtered =
          excludeDismissedSuspicions(rows, {blameHistoryKey(1, 'Nausea')});

      expect(filtered.where((r) => r.reactionLogId == 1 && r.symptom == 'Nausea'),
          isEmpty, reason: 'both auto (salad) and manual (yogurt) rows gone');
      expect(filtered.where((r) => r.reactionLogId == 1 && r.symptom == 'Bloating'),
          hasLength(2),
          reason: 'sibling symptom on the same log keeps scoring '
              '(both candidates fan out across every active symptom)');
      expect(filtered.where((r) => r.reactionLogId == 2 && r.symptom == 'Nausea'),
          hasLength(1), reason: 'same symptom on a different log is unaffected');
    });

    test('AC4: empty dismissed set lets every row through unchanged', () {
      final rows = buildSuspicionRows(
        reactionLogId: 1,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [_food(1, 'Milk')],
        manualSelections: const [],
        createdAt: _now,
      );
      expect(excludeDismissedSuspicions(rows, const {}), rows);
    });
  });

  group('[MFT] buildBlameHistory — group ledger rows into reviewable episodes', () {
    // testTheory: MFT — the dashboard's row-building math: group by (log,
    // symptom), dedupe blamed names across auto+manual (insertion order),
    // attach severity/checkinTime/dismissed, sort newest-checkin-first.
    // contract: buildBlameHistory is the pure spec of StorageService.getBlameHistory.
    // implication: what the user reviews matches what aggregation actually sums.
    test('AC2: groups by (log, symptom), dedupes names, newest checkin first', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Nausea': ReactionLevel.bad},
          autoCandidates: [_food(1, 'Salad'), _food(1, 'Salad')], // same target twice
          manualSelections: [_food(2, 'Yogurt')],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Bloating': ReactionLevel.mild},
          autoCandidates: [_food(3, 'Soup')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final entries = buildBlameHistory(
        rows: rows,
        checkinTimes: {1: DateTime(2026, 6, 1, 20), 2: DateTime(2026, 6, 2, 8)},
        symptomLevelsByLog: {
          1: {'Nausea': ReactionLevel.bad},
          2: {'Bloating': ReactionLevel.mild},
        },
        dismissedKeys: const {},
      );

      expect(entries, hasLength(2));
      // log 2's check-in (Jun 2, 8am) is newer than log 1's (Jun 1, 8pm).
      expect(entries[0].reactionLogId, 2);
      expect(entries[0].symptom, 'Bloating');
      expect(entries[0].severity, ReactionLevel.mild);
      expect(entries[0].blamedNames, ['soup']);

      expect(entries[1].reactionLogId, 1);
      expect(entries[1].symptom, 'Nausea');
      expect(entries[1].severity, ReactionLevel.bad);
      expect(entries[1].blamedNames, ['salad', 'yogurt'],
          reason: 'auto+manual together, duplicate target deduped, insertion order');
      expect(entries.every((e) => !e.dismissed), isTrue);
    });

    test('AC4: dismissed flag mirrors dismissedKeys; ties broken by log id desc', () {
      final rows = [
        ...buildSuspicionRows(
          reactionLogId: 1,
          symptomLevels: {'Nausea': ReactionLevel.bad},
          autoCandidates: [_food(1, 'Salad')],
          manualSelections: const [],
          createdAt: _now,
        ),
        ...buildSuspicionRows(
          reactionLogId: 2,
          symptomLevels: {'Bloating': ReactionLevel.mild},
          autoCandidates: [_food(2, 'Eggs')],
          manualSelections: const [],
          createdAt: _now,
        ),
      ];
      final sameTime = DateTime(2026, 6, 2, 8);
      final entries = buildBlameHistory(
        rows: rows,
        checkinTimes: {1: sameTime, 2: sameTime},
        symptomLevelsByLog: {
          1: {'Nausea': ReactionLevel.bad},
          2: {'Bloating': ReactionLevel.mild},
        },
        dismissedKeys: {blameHistoryKey(1, 'Nausea')},
      );

      expect(entries[0].reactionLogId, 2, reason: 'tie on checkinTime → higher log id first');
      expect(entries[0].dismissed, isFalse);
      expect(entries[1].reactionLogId, 1);
      expect(entries[1].dismissed, isTrue);
    });

    test('defensively skips a log missing from checkinTimes (deleted between reads)', () {
      final rows = buildSuspicionRows(
        reactionLogId: 99,
        symptomLevels: {'Bloating': ReactionLevel.mild},
        autoCandidates: [_food(1, 'Milk')],
        manualSelections: const [],
        createdAt: _now,
      );
      final entries = buildBlameHistory(
        rows: rows,
        checkinTimes: const {},
        symptomLevelsByLog: const {},
        dismissedKeys: const {},
      );
      expect(entries, isEmpty);
    });

    test('empty ledger → empty list', () {
      expect(
        buildBlameHistory(
          rows: const [],
          checkinTimes: const {},
          symptomLevelsByLog: const {},
          dismissedKeys: const {},
        ),
        isEmpty,
      );
    });
  });
}
