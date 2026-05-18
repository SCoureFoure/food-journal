import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/services/import_service.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

MealEntry _meal({
  String date = '2026-05-14',
  String time = '8:00 AM',
  String mealType = 'breakfast',
}) =>
    MealEntry(
      date: DateTime.parse(date),
      time: time,
      mealType: mealType,
      createdAt: DateTime.parse('${date}T08:00:00.000'),
    );

FoodItem _item(String name) => FoodItem(mealId: 0, name: name);

MealImportRecord _record({
  required MealEntry meal,
  required List<FoodItem> foodItems,
}) =>
    MealImportRecord(
      meal: meal,
      foodItems: foodItems,
      ingredientsByItem: List.generate(foodItems.length, (_) => <Ingredient>[]),
      reactionLogs: [],
    );

void main() {
  // ── ImportSelection.totalCount — counting ────────────────────────────────

  group('[MFT] ImportSelection.totalCount', () {
    test('sums across all three sets', () {
      final sel = ImportSelection(
        mealIndices: {0, 1, 2},
        medicationIndices: {0},
        foodMemoryIndices: {0, 1},
      );
      expect(sel.totalCount, 6);
    });

    test('counts only selected indices, not total available', () {
      final sel = ImportSelection(
        mealIndices: {5, 10},
        medicationIndices: {},
        foodMemoryIndices: {},
      );
      expect(sel.totalCount, 2);
    });
  });

  // ── ImportSelection.totalCount — boundary ───────────────────────────────

  group('[BVA] ImportSelection.totalCount — boundary', () {
    test('zero when all sets are empty', () {
      final sel = ImportSelection(
        mealIndices: {},
        medicationIndices: {},
        foodMemoryIndices: {},
      );
      expect(sel.totalCount, 0);
    });
  });

  // ── MealImportRecord.dupeKey — format ────────────────────────────────────

  group('[MFT] MealImportRecord.dupeKey', () {
    test('format is date|time|mealType|sorted-lowercase-food-names', () {
      final record = _record(
        meal: _meal(date: '2026-05-14', time: '7:30 AM', mealType: 'breakfast'),
        foodItems: [_item('Eggs'), _item('Toast')],
      );
      expect(record.dupeKey, '2026-05-14|7:30 AM|breakfast|eggs,toast');
    });

    test('food names are sorted alphabetically before joining', () {
      final record = _record(
        meal: _meal(mealType: 'lunch'),
        foodItems: [_item('Tomato'), _item('Avocado'), _item('Bread')],
      );
      expect(record.dupeKey, contains('avocado,bread,tomato'));
    });

    test('food names are lowercased', () {
      final record = _record(
        meal: _meal(mealType: 'dinner'),
        foodItems: [_item('STEAK'), _item('Broccoli')],
      );
      expect(record.dupeKey, contains('broccoli,steak'));
    });
  });

  // ── MealImportRecord.dupeKey — edge cases ────────────────────────────────

  group('[BVA] MealImportRecord.dupeKey — edge cases', () {
    test('empty food items list produces trailing pipe with no names', () {
      final record = _record(
        meal: _meal(mealType: 'snack'),
        foodItems: [],
      );
      expect(record.dupeKey, '2026-05-14|8:00 AM|snack|');
    });

    test('single food item produces no comma', () {
      final record = _record(
        meal: _meal(mealType: 'breakfast'),
        foodItems: [_item('Oatmeal')],
      );
      expect(record.dupeKey, '2026-05-14|8:00 AM|breakfast|oatmeal');
    });

    test('same food item listed twice both appear in key', () {
      final record = _record(
        meal: _meal(mealType: 'lunch'),
        foodItems: [_item('Rice'), _item('Rice')],
      );
      expect(record.dupeKey, contains('rice,rice'));
    });
  });
}
