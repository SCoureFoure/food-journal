import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';

void main() {
  // ─── int round-trip ───────────────────────────────────────────────────────

  group('[INV] ReactionLevel — int round-trip', () {
    test('fromInt(toInt(x)) == x for every level', () {
      for (final level in ReactionLevel.values) {
        expect(ReactionLevel.fromInt(level.toInt()), level);
      }
    });

    test('toInt returns index value', () {
      expect(ReactionLevel.pending.toInt(), 0);
      expect(ReactionLevel.none.toInt(), 1);
      expect(ReactionLevel.mild.toInt(), 2);
      expect(ReactionLevel.moderate.toInt(), 3);
      expect(ReactionLevel.bad.toInt(), 4);
    });
  });

  // ─── int boundary ─────────────────────────────────────────────────────────

  group('[BVA] ReactionLevel — int boundary', () {
    test('fromInt out-of-range index throws RangeError', () {
      expect(() => ReactionLevel.fromInt(99), throwsRangeError);
    });
  });

  // ─── label ───────────────────────────────────────────────────────────────

  group('[MFT] ReactionLevel — label', () {
    test('label returns human-readable string for each level', () {
      expect(ReactionLevel.pending.label, 'Pending');
      expect(ReactionLevel.none.label, 'No reaction');
      expect(ReactionLevel.mild.label, 'Mild');
      expect(ReactionLevel.moderate.label, 'Moderate');
      expect(ReactionLevel.bad.label, 'Bad');
    });

    test('all values have a non-empty label', () {
      for (final level in ReactionLevel.values) {
        expect(level.label, isNotEmpty);
      }
    });
  });

  // ─── name round-trip ─────────────────────────────────────────────────────

  group('[INV] ReactionLevel — name round-trip', () {
    test('byName(level.name) == level for every level', () {
      for (final level in ReactionLevel.values) {
        expect(ReactionLevel.values.byName(level.name), level);
      }
    });
  });

  // ─── byName boundary ─────────────────────────────────────────────────────

  group('[BVA] ReactionLevel — byName boundary', () {
    test('byName throws ArgumentError for unknown string', () {
      expect(
        () => ReactionLevel.values.byName('superBad'),
        throwsArgumentError,
      );
    });
  });

  // ─── fromLabel round-trip ─────────────────────────────────────────────────

  group('[INV] ReactionLevel — fromLabel round-trip', () {
    test('fromLabel(level.label) == level for every level', () {
      for (final level in ReactionLevel.values) {
        expect(ReactionLevel.fromLabel(level.label), level);
      }
    });
  });

  // ─── fromLabel boundary ──────────────────────────────────────────────────

  group('[BVA] ReactionLevel — fromLabel boundary', () {
    test('fromLabel returns pending for null', () {
      expect(ReactionLevel.fromLabel(null), ReactionLevel.pending);
    });

    test('fromLabel returns pending for unknown string', () {
      expect(ReactionLevel.fromLabel('superBad'), ReactionLevel.pending);
    });
  });
}
