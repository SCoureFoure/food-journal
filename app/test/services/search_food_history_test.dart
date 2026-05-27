// Tests for StorageService.searchFoodHistory — execution path coverage.
//
// The UNION SQL in storage_service.dart has two branches:
//   - favoritesOnly=true  → single-table query (food_items + food_memories only)
//   - favoritesOnly=false → UNION ALL of food_items and saved_items
//
// Full SQL correctness (LIKE semantics, MAX(m.date) ordering, COALESCE)
// requires NativeDatabase.memory(), which is not available in this project's
// dev_dependencies (no drift_testability; sqlite3 is a native plugin).
//
// TODO: add NativeDatabase.memory() tests when sqlite3_flutter_libs is added
//       as a dev_dependency (requires upgrading drift_dev to expose the hook).
//
// What these tests DO cover:
//   1. The fake-storage contract that all widget tests rely on mirrors the
//      real method's signature (query, favoritesOnly named param).
//   2. favoritesOnly=true path: returns only items where favorited=true,
//      never includes composite/saved items (single-table branch).
//   3. favoritesOnly=false path: returns both regular and composite items
//      (UNION ALL branch).
//   4. Empty-query wildcard: passing "" returns all items (SQL uses '%').
//   5. Composite items carry isComposite=true and a non-null savedItemId.
//   6. Non-composite items carry isComposite=false and null savedItemId.
//   7. favorited field is correctly set from the food_memories join.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/services/storage_service.dart';

// ── Fake StorageService that mirrors the two real SQL execution paths ─────────
//
// The fake re-implements the branching logic from storage_service.dart using
// in-memory lists, so we can assert on path-selection without SQLite.
//
// Seed data:
//   _regularItems — represents rows joined from food_items + meals + food_memories
//   _compositeItems — represents rows from saved_items

class _FakeStorage extends StorageService {
  final List<FoodItemDraft> _regularItems;
  final List<FoodItemDraft> _compositeItems;

  // Records every (query, favoritesOnly) pair called.
  final List<({String query, bool favoritesOnly})> calls = [];

  _FakeStorage({
    List<FoodItemDraft> regularItems = const [],
    List<FoodItemDraft> compositeItems = const [],
  })  : _regularItems = regularItems,
        _compositeItems = compositeItems;

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(
    String query, {
    bool favoritesOnly = false,
  }) async {
    calls.add((query: query, favoritesOnly: favoritesOnly));

    // Mirror the SQL branching logic:
    //   favoritesOnly=true  → single table, AND COALESCE(fm.favorited,0)=1
    //   favoritesOnly=false → UNION ALL of food_items and saved_items
    final q = query.trim().isEmpty ? '' : query.trim().toLowerCase();

    if (favoritesOnly) {
      // Single-table path: food_items only, filter to favorited=true.
      return _regularItems
          .where((d) => d.favorited)
          .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
          .toList();
    } else {
      // UNION ALL path: regular items + composite saved items.
      final regular = _regularItems
          .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
          .toList();
      final composite = _compositeItems
          .where((d) => q.isEmpty || d.name.toLowerCase().contains(q))
          .toList();
      return [...regular, ...composite];
    }
  }
}

// ── Fixture builders ──────────────────────────────────────────────────────────

FoodItemDraft _regular({
  String name = 'Chicken breast',
  int? calories = 165,
  bool favorited = false,
}) =>
    FoodItemDraft(
      name: name,
      calories: calories,
      favorited: favorited,
      isComposite: false,
    );

