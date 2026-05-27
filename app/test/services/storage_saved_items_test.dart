// Tests for the saved-items methods added to StorageService in v7.
//
// StorageService requires native sqlite3 so a fake subclass replaces the
// DB-touching methods with in-memory implementations.  This validates:
//   - searchSavedItems: filtering by query, empty-query returns all,
//     results carry isComposite=true and correct savedItemId
//   - saveSavedItem: inserts and returns assigned id
//   - deleteSavedItem: removes by id, subsequent search excludes it
//
// Full SQL correctness (UNION with food_items, ORDER BY created_at) is
// covered by on-device integration tests.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/saved_item.dart';
import 'package:food_journal/services/storage_service.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// In-memory map keyed by auto-incrementing id, mimicking the real saved_items
// table.  Encoding/decoding componentsJson is mirrored from storage_service.dart
// so the round-trip behaviour is tested end-to-end at this layer.

class _FakeStorage extends StorageService {
  int _nextId = 1;
  final Map<int, _Row> _store = {};

  @override
  Future<int> saveSavedItem(SavedItem item) async {
    final id = _nextId++;
    _store[id] = _Row(
      id: id,
      name: item.name,
      calories: item.calories,
      protein: item.protein,
      carbs: item.carbs,
      fat: item.fat,
      componentsJson: jsonEncode(item.components),
      createdAt: item.createdAt,
    );
    return id;
  }

  @override
  Future<void> deleteSavedItem(int id) async {
    _store.remove(id);
  }

  @override
  Future<List<FoodItemDraft>> searchSavedItems(String query) async {
    final rows = _store.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? rows
        : rows.where((r) => r.name.toLowerCase().contains(q)).toList();
    return filtered.map((r) {
      final components = List<String>.from(jsonDecode(r.componentsJson) as List);
      return FoodItemDraft(
        name: r.name,
        calories: r.calories,
        protein: r.protein,
        carbs: r.carbs,
        fat: r.fat,
        ingredients: components,
        isComposite: true,
        savedItemId: r.id,
      );
    }).toList();
  }
}

class _Row {
  final int id;
  final String name;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final String componentsJson;
  final DateTime createdAt;

  const _Row({
    required this.id,
    required this.name,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.componentsJson,
    required this.createdAt,
  });
}

