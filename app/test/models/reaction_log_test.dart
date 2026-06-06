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

  // ── Mood ──────────────────────────────────────────────────────────────────

  group('[DIR] Mood.toInt / fromInt round-trip', () {
    test('all Mood values survive toInt → fromInt', () {
      for (final mood in Mood.values) {
        expect(Mood.fromInt(mood.toInt()), mood);
      }
    });

    test('toInt is ordinal (great=0, awful=4)', () {
      expect(Mood.great.toInt(), 0);
      expect(Mood.awful.toInt(), 4);
    });

    test('fromInt(0) is great', () => expect(Mood.fromInt(0), Mood.great));
    test('fromInt(4) is awful', () => expect(Mood.fromInt(4), Mood.awful));
  });

  group('[DIR] Mood.label', () {
    test('each Mood has a non-empty label', () {
      for (final mood in Mood.values) {
        expect(mood.label, isNotEmpty);
      }
    });

    test('labels are distinct', () {
      final labels = Mood.values.map((m) => m.label).toSet();
      expect(labels.length, Mood.values.length);
    });

    test('great label is Great', () => expect(Mood.great.label, 'Great'));
    test('awful label is Awful', () => expect(Mood.awful.label, 'Awful'));
  });

  group('[DIR] Mood.isNegative', () {
    test('low and awful are negative', () {
      expect(Mood.low.isNegative, isTrue);
      expect(Mood.awful.isNegative, isTrue);
    });

    test('great, good, okay are not negative', () {
      expect(Mood.great.isNegative, isFalse);
      expect(Mood.good.isNegative, isFalse);
      expect(Mood.okay.isNegative, isFalse);
    });
  });

  group('[DIR] Mood.face', () {
    test('each Mood has an IconData face', () {
      for (final mood in Mood.values) {
        expect(mood.face, isNotNull);
      }
    });

    test('faces are distinct per mood', () {
      final faces = Mood.values.map((m) => m.face.codePoint).toSet();
      expect(faces.length, Mood.values.length);
    });
  });

  // ── ReactionLog.copyWith ──────────────────────────────────────────────────

  group('[DIR] ReactionLog.copyWith — field replacement', () {
    final base = ReactionLog(
      id: 1,
      mealId: 10,
      checkinTime: DateTime(2026, 6, 1, 12),
      symptoms: const ['Nausea', 'Bloating'],
      symptomLevels: const {
        'Nausea': ReactionLevel.mild,
        'Bloating': ReactionLevel.moderate,
      },
      severity: ReactionLevel.moderate,
      mood: Mood.okay,
      notes: 'felt off',
    );

    test('copyWith id replaces id', () {
      expect(base.copyWith(id: 99).id, 99);
    });

    test('copyWith mealId replaces mealId', () {
      expect(base.copyWith(mealId: 55).mealId, 55);
    });

    test('copyWith checkinTime replaces checkinTime', () {
      final t = DateTime(2026, 12, 31);
      expect(base.copyWith(checkinTime: t).checkinTime, t);
    });

    test('copyWith symptoms replaces symptoms', () {
      final copy = base.copyWith(symptoms: ['Headache']);
      expect(copy.symptoms, ['Headache']);
    });

    test('copyWith symptomLevels replaces symptomLevels', () {
      final copy = base.copyWith(
        symptomLevels: {'Headache': ReactionLevel.bad},
      );
      expect(copy.symptomLevels, {'Headache': ReactionLevel.bad});
    });

    test('copyWith severity replaces severity', () {
      expect(base.copyWith(severity: ReactionLevel.bad).severity, ReactionLevel.bad);
    });

    test('copyWith mood replaces mood', () {
      expect(base.copyWith(mood: Mood.awful).mood, Mood.awful);
    });

    test('copyWith notes replaces notes', () {
      expect(base.copyWith(notes: 'better now').notes, 'better now');
    });

    test('no-arg copyWith preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.mealId, base.mealId);
      expect(copy.checkinTime, base.checkinTime);
      expect(copy.symptoms, base.symptoms);
      expect(copy.symptomLevels, base.symptomLevels);
      expect(copy.severity, base.severity);
      expect(copy.mood, base.mood);
      expect(copy.notes, base.notes);
    });
  });
}
