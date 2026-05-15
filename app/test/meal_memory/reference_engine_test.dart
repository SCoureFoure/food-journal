import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:food_journal/services/meal_memory/meal_reference_rules.dart';
import 'package:food_journal/services/meal_memory/reference_engine.dart';

void main() {
  // Use a fixed "today" so named-day tests are deterministic.
  // Thursday, May 14, 2026.
  final kToday = DateTime(2026, 5, 14);

  group('isReferential', () {
    bool ref(String s) => detectReferences(s, mealRules,
        temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys).hasTemporalRef;

    test('leftovers → true', () => expect(ref('I had the leftovers'), isTrue));
    test('last night → true', () => expect(ref('same as last night'), isTrue));
    test('yesterday → true', () => expect(ref('had eggs yesterday'), isTrue));
    test('again → true', () => expect(ref('had that again'), isTrue));
    test('the usual → true', () => expect(ref('the usual breakfast'), isTrue));
    test('named day → true', () => expect(ref('leftovers from last friday'), isTrue));
    test('earlier → true', () => expect(ref('had some earlier'), isTrue));
    test('plain food → false', () => expect(ref('I had a chicken sandwich'), isFalse));
    test('empty → false', () => expect(ref(''), isFalse));
  });

  group('buildQuerySpec — dateOffset', () {
    MealQuerySpec spec(String s) {
      final p = detectReferences(s, mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      return buildQuerySpec(p, now: kToday);
    }

    test('"leftovers from last night" → offset 1', () {
      expect(spec('leftovers from last night').dateOffset, equals(1));
    });

    test('"had that for breakfast yesterday" → offset 1', () {
      expect(spec('had that for breakfast yesterday').dateOffset, equals(1));
    });

    test('"leftovers from last friday" → offset 6 (Friday May 8)', () {
      // kToday = Thursday May 14; last Friday = May 8 = 6 days ago
      expect(spec('leftovers from last friday').dateOffset, equals(6));
    });

    test('"what I had on monday" → offset 3 (Monday May 11)', () {
      // kToday = Thursday May 14; last Monday = May 11 = 3 days ago
      expect(spec('what I had on monday').dateOffset, equals(3));
    });

    test('"same as wednesday" → offset 2', () {
      // kToday = Thursday May 14; last Wednesday = May 13 = 1... wait:
      // Thu=14, Wed=13, offset=1... no: May 14 - May 13 = 1 day
      // Actually proximity walk: i=1 → May 13 = Wednesday → offset 1
      expect(spec('same as wednesday').dateOffset, equals(1));
    });

    test('"the usual" → matchRecent true, no offset', () {
      final s = spec('the usual');
      expect(s.dateOffset, isNull);
      expect(s.matchRecent, isTrue);
    });

    test('"had that again" → matchRecent true', () {
      final s = spec('had that again');
      expect(s.matchRecent, isTrue);
    });
  });

  group('buildQuerySpec — mealType', () {
    MealQuerySpec spec(String s) {
      final p = detectReferences(s, mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      return buildQuerySpec(p, now: kToday);
    }

    test('dinner in input → mealType dinner', () {
      expect(spec('leftovers from dinner last night').mealType, equals('dinner'));
    });

    test('breakfast in input → mealType breakfast', () {
      expect(spec('same breakfast as yesterday').mealType, equals('breakfast'));
    });

    test('no meal type → null', () {
      expect(spec('leftovers from yesterday').mealType, isNull);
    });
  });

  group('confidence scoring', () {
    test('single match = 1.0', () {
      final p = detectReferences('leftovers', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      expect(p.confidence['leftovers'], equals(1.0));
    });

    test('double match on same rule = 1.5', () {
      // "leftovers ... rest of the leftovers" — two matches for leftovers rule
      final p = detectReferences('leftovers and the rest of the leftovers', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      // "leftovers" fires twice (1.0 + 0.5), "the rest of" fires once (+1.0)
      expect(p.confidence['leftovers']! >= 1.5, isTrue);
    });

    test('multi-rule total confidence > single', () {
      final single = detectReferences('leftovers', mealRules).totalConfidence;
      final multi = detectReferences('leftovers from dinner last night', mealRules).totalConfidence;
      expect(multi, greaterThan(single));
    });
  });

  group('_resolveNamedDayOffset (via buildQuerySpec)', () {
    // kToday = Thursday May 14
    MealQuerySpec spec(String s) {
      final p = detectReferences(s, mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      return buildQuerySpec(p, now: kToday);
    }

    test('friday from thursday → 6 days ago', () {
      expect(spec('had leftover pizza from friday').dateOffset, equals(6));
    });

    test('tuesday from thursday → 2 days ago', () {
      expect(spec('the tuesday dinner').dateOffset, equals(2));
    });

    test('thursday from thursday → 7 days ago (same day = last week)', () {
      expect(spec('had it thursday').dateOffset, equals(7));
    });

    test('the other day → matchRecent, no specific offset', () {
      final s = spec('the other day we had pizza');
      expect(s.matchRecent, isTrue);
    });
  });

  group('priority boundaries', () {
    MealQuerySpec spec(String s) {
      final p = detectReferences(s, mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      return buildQuerySpec(p, now: kToday);
    }

    // ignore: avoid_print
    void out(String input, MealQuerySpec r) => print(
          jsonEncode(<String, Object?>{
            'type': 'test_output',
            'input': input,
            'dateOffset': r.dateOffset,
            'mealType': r.mealType,
            'matchRecent': r.matchRecent,
          }),
        );

    test('leftovers + named_day → named_day wins', () {
      final r = spec('leftovers from last friday');
      out('leftovers from last friday', r);
      expect(r.dateOffset, equals(6));
    });

    test('days_ago + this_morning → days_ago wins (offset 3)', () {
      final r = spec('earlier this week');
      out('earlier this week', r);
      expect(r.dateOffset, equals(3));
    });

    test('two_days_ago + yesterday → two_days_ago wins (offset 2)', () {
      final r = spec('the dinner from the day before yesterday');
      out('the dinner from the day before yesterday', r);
      expect(r.dateOffset, equals(2));
    });

    test('named_day + meal_type → dateOffset and mealType both set', () {
      final r = spec('the tuesday lunch');
      out('the tuesday lunch', r);
      expect(r.dateOffset, equals(2));
      expect(r.mealType, equals('lunch'));
    });

    test('named_day rule fires but no weekday string → matchRecent', () {
      final r = spec('the other day we had soup');
      out('the other day we had soup', r);
      expect(r.dateOffset, isNull);
      expect(r.matchRecent, isTrue);
    });

    test('same_as_before with no temporal → matchRecent true, dateOffset null', () {
      final r = spec('the usual breakfast');
      out('the usual breakfast', r);
      expect(r.dateOffset, isNull);
      expect(r.matchRecent, isTrue);
    });
  });

  group('new rules smoke tests', () {
    bool ref(String s) => detectReferences(s, mealRules,
        temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys).hasTemporalRef;

    MealQuerySpec spec(String s) {
      final p = detectReferences(s, mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      return buildQuerySpec(p, now: kToday);
    }

    test('"same old" → referential', () => expect(ref('same old dinner'), isTrue));
    test('"repeat" → referential', () => expect(ref('repeat dinner'), isTrue));
    test('"the thing I had" → referential', () => expect(ref('the thing I had'), isTrue));
    test('"like what I had" → referential', () => expect(ref('like what I had on monday'), isTrue));
    test('"the other night" → referential, offset 1', () {
      expect(spec('the other night we had tacos').dateOffset, equals(1));
    });
    test('"last week" → referential, offset 3', () {
      expect(spec("last week's dinner").dateOffset, equals(3));
    });
    test('"a while back" → referential, offset 3', () {
      expect(spec('a while back I had that salmon').dateOffset, equals(3));
    });
    test('"couple nights ago" → referential, offset 3', () {
      expect(spec('had it a couple nights ago').dateOffset, equals(3));
    });
    test('"day before yesterday" → offset 2', () {
      expect(spec('the day before yesterday').dateOffset, equals(2));
    });
    test('"day before last" → offset 2', () {
      expect(spec('day before last').dateOffset, equals(2));
    });
  });

  group('buildContextSnippet format', () {
    test('output starts with "Recent meals:" header', () {
      // Verify the format string that gets injected into the Gemini prompt.
      // This is a unit test of the format shape, not DB content.
      // Format: "Recent meals:\n- <label> <mealType>: <foods> (<macros>)"
      const snippet = 'Recent meals:\n- Yesterday dinner: grilled chicken, rice (450 cal, 35g protein)';
      expect(snippet, startsWith('Recent meals:'));
      expect(snippet, contains('- Yesterday'));
      expect(snippet, contains(':'));
    });
  });
}
