import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';

void main() {
  // ─── Happy path ───────────────────────────────────────────────────────────

  group('[Scenario] FoodItemDraft.fromJson', () {
    test('parses all fields when present', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Chicken breast',
        'portion': '150g',
        'prep': 'grilled',
        'calories': 165,
        'protein': 31,
        'carbs': 0,
        'fat': 4,
        'ingredients': ['chicken', 'olive oil'],
        'notes': 'no skin',
      });

      expect(draft.name, 'Chicken breast');
      expect(draft.portion, '150g');
      expect(draft.prep, 'grilled');
      expect(draft.calories, 165);
      expect(draft.protein, 31);
      expect(draft.carbs, 0);
      expect(draft.fat, 4);
      expect(draft.ingredients, ['chicken', 'olive oil']);
      expect(draft.notes, 'no skin');
    });
  });

  // ─── favorited field ──────────────────────────────────────────────────────

  group('[MFT] FoodItemDraft.favorited — default and construction', () {
    test('favorited defaults to false when not supplied', () {
      const draft = FoodItemDraft(name: 'Oats');
      expect(draft.favorited, isFalse);
    });

    test('favorited can be set to true at construction', () {
      const draft = FoodItemDraft(name: 'Oats', favorited: true);
      expect(draft.favorited, isTrue);
    });

    test('fromJson always produces favorited=false (field is not in AI JSON output)', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Chicken breast',
        'ingredients': [],
        // even if a rogue payload includes the field, fromJson ignores it
        'favorited': true,
      });
      expect(draft.favorited, isFalse,
          reason: 'AI-parsed drafts must never carry a favorited flag; '
              'only history queries populate it');
    });
  });

  // ─── Edge inputs ─────────────────────────────────────────────────────────

  group('[BVA] FoodItemDraft.fromJson — edge inputs', () {
    test('coerces double calories to int (worker returns doubles)', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Oats',
        'calories': 150.0,
        'protein': 5.0,
        'carbs': 27.0,
        'fat': 3.0,
        'ingredients': [],
      });
      expect(draft.calories, 150);
      expect(draft.protein, 5);
      expect(draft.carbs, 27);
      expect(draft.fat, 3);
    });

    test('missing optional fields default to null', () {
      final draft = FoodItemDraft.fromJson({'name': 'Mystery food', 'ingredients': []});
      expect(draft.portion, isNull);
      expect(draft.prep, isNull);
      expect(draft.calories, isNull);
      expect(draft.protein, isNull);
      expect(draft.carbs, isNull);
      expect(draft.fat, isNull);
      expect(draft.notes, isNull);
    });

    test('missing ingredients key defaults to empty list', () {
      final draft = FoodItemDraft.fromJson({'name': 'Salad'});
      expect(draft.ingredients, isEmpty);
    });

    test('null ingredients key defaults to empty list', () {
      final draft = FoodItemDraft.fromJson({'name': 'Salad', 'ingredients': null});
      expect(draft.ingredients, isEmpty);
    });

    test('zero macros are preserved (not treated as null)', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Water',
        'calories': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
        'ingredients': [],
      });
      expect(draft.calories, 0);
      expect(draft.protein, 0);
      expect(draft.carbs, 0);
      expect(draft.fat, 0);
    });

    test('ingredients with empty strings are preserved as-is', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Test',
        'ingredients': ['', 'salt'],
      });
      expect(draft.ingredients, ['', 'salt']);
    });

    test('name with special characters is preserved', () {
      final draft = FoodItemDraft.fromJson({
        'name': 'Café au lait {"injection": true}',
        'ingredients': [],
      });
      expect(draft.name, 'Café au lait {"injection": true}');
    });
  });
}
