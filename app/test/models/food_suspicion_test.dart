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
}