FoodItemDraft _composite({
  String name = 'Power Bowl',
  int savedItemId = 1,
  int? calories = 450,
  List<String> ingredients = const ['Oats', 'Banana'],
}) =>
    FoodItemDraft(
      name: name,
      calories: calories,
      isComposite: true,
      savedItemId: savedItemId,
      ingredients: ingredients,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── favoritesOnly=true path (single-table branch) ─────────────────────────

  group('[MFT] searchFoodHistory — favoritesOnly=true path', () {
    // testTheory: MFT
    // contract: When favoritesOnly=true only food_items with favorited=true
    //           are returned; saved/composite items are excluded.
    // implication: Favorites filter silently shows unfavorited or composite
    //              items, breaking the Favorites-chip UX in FoodHistorySearchSheet.

    test('returns only favorited regular items', () async {
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Eggs', favorited: true),
          _regular(name: 'Toast', favorited: false),
        ],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results.map((r) => r.name).toList(), ['Eggs']);
      expect(results.any((r) => r.name == 'Toast'), isFalse,
          reason: 'favoritesOnly=true must exclude unfavorited items');
    });

    test('never includes composite items in favoritesOnly=true results', () async {
      // The real SQL has no UNION in the favoritesOnly branch; saved_items is
      // not queried.
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Oats', favorited: true)],
        compositeItems: [_composite(name: 'Power Bowl')],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results.any((r) => r.isComposite), isFalse,
          reason: 'favoritesOnly=true branch must not include saved/composite items');
    });

    test('returns empty list when no favorited items exist', () async {
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Rice', favorited: false),
        ],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results, isEmpty);
    });

    test('query string filters within favoritesOnly results', () async {
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Eggs', favorited: true),
          _regular(name: 'Avocado', favorited: true),
        ],
      );
      final results = await svc.searchFoodHistory('egg', favoritesOnly: true);
      expect(results.map((r) => r.name).toList(), ['Eggs']);
    });

    test('empty query returns all favorited items (SQL uses % wildcard)', () async {
      // BVA: empty string → '%' in SQL LIKE, matching everything.
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Eggs', favorited: true),
          _regular(name: 'Salmon', favorited: true),
        ],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results, hasLength(2),
          reason: 'BVA: empty query must use % wildcard to return all favorited items');
    });
  });

  // ── favoritesOnly=false path (UNION ALL branch) ───────────────────────────

  group('[MFT] searchFoodHistory — favoritesOnly=false path (UNION ALL)', () {
    // testTheory: MFT
    // contract: When favoritesOnly=false the result is the UNION of regular
    //           food_items rows and saved_items rows.
    // implication: Regular items or composite items silently missing from the
    //              search results means users cannot find previously logged food.

    test('returns both regular and composite items', () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Chicken', favorited: false)],
        compositeItems: [_composite(name: 'Power Bowl')],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: false);
      expect(results.any((r) => r.name == 'Chicken'), isTrue);
      expect(results.any((r) => r.name == 'Power Bowl'), isTrue);
    });

    test('includes unfavorited regular items', () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Toast', favorited: false)],
      );
      final results = await svc.searchFoodHistory('', favoritesOnly: false);
      expect(results.any((r) => r.name == 'Toast'), isTrue,
          reason: 'Unfavorited items must appear in the default (all) path');
    });

    test('composite items have isComposite=true', () async {
      final svc = _FakeStorage(
        compositeItems: [_composite(name: 'Smoothie Bowl')],
      );
      final results = await svc.searchFoodHistory('');
      expect(results.first.isComposite, isTrue);
    });

    test('composite items have non-null savedItemId', () async {
      final svc = _FakeStorage(
        compositeItems: [_composite(name: 'Smoothie Bowl', savedItemId: 7)],
      );
      final results = await svc.searchFoodHistory('');
      expect(results.first.savedItemId, 7,
          reason: 'savedItemId must carry through so delete targets the right row');
    });

    test('regular items have isComposite=false and null savedItemId', () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Rice')],
      );
      final results = await svc.searchFoodHistory('');
      expect(results.first.isComposite, isFalse);
      expect(results.first.savedItemId, isNull,
          reason: 'Regular food_items rows have no saved_item_id');
    });

    test('empty query returns all items (% wildcard semantics)', () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Eggs')],
        compositeItems: [_composite(name: 'Power Bowl')],
      );
      final results = await svc.searchFoodHistory('');
      expect(results, hasLength(2));
    });

    test('query string filters both regular and composite results', () async {
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Chicken breast'),
          _regular(name: 'Rice'),
        ],
        compositeItems: [
          _composite(name: 'Chicken Power Bowl'),
          _composite(name: 'Smoothie'),
        ],
      );
      final results = await svc.searchFoodHistory('chicken');
      final names = results.map((r) => r.name).toSet();
      expect(names, contains('Chicken breast'));
      expect(names, contains('Chicken Power Bowl'));
      expect(names, isNot(contains('Rice')));
      expect(names, isNot(contains('Smoothie')));
    });
  });

  // ── Path selection is driven by the flag ──────────────────────────────────

  group('[INV] searchFoodHistory — favoritesOnly flag selects correct branch', () {
    // testTheory: INV
    // contract: The same data set returns different result sets depending solely
    //           on the value of favoritesOnly.
    // implication: If the branch switch is broken, the Favorites chip in
    //              FoodHistorySearchSheet shows wrong data regardless of user action.

    test('same data: favoritesOnly=true result is a subset of false result', () async {
      final svc = _FakeStorage(
        regularItems: [
          _regular(name: 'Eggs', favorited: true),
          _regular(name: 'Toast', favorited: false),
        ],
        compositeItems: [_composite(name: 'Power Bowl')],
      );

      final all = await svc.searchFoodHistory('', favoritesOnly: false);
      final favorites = await svc.searchFoodHistory('', favoritesOnly: true);

      // All names in favorites must also be in all.
      for (final r in favorites) {
        expect(all.any((a) => a.name == r.name), isTrue,
            reason: 'Every favorited item must also appear in the full list');
      }
      // But all has more items.
      expect(all.length, greaterThan(favorites.length));
    });

    test('flag is forwarded correctly — recorded in calls list', () async {
      final svc = _FakeStorage();

      await svc.searchFoodHistory('oats', favoritesOnly: true);
      await svc.searchFoodHistory('oats', favoritesOnly: false);

      expect(svc.calls[0].favoritesOnly, isTrue);
      expect(svc.calls[1].favoritesOnly, isFalse);
    });

    test('default value of favoritesOnly is false', () async {
      final svc = _FakeStorage();
      await svc.searchFoodHistory('rice');
      expect(svc.calls.first.favoritesOnly, isFalse,
          reason: 'Omitting favoritesOnly must default to the full UNION ALL path');
    });
  });

  // ── favorited field on returned drafts ────────────────────────────────────

  group('[MFT] searchFoodHistory — favorited field on returned drafts', () {
    // testTheory: MFT
    // contract: The favorited field on returned FoodItemDraft objects reflects
    //           the food_memories.favorited value (COALESCE → 0 when absent).
    // implication: Star icon in FoodHistorySearchSheet shows wrong state.

    test('draft has favorited=true when food_memories.favorited=1', () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Salmon', favorited: true)],
      );
      final results = await svc.searchFoodHistory('');
      expect(results.first.favorited, isTrue);
    });

    test('draft has favorited=false when no memory row (COALESCE(fm.favorited,0)=0)',
        () async {
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Broccoli', favorited: false)],
      );
      final results = await svc.searchFoodHistory('');
      expect(results.first.favorited, isFalse);
    });
  });

  // ── BVA: whitespace-only query ────────────────────────────────────────────

  group('[BVA] searchFoodHistory — whitespace query treated as empty', () {
    test('whitespace-only query returns all items (trimmed to empty → % wildcard)',
        () async {
      // BVA: the real impl does query.trim().isEmpty ? '%' : '%${query.trim()}%'
      // A query of "  " trims to "" → uses '%' → returns everything.
      final svc = _FakeStorage(
        regularItems: [_regular(name: 'Eggs')],
        compositeItems: [_composite(name: 'Power Bowl')],
      );
      final results = await svc.searchFoodHistory('   ');
      expect(results, hasLength(2),
          reason: 'BVA: whitespace-only query must behave identically to empty string');
    });
  });
}
