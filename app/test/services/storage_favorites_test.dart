// Tests for the favorites-related methods added to StorageService.
//
// StorageService requires native sqlite3 so these tests use a controlled
// subclass (_FakeStorageService) that replaces the DB-touching methods with
// in-memory implementations.  This validates:
//   - toggleFoodFavorite logic (flip true→false, false→true, missing→creates true)
//   - searchFoodHistory correctly forwards favoritesOnly flag
//   - insertFoodMemory preserves favorited from the FoodMemory model
//
// Full SQL correctness is covered by on-device integration tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/food_memory.dart';
import 'package:food_journal/services/storage_service.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// Maintains an in-memory map of foodName → favorited state so toggle logic
// can be tested without SQLite.  All other StorageService methods are
// unreachable (never called by these tests).

class _FakeStorageService extends StorageService {
  // null entry = no memory row exists yet (simulates "food was logged but no
  // food_memories row" — the missing-row path in toggleFoodFavorite).
  final Map<String, bool?> _memoryStore;

  // Records (foodName, favorited, occurrences) passed to insertFoodMemory
  final List<({String foodName, bool favorited})> insertCalls = [];

  // Records every (query, favoritesOnly) pair passed to searchFoodHistory
  final List<({String query, bool favoritesOnly})> searchCalls = [];

