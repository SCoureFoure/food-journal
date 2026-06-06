// Tests for CreateSavedItemSheet widget.
//
// Uses a fake StorageService subclass so tests never touch SQLite.
// Does not test EditableFoodItemCard internals — only the sheet's own
// structure, validation, callback, and header-totals logic.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/saved_item.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/meal_memory/meal_memory_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/create_saved_item_sheet.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────

class _FakeStorage extends StorageService {
  final List<FoodItemDraft> Function(String) searchImpl;
  final List<SavedItem> savedItems = [];
  int _nextId = 1;

  _FakeStorage({required this.searchImpl});

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(
    String query, {
    bool favoritesOnly = false,
  }) async =>
      searchImpl(query);

  @override
  Future<int> saveSavedItem(SavedItem item) async {
    savedItems.add(item);
    return _nextId++;
  }
}

// ── Fake AiService ────────────────────────────────────────────────────────────

class _FakeAi implements AiService {
  final MealParseResult Function(String? text) mealImpl;
  int calls = 0;
  String? lastContext;
  _FakeAi(this.mealImpl);

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async {
    calls++;
    lastContext = mealContext;
    return mealImpl(text);
  }

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async =>
      throw UnimplementedError();
}

// Fake memory: pure overrides, no DB. Referential when text contains "leftover".
class _FakeMemory extends MealMemoryService {
  final String snippet;
  _FakeMemory({this.snippet = 'CONTEXT: last night = pizza'});

  @override
  bool isReferential(String input) => input.toLowerCase().contains('leftover');

