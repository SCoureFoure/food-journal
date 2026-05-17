// Scenario table for meal memory pattern engine.
//
// Each row is an equivalence class representative, boundary value, invariance probe,
// or false-positive guard. The testTheory field marks which type:
//   EQUIV      — one representative from a partition the system treats identically
//   BVA        — value at or near a defined boundary (edge of input space)
//   INV        — perturbation that must NOT change output
//   FP         — input that must NOT fire (false-positive guard)
//   REGRESSION — input that previously failed in production or integration
//
// The rationale field explains WHY this scenario exists. Without it, future
// contributors cannot tell which cases are load-bearing vs redundant.
//
// Fixed "today" = Thursday May 14, 2026 for deterministic named-day offsets.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/meal_memory/meal_reference_rules.dart';
import 'package:food_journal/services/meal_memory/reference_engine.dart';

// ─── Test case definition ─────────────────────────────────────────────────────

class _Scenario {
  final String input;
  final bool expectReferential;
  final int? expectDateOffset;
  final String? expectMealType;
  final bool expectMatchRecent;
  final String rationale;
  final String testTheory;

  const _Scenario(
    this.input, {
    required this.expectReferential,
    this.expectDateOffset,
    this.expectMealType,
    this.expectMatchRecent = false,
    this.rationale = '',
    this.testTheory = 'EQUIV',
  });
}

// ─── Scenario table ───────────────────────────────────────────────────────────
// kToday = Thursday May 14, 2026
//   Monday    May 11 → 3 days ago
//   Tuesday   May 12 → 2 days ago
//   Wednesday May 13 → 1 day ago
//   Thursday  May 7  → 7 days ago (same weekday = last week)
//   Friday    May 8  → 6 days ago
//   Saturday  May 9  → 5 days ago
//   Sunday    May 10 → 4 days ago

