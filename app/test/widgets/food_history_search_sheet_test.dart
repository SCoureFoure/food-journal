import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/food_history_search_sheet.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// searchImpl receives (query, favoritesOnly) so tests can assert on both.
// Overrides only the methods called by FoodHistorySearchSheet so tests never
// touch SQLite.

class _FakeStorage extends StorageService {
  final List<FoodItemDraft> Function(String, bool) searchImpl;
  final List<String> toggleCalls = [];

  _FakeStorage({required this.searchImpl});

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(
    String query, {
    bool favoritesOnly = false,
  }) async =>
      searchImpl(query, favoritesOnly);

  @override
  Future<void> toggleFoodFavorite(String foodName) async =>
      toggleCalls.add(foodName);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Finds the FilterChip wrapped in a Semantics node with the given identifier.
/// Tapping this finder hits the chip's gesture area rather than its inner Text,
/// avoiding the "offset would not hit test" warning from tapping text children.
Finder _findChipByIdentifier(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Widget _sheet({
  required StorageService storage,
  void Function(FoodItemDraft)? onSelect,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FoodHistorySearchSheet(
          storageOverride: storage,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );

FoodItemDraft _draft({
  String name = 'Chicken breast',
  String? portion = '150g',
  int? calories = 165,
  int? protein = 31,
  bool favorited = false,
}) =>
    FoodItemDraft(
      name: name,
      portion: portion,
      calories: calories,
      protein: protein,
      favorited: favorited,
    );

void main() {
  // ── Empty history ─────────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — empty state', () {
    testWidgets('shows "No meal history yet." when DB is empty', (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump(); // allow initState _load() to complete
      expect(find.text('No meal history yet.'), findsOneWidget);
    });

    testWidgets('shows search field on open', (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ── Results list ──────────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — results list', () {
    testWidgets('renders one ListTile per result', (tester) async {
      final items = [_draft(name: 'Oats'), _draft(name: 'Eggs')];
      final storage = _FakeStorage(searchImpl: (_, __) => items);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('subtitle shows portion and calories when present', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Rice', portion: '200g', calories: 260)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.textContaining('200g'), findsOneWidget);
      expect(find.textContaining('260 cal'), findsOneWidget);
    });

    testWidgets('subtitle shows protein when present', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Steak', protein: 42)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.textContaining('42g protein'), findsOneWidget);
    });

    testWidgets('no subtitle when all optional macro fields are null', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [
          const FoodItemDraft(name: 'Mystery food'),
        ],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.text('Mystery food'), findsOneWidget);
      // Should not find any macro text
      expect(find.textContaining(' cal'), findsNothing);
      expect(find.textContaining('g protein'), findsNothing);
    });
  });

  // ── Selection callback ────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — item selection', () {
    testWidgets('tapping an item fires onSelect with correct draft', (tester) async {
      FoodItemDraft? selected;
      final target = _draft(name: 'Salmon', calories: 208, protein: 28);
      final storage = _FakeStorage(searchImpl: (_, __) => [target]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodHistorySearchSheet(
              storageOverride: storage,
              onSelect: (d) => selected = d,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Salmon'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Salmon');
      expect(selected!.calories, 208);
      expect(selected!.protein, 28);
    });
  });

  // ── Search filtering (no-results path) ───────────────────────────────────

  group('[Scenario] FoodHistorySearchSheet — no-match message', () {
    testWidgets('shows quoted query in no-results message after typing', (tester) async {
      // First call (empty query) returns nothing; subsequent call with query also returns nothing.
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Type a search term that matches nothing
      await tester.enterText(find.byType(TextField), 'zzz');
      // Advance past the 300ms debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(); // allow async _load to complete

      expect(find.textContaining('"zzz"'), findsOneWidget);
    });
  });

  // ── Search fires searchFoodHistory ────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — search wires to storage', () {
    testWidgets('initial load calls searchFoodHistory with empty string', (tester) async {
      final queries = <String>[];
      final storage = _FakeStorage(
        searchImpl: (q, __) {
          queries.add(q);
          return [];
        },
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(queries, contains(''));
    });

    testWidgets('typing a query calls searchFoodHistory with that text after debounce',
        (tester) async {
      final queries = <String>[];
      final storage = _FakeStorage(
        searchImpl: (q, __) {
          queries.add(q);
          return [];
        },
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'egg');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(queries, contains('egg'));
    });
  });

  // ── Semantics anchors ─────────────────────────────────────────────────────

  group('[INV] FoodHistorySearchSheet — Semantics anchors', () {
    testWidgets('search field has Semantics identifier', (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(TextField));
      expect(semantics.identifier, 'food-history-search-field');
    });

    testWidgets('each result item has a Semantics identifier', (tester) async {
      final items = [_draft(name: 'A'), _draft(name: 'B')];
      final storage = _FakeStorage(searchImpl: (_, __) => items);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Find Semantics nodes with identifiers matching the pattern
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.identifier ?? '').startsWith('history-item-'),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('filter chip All has Semantics identifier btn-history-filter-all', (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-history-filter-all',
        ),
        findsOneWidget,
      );
    });