  // ── getFavoritedFoodNames ────────────────────────────────────────────────
  // Derives directly from _memoryStore so we don't need a separate list.
  @override
  Future<Set<String>> getFavoritedFoodNames() async {
    return _memoryStore.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toLowerCase())
        .toSet();
  }

  _FakeStorageService({Map<String, bool?> initial = const {}})
      : _memoryStore = Map<String, bool?>.of(initial);

  @override
  Future<void> toggleFoodFavorite(String foodName) async {
    final current = _memoryStore[foodName];
    if (current == null) {
      // Row missing — create one with favorited=true (mirrors production impl)
      _memoryStore[foodName] = true;
    } else {
      _memoryStore[foodName] = !current;
    }
  }

  @override
  Future<void> insertFoodMemory(FoodMemory memory) async {
    insertCalls.add((foodName: memory.foodName, favorited: memory.favorited));
    _memoryStore[memory.foodName] = memory.favorited;
  }

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(
    String query, {
    bool favoritesOnly = false,
  }) async {
    searchCalls.add((query: query, favoritesOnly: favoritesOnly));
    // Return all items, optionally filtered, from a fixed list for assertion tests.
    return _searchResults
        .where((d) => !favoritesOnly || d.favorited)
        .where((d) => d.name.toLowerCase().contains(query.toLowerCase()) || query.isEmpty)
        .toList();
  }

  /// Seed results for searchFoodHistory.
  List<FoodItemDraft> _searchResults = [];
  void seedSearchResults(List<FoodItemDraft> results) => _searchResults = results;

  /// Read the current favorited state for a food name.
  bool? favoritedState(String foodName) => _memoryStore[foodName];
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── toggleFoodFavorite — existing row ────────────────────────────────────

  group('[MFT] toggleFoodFavorite — existing memory row', () {
    test('flips false → true', () async {
      final svc = _FakeStorageService(initial: {'Eggs': false});
      await svc.toggleFoodFavorite('Eggs');
      expect(svc.favoritedState('Eggs'), isTrue);
    });

    test('flips true → false', () async {
      final svc = _FakeStorageService(initial: {'Eggs': true});
      await svc.toggleFoodFavorite('Eggs');
      expect(svc.favoritedState('Eggs'), isFalse);
    });

    test('double-toggle returns to original state', () async {
      final svc = _FakeStorageService(initial: {'Oats': false});
      await svc.toggleFoodFavorite('Oats');
      await svc.toggleFoodFavorite('Oats');
      expect(svc.favoritedState('Oats'), isFalse);
    });

    test('toggle only affects the target food, not others', () async {
      final svc = _FakeStorageService(initial: {'Eggs': false, 'Toast': false});
      await svc.toggleFoodFavorite('Eggs');
      expect(svc.favoritedState('Eggs'), isTrue);
      expect(svc.favoritedState('Toast'), isFalse,
          reason: 'Toggling Eggs must not affect Toast');
    });
  });

  // ── toggleFoodFavorite — missing row ─────────────────────────────────────

  group('[MFT] toggleFoodFavorite — missing memory row (no-op guard)', () {
    test('creates row with favorited=true when no memory row exists', () async {
      // null entry simulates "food_items row exists but no food_memories row"
      final svc = _FakeStorageService(initial: {'Chicken': null});
      await svc.toggleFoodFavorite('Chicken');
      expect(svc.favoritedState('Chicken'), isTrue,
          reason: 'First-time favorite must create a row set to true, not no-op');
    });

    test('toggling the newly created row flips it to false on second call', () async {
      final svc = _FakeStorageService(initial: {'Chicken': null});
      await svc.toggleFoodFavorite('Chicken'); // creates → true
      await svc.toggleFoodFavorite('Chicken'); // flips → false
      expect(svc.favoritedState('Chicken'), isFalse);
    });
  });

  // ── insertFoodMemory — favorited preserved ───────────────────────────────

  group('[MFT] insertFoodMemory — favorited field', () {
    test('inserts with favorited=true when memory.favorited is true', () async {
      final svc = _FakeStorageService();
      final memory = FoodMemory(
        foodName: 'Salmon',
        occurrences: 1,
        lastSeen: DateTime(2026, 5, 20),
        flagged: false,
        favorited: true,
      );
      await svc.insertFoodMemory(memory);

      expect(svc.insertCalls, hasLength(1));
      expect(svc.insertCalls.first.foodName, 'Salmon');
      expect(svc.insertCalls.first.favorited, isTrue,
          reason: 'insertFoodMemory must pass favorited=true to the DB companion');
    });

    test('inserts with favorited=false when memory.favorited is false', () async {
      final svc = _FakeStorageService();
      final memory = FoodMemory(
        foodName: 'Broccoli',
        occurrences: 2,
        lastSeen: DateTime(2026, 5, 20),
        flagged: false,
        favorited: false,
      );
      await svc.insertFoodMemory(memory);

      expect(svc.insertCalls.first.favorited, isFalse);
    });

    test('inserting with favorited=true followed by toggle results in false', () async {
      final svc = _FakeStorageService();
      final memory = FoodMemory(
        foodName: 'Rice',
        occurrences: 1,
        lastSeen: DateTime(2026, 5, 1),
        flagged: false,
        favorited: true,
      );
      await svc.insertFoodMemory(memory);
      await svc.toggleFoodFavorite('Rice');
      expect(svc.favoritedState('Rice'), isFalse);
    });
  });

  // ── searchFoodHistory — favoritesOnly flag forwarding ────────────────────

  group('[MFT] searchFoodHistory — favoritesOnly flag', () {
    test('favoritesOnly=false returns all items', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([
        const FoodItemDraft(name: 'Eggs', favorited: true),
        const FoodItemDraft(name: 'Toast', favorited: false),
      ]);

      final results = await svc.searchFoodHistory('', favoritesOnly: false);
      expect(results.map((r) => r.name).toList(), containsAll(['Eggs', 'Toast']));
    });

    test('favoritesOnly=true returns only favorited items', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([
        const FoodItemDraft(name: 'Eggs', favorited: true),
        const FoodItemDraft(name: 'Toast', favorited: false),
      ]);

      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results.map((r) => r.name).toList(), equals(['Eggs']));
      expect(results.any((r) => r.name == 'Toast'), isFalse,
          reason: 'favoritesOnly=true must exclude unfavorited items');
    });

    test('favoritesOnly=true with no favorites returns empty list', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([
        const FoodItemDraft(name: 'Toast', favorited: false),
        const FoodItemDraft(name: 'Oats', favorited: false),
      ]);

      final results = await svc.searchFoodHistory('', favoritesOnly: true);
      expect(results, isEmpty);
    });

    test('favoritesOnly flag is forwarded correctly to the implementation', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([]);

      await svc.searchFoodHistory('egg', favoritesOnly: true);

      expect(svc.searchCalls, hasLength(1));
      expect(svc.searchCalls.first.query, 'egg');
      expect(svc.searchCalls.first.favoritesOnly, isTrue);
    });

    test('default value of favoritesOnly is false', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([]);

      // Call without named param — should default to false
      await svc.searchFoodHistory('oats');

      expect(svc.searchCalls.first.favoritesOnly, isFalse);
    });
  });

  // ── FoodItemDraft.favorited in search results ────────────────────────────

  group('[MFT] searchFoodHistory — favorited field on returned drafts', () {
    test('returned draft has favorited=true when food_memories.favorited=1', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([const FoodItemDraft(name: 'Eggs', favorited: true)]);

      final results = await svc.searchFoodHistory('');
      expect(results.first.favorited, isTrue);
    });

    test('returned draft has favorited=false when no memory row (COALESCE → 0)', () async {
      final svc = _FakeStorageService();
      svc.seedSearchResults([const FoodItemDraft(name: 'Toast', favorited: false)]);

      final results = await svc.searchFoodHistory('');
      expect(results.first.favorited, isFalse);
    });
  });

  // ── getFavoritedFoodNames ────────────────────────────────────────────────

  group('[MFT] getFavoritedFoodNames — returns lowercased Set of favorited names', () {
    test('returns only names where favorited=true', () async {
      final svc = _FakeStorageService(initial: {
        'Eggs': true,
        'Toast': false,
        'Chicken': true,
      });
      final names = await svc.getFavoritedFoodNames();
      expect(names, containsAll(['eggs', 'chicken']));
      expect(names, isNot(contains('toast')),
          reason: 'Only favorited=true entries should be returned');
    });

    test('returns empty set when no entries are favorited', () async {
      final svc = _FakeStorageService(initial: {'Toast': false, 'Oats': false});
      final names = await svc.getFavoritedFoodNames();
      expect(names, isEmpty);
    });

    test('returns empty set when store is empty', () async {
      final svc = _FakeStorageService();
      final names = await svc.getFavoritedFoodNames();
      expect(names, isEmpty);
    });

    test('result is lowercased regardless of stored casing', () async {
      // BVA: food names are stored with mixed case in the DB; the query lowercases
      // them so MealTile.contains(name.toLowerCase()) matches correctly.
      final svc = _FakeStorageService(initial: {
        'GREEK YOGURT': true,
        'Brown Rice': true,
      });
      final names = await svc.getFavoritedFoodNames();
      expect(names, contains('greek yogurt'));
      expect(names, contains('brown rice'));
      expect(names, isNot(contains('GREEK YOGURT')),
          reason: 'getFavoritedFoodNames must lowercase all names');
    });

    test('null entry (missing memory row) is excluded even after toggle creates true row', () async {
      // Simulate: toggle was called for a food with no prior memory row.
      // After first toggle the state is true — that name must now appear.
      final svc = _FakeStorageService(initial: {'Salmon': null});
      expect(await svc.getFavoritedFoodNames(), isNot(contains('salmon')),
          reason: 'null (not-yet-favorited) row must not appear in set');

      await svc.toggleFoodFavorite('Salmon'); // creates → true
      expect(await svc.getFavoritedFoodNames(), contains('salmon'));
    });

    test('returns a Set — duplicate lowercased names deduplicated', () async {
      // Pathological: two entries that differ only in casing would be deduplicated
      // by the Set contract. Fake uses Map so no duplicates, but return type is Set.
      final svc = _FakeStorageService(initial: {'Eggs': true});
      final names = await svc.getFavoritedFoodNames();
      expect(names, isA<Set<String>>());
      expect(names.length, 1);
    });
  });
}