  @override
  Future<String?> buildContextSnippet(String input) async => snippet;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _sheet({
  required StorageService storage,
  AiService? ai,
  MealMemoryService? memory,
  void Function(FoodItemDraft)? onCreated,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CreateSavedItemSheet(
          storageOverride: storage,
          aiOverride: ai,
          memoryOverride: memory,
          onCreated: onCreated ?? (_) {},
        ),
      ),
    );

Finder _aiField() => find.descendant(
      of: _bySemanticsId('saved-item-ai-field'),
      matching: find.byType(TextField),
    );

Finder _nameField() => find.descendant(
      of: _bySemanticsId('saved-item-name-field'),
      matching: find.byType(TextField),
    );

// Finds the Semantics node with the given identifier and returns it.
Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── Structure ─────────────────────────────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — initial structure', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: On open the sheet renders all required fields and controls.
      // implication: If any required control is absent the user cannot create saved items.
    });

    testWidgets('shows title "Create saved item"', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.text('Create saved item'), findsOneWidget);
    });

    testWidgets('shows subtext description below title', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        find.textContaining('reusable item'),
        findsOneWidget,
        reason: 'Subtext must explain the purpose of the sheet',
      );
    });

    testWidgets('name field has Semantics identifier saved-item-name-field',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        _bySemanticsId('saved-item-name-field'),
        findsOneWidget,
        reason: 'Name field must carry its semantics anchor for the explore rig',
      );
    });

    testWidgets('history search field has Semantics identifier saved-item-search-field',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        _bySemanticsId('saved-item-search-field'),
        findsOneWidget,
      );
    });

    testWidgets('Add item button has Semantics identifier btn-create-item-add-blank',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        _bySemanticsId('btn-create-item-add-blank'),
        findsOneWidget,
      );
    });

    testWidgets('Save item button has Semantics identifier btn-save-saved-item',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(
        _bySemanticsId('btn-save-saved-item'),
        findsOneWidget,
      );
    });
  });

  // ── Add blank component ───────────────────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — Add item button', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: Tapping "Add item" appends a new EditableFoodItemCard to the list.
      // implication: Without this the user cannot build a composite item.
    });

    testWidgets('tapping Add item adds a card to the list', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // No cards initially.
      expect(find.byType(Card), findsNothing);

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      // One card after tap.
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('tapping Add item twice adds two cards', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();
      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      expect(find.byType(Card), findsNWidgets(2));
    });
  });

  // ── Validation errors ─────────────────────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — save validation', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: Tapping Save with missing name or zero components shows a specific
      //           error message and does not call onCreated.
      // implication: Invalid items would be silently saved, corrupting the saved-items list.
    });

    testWidgets('shows "Name is required." when saved with empty name',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      FoodItemDraft? created;
      await tester.pumpWidget(_sheet(storage: storage, onCreated: (d) => created = d));
      await tester.pump();

      // Tap Save without entering a name.
      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pump();

      expect(find.text('Name is required.'), findsOneWidget);
      expect(created, isNull,
          reason: 'onCreated must not fire when name is empty');
    });

    testWidgets('shows "Add at least one item." when saved with no components',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      FoodItemDraft? created;
      await tester.pumpWidget(_sheet(storage: storage, onCreated: (d) => created = d));
      await tester.pump();

      // Enter a name but no components.
      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        'My Bowl',
      );
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pump();

      expect(find.text('Add at least one item.'), findsOneWidget);
      expect(created, isNull);
    });

    testWidgets('name-required error takes priority over no-components error',
        (tester) async {
      // BVA: both conditions are true; the first guard (name) fires first.
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pump();

      // Only the name error is shown.
      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('Add at least one item.'), findsNothing);
    });

    testWidgets('no error shown on initial open', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.text('Name is required.'), findsNothing);
      expect(find.text('Add at least one item.'), findsNothing);
    });
  });

  // ── Successful save ───────────────────────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — successful save calls onCreated', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: When name is non-empty and at least one component exists, Save
      //           calls onCreated with a FoodItemDraft where isComposite=true.
      // implication: Caller cannot add the new composite item to the meal if
      //              onCreated is not fired or the draft has wrong fields.
    });

    testWidgets('calls onCreated with isComposite=true after valid save',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      FoodItemDraft? created;
      await tester.pumpWidget(_sheet(storage: storage, onCreated: (d) => created = d));
      await tester.pump();

      // Enter name.
      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        'Morning Smoothie',
      );
      await tester.pump();

      // Add one blank component.
      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      // Tap Save.
      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pumpAndSettle();

      expect(created, isNotNull,
          reason: 'onCreated must be called after a valid save');
      expect(created!.isComposite, isTrue,
          reason: 'Saved items must always have isComposite=true');
    });

    testWidgets('draft name matches entered name', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      FoodItemDraft? created;
      await tester.pumpWidget(_sheet(storage: storage, onCreated: (d) => created = d));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        'Protein Bowl',
      );
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pumpAndSettle();

      expect(created!.name, 'Protein Bowl');
    });

    testWidgets('saveSavedItem is called on storage during save', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        'Snack Pack',
      );
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pumpAndSettle();

      expect(storage.savedItems, hasLength(1),
          reason: 'saveSavedItem must be called once with the correct item');
      expect(storage.savedItems.first.name, 'Snack Pack');
    });

    testWidgets('savedItemId on draft matches id returned by saveSavedItem',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      FoodItemDraft? created;
      await tester.pumpWidget(_sheet(storage: storage, onCreated: (d) => created = d));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        'Lunch Box',
      );
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pumpAndSettle();

      // _FakeStorage starts nextId at 1.
      expect(created!.savedItemId, 1,
          reason: 'savedItemId must carry the id assigned by saveSavedItem');
    });
  });

  // ── History search → add from draft ──────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — history search', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: Typing in the search field after the 300 ms debounce calls
      //           searchFoodHistory and shows the returned items as tappable rows.
      // implication: Users cannot add past items as components if search is broken.
    });

    testWidgets('typing in search field shows results from searchFoodHistory',
        (tester) async {
      // Use null calories so the ListTile title is just the name (no calStr suffix).
      final items = [
        const FoodItemDraft(name: 'Banana'),
        const FoodItemDraft(name: 'Oats'),
      ];
      final storage = _FakeStorage(searchImpl: (_) => items);

      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Enter text in the search TextField (identified by saved-item-search-field).
      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-search-field'),
          matching: find.byType(TextField),
        ),
        'ba',
      );
      // Advance past debounce.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('Oats'), findsOneWidget);
    });

    testWidgets('empty search query clears results', (tester) async {
      // Use null calories so the ListTile title is just the name.
      final storage = _FakeStorage(
        searchImpl: (q) => q.isEmpty ? [] : [const FoodItemDraft(name: 'Rice')],
      );

      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      // Type something, wait, then clear.
      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-search-field'),
          matching: find.byType(TextField),
        ),
        'ri',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Rice'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-search-field'),
          matching: find.byType(TextField),
        ),
        '',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Rice'), findsNothing,
          reason: 'Clearing the search field must remove the results list');
    });

    testWidgets('tapping a search result adds a component card', (tester) async {
      // Use null calories so the ListTile title is exactly 'Avocado'.
      final storage = _FakeStorage(
        searchImpl: (_) => [const FoodItemDraft(name: 'Avocado')],
      );

      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-search-field'),
          matching: find.byType(TextField),
        ),
        'av',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Tap the result tile.
      await tester.tap(find.text('Avocado'));
      await tester.pump();

      // One card should now be in the list.
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('tapping a search result clears the search field', (tester) async {
      // Use null calories so the ListTile title is exactly 'Mango'.
      final storage = _FakeStorage(
        searchImpl: (_) => [const FoodItemDraft(name: 'Mango')],
      );

      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      final searchField = find.descendant(
        of: _bySemanticsId('saved-item-search-field'),
        matching: find.byType(TextField),
      );

      await tester.enterText(searchField, 'man');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      await tester.tap(find.text('Mango'));
      await tester.pump();

      // Search field should be empty.
      final controller = tester.widget<TextField>(searchField).controller;
      expect(controller?.text ?? '', isEmpty,
          reason: 'Search field must clear after a result is tapped');
    });

    testWidgets('composite result shows bookmark icon in search results',
        (tester) async {
      const compositeResult = FoodItemDraft(
        name: 'Power Bowl',
        isComposite: true,
        savedItemId: 1,
        ingredients: ['Oats', 'Banana'],
      );
      final storage = _FakeStorage(searchImpl: (_) => [compositeResult]);

      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-search-field'),
          matching: find.byType(TextField),
        ),
        'pow',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.bookmark_outline,
        ),
        findsAtLeastNWidgets(1),
        reason: 'Composite search results must show the bookmark icon',
      );
    });
  });

  // ── Live totals in header ─────────────────────────────────────────────────

  group('[MFT] CreateSavedItemSheet — live totals', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: When components are present the header shows cal/macro totals.
      //           When no components are present the totals widget is absent.
      // implication: User cannot see a running macro count while building the item,
      //              removing the primary UX affordance of the sheet.
    });

    testWidgets('totals widget is absent when no components', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.textContaining(' cal'), findsNothing,
          reason: 'Calorie total must not appear when the component list is empty');
    });

    testWidgets('totals widget appears in header after adding a component',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();

      // The header renders "X cal\nYg P · Zg C · Wg F" when components > 0.
      // With a blank card all values are 0 but the widget is still present.
      expect(
        find.textContaining('0 cal'),
        findsOneWidget,
        reason: 'Totals row must appear in the header once at least one component exists',
      );
    });
  });

  // ── BVA: whitespace-only name ─────────────────────────────────────────────

  group('[BVA] CreateSavedItemSheet — whitespace-only name', () {
    testWidgets('whitespace-only name treated as empty (shows name-required error)',
        (tester) async {
      // BVA: name.trim().isEmpty must catch "   " just like "".
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      await tester.enterText(
        find.descendant(
          of: _bySemanticsId('saved-item-name-field'),
          matching: find.byType(TextField),
        ),
        '   ',
      );
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-save-saved-item'));
      await tester.pump();

      expect(find.text('Name is required.'), findsOneWidget,
          reason: 'BVA: whitespace-only name must be rejected the same as empty name');
    });
  });

  // ── FP: valid save clears error ───────────────────────────────────────────

  group('[FP] CreateSavedItemSheet — error is cleared on valid submit', () {
    testWidgets('previous error is not shown after a fresh open', (tester) async {
      // FP: error state should not bleed into the display before any interaction.
      final storage = _FakeStorage(searchImpl: (_) => []);
      await tester.pumpWidget(_sheet(storage: storage));
      await tester.pump();

      expect(find.textContaining('required'), findsNothing);
      expect(find.textContaining('least one'), findsNothing);
    });
  });

  // ── AI parse (spec: create_saved_item_ai_parse) ───────────────────────────

  group('[MFT] CreateSavedItemSheet — AI parse', () {
    setUpAll(() {
      // testTheory: MFT
      // contract: Parsing a description appends component cards and prefills the
      //           name when empty; failures are non-blocking. See spec
      //           specs/create_saved_item_ai_parse.spec.md.
    });

    MealParseResult ok(List<String> names, {String? title}) => MealParseResult(
          success: true,
          title: title,
          items: names.map((n) => FoodItemDraft(name: n)).toList(),
        );

    // AC2 — text parse populates components.
    testWidgets('successful parse appends one card per returned item', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Yogurt', 'Granola']));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      await tester.enterText(_aiField(), 'yogurt and granola');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(2));
    });

    // AC3 — name fill only when empty.
    testWidgets('fills name from title when name is empty', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Oats'], title: 'Power Bowl'));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      await tester.enterText(_aiField(), 'oats');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_nameField()).controller?.text, 'Power Bowl');
    });

    testWidgets('does not overwrite a name the user already typed', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Oats'], title: 'Power Bowl'));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      await tester.enterText(_nameField(), 'My Custom Name');
      await tester.enterText(_aiField(), 'oats');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_nameField()).controller?.text, 'My Custom Name');
    });

    // AC4 — append, not replace.
    testWidgets('parsed items append to existing component cards', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Honey', 'Berries']));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      // Pre-add one manual card.
      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();
      expect(find.byType(Card), findsOneWidget);

      await tester.enterText(_aiField(), 'honey and berries');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsNWidgets(3), reason: 'AC4: 1 existing + 2 parsed');
    });

    // AC5 — failure is non-blocking.
    testWidgets('parse failure shows error and leaves form usable', (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => MealParseResult(success: false, errorMessage: 'Worker down'));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      await tester.enterText(_aiField(), 'something');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(find.text('Worker down'), findsOneWidget);
      expect(find.byType(Card), findsNothing);

      // Manual path still works after failure.
      await tester.tap(_bySemanticsId('btn-create-item-add-blank'));
      await tester.pump();
      expect(find.byType(Card), findsOneWidget);
    });

    // AC6 — empty input guard.
    testWidgets('empty AI field does not call the service and prompts for text',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['X']));
      await tester.pumpWidget(_sheet(storage: storage, ai: ai));
      await tester.pump();

      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(ai.calls, 0, reason: 'AC6: no service call on empty input');
      expect(find.text('Enter a description to parse.'), findsOneWidget);
      expect(find.byType(Card), findsNothing);
    });

    // AC7 — historical-meal context injection.
    testWidgets('referential text builds a context snippet and passes it to parseMeal',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Pizza']));
      final memory = _FakeMemory(snippet: 'CONTEXT: last night = pizza');
      await tester.pumpWidget(_sheet(storage: storage, ai: ai, memory: memory));
      await tester.pump();

      await tester.enterText(_aiField(), 'leftovers from last night');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(ai.lastContext, 'CONTEXT: last night = pizza',
          reason: 'AC7: snippet for referential input must reach parseMeal');
    });

    testWidgets('non-referential text passes null mealContext (no DB hit)',
        (tester) async {
      final storage = _FakeStorage(searchImpl: (_) => []);
      final ai = _FakeAi((_) => ok(['Eggs']));
      final memory = _FakeMemory();
      await tester.pumpWidget(_sheet(storage: storage, ai: ai, memory: memory));
      await tester.pump();

      await tester.enterText(_aiField(), 'two eggs and toast');
      await tester.tap(_bySemanticsId('btn-parse-saved-item-ai'));
      await tester.pumpAndSettle();

      expect(ai.lastContext, isNull,
          reason: 'AC7: non-referential input must not build a snippet');
    });
  });
}