const _scenarios = [
  // ── Leftovers + named day ────────────────────────────────────────────────────
  _Scenario(
    'I had some of the leftovers from last friday',
    expectReferential: true,
    expectDateOffset: 6,
    expectMealType: null,
    testTheory: 'REGRESSION',
    rationale: 'first integration failure logged: named-day must override leftover default offset (1→6)',
  ),
  _Scenario(
    'leftovers from dinner last friday',
    expectReferential: true,
    expectDateOffset: 6,
    expectMealType: 'dinner',
    rationale: 'named day + meal type combination — both fields must coexist in output',
  ),

  // ── Yesterday / last night ───────────────────────────────────────────────────
  _Scenario(
    'leftovers from last night',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: null,
    rationale: 'compound: leftover synonym fires alongside yesterday synonym — priority: yesterday wins',
  ),
  _Scenario(
    'same dinner I had yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'dinner',
    rationale: 'three rules fire together: same_as_before + yesterday + meal_dinner',
  ),
  _Scenario(
    'had that for breakfast yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'breakfast',
    rationale: 'yesterday + meal type; "had that" is the same_as_before trigger',
  ),

  // ── Named days ───────────────────────────────────────────────────────────────
  _Scenario(
    'what I had on monday',
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: null,
    rationale: 'EQUIV class B: explicit weekday resolves to computed offset (Mon from Thu = 3)',
  ),
  _Scenario(
    'the tuesday lunch',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: 'lunch',
    rationale: 'named day (tuesday) + meal type — both dateOffset and mealType must be set',
  ),
  _Scenario(
    'had it thursday',
    expectReferential: true,
    expectDateOffset: 7, // same weekday → previous week
    expectMealType: null,
    testTheory: 'BVA',
    rationale: 'BVA: same weekday as today must resolve to 7 (last week), not 0 (today) — off-by-one boundary',
  ),

  // ── Same / usual / again ─────────────────────────────────────────────────────
  _Scenario(
    'the usual breakfast',
    expectReferential: true,
    expectMealType: 'breakfast',
    expectMatchRecent: true,
    rationale: 'EQUIV class C same_as_before: "usual" keyword + meal type',
  ),
  _Scenario(
    'had that again',
    expectReferential: true,
    expectMatchRecent: true,
    rationale: 'EQUIV class C same_as_before: minimal "again" trigger, no meal type',
  ),
  _Scenario(
    'same thing I always have',
    expectReferential: true,
    expectMatchRecent: true,
    rationale: 'EQUIV class C same_as_before: "always" variant — different seed, same rule key',
  ),
  _Scenario(
    'my go-to lunch',
    expectReferential: true,
    expectMealType: 'lunch',
    expectMatchRecent: true,
    rationale: 'slang coverage: "go-to" colloquialism must fire same_as_before + meal type',
  ),

  // ── Earlier today ────────────────────────────────────────────────────────────
  _Scenario(
    'had some earlier',
    expectReferential: true,
    expectDateOffset: 0,
    rationale: 'EQUIV class A this_morning: vague "earlier" resolves to offset=0 (same day)',
  ),
  _Scenario(
    'this morning I had oatmeal',
    expectReferential: true,
    expectDateOffset: 0,
    // no breakfast keyword in input — mealType stays null
    rationale: 'EQUIV class A this_morning: explicit morning reference; mealType stays null (no keyword in input)',
  ),

  // ── Days ago ─────────────────────────────────────────────────────────────────
  _Scenario(
    'that pasta dish from a few days ago',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'EQUIV: days_ago canonical phrase "a few days ago"',
  ),
  _Scenario(
    'earlier this week I had salmon',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'priority: days_ago must win over this_morning for "earlier this week"',
  ),

  // ── Slang / colloquial ───────────────────────────────────────────────────────
  _Scenario(
    'same old lunch',
    expectReferential: true,
    expectMealType: 'lunch',
    expectMatchRecent: true,
    rationale: 'slang coverage: "same old" colloquialism must fire same_as_before',
  ),
  _Scenario(
    'repeat dinner from last night',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'dinner',
    rationale: 'slang coverage: "repeat" keyword + compound yesterday; named day overrides same_as_before matchRecent',
  ),
  _Scenario(
    'the thing I had for breakfast',
    expectReferential: true,
    expectMealType: 'breakfast',
    expectMatchRecent: true,
    rationale: 'slang coverage: "the thing I had" informal phrase + meal type',
  ),
  _Scenario(
    'like what I had on tuesday',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: null,
    rationale: 'slang coverage: "like what I had" prefix + named day — named day offset wins',
  ),

  // ── Two days ago ─────────────────────────────────────────────────────────────
  _Scenario(
    'the dinner from the day before yesterday',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: 'dinner',
    rationale: 'two_days_ago priority over yesterday: "day before yesterday" fires both, two_days_ago wins (2 not 1)',
  ),
  _Scenario(
    'day before last',
    expectReferential: true,
    expectDateOffset: 2,
    rationale: 'EQUIV: two_days_ago colloquial variant "day before last"',
  ),

  // ── Last week ────────────────────────────────────────────────────────────────
  _Scenario(
    "last week's dinner",
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: 'dinner',
    rationale: 'EQUIV: days_ago — possessive week reference "last week\'s" maps to mid-week offset',
  ),

  // ── Multi-temporal ambiguity: days_ago wins ───────────────────────────────────
  _Scenario(
    'had it a couple nights ago',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'EQUIV: days_ago — "nights" plural variant of canonical "days ago"',
  ),
  _Scenario(
    'a while back I had that salmon',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'EQUIV: days_ago — vague "a while back" resolves to mid-week offset',
  ),

  // ── The other night ───────────────────────────────────────────────────────────
  _Scenario(
    'the other night we had tacos',
    expectReferential: true,
    expectDateOffset: 1,
    rationale: 'EQUIV: yesterday synonym — "the other night" colloquialism maps to offset=1',
  ),

  // ── Named day + meal type combinations ───────────────────────────────────────
  _Scenario(
    'the breakfast I had on wednesday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'breakfast',
    rationale: 'named day (wednesday=1 from thursday) + meal type — both fields set',
  ),
  _Scenario(
    'sunday dinner',
    expectReferential: true,
    expectDateOffset: 4,
    expectMealType: 'dinner',
    testTheory: 'BVA',
    rationale: 'BVA: minimal input — bare weekday + meal type, no extra words or prepositions',
  ),
  _Scenario(
    'saturday brunch',
    expectReferential: true,
    expectDateOffset: 5,
    expectMealType: 'breakfast', // brunch maps to breakfast
    rationale: 'EQUIV: brunch keyword maps to breakfast meal type — synonym normalization',
  ),

  // ── Edge inputs ───────────────────────────────────────────────────────────────
  _Scenario(
    'again',
    expectReferential: true,
    expectMatchRecent: true,
    testTheory: 'BVA',
    rationale: 'BVA: single-word same_as_before input — minimal valid referential input',
  ),
  _Scenario(
    'leftovers',
    expectReferential: true,
    expectDateOffset: 1,
    testTheory: 'BVA',
    rationale: 'BVA: single-word leftover input — minimal valid leftover input',
  ),
  _Scenario(
    'yesterday yesterday yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    testTheory: 'BVA',
    rationale: 'BVA: repeated temporal keyword — confidence increases but dateOffset must not multiply',
  ),

  // ── Two days ago variants ─────────────────────────────────────────────────────
  _Scenario(
    'the night before last I had tacos',
    expectReferential: true,
    expectDateOffset: 2,
    rationale: 'EQUIV: two_days_ago — "night before last" variant; two_days_ago priority over yesterday',
  ),
  _Scenario(
    'had that a couple days back',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'EQUIV: days_ago — "days back" preposition variant of "days ago"',
  ),
  _Scenario(
    'had pasta earlier in the week',
    expectReferential: true,
    expectDateOffset: 3,
    rationale: 'priority: days_ago wins over this_morning for "earlier in the week"',
  ),

  // ── "what I ate/had" variants ─────────────────────────────────────────────────
  _Scenario(
    'what I ate on monday',
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: null,
    rationale: 'EQUIV: same_as_before "ate" verb variant + named day — "ate" fires same_as_before rule',
  ),
  _Scenario(
    'what I ate for lunch yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'lunch',
    rationale: 'three signals: "ate" same_as_before + meal type + yesterday; yesterday offset wins',
  ),
  _Scenario(
    'what I had for dinner',
    expectReferential: true,
    expectMealType: 'dinner',
    expectMatchRecent: true,
    rationale: 'same_as_before + meal type; no temporal anchor → matchRecent (not a specific day)',
  ),

  // ── False-positive guards: must NOT be referential ────────────────────────────
  _Scenario(
    'I just made a salad',
    expectReferential: false,
    testTheory: 'FP',
    rationale: 'FP guard: "just" adverb must not trigger temporal detection — plain present-tense action',
  ),
  _Scenario(
    'I had a burger and fries',
    expectReferential: false,
    testTheory: 'FP',
    rationale: 'FP guard: past tense "had" without any temporal or same-as anchor must not fire',
  ),
  _Scenario(
    'I had a chicken sandwich',
    expectReferential: false,
    testTheory: 'FP',
    rationale: 'FP guard: simple meal description — "had" alone is not sufficient to fire',
  ),
  _Scenario(
    'eggs with toast',
    expectReferential: false,
    testTheory: 'FP',
    rationale: 'FP guard: EQUIV class D — bare food description with no temporal signal',
  ),
  _Scenario(
    'protein shake',
    expectReferential: false,
    testTheory: 'FP',
    rationale: 'FP guard: EQUIV class D — single food item with no temporal signal',
  ),
  _Scenario(
    '',
    expectReferential: false,
    testTheory: 'BVA',
    rationale: 'BVA: empty input — must return false without crashing',
  ),
  _Scenario(
    'I usually have eggs',
    expectReferential: false,
    testTheory: 'BVA',
    rationale: 'BVA word-boundary: "usually" must not match \\busual\\b pattern — word-boundary edge case',
  ),
  _Scenario(
    'leftovers!!!',
    expectReferential: true,
    expectDateOffset: 1,
    testTheory: 'INV',
    rationale: 'INV: trailing punctuation must not suppress detection — "leftovers!!!" == "leftovers"',
  ),
];

