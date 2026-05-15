// INV (Invariance) tests for the meal memory pattern engine.
//
// Each test verifies that a perturbation of a canonical input — case mutation,
// punctuation, whitespace, or synonym seed — produces output identical to the
// canonical form. None of these surface-level changes should affect rule firing
// or buildQuerySpec output.
//
// Fixed "today" = Thursday May 14, 2026 for deterministic named-day offsets.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/meal_memory/meal_reference_rules.dart';
import 'package:food_journal/services/meal_memory/reference_engine.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

final kToday = DateTime(2026, 5, 14); // Thursday

MealQuerySpec _spec(String input) {
  final p = detectReferences(input, mealRules,
      temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
  final s = buildQuerySpec(p, now: kToday);
  // ignore: avoid_print
  print(jsonEncode(<String, Object?>{
    'type': 'test_output',
    'input': input,
    'hasTemporalRef': p.hasTemporalRef,
    'firedKeys': List<String>.from(p.firedKeys),
    'dateOffset': s.dateOffset,
    'mealType': s.mealType,
    'matchRecent': s.matchRecent,
  }));
  return s;
}

bool _ref(String input) => detectReferences(input, mealRules,
    temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys).hasTemporalRef;

// Assert that every perturbation of [canonical] produces the same spec as
// [canonical] itself.
void _assertInvariant(
  String canonical,
  List<String> perturbations, {
  required bool expectRef,
  int? expectOffset,
  String? expectMealType,
  bool expectMatchRecent = false,
}) {
  final all = [canonical, ...perturbations];
  for (final variant in all) {
    final s = _spec(variant);
    expect(
      _ref(variant),
      equals(expectRef),
      reason: 'hasTemporalRef invariance failed for: "$variant" '
          '(canonical: "$canonical")',
    );
    if (expectOffset != null) {
      expect(
        s.dateOffset,
        equals(expectOffset),
        reason: 'dateOffset invariance failed for: "$variant" '
            '(canonical: "$canonical")',
      );
    }
    if (expectMealType != null) {
      expect(
        s.mealType,
        equals(expectMealType),
        reason: 'mealType invariance failed for: "$variant" '
            '(canonical: "$canonical")',
      );
    }
    if (expectMatchRecent) {
      expect(
        s.matchRecent,
        isTrue,
        reason: 'matchRecent invariance failed for: "$variant" '
            '(canonical: "$canonical")',
      );
    }
  }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── isReferential — case, punctuation, whitespace invariance ─────────────

  group('INV — isReferential', () {
    test('UPPER / Title / mIxEd all fire identically to lowercase', () {
      const canonical = 'leftovers from last night';
      _assertInvariant(
        canonical,
        [
          'LEFTOVERS FROM LAST NIGHT',
          'Leftovers From Last Night',
          'LeFtOvErS fRoM lAsT nIgHt',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('trailing punctuation does not suppress detection', () {
      const canonical = 'leftovers';
      _assertInvariant(
        canonical,
        [
          'leftovers.',
          'leftovers!',
          'leftovers...',
          'leftovers???',
          'leftovers!',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('prepended punctuation does not suppress detection', () {
      const canonical = 'yesterday dinner';
      _assertInvariant(
        canonical,
        [
          '...yesterday dinner',
          '!yesterday dinner',
          '??? yesterday dinner',
        ],
        expectRef: true,
        expectOffset: 1,
        expectMealType: 'dinner',
      );
    });

    test('leading/trailing whitespace does not affect output', () {
      const canonical = 'leftovers from last night';
      _assertInvariant(
        canonical,
        [
          '  leftovers from last night',
          'leftovers from last night  ',
          '  leftovers from last night  ',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('double/extra internal spaces do not affect output', () {
      const canonical = 'had that again';
      _assertInvariant(
        canonical,
        [
          'had  that  again',
          'had   that again',
        ],
        expectRef: true,
        expectMatchRecent: true,
      );
    });
  });

  // ── INV — leftovers rule group ───────────────────────────────────────────

  group('INV — leftovers', () {
    test('all leftovers seed patterns fire with offset=1', () {
      // All patterns within the leftovers rule should detect as referential
      // and resolve to offset=1 (the default leftover dateOffset).
      _assertInvariant(
        'leftovers',
        [
          'LEFTOVERS',
          'Leftovers',
          'left overs', // space variant
          'leftover',   // singular
          'the rest of the meal',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('what was left variant — case invariant', () {
      _assertInvariant(
        "what was left",
        [
          "WHAT WAS LEFT",
          "What Was Left",
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('what\'s left variant — case invariant', () {
      _assertInvariant(
        "what's left",
        [
          "WHAT'S LEFT",
          "What's Left",
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });
  });

  // ── INV — yesterday / last_night rule group ──────────────────────────────

  group('INV — yesterday/last_night', () {
    test('yesterday: case and punctuation invariant', () {
      _assertInvariant(
        'yesterday',
        [
          'YESTERDAY',
          'Yesterday',
          'yesterday.',
          'yesterday!',
          '  yesterday  ',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('last night: case invariant', () {
      _assertInvariant(
        'last night',
        [
          'LAST NIGHT',
          'Last Night',
          'last night.',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('the night before: case invariant → offset 1', () {
      _assertInvariant(
        'the night before',
        [
          'THE NIGHT BEFORE',
          'The Night Before',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });

    test('the other night: case invariant → offset 1', () {
      _assertInvariant(
        'the other night',
        [
          'THE OTHER NIGHT',
          'The Other Night',
        ],
        expectRef: true,
        expectOffset: 1,
      );
    });
  });

  // ── INV — named_day rule group ───────────────────────────────────────────

  group('INV — named_day', () {
    test('monday: case invariant → offset 3', () {
      // kToday = Thursday May 14; Monday May 11 = 3 days ago
      _assertInvariant(
        'had it on monday',
        [
          'had it on MONDAY',
          'Had It On Monday',
          'HAD IT ON MONDAY',
        ],
        expectRef: true,
        expectOffset: 3,
      );
    });

    test('friday: case invariant → offset 6', () {
      // Friday May 8 = 6 days ago from Thursday May 14
      _assertInvariant(
        'leftovers from friday',
        [
          'leftovers from FRIDAY',
          'Leftovers From Friday',
        ],
        expectRef: true,
        expectOffset: 6,
      );
    });

    test('named day + punctuation → still resolves', () {
      _assertInvariant(
        'had it tuesday',
        [
          'had it tuesday!',
          'had it tuesday...',
          'had it tuesday?',
        ],
        expectRef: true,
        expectOffset: 2,
      );
    });
  });

  // ── INV — same_as_before rule group ─────────────────────────────────────

  group('INV — same_as_before', () {
    test('again: case and punctuation invariant → matchRecent', () {
      _assertInvariant(
        'had that again',
        [
          'had that AGAIN',
          'Had That Again',
          'had that again.',
          'had that again!',
          '  had that again  ',
        ],
        expectRef: true,
        expectMatchRecent: true,
      );
    });

    test('the usual: case invariant → matchRecent', () {
      _assertInvariant(
        'the usual breakfast',
        [
          'THE USUAL BREAKFAST',
          'The Usual Breakfast',
          'the usual breakfast.',
        ],
        expectRef: true,
        expectMatchRecent: true,
        expectMealType: 'breakfast',
      );
    });

    test('repeat: case invariant → matchRecent', () {
      _assertInvariant(
        'repeat dinner',
        [
          'REPEAT DINNER',
          'Repeat Dinner',
          'repeat dinner.',
        ],
        expectRef: true,
        expectMatchRecent: true,
        expectMealType: 'dinner',
      );
    });

    test('same old: case invariant → matchRecent', () {
      _assertInvariant(
        'same old lunch',
        [
          'SAME OLD LUNCH',
          'Same Old Lunch',
          'same old lunch!',
        ],
        expectRef: true,
        expectMatchRecent: true,
        expectMealType: 'lunch',
      );
    });

    test('my go-to: case invariant → matchRecent', () {
      _assertInvariant(
        'my go-to lunch',
        [
          'MY GO-TO LUNCH',
          'My Go-To Lunch',
          'my go-to lunch.',
        ],
        expectRef: true,
        expectMatchRecent: true,
        expectMealType: 'lunch',
      );
    });

    test('the thing I had: case invariant → matchRecent', () {
      _assertInvariant(
        'the thing I had',
        [
          'THE THING I HAD',
          'The Thing I Had',
          'the thing i had', // lowercase i — already the normalized form
        ],
        expectRef: true,
        expectMatchRecent: true,
      );
    });
  });

  // ── INV — days_ago rule group ────────────────────────────────────────────

  group('INV — days_ago', () {
    test('a few days ago: case and punctuation invariant → offset 3', () {
      _assertInvariant(
        'a few days ago',
        [
          'A FEW DAYS AGO',
          'A Few Days Ago',
          'a few days ago.',
          'a few days ago!',
          '  a few days ago  ',
        ],
        expectRef: true,
        expectOffset: 3,
      );
    });

    test('last week: case invariant → offset 3', () {
      _assertInvariant(
        "last week's dinner",
        [
          "LAST WEEK'S DINNER",
          "Last Week's Dinner",
        ],
        expectRef: true,
        expectOffset: 3,
        expectMealType: 'dinner',
      );
    });

    test('a while back: case invariant → offset 3', () {
      _assertInvariant(
        'a while back',
        [
          'A WHILE BACK',
          'A While Back',
          'a while back.',
        ],
        expectRef: true,
        expectOffset: 3,
      );
    });

    test('couple days back: case invariant → offset 3', () {
      _assertInvariant(
        'a couple days back',
        [
          'A COUPLE DAYS BACK',
          'A Couple Days Back',
        ],
        expectRef: true,
        expectOffset: 3,
      );
    });
  });

  // ── INV — this_morning rule group ────────────────────────────────────────

  group('INV — this_morning', () {
    test('this morning: case and punctuation invariant → offset 0', () {
      _assertInvariant(
        'this morning I had oatmeal',
        [
          'THIS MORNING I HAD OATMEAL',
          'This Morning I Had Oatmeal',
          'this morning I had oatmeal.',
          '  this morning I had oatmeal  ',
        ],
        expectRef: true,
        expectOffset: 0,
      );
    });

    test('earlier today: case invariant → offset 0', () {
      _assertInvariant(
        'earlier today',
        [
          'EARLIER TODAY',
          'Earlier Today',
        ],
        expectRef: true,
        expectOffset: 0,
      );
    });

    test('a few hours ago: case invariant → offset 0', () {
      _assertInvariant(
        'a few hours ago',
        [
          'A FEW HOURS AGO',
          'A Few Hours Ago',
          'a few hours ago.',
        ],
        expectRef: true,
        expectOffset: 0,
      );
    });
  });

  // ── INV — synonym seeds produce identical buildQuerySpec output ──────────

  group('INV — synonym seeds (same rule key → same spec)', () {
    test('leftovers synonyms all yield offset=1, isLeftover=true', () {
      // All of these fire the leftovers rule key — specs must be equivalent.
      final seeds = [
        'leftovers',
        'leftover',
        'the rest of dinner',
        "what's left",
        'what was left',
      ];
      final specs = seeds.map(_spec).toList();
      for (var i = 0; i < specs.length; i++) {
        expect(specs[i].dateOffset, equals(1),
            reason: 'seed "${seeds[i]}" should give offset=1');
        expect(specs[i].isLeftover, isTrue,
            reason: 'seed "${seeds[i]}" should set isLeftover=true');
      }
    });

    test('same_as_before synonyms all yield matchRecent=true', () {
      final seeds = [
        'had that again',
        'the usual',
        'repeat lunch',
        'same old thing',
        'my go-to',
        'the thing I had',
        'what I always have',
      ];
      for (final seed in seeds) {
        final s = _spec(seed);
        expect(s.matchRecent, isTrue,
            reason: '"$seed" should yield matchRecent=true');
      }
    });

    test('yesterday synonyms all yield offset=1', () {
      final seeds = [
        'yesterday',
        'last night',
        'the night before',
        'the day before',
        'the other night',
      ];
      for (final seed in seeds) {
        final s = _spec(seed);
        expect(s.dateOffset, equals(1),
            reason: '"$seed" should yield dateOffset=1');
      }
    });

    test('days_ago synonyms all yield offset=3', () {
      final seeds = [
        'a few days ago',
        'a couple days ago',
        'couple nights ago',
        'earlier this week',
        'earlier in the week',
        'a while back',
        'a while ago',
        'last week',
      ];
      for (final seed in seeds) {
        final s = _spec(seed);
        expect(s.dateOffset, equals(3),
            reason: '"$seed" should yield dateOffset=3');
      }
    });

    test('this_morning synonyms all yield offset=0', () {
      final seeds = [
        'this morning',
        'earlier today',
        'had some earlier',
        'a few hours ago',
      ];
      for (final seed in seeds) {
        final s = _spec(seed);
        expect(s.dateOffset, equals(0),
            reason: '"$seed" should yield dateOffset=0');
      }
    });
  });
}