    testWidgets('filter chip Favorites has Semantics identifier btn-history-filter-favorites',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-history-filter-favorites',
        ),
        findsOneWidget,
      );
    });

    testWidgets('star button has Semantics identifier btn-favorite-<name>', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Oats')],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-favorite-Oats',
        ),
        findsOneWidget,
      );
    });
  });

  // ── Empty portion string ──────────────────────────────────────────────────

  group('[BVA] FoodHistorySearchSheet — empty portion string', () {
    testWidgets('empty portion string is not shown in subtitle', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [
          const FoodItemDraft(name: 'Plain rice', portion: '', calories: 200),
        ],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      // calories should show but the empty portion should be suppressed
      expect(find.textContaining('200 cal'), findsOneWidget);
      expect(find.textContaining(' · '), findsNothing); // separator only when two parts
    });
  });

  // ── Filter chips ──────────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — filter chips', () {
    testWidgets('All chip is selected and Favorites chip is unselected on open',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // All chip: selected=true means !_favoritesOnly
      final allChips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      final allChip = allChips.firstWhere((c) => (c.label as Text).data == 'All');
      final favChip = allChips.firstWhere((c) => (c.label as Text).data == 'Favorites');

      expect(allChip.selected, isTrue);
      expect(favChip.selected, isFalse);
    });

    testWidgets('tapping Favorites chip sets _favoritesOnly=true and passes it to storage',
        (tester) async {
      final capturedFlags = <bool>[];
      final storage = _FakeStorage(
        searchImpl: (_, favOnly) {
          capturedFlags.add(favOnly);
          return [];
        },
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump(); // initial load

      await tester.tap(_findChipByIdentifier('btn-history-filter-favorites'));
      await tester.pump(); // trigger setState + _load
      await tester.pump(); // async _load completes

      // At least one call after the tap must have favoritesOnly=true
      expect(capturedFlags, contains(true));
    });

    testWidgets('tapping All chip after Favorites resets _favoritesOnly=false', (tester) async {
      final capturedFlags = <bool>[];
      final storage = _FakeStorage(
        searchImpl: (_, favOnly) {
          capturedFlags.add(favOnly);
          return [];
        },
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Switch to Favorites then back to All
      await tester.tap(_findChipByIdentifier('btn-history-filter-favorites'));
      await tester.pump();
      await tester.pump();

      await tester.tap(_findChipByIdentifier('btn-history-filter-all'));
      await tester.pump();
      await tester.pump();

      // Last recorded flag should be false
      expect(capturedFlags.last, isFalse);
    });

    testWidgets('Favorites chip becomes selected after tap', (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_findChipByIdentifier('btn-history-filter-favorites'));
      await tester.pump();
      await tester.pump();

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
      final favChip = chips.firstWhere((c) => (c.label as Text).data == 'Favorites');
      expect(favChip.selected, isTrue);
    });
  });

  // ── Star icon reflects favorited state ───────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — star icon state', () {
    testWidgets('star icon is filled (Icons.star) when item is favorited', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Oats', favorited: true)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Find an Icon widget with Icons.star (filled)
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.star && w.size == 20,
        ),
        findsOneWidget,
      );
    });

    testWidgets('star icon is outline (Icons.star_border) when item is not favorited',
        (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Oats', favorited: false)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.star_border && w.size == 20,
        ),
        findsOneWidget,
      );
    });

    testWidgets('mixed list shows correct filled/outline icons per item', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [
          _draft(name: 'Apple', favorited: true),
          _draft(name: 'Broccoli', favorited: false),
        ],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star && w.size == 20),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.star_border && w.size == 20),
        findsOneWidget,
      );
    });
  });

  // ── Star tap calls toggleFoodFavorite ─────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — star tap wires to storage', () {
    testWidgets('tapping star calls toggleFoodFavorite with correct food name',
        (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_, __) => [_draft(name: 'Eggs', favorited: false)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Tap the star icon button
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-favorite-Eggs',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(storage.toggleCalls, contains('Eggs'));
    });

    testWidgets('tapping star triggers a reload of results', (tester) async {
      var callCount = 0;
      final storage = _FakeStorage(
        searchImpl: (_, __) {
          callCount++;
          return [_draft(name: 'Toast', favorited: false)];
        },
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump(); // initial load → callCount == 1

      final countBeforeTap = callCount;

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'btn-favorite-Toast',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(callCount, greaterThan(countBeforeTap),
          reason: 'A reload must fire after toggleFoodFavorite so the star icon updates');
    });
  });

  // ── Empty state messages ──────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — empty message variants', () {
    testWidgets(
        'favoritesOnly=false, empty query → "No meal history yet."',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.text('No meal history yet.'), findsOneWidget);
    });

    testWidgets(
        'favoritesOnly=false, non-empty query → "No items match ..."',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.textContaining('No items match'), findsOneWidget);
      expect(find.textContaining('"xyz"'), findsOneWidget);
    });

    testWidgets(
        'favoritesOnly=true, empty query → "No favorites yet — tap the star on any item."',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_findChipByIdentifier('btn-history-filter-favorites'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('No favorites yet — tap the star on any item.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'favoritesOnly=true, non-empty query → "No favorites match ..."',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_, __) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_findChipByIdentifier('btn-history-filter-favorites'));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'cake');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.textContaining('No favorites match'), findsOneWidget);
      expect(find.textContaining('"cake"'), findsOneWidget);
    });
  });
}
