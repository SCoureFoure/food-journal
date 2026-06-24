import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';

// Fractional servings (schema v14). Covers the display formatter and the
// double round-trip through FoodItemDraft.fromJson.

void main() {
  group('[EQUIV] formatServings', () {
    test('whole numbers drop the decimal', () {
      expect(formatServings(1), '1');
      expect(formatServings(2), '2');
      expect(formatServings(10), '10');
    });

    test('common fractions render as glyphs', () {
      expect(formatServings(0.5), '½');
      expect(formatServings(0.25), '¼');
      expect(formatServings(0.75), '¾');
    });

    test('mixed numbers combine whole + glyph', () {
      expect(formatServings(1.5), '1½');
      expect(formatServings(2.25), '2¼');
      expect(formatServings(3.75), '3¾');
    });

    test('uncommon fractions fall back to trimmed decimal', () {
      expect(formatServings(1.2), '1.2');
      expect(formatServings(0.1), '0.1');
    });
  });

  group('[BVA] FoodItemDraft.fromJson — servings', () {
    test('defaults to 1.0 when absent', () {
      final d = FoodItemDraft.fromJson({'name': 'Eggs'});
      expect(d.servings, 1.0);
    });

    test('parses a fractional value', () {
      final d = FoodItemDraft.fromJson({'name': 'Eggs', 'servings': 0.5});
      expect(d.servings, 0.5);
    });

    test('parses an integer value as double', () {
      final d = FoodItemDraft.fromJson({'name': 'Eggs', 'servings': 2});
      expect(d.servings, 2.0);
    });
  });
}