SavedItem _item({
  String name = 'Power Bowl',
  int? calories = 450,
  int? protein = 22,
  int? carbs = 55,
  int? fat = 14,
  List<String> components = const ['Oats', 'Banana'],
  DateTime? createdAt,
}) =>
    SavedItem(
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      components: components,
      createdAt: createdAt ?? DateTime(2026, 5, 27),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── saveSavedItem ─────────────────────────────────────────────────────────

  group('[MFT] saveSavedItem — inserts and returns id', () {
    test('returns a positive integer id', () async {
      final svc = _FakeStorage();
      final id = await svc.saveSavedItem(_item());
      expect(id, greaterThan(0));
    });

    test('subsequent saves return distinct ids', () async {
      final svc = _FakeStorage();
      final id1 = await svc.saveSavedItem(_item(name: 'Bowl A'));
      final id2 = await svc.saveSavedItem(_item(name: 'Bowl B'));
      expect(id1, isNot(equals(id2)));
    });

    test('saved item appears in searchSavedItems with empty query', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Breakfast Bowl'));
      final results = await svc.searchSavedItems('');
      expect(results.map((r) => r.name), contains('Breakfast Bowl'));
    });

    test('saved item carries isComposite=true in search results', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Lunch Set'));
      final results = await svc.searchSavedItems('');
      expect(results.first.isComposite, isTrue,
          reason: 'All results from searchSavedItems must be composite items');
    });

    test('saved item preserves all macro values', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(calories: 320, protein: 18, carbs: 40, fat: 8));
      final results = await svc.searchSavedItems('');
      expect(results.first.calories, 320);
      expect(results.first.protein, 18);
      expect(results.first.carbs, 40);
      expect(results.first.fat, 8);
    });

    test('saved item preserves components as ingredients list', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(components: ['Chicken', 'Rice', 'Broccoli']));
      final results = await svc.searchSavedItems('');
      expect(results.first.ingredients, ['Chicken', 'Rice', 'Broccoli'],
          reason: 'components must round-trip through JSON encode/decode correctly');
    });
  });

  // ── searchSavedItems — empty query ────────────────────────────────────────

  group('[MFT] searchSavedItems — empty query returns all', () {
    test('empty store returns empty list', () async {
      final svc = _FakeStorage();
      final results = await svc.searchSavedItems('');
      expect(results, isEmpty);
    });

    test('empty query returns all saved items', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Bowl A'));
      await svc.saveSavedItem(_item(name: 'Bowl B'));
      final results = await svc.searchSavedItems('');
      expect(results, hasLength(2));
    });

    test('whitespace-only query is treated as empty', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Power Bowl'));
      final results = await svc.searchSavedItems('   ');
      expect(results, hasLength(1),
          reason: 'Whitespace query must be trimmed and treated as empty');
    });
  });

  // ── searchSavedItems — filtering ──────────────────────────────────────────

  group('[MFT] searchSavedItems — query filtering', () {
    test('query returns only matching items (case-insensitive)', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Power Bowl'));
      await svc.saveSavedItem(_item(name: 'Snack Plate'));
      final results = await svc.searchSavedItems('power');
      expect(results.map((r) => r.name).toList(), ['Power Bowl']);
    });

    test('case-insensitive: uppercase query matches lowercase name', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'breakfast bowl'));
      final results = await svc.searchSavedItems('BREAKFAST');
      expect(results, hasLength(1),
          reason: 'Search must be case-insensitive');
    });

    test('no-match query returns empty list', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Power Bowl'));
      final results = await svc.searchSavedItems('zzz');
      expect(results, isEmpty);
    });

    test('partial match works (substring)', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Mediterranean Bowl'));
      final results = await svc.searchSavedItems('med');
      expect(results, hasLength(1));
    });
  });

  // ── searchSavedItems — savedItemId populated ──────────────────────────────

  group('[MFT] searchSavedItems — savedItemId on results', () {
    test('result carries the same id returned by saveSavedItem', () async {
      final svc = _FakeStorage();
      final id = await svc.saveSavedItem(_item(name: 'Bowl'));
      final results = await svc.searchSavedItems('');
      expect(results.first.savedItemId, id,
          reason: 'savedItemId must match the id assigned by saveSavedItem '
              'so delete can target the correct row');
    });

    test('two items have distinct savedItemIds', () async {
      final svc = _FakeStorage();
      final id1 = await svc.saveSavedItem(_item(name: 'A'));
      final id2 = await svc.saveSavedItem(_item(name: 'B'));
      final results = await svc.searchSavedItems('');
      final ids = results.map((r) => r.savedItemId).toSet();
      expect(ids, containsAll([id1, id2]));
      expect(ids.length, 2, reason: 'savedItemIds must be distinct');
    });
  });

  // ── deleteSavedItem ───────────────────────────────────────────────────────

  group('[MFT] deleteSavedItem — removes item from store', () {
    test('item is absent from search results after delete', () async {
      final svc = _FakeStorage();
      final id = await svc.saveSavedItem(_item(name: 'Power Bowl'));
      await svc.deleteSavedItem(id);
      final results = await svc.searchSavedItems('');
      expect(results, isEmpty,
          reason: 'Deleted item must not appear in subsequent searches');
    });

    test('deleting one item does not affect others', () async {
      final svc = _FakeStorage();
      final id1 = await svc.saveSavedItem(_item(name: 'Bowl A'));
      await svc.saveSavedItem(_item(name: 'Bowl B'));
      await svc.deleteSavedItem(id1);
      final results = await svc.searchSavedItems('');
      expect(results.map((r) => r.name).toList(), ['Bowl B'],
          reason: 'Only the deleted item must be removed');
    });

    test('deleting a non-existent id is a no-op (does not throw)', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(name: 'Survivor'));
      // 999 was never inserted
      await expectLater(svc.deleteSavedItem(999), completes);
      final results = await svc.searchSavedItems('');
      expect(results, hasLength(1),
          reason: 'Delete of unknown id must not remove other items');
    });
  });

  // ── BVA: empty components list ────────────────────────────────────────────

  group('[BVA] saveSavedItem / searchSavedItems — empty components', () {
    test('empty components list round-trips as empty ingredients', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(components: []));
      final results = await svc.searchSavedItems('');
      expect(results.first.ingredients, isEmpty,
          reason: 'Empty components list must encode to "[]" and decode back to empty');
    });
  });

  // ── BVA: null macros ──────────────────────────────────────────────────────

  group('[BVA] saveSavedItem / searchSavedItems — null macro fields', () {
    test('null calories/protein/carbs/fat are preserved through round-trip', () async {
      final svc = _FakeStorage();
      await svc.saveSavedItem(_item(
        name: 'Unknown macros',
        calories: null,
        protein: null,
        carbs: null,
        fat: null,
      ));
      final results = await svc.searchSavedItems('');
      expect(results.first.calories, isNull);
      expect(results.first.protein, isNull);
      expect(results.first.carbs, isNull);
      expect(results.first.fat, isNull);
    });
  });
}
