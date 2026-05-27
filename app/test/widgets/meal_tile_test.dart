// Tests for MealTile favorites integration:
//   - _favoritedNames is loaded via getFavoritedFoodNames() in parallel with items
//   - favorited: flag is passed correctly to each FoodItemCard
//   - _toggleFavorite calls toggleFoodFavorite then re-fetches getFavoritedFoodNames
//
// MealTile uses Navigator for edit, so widgets are wrapped in a Navigator/
// MaterialApp that can handle route pushes without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/home/meal_tile.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// Provides controllable in-memory implementations for the three methods
// MealTile calls:
//   - getFoodItemsWithIngredients  → seeded list
//   - getFavoritedFoodNames        → mutable Set
//   - toggleFoodFavorite           → records calls, mutates the Set

class _FakeStorage extends StorageService {
  // Seed these before pumping the widget.
  List<({FoodItem item, List<Ingredient> ingredients})> itemsResult = [];
  Set<String> favoritedNames = {};

  // Call log
  final List<String> toggleCalls = [];

  @override
  Future<List<({FoodItem item, List<Ingredient> ingredients})>>
      getFoodItemsWithIngredients(int mealId) async => itemsResult;

  @override
  Future<Set<String>> getFavoritedFoodNames() async =>
      Set<String>.of(favoritedNames);

