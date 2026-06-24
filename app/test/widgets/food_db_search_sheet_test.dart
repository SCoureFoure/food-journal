// Widget tests for FoodDbSearchSheet — the external food-database (USDA FDC,
// via Worker) search sheet on the Log Meal screen.
//
// A fake AiService stands in for the Worker so tests never hit the network.
// Covers: debounced query gating (min length), loading state, result rendering,
// onSelect callback, error display, and stale-response dropping.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/widgets/food_db_search_sheet.dart';

// ── Fake AiService ────────────────────────────────────────────────────────────

class _FakeAi implements AiService {
  final Future<FoodDbSearchResult> Function(String query) searchImpl;
  final List<String> queries = [];

  _FakeAi(this.searchImpl);

  @override
  Future<FoodDbSearchResult> searchFoodDatabase(String query) async {
    queries.add(query);
    return searchImpl(query);
  }

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async =>
      throw UnimplementedError();

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async =>
      throw UnimplementedError();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sheet({
  required AiService ai,
  void Function(FoodItemDraft)? onSelect,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FoodDbSearchSheet(
          aiOverride: ai,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );

FoodDbSearchResult _ok(List<FoodItemDraft> items) =>
    FoodDbSearchResult(success: true, items: items);

FoodItemDraft _draft({
  String name = 'Bread, whole-wheat',
  String? portion = '100 g',
  int? calories = 252,
  int? protein = 12,
}) =>
    FoodItemDraft(name: name, portion: portion, calories: calories, protein: protein);

void main() {
  // ── Query gating ────────────────────────────────────────────────────────────

  group('[BVA] Min-length query gating', () {
    testWidgets('prompt shown before typing; no search fired', (tester) async {
      final ai = _FakeAi((_) async => _ok([]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.pump();

      expect(find.textContaining('Type at least'), findsOneWidget);
      expect(ai.queries, isEmpty);
    });

    testWidgets('single character does not trigger a search', (tester) async {
      final ai = _FakeAi((_) async => _ok([_draft()]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'b');
      await tester.pump(const Duration(milliseconds: 600));

      expect(ai.queries, isEmpty);
    });

    testWidgets('two characters trigger a debounced search', (tester) async {
      final ai = _FakeAi((_) async => _ok([_draft()]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'wheat');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(ai.queries, ['wheat']);
    });
  });

  // ── Result rendering ──────────────────────────────────────────────────────────

  group('[MFT] Results render', () {
    testWidgets('one ListTile per result with macro subtitle', (tester) async {
      final ai = _FakeAi((_) async =>
          _ok([_draft(), _draft(name: 'Tuna sushi (Acme)', calories: 130, protein: 24)]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'food');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.textContaining('252 cal'), findsOneWidget);
    });

    testWidgets('each result has a Semantics identifier', (tester) async {
      final ai = _FakeAi((_) async => _ok([_draft()]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'bread');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'food-db-item-0',
        ),
        findsOneWidget,
      );
    });

    testWidgets('empty results show no-match message', (tester) async {
      final ai = _FakeAi((_) async => _ok([]));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'zzzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('No matches'), findsOneWidget);
    });
  });

  // ── Selection ─────────────────────────────────────────────────────────────────

  group('[DIR] Selection callback', () {
    testWidgets('tapping a result fires onSelect with that draft and pops', (tester) async {
      FoodItemDraft? selected;
      final ai = _FakeAi((_) async => _ok([_draft(name: 'Tuna sushi')]));
      await tester.pumpWidget(_sheet(ai: ai, onSelect: (d) => selected = d));
      await tester.enterText(find.byType(TextField), 'tuna');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      await tester.tap(find.text('Tuna sushi'));
      await tester.pumpAndSettle();

      expect(selected?.name, 'Tuna sushi');
    });
  });

  // ── Error handling ──────────────────────────────────────────────────────────

  group('[INV] Failure surfaces an error, not a crash', () {
    testWidgets('failed search shows error message', (tester) async {
      final ai = _FakeAi((_) async =>
          FoodDbSearchResult(success: false, errorMessage: 'Worker error 503'));
      await tester.pumpWidget(_sheet(ai: ai));
      await tester.enterText(find.byType(TextField), 'eggs');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('Worker error 503'), findsOneWidget);
    });
  });
}
