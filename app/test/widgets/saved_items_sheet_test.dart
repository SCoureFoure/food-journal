import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/saved_items_sheet.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────

class _FakeStorage extends StorageService {
  List<FoodItemDraft> _items;
  final List<int> deleteCalls = [];

  _FakeStorage({List<FoodItemDraft> items = const []}) : _items = List.of(items);

  @override
  Future<List<FoodItemDraft>> searchSavedItems(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.of(_items);
    return _items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  @override
  Future<void> deleteSavedItem(int id) async {
    deleteCalls.add(id);
    _items = _items.where((i) => i.savedItemId != id).toList();
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

FoodItemDraft _savedItem({
  String name = 'Breakfast Bowl',
  int savedItemId = 1,
  int? calories = 450,
  int? protein = 22,
  List<String> ingredients = const ['Oats', 'Banana'],
}) =>
    FoodItemDraft(
      name: name,
      calories: calories,
      protein: protein,
      isComposite: true,
      savedItemId: savedItemId,
      ingredients: ingredients,
    );

Widget _sheet({
  required StorageService storage,
  void Function(FoodItemDraft)? onSelect,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SavedItemsSheet(
          storageOverride: storage,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Empty state ───────────────────────────────────────────────────────────

  group('[MFT] SavedItemsSheet — empty state', () {
    testWidgets('shows "No saved items yet" when list is empty', (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.textContaining('No saved items yet'),
        findsOneWidget,
        reason: 'Empty list must show the correct empty-state message',
      );
    });

    testWidgets('shows search field on open', (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ── Results list ──────────────────────────────────────────────────────────

  group('[MFT] SavedItemsSheet — results list', () {
    testWidgets('renders one ListTile per item', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Power Bowl', savedItemId: 1),
        _savedItem(name: 'Snack Plate', savedItemId: 2),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.text('Power Bowl'), findsOneWidget);
      expect(find.text('Snack Plate'), findsOneWidget);
    });

    testWidgets('subtitle shows calories and protein when present', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Bowl', calories: 350, protein: 18),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.textContaining('350 cal'), findsOneWidget);
      expect(find.textContaining('18g protein'), findsOneWidget);
    });

    testWidgets('ingredient components shown in subtitle', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Bowl', ingredients: ['Oats', 'Almond milk', 'Berries']),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.textContaining('Oats'), findsOneWidget);
    });

    testWidgets('each item has a Semantics identifier', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'A', savedItemId: 1),
        _savedItem(name: 'B', savedItemId: 2),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.identifier ?? '').startsWith('saved-item-'),
        ),
        findsNWidgets(2),
        reason: 'Each saved item row must have a Semantics identifier',
      );
    });

    testWidgets('each item has a delete button with Semantics identifier', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Bowl', savedItemId: 3),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.identifier == 'btn-delete-saved-item-0',
        ),
        findsOneWidget,
        reason: 'Delete button must carry Semantics identifier "btn-delete-saved-item-<index>"',
      );
    });
  });

  // ── Search filtering ──────────────────────────────────────────────────────

  group('[MFT] SavedItemsSheet — search filtering', () {
    testWidgets('typing a query filters results', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Power Bowl', savedItemId: 1),
        _savedItem(name: 'Snack Plate', savedItemId: 2),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Power');
      await tester.pump();
      await tester.pump();

      expect(find.text('Power Bowl'), findsOneWidget);
      expect(find.text('Snack Plate'), findsNothing);
    });

    testWidgets('no-match message shows quoted query', (tester) async {
      final storage = _FakeStorage(items: [
        _savedItem(name: 'Power Bowl', savedItemId: 1),
      ]);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('"zzz"'), findsOneWidget);
    });
  });

  // ── Selection callback ────────────────────────────────────────────────────

  group('[MFT] SavedItemsSheet — item selection', () {
    testWidgets('tapping an item fires onSelect with correct draft', (tester) async {
      FoodItemDraft? selected;
      final target = _savedItem(name: 'Power Bowl', savedItemId: 42, calories: 450);
      final storage = _FakeStorage(items: [target]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SavedItemsSheet(
              storageOverride: storage,
              onSelect: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Power Bowl'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Power Bowl');
      expect(selected!.isComposite, isTrue,
          reason: 'Selected draft must preserve isComposite=true');
      expect(selected!.savedItemId, 42,
          reason: 'Selected draft must preserve the savedItemId');
      expect(selected!.calories, 450);
    });
  });

  // ── Semantics anchors ─────────────────────────────────────────────────────

  group('[INV] SavedItemsSheet — Semantics anchors', () {
    testWidgets('search field has Semantics identifier saved-items-search-field',
        (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(TextField));
      expect(semantics.identifier, 'saved-items-search-field');
    });
  });
}