  @override
  Future<void> toggleFoodFavorite(String foodName) async {
    toggleCalls.add(foodName);
    // Simulate the toggle: add if absent, remove if present (lowercased).
    final key = foodName.toLowerCase();
    if (favoritedNames.contains(key)) {
      favoritedNames.remove(key);
    } else {
      favoritedNames.add(key);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

MealEntry _meal({int id = 1}) => MealEntry(
      id: id,
      date: DateTime(2026, 5, 22),
      time: '12:00 PM',
      mealType: 'Lunch',
      createdAt: DateTime(2026, 5, 22, 12),
    );

FoodItem _foodItem({int id = 1, String name = 'Chicken breast'}) => FoodItem(
      id: id,
      mealId: 1,
      name: name,
    );

Widget _wrap({
  required MealEntry meal,
  required StorageService storage,
  VoidCallback? onReload,
}) =>
    MaterialApp(
      routes: {
        '/edit_meal': (_) => const Scaffold(body: Text('edit')),
      },
      home: Scaffold(
        body: SingleChildScrollView(
          child: MealTile(
            meal: meal,
            storage: storage,
            onReload: onReload ?? () {},
          ),
        ),
      ),
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ── Favorited flag passed to FoodItemCard ──────────────────────────────────

  group('[MFT] MealTile — favorited flag passed to FoodItemCard', () {
    testWidgets('FoodItemCard gets favorited=true when name is in favorited set',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 1, name: 'Chicken breast'), ingredients: []),
        ]
        ..favoritedNames = {'chicken breast'};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump(); // let initState async complete

      // Expand the tile to reveal FoodItemCard children
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      // A filled heart icon means favorited=true was passed to FoodItemCard
      expect(find.byIcon(Icons.favorite), findsOneWidget,
          reason: 'FoodItemCard must show filled heart when name is in _favoritedNames');
    });

    testWidgets('FoodItemCard gets favorited=false when name is not in favorited set',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 2, name: 'Toast'), ingredients: []),
        ]
        ..favoritedNames = {}; // empty — Toast is not favorited

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget,
          reason: 'FoodItemCard must show border heart when name is not in _favoritedNames');
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('comparison is case-insensitive: mixed-case item name matches lowercase set entry',
        (tester) async {
      // INV: MealTile stores names lowercased in _favoritedNames.
      // FoodItemCard receives favorited: _favoritedNames.contains(name.toLowerCase())
      // so "Greek Yogurt" must match 'greek yogurt'.
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 3, name: 'Greek Yogurt'), ingredients: []),
        ]
        ..favoritedNames = {'greek yogurt'};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget,
          reason: 'Case-insensitive match: "Greek Yogurt".toLowerCase() must hit '
              'the lowercased set entry "greek yogurt"');
    });
  });

  // ── Toggle calls storage then refreshes ───────────────────────────────────
  //
  // Design note: FoodItemCard wraps its heart in GestureDetector(onTap:) but
  // the entire card is wrapped in GestureDetector(onDoubleTap:). Flutter's
  // gesture arena delays onTap recognition until the double-tap timeout
  // (kDoubleTapTimeout = 300 ms) expires without a second tap. Tests must
  // pump past that deadline before asserting on toggle side-effects.

  group('[MFT] MealTile — _toggleFavorite calls storage and refreshes UI', () {
    // Pumps past the double-tap disambiguation timeout so the inner onTap fires.
    // kDoubleTapTimeout = 300 ms; we pump 310 ms to clear it, then one more
    // frame to let setState rebuild.
    Future<void> drainTap(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pump();
    }

    testWidgets('tapping heart calls toggleFoodFavorite with the food name',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 4, name: 'Salmon'), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump(); // drain initState Future.wait

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      final heartSem = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'btn-favorite-4',
      );
      await tester.tap(heartSem);
      await drainTap(tester);
      await tester.pumpAndSettle();

      expect(storage.toggleCalls, ['Salmon'],
          reason: '_toggleFavorite must call storage.toggleFoodFavorite with '
              'the original (non-lowercased) food name');
    });

    testWidgets('UI updates to filled heart after toggling unfavorited item',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 5, name: 'Oats'), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump(); // drain initState Future.wait

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      // Before toggle: border heart
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      final heartSem = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'btn-favorite-5',
      );
      await tester.tap(heartSem);
      await drainTap(tester);
      await tester.pumpAndSettle();

      // After toggle: filled heart (storage.favoritedNames now contains 'oats')
      expect(find.byIcon(Icons.favorite), findsOneWidget,
          reason: 'After toggling, MealTile must re-fetch and setState so '
              'FoodItemCard shows the updated favorited state');
    });

    testWidgets('UI updates to border heart after toggling favorited item',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 6, name: 'Eggs'), ingredients: []),
        ]
        ..favoritedNames = {'eggs'};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump(); // drain initState Future.wait

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      // Before toggle: filled heart
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      final heartSem = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'btn-favorite-6',
      );
      await tester.tap(heartSem);
      await drainTap(tester);
      await tester.pumpAndSettle();

      // After toggle: border heart (unfavorited)
      expect(find.byIcon(Icons.favorite_border), findsOneWidget,
          reason: 'Toggling a favorited item must result in border heart');
    });
  });

  // ── Calorie total in subtitle ─────────────────────────────────────────────

  group('[MFT] MealTile — _totalCalories subtitle', () {
    testWidgets('subtitle shows "time · N cal" when items are loaded with calories',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: FoodItem(id: 1, mealId: 1, name: 'Eggs', calories: 140), ingredients: []),
          (item: FoodItem(id: 2, mealId: 1, name: 'Toast', calories: 80), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      // Subtitle should show the time plus total calories (220)
      expect(find.textContaining('220 cal'), findsOneWidget,
          reason: '_totalCalories must sum calories across all loaded items');
    });

    testWidgets('subtitle shows only time when all items have null calories',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: FoodItem(id: 1, mealId: 1, name: 'Mystery food'), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      // _totalCalories is null when no item has calories — subtitle is just meal.time
      expect(find.textContaining(' cal'), findsNothing,
          reason: 'No cal text when all items have null calories');
    });

    testWidgets('subtitle shows only time when items list is empty',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = []
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      expect(find.textContaining(' cal'), findsNothing,
          reason: '_totalCalories returns null when items list is empty');
    });

    testWidgets('subtitle shows only time when total calories sums to zero',
        (tester) async {
      // BVA: calories=0 items should sum to 0; _totalCalories returns null for 0
      // to avoid showing "12:00 PM · 0 cal" which looks like no data.
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: FoodItem(id: 1, mealId: 1, name: 'Water', calories: 0), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      expect(find.textContaining(' cal'), findsNothing,
          reason: '_totalCalories returns null for zero sum — "0 cal" subtitle is suppressed');
    });

    testWidgets('subtitle total includes items where calories is null (counts as zero)',
        (tester) async {
      // Mixed: one item has calories, one has null — null treated as 0 in fold
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: FoodItem(id: 1, mealId: 1, name: 'Eggs', calories: 140), ingredients: []),
          (item: FoodItem(id: 2, mealId: 1, name: 'Mystery side'), ingredients: []),
        ]
        ..favoritedNames = {};

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      // 140 + 0 = 140, which is > 0 so subtitle shows it
      expect(find.textContaining('140 cal'), findsOneWidget,
          reason: 'Items with null calories contribute 0 to the total');
    });
  });

  // ── Multiple items ─────────────────────────────────────────────────────────

  group('[EQUIV] MealTile — multiple items, mixed favorited state', () {
    testWidgets('each FoodItemCard gets its own independent favorited value',
        (tester) async {
      final storage = _FakeStorage()
        ..itemsResult = [
          (item: _foodItem(id: 10, name: 'Eggs'), ingredients: []),
          (item: _foodItem(id: 11, name: 'Toast'), ingredients: []),
          (item: _foodItem(id: 12, name: 'Coffee'), ingredients: []),
        ]
        ..favoritedNames = {'eggs', 'coffee'}; // Toast is NOT favorited

      await tester.pumpWidget(_wrap(meal: _meal(), storage: storage));
      await tester.pump();

      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      // 2 filled hearts (Eggs, Coffee) + 1 border (Toast)
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });
}
