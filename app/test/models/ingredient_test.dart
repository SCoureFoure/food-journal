import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/ingredient.dart';

void main() {
  const base = Ingredient(
    id: 10,
    foodItemId: 5,
    name: 'olive oil',
    quantity: '2',
    unit: 'tbsp',
  );

  group('[DIR] Ingredient.copyWith — field replacement', () {
    test('copyWith id replaces id', () {
      final copy = base.copyWith(id: 99);
      expect(copy.id, 99);
      expect(copy.foodItemId, base.foodItemId);
      expect(copy.name, base.name);
    });

    test('copyWith foodItemId replaces foodItemId', () {
      final copy = base.copyWith(foodItemId: 42);
      expect(copy.foodItemId, 42);
      expect(copy.id, base.id);
    });

    test('copyWith name replaces name', () {
      final copy = base.copyWith(name: 'feta cheese');
      expect(copy.name, 'feta cheese');
    });

    test('copyWith quantity replaces quantity', () {
      final copy = base.copyWith(quantity: '50');
      expect(copy.quantity, '50');
    });

    test('copyWith unit replaces unit', () {
      final copy = base.copyWith(unit: 'g');
      expect(copy.unit, 'g');
    });
  });

  group('[INV] Ingredient.copyWith — unchanged fields preserved', () {
    test('no-arg copyWith preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.foodItemId, base.foodItemId);
      expect(copy.name, base.name);
      expect(copy.quantity, base.quantity);
      expect(copy.unit, base.unit);
    });

    test('replacing name does not alter other fields', () {
      final copy = base.copyWith(name: 'garlic');
      expect(copy.id, base.id);
      expect(copy.foodItemId, base.foodItemId);
      expect(copy.quantity, base.quantity);
      expect(copy.unit, base.unit);
    });
  });

  group('[BVA] Ingredient.copyWith — null optional fields', () {
    test('ingredient with null optionals copies without error', () {
      const minimal = Ingredient(
        foodItemId: 1,
        name: 'salt',
      );
      final copy = minimal.copyWith(name: 'pepper');
      expect(copy.id, isNull);
      expect(copy.quantity, isNull);
      expect(copy.unit, isNull);
      expect(copy.name, 'pepper');
    });
  });
}
