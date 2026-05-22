import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/food_history_search_sheet.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// Overrides only the methods called by FoodHistorySearchSheet so tests never
// touch SQLite.  All other StorageService methods remain unreachable.

class _FakeStorage extends StorageService {
  final List<FoodItemDraft> Function(String) searchImpl;
  final List<String> toggleCalls = [];

  _FakeStorage({required this.searchImpl});

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(String query) async =>
      searchImpl(query);

  @override
  Future<void> toggleFoodFavorite(String foodName) async =>
      toggleCalls.add(foodName);
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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
}) =>
    FoodItemDraft(
      name: name,
      portion: portion,
      calories: calories,
      protein: protein,
    );

void main() {
  // ── Empty history ─────────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — empty state', () {
    testWidgets('shows "No meal history yet." when DB is empty', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump(); // allow initState _load() to complete
      expect(find.text('No meal history yet.'), findsOneWidget);
    });

    testWidgets('shows search field on open', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  // ── Results list ──────────────────────────────────────────────────────────

  group('[MFT] FoodHistorySearchSheet — results list', () {
    testWidgets('renders one ListTile per result', (tester) async {
      final items = [_draft(name: 'Oats'), _draft(name: 'Eggs')];
      final storage = _FakeStorage(searchImpl: (_) => items);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.text('Oats'), findsOneWidget);
      expect(find.text('Eggs'), findsOneWidget);
    });

    testWidgets('subtitle shows portion and calories when present', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_) => [_draft(name: 'Rice', portion: '200g', calories: 260)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.textContaining('200g'), findsOneWidget);
      expect(find.textContaining('260 cal'), findsOneWidget);
    });

    testWidgets('subtitle shows protein when present', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_) => [_draft(name: 'Steak', protein: 42)],
      );
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();
      expect(find.textContaining('42g protein'), findsOneWidget);
    });

    testWidgets('no subtitle when all optional macro fields are null', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_) => [
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
      final storage = _FakeStorage(searchImpl: (_) => [target]);

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
      final storage = _FakeStorage(searchImpl: (_) => []);
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
        searchImpl: (q) {
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
        searchImpl: (q) {
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
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      final semantics = tester.getSemantics(find.byType(TextField));
      expect(semantics.identifier, 'food-history-search-field');
    });

    testWidgets('each result item has a Semantics identifier', (tester) async {
      final items = [_draft(name: 'A'), _draft(name: 'B')];
      final storage = _FakeStorage(searchImpl: (_) => items);
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
  });

  // ── Empty portion string ──────────────────────────────────────────────────

  group('[BVA] FoodHistorySearchSheet — empty portion string', () {
    testWidgets('empty portion string is not shown in subtitle', (tester) async {
      final storage = _FakeStorage(
        searchImpl: (_) => [
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
}
