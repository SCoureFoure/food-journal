// Scenario table for meal memory pattern engine.
//
// Add new rows to _scenarios to cover edge cases as you discover them.
// Each row is: input, expectReferential, expectedDateOffset, expectedMealType, expectMatchRecent.
//
// Fixed "today" = Thursday May 14, 2026 for deterministic named-day offsets.

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

  const _Scenario(
    this.input, {
    required this.expectReferential,
    this.expectDateOffset,
    this.expectMealType,
    this.expectMatchRecent = false,
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
  // ── Leftovers + named day (the failing case) ──
  _Scenario(
    'I had some of the leftovers from last friday',
    expectReferential: true,
    expectDateOffset: 6,
    expectMealType: null,
  ),
  _Scenario(
    'leftovers from dinner last friday',
    expectReferential: true,
    expectDateOffset: 6,
    expectMealType: 'dinner',
  ),

  // ── Yesterday / last night ──
  _Scenario(
    'leftovers from last night',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: null,
  ),
  _Scenario(
    'same dinner I had yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'dinner',
  ),
  _Scenario(
    'had that for breakfast yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'breakfast',
  ),

  // ── Named days ──
  _Scenario(
    'what I had on monday',
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: null,
  ),
  _Scenario(
    'the tuesday lunch',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: 'lunch',
  ),
  _Scenario(
    'had it thursday',
    expectReferential: true,
    expectDateOffset: 7, // same weekday → previous week
    expectMealType: null,
  ),

  // ── Same / usual / again ──
  _Scenario(
    'the usual breakfast',
    expectReferential: true,
    expectMealType: 'breakfast',
    expectMatchRecent: true,
  ),
  _Scenario(
    'had that again',
    expectReferential: true,
    expectMatchRecent: true,
  ),
  _Scenario(
    'same thing I always have',
    expectReferential: true,
    expectMatchRecent: true,
  ),
  _Scenario(
    'my go-to lunch',
    expectReferential: true,
    expectMealType: 'lunch',
    expectMatchRecent: true,
  ),

  // ── Earlier today ──
  _Scenario(
    'had some earlier',
    expectReferential: true,
    expectDateOffset: 0,
  ),
  _Scenario(
    'this morning I had oatmeal',
    expectReferential: true,
    expectDateOffset: 0,
    // no breakfast keyword in input — mealType stays null
  ),

  // ── Days ago ──
  _Scenario(
    'that pasta dish from a few days ago',
    expectReferential: true,
    expectDateOffset: 3,
  ),
  _Scenario(
    'earlier this week I had salmon',
    expectReferential: true,
    expectDateOffset: 3,
  ),

  // ── Slang / colloquial ──
  _Scenario(
    'same old lunch',
    expectReferential: true,
    expectMealType: 'lunch',
    expectMatchRecent: true,
  ),
  _Scenario(
    'repeat dinner from last night',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'dinner',
  ),
  _Scenario(
    'the thing I had for breakfast',
    expectReferential: true,
    expectMealType: 'breakfast',
    expectMatchRecent: true,
  ),
  _Scenario(
    'like what I had on tuesday',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: null,
  ),

  // ── Two days ago ──
  _Scenario(
    'the dinner from the day before yesterday',
    expectReferential: true,
    expectDateOffset: 2,
    expectMealType: 'dinner',
  ),
  _Scenario(
    'day before last',
    expectReferential: true,
    expectDateOffset: 2,
  ),

  // ── Last week ──
  _Scenario(
    "last week's dinner",
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: 'dinner',
  ),

  // ── Multi-temporal ambiguity: days_ago wins ──
  _Scenario(
    'had it a couple nights ago',
    expectReferential: true,
    expectDateOffset: 3,
  ),
  _Scenario(
    'a while back I had that salmon',
    expectReferential: true,
    expectDateOffset: 3,
  ),

  // ── The other night ──
  _Scenario(
    'the other night we had tacos',
    expectReferential: true,
    expectDateOffset: 1,
  ),

  // ── Named day + meal type combinations ──
  _Scenario(
    'the breakfast I had on wednesday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'breakfast',
  ),
  _Scenario(
    'sunday dinner',
    expectReferential: true,
    expectDateOffset: 4,
    expectMealType: 'dinner',
  ),
  _Scenario(
    'saturday brunch',
    expectReferential: true,
    expectDateOffset: 5,
    expectMealType: 'breakfast', // brunch maps to breakfast
  ),

  // ── Edge inputs ──
  _Scenario('again', expectReferential: true, expectMatchRecent: true),
  _Scenario('leftovers', expectReferential: true, expectDateOffset: 1),
  _Scenario(
    'yesterday yesterday yesterday',
    expectReferential: true,
    expectDateOffset: 1,
  ),

  // ── Two days ago — night before last ──
  _Scenario(
    'the night before last I had tacos',
    expectReferential: true,
    expectDateOffset: 2,
  ),

  // ── Days ago — "back" variant ──
  _Scenario(
    'had that a couple days back',
    expectReferential: true,
    expectDateOffset: 3,
  ),

  // ── Days ago — "earlier in the week" ──
  _Scenario(
    'had pasta earlier in the week',
    expectReferential: true,
    expectDateOffset: 3,
  ),

  // ── Same as before — "what I ate" variant ──
  _Scenario(
    'what I ate on monday',
    expectReferential: true,
    expectDateOffset: 3,
    expectMealType: null,
  ),
  _Scenario(
    'what I ate for lunch yesterday',
    expectReferential: true,
    expectDateOffset: 1,
    expectMealType: 'lunch',
  ),

  // ── Same as before — "what I had" without "like" prefix ──
  _Scenario(
    'what I had for dinner',
    expectReferential: true,
    expectMealType: 'dinner',
    expectMatchRecent: true,
  ),

  // ── False-positive guard: "just" alone is not referential ──
  _Scenario('I just made a salad', expectReferential: false),
  // "had" alone is not referential (no temporal or same-as anchor)
  _Scenario('I had a burger and fries', expectReferential: false),

  // ── Should NOT be referential ──
  _Scenario('I had a chicken sandwich', expectReferential: false),
  _Scenario('eggs with toast', expectReferential: false),
  _Scenario('protein shake', expectReferential: false),
  _Scenario('', expectReferential: false),
  // "usually" must NOT match the \busual\b pattern
  _Scenario('I usually have eggs', expectReferential: false),
  // punctuation-heavy — should still work if temporal word present
  _Scenario('leftovers!!!', expectReferential: true, expectDateOffset: 1),
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