// ─── Runner ───────────────────────────────────────────────────────────────────

void main() {
  final kToday = DateTime(2026, 5, 14); // Thursday

  for (final s in _scenarios) {
    test('"${s.input.isEmpty ? '<empty>' : s.input}"', () {
      final profile = detectReferences(
        s.input,
        mealRules,
        temporalKeys: temporalKeys,
        mealTypeKeys: mealTypeKeys,
      );
      final spec = buildQuerySpec(profile, now: kToday);

      // ignore: avoid_print
      print(jsonEncode(<String, Object?>{
        'type': 'test_output',
        'testTheory': s.testTheory,
        if (s.rationale.isNotEmpty) 'rationale': s.rationale,
        'input': s.input.isEmpty ? '<empty>' : s.input,
        'hasTemporalRef': profile.hasTemporalRef,
        'firedKeys': List<String>.from(profile.firedKeys),
        'totalConfidence': profile.totalConfidence,
        'dateOffset': spec.dateOffset,
        'mealType': spec.mealType,
        'matchRecent': spec.matchRecent,
      }));

      expect(
        profile.hasTemporalRef,
        equals(s.expectReferential),
        reason: 'hasTemporalRef mismatch',
      );

      if (s.expectDateOffset != null) {
        expect(
          spec.dateOffset,
          equals(s.expectDateOffset),
          reason: 'dateOffset: expected ${s.expectDateOffset}, got ${spec.dateOffset}. '
              'Fired rules: ${profile.firedKeys}',
        );
      }

      if (s.expectMealType != null) {
        expect(
          spec.mealType,
          equals(s.expectMealType),
          reason: 'mealType mismatch',
        );
      }

      if (s.expectMatchRecent) {
        expect(
          spec.matchRecent,
          isTrue,
          reason: 'expected matchRecent=true',
        );
      }
    });
  }
}
