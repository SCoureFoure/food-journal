// AC5 (specs/log_feeling.spec.md) — severity is derived as the worst per-symptom
// level, none when empty. Pure model test (cheapest layer).

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/reaction_log.dart';

void main() {
  group('[AC5] ReactionLog.deriveSeverity', () {
    test('empty map → none', () {
      expect(ReactionLog.deriveSeverity(const {}), ReactionLevel.none);
    });

    test('single symptom → its own level', () {
      expect(
        ReactionLog.deriveSeverity(const {'Nausea': ReactionLevel.mild}),
        ReactionLevel.mild,
      );
    });

    test('mixed levels → worst (max index) wins', () {
      expect(
        ReactionLog.deriveSeverity(const {
          'Bloating': ReactionLevel.mild,
          'Headache': ReactionLevel.bad,
          'Fatigue': ReactionLevel.moderate,
        }),
        ReactionLevel.bad,
      );
    });

    test('order does not matter', () {
      const a = {'x': ReactionLevel.bad, 'y': ReactionLevel.mild};
      const b = {'y': ReactionLevel.mild, 'x': ReactionLevel.bad};
      expect(ReactionLog.deriveSeverity(a), ReactionLog.deriveSeverity(b));
    });
  });
}
