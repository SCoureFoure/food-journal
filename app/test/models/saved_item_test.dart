import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/saved_item.dart';

void main() {
  // ── Construction and field access ─────────────────────────────────────────

  group('[MFT] SavedItem — field construction', () {
    test('stores all required fields correctly', () {
      final now = DateTime(2026, 5, 27, 10, 0);
      final item = SavedItem(
        id: 1,
        name: 'Breakfast Bowl',
        calories: 450,
        protein: 22,
        carbs: 55,
        fat: 14,
        components: ['Oats', 'Banana', 'Peanut butter'],
        createdAt: now,
      );

      expect(item.id, 1);
      expect(item.name, 'Breakfast Bowl');
      expect(item.calories, 450);
      expect(item.protein, 22);
      expect(item.carbs, 55);
      expect(item.fat, 14);
      expect(item.components, ['Oats', 'Banana', 'Peanut butter']);
      expect(item.createdAt, now);
    });

    test('id defaults to null when not supplied', () {
      final item = SavedItem(
        name: 'Snack Plate',
        components: ['Apple', 'Cheese'],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.id, isNull);
    });

    test('all macro fields default to null when not supplied', () {
      final item = SavedItem(
        name: 'Unknown macro item',
        components: [],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.calories, isNull);
      expect(item.protein, isNull);
      expect(item.carbs, isNull);
      expect(item.fat, isNull);
    });
  });

  // ── Components list ───────────────────────────────────────────────────────

  group('[BVA] SavedItem — components list edge cases', () {
    test('empty components list is preserved', () {
      final item = SavedItem(
        name: 'Empty item',
        components: [],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.components, isEmpty);
    });

    test('single-component list is preserved', () {
      final item = SavedItem(
        name: 'Solo',
        components: ['Eggs'],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.components, ['Eggs']);
    });

    test('components with special characters are preserved as-is', () {
      final item = SavedItem(
        name: 'Fancy Salad',
        components: ['Café au lait', 'Jalapeño chips', '{"injection": true}'],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.components[0], 'Café au lait');
      expect(item.components[1], 'Jalapeño chips');
      expect(item.components[2], '{"injection": true}');
    });
  });

  // ── Zero macros ───────────────────────────────────────────────────────────

  group('[BVA] SavedItem — zero macro values', () {
    test('zero calories is preserved (not treated as null)', () {
      final item = SavedItem(
        name: 'Water item',
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        components: [],
        createdAt: DateTime(2026, 5, 27),
      );
      expect(item.calories, 0);
      expect(item.protein, 0);
      expect(item.carbs, 0);
      expect(item.fat, 0);
    });
  });
}
