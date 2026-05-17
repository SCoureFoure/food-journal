// DIR (Directional) tests for the meal memory pattern engine.
//
// Each test verifies a monotonic behavioral contract: adding or changing a
// specific element of the input must shift a specific output property in a
// specific direction, regardless of the absolute value.
//
// Fixed "today" = Thursday May 14, 2026 for deterministic named-day offsets.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/meal_memory/meal_reference_rules.dart';
import 'package:food_journal/services/meal_memory/reference_engine.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

final kToday = DateTime(2026, 5, 14); // Thursday

// Module-level context set by each group's setUpAll. Included in _spec() output
// so reports can show which directional contract each data point validates.
String _activeContract = '';
String _activeImplication = '';

void _emitGroupHeader({
  required String contract,
  required String implication,
}) {
  _activeContract = contract;
  _activeImplication = implication;
  // ignore: avoid_print
  print(jsonEncode(<String, Object?>{
    'type': 'test_group_header',
    'testTheory': 'DIR',
    'contract': contract,
    'implication': implication,
  }));
}

MealQuerySpec _spec(String input) {
  final p = detectReferences(input, mealRules,
      temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
  final s = buildQuerySpec(p, now: kToday);
  // ignore: avoid_print
  print(jsonEncode(<String, Object?>{
    'type': 'test_output',
    'testTheory': 'DIR',
    if (_activeContract.isNotEmpty) 'contract': _activeContract,
    if (_activeImplication.isNotEmpty) 'implication': _activeImplication,
    'input': input,
    'hasTemporalRef': p.hasTemporalRef,
    'firedKeys': List<String>.from(p.firedKeys),
    'totalConfidence': p.totalConfidence,
    'dateOffset': s.dateOffset,
    'mealType': s.mealType,
    'matchRecent': s.matchRecent,
  }));
  return s;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  group('DIR — directional contracts', () {
    setUpAll(() => _emitGroupHeader(
      contract: 'adding a more specific signal must shift output in the expected direction — never opposite',
      implication: 'adding a named day still returns matchRecent=true, or adding meal type removes temporal offset — lookup targets wrong records',
    ));

    // ── Contract 1: Vague → specific day drops matchRecent, adds dateOffset ──

    test('vague input: "had that again" → matchRecent=true, dateOffset=null', () {
      final s = _spec('had that again');
      expect(s.matchRecent, isTrue,
          reason: 'vague referential input should matchRecent');
      expect(s.dateOffset, isNull,
          reason: 'vague input has no specific day, so dateOffset must be null');
    });

    test(
        'adding named day drops matchRecent and adds dateOffset: '
        '"had that again on monday"', () {
      final s = _spec('had that again on monday');
      // kToday = Thursday May 14; Monday May 11 = 3 days ago
      expect(s.matchRecent, isFalse,
          reason: 'named-day input must NOT matchRecent when a specific day is resolved');
      expect(s.dateOffset, isNotNull,
          reason: 'named-day input must provide a dateOffset');
      expect(s.dateOffset, equals(3),
          reason: 'Monday from Thursday May 14 = 3 days ago');
    });

    test(
        'direction: vague.matchRecent=true AND specific.matchRecent=false '
        '(direction verified)', () {
      final vague = _spec('the usual');
      final specific = _spec('the usual on tuesday');
      // kToday = Thursday May 14; Tuesday May 12 = 2 days ago
      expect(vague.matchRecent, isTrue);
      expect(specific.matchRecent, isFalse);
      // The specific form must also gain a non-null dateOffset
      expect(specific.dateOffset, isNotNull);
    });

    test(
        'direction: vague.dateOffset=null → specific.dateOffset!=null '
        'for "repeat dinner" vs "repeat dinner last friday"', () {
      final vague = _spec('repeat dinner');
      final specific = _spec('repeat dinner last friday');
      // Friday May 8 = 6 days ago from Thursday May 14
      expect(vague.dateOffset, isNull,
          reason: '"repeat dinner" has no temporal signal beyond same_as_before');
      expect(specific.dateOffset, equals(6),
          reason: '"last friday" = 6 days ago should be resolved');
    });

    // ── Contract 2: Meal type additive — adding meal type does not remove temporal ──

    test(
        'leftovers yesterday: no mealType, has dateOffset=1', () {
      final s = _spec('leftovers yesterday');
      expect(s.dateOffset, equals(1),
          reason: 'temporal signal must be present');
      expect(s.mealType, isNull,
          reason: 'no meal type keyword in input');
    });

    test(
        'adding "dinner" to "leftovers yesterday" sets mealType without '
        'removing dateOffset', () {
      final s = _spec('leftovers from dinner yesterday');
      expect(s.mealType, equals('dinner'),
          reason: 'dinner keyword must set mealType');
      expect(s.dateOffset, equals(1),
          reason: 'temporal dateOffset must still be present after adding meal type');
    });

    test(
        'direction: no-type.mealType=null → with-type.mealType!=null; '
        'dateOffset unchanged for "a few days ago" + breakfast', () {
      final noType = _spec('had it a few days ago');
      final withType = _spec('had breakfast a few days ago');
      expect(noType.mealType, isNull);
      expect(withType.mealType, equals('breakfast'));
      // dateOffset must remain the same in both cases
      expect(noType.dateOffset, equals(withType.dateOffset),
          reason: 'adding meal type must not change dateOffset');
      expect(withType.dateOffset, equals(3));
    });

    test(
        'meal type additive with named day: adding lunch keyword preserves '
        'named-day dateOffset', () {
      final noType = _spec('what I had on wednesday');
      final withType = _spec('what I had for lunch on wednesday');
      // kToday = Thursday May 14; Wednesday May 13 = 1 day ago
      expect(noType.dateOffset, equals(1),
          reason: 'named day resolves correctly without meal type');
      expect(withType.dateOffset, equals(1),
          reason: 'named day offset must be preserved when meal type is added');
      expect(noType.mealType, isNull);
      expect(withType.mealType, equals('lunch'));
    });

    // ── Contract 3: Confidence is strictly additive ───────────────────────

    test(
        'direction: adding more temporal/rule signals strictly increases '
        'totalConfidence', () {
      final base = detectReferences('leftovers', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      final added = detectReferences('leftovers from dinner last night', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      expect(added.totalConfidence, greaterThan(base.totalConfidence),
          reason: 'more matching rules must strictly increase totalConfidence');
    });

    test(
        'direction: adding duplicate temporal words increases confidence '
        'beyond single occurrence', () {
      final single = detectReferences('yesterday', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      final doubled = detectReferences('yesterday yesterday', mealRules,
          temporalKeys: temporalKeys, mealTypeKeys: mealTypeKeys);
      expect(doubled.totalConfidence, greaterThan(single.totalConfidence),
          reason: 'two matches on same rule must score higher than one');
    });

    // ── Contract 4: Named day always overrides weaker temporal signals ─────

    test(
        'direction: named_day always overrides leftovers default offset — '
        'leftovers alone=1, leftovers+named_day=named_day offset', () {
      final plain = _spec('leftovers');
      final withDay = _spec('leftovers from last friday');
      // Friday May 8 = 6 days ago
      expect(plain.dateOffset, equals(1),
          reason: 'plain leftovers defaults to offset=1');
      expect(withDay.dateOffset, equals(6),
          reason: 'named day must override the default leftover offset');
      expect(withDay.dateOffset, greaterThan(plain.dateOffset!),
          reason: 'named-day offset (6) must be > leftover default (1)');
    });

    test(
        'direction: named_day overrides yesterday — '
        '"the dinner from the day before" + monday resolves to monday', () {
      final withYesterday = _spec('had it yesterday');
      final withMonday = _spec('had it on monday');
      // yesterday=1, monday=3 from Thursday May 14
      expect(withYesterday.dateOffset, equals(1));
      expect(withMonday.dateOffset, equals(3));
      // If both appear, named_day wins:
      final both = _spec('yesterday I think it was... actually monday');
      // Named-day resolution: Monday = 3
      expect(both.dateOffset, equals(3),
          reason: 'named_day must override yesterday when both are present');
    });

    // ── Contract 5: Priority ordering is monotone ─────────────────────────

    test(
        'direction: two_days_ago > yesterday — '
        '"day before yesterday" fires both but resolves to offset=2 not 1', () {
      final justYesterday = _spec('yesterday dinner');
      final twoDaysAgo = _spec('the dinner the day before yesterday');
      expect(justYesterday.dateOffset, equals(1));
      expect(twoDaysAgo.dateOffset, equals(2));
      expect(twoDaysAgo.dateOffset, greaterThan(justYesterday.dateOffset!),
          reason: 'two_days_ago priority must win over yesterday');
    });

    test(
        'direction: days_ago > this_morning — '
        '"earlier this week" resolves to offset=3 not 0', () {
      final thisMorning = _spec('had some earlier');
      final daysAgo = _spec('earlier this week');
      expect(thisMorning.dateOffset, equals(0));
      expect(daysAgo.dateOffset, equals(3));
      expect(daysAgo.dateOffset, greaterThan(thisMorning.dateOffset!),
          reason: 'days_ago priority must win over this_morning for "earlier this week"');
    });
  });
}
