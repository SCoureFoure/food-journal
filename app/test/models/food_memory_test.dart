import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_memory.dart';

FoodMemory _mem({bool favorited = false, bool flagged = false}) => FoodMemory(
      foodName: 'Chicken breast',
      occurrences: 3,
      lastSeen: DateTime(2026, 5, 20),
      flagged: flagged,
      favorited: favorited,
    );

void main() {
  // ── Field defaults ─────────────────────────────────────────────────────────

  group('[MFT] FoodMemory — field defaults', () {
    test('favorited defaults to false', () {
      final mem = FoodMemory(
        foodName: 'Oatmeal',
        occurrences: 1,
        lastSeen: DateTime(2026, 5, 1),
        flagged: false,
      );
      expect(mem.favorited, isFalse);
    });

    test('reactionPattern defaults to null', () {
      expect(_mem().reactionPattern, isNull);
    });

    test('id defaults to null', () {
      expect(_mem().id, isNull);
    });
  });

  // ── favorited field ────────────────────────────────────────────────────────

  group('[MFT] FoodMemory.favorited — construction and read', () {
    test('favorited: true is stored and readable', () {
      expect(_mem(favorited: true).favorited, isTrue);
    });

    test('favorited: false is stored and readable', () {
      expect(_mem(favorited: false).favorited, isFalse);
    });

    test('favorited is independent of flagged', () {
      final mem = _mem(favorited: true, flagged: false);
      expect(mem.favorited, isTrue);
      expect(mem.flagged, isFalse);
    });

    test('both favorited and flagged can be true simultaneously', () {
      final mem = _mem(favorited: true, flagged: true);
      expect(mem.favorited, isTrue);
      expect(mem.flagged, isTrue);
    });
  });

  // ── copyWith ──────────────────────────────────────────────────────────────

  group('[INV] FoodMemory.copyWith — favorited field', () {
    test('copyWith(favorited: true) flips false → true', () {
      final toggled = _mem(favorited: false).copyWith(favorited: true);
      expect(toggled.favorited, isTrue);
    });

    test('copyWith(favorited: false) flips true → false', () {
      final toggled = _mem(favorited: true).copyWith(favorited: false);
      expect(toggled.favorited, isFalse);
    });

    test('copyWith without favorited preserves existing value: true', () {
      final copy = _mem(favorited: true).copyWith(foodName: 'Salmon');
      expect(copy.favorited, isTrue);
      expect(copy.foodName, 'Salmon');
    });

    test('copyWith without favorited preserves existing value: false', () {
      final copy = _mem(favorited: false).copyWith(occurrences: 10);
      expect(copy.favorited, isFalse);
      expect(copy.occurrences, 10);
    });

    test('copyWith does not mutate the original', () {
      final original = _mem(favorited: false);
      original.copyWith(favorited: true);
      expect(original.favorited, isFalse);
    });
  });

  // ── BVA: occurrences boundary ─────────────────────────────────────────────

  group('[BVA] FoodMemory.occurrences — boundary values', () {
    test('occurrences of 0 is valid', () {
      final mem = FoodMemory(
        foodName: 'New food',
        occurrences: 0,
        lastSeen: DateTime(2026, 5, 1),
        flagged: false,
      );
      expect(mem.occurrences, 0);
    });

    test('occurrences of 1 is the typical first-log value', () {
      final mem = _mem().copyWith(occurrences: 1);
      expect(mem.occurrences, 1);
    });
  });
}
