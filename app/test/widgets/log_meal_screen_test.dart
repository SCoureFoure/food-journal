// Widget tests for the Log Meal AI autofill flow.
// Spec: specs/log_meal_ai_parse.spec.md (AC1–AC10).
//
// All five service seams are faked — no network, no native SQLite, no plugins.
// The happy-path fake AI returns drafts parsed from
// test/fixtures/import/single_meal.json, so the flow runs against real
// structured data ("against the fixtures").

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/screens/log_meal/log_meal_screen.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/import_service.dart';
import 'package:food_journal/services/meal_memory/meal_memory_service.dart';
import 'package:food_journal/services/notification_service.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/editable_food_item_card.dart';
import 'package:food_journal/widgets/log_photo_section.dart';
import 'package:food_journal/widgets/reuse_suggestion.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAi implements AiService {
  final MealParseResult Function(String? text, Uint8List? image) mealImpl;
  int calls = 0;
  String? lastText;
  String? lastContext;
  Uint8List? lastImage;
  _FakeAi(this.mealImpl);

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async {
    calls++;
    lastText = text;
    lastImage = imageBytes;
    lastContext = mealContext;
    return mealImpl(text, imageBytes);
  }

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async =>
      throw UnimplementedError();
}

// Referential when text contains "leftover"; pure, no DB.
class _FakeMemory extends MealMemoryService {
  final String snippet;
  _FakeMemory({this.snippet = 'CONTEXT: last night = pizza'});

  @override
  bool isReferential(String input) => input.toLowerCase().contains('leftover');

  @override
  Future<String?> buildContextSnippet(String input) async => snippet;
}

class _FakeSettings extends SettingsService {
  final bool aiEnabled;
  _FakeSettings({this.aiEnabled = true});
  @override
  Future<bool> get isAiEnabled async => aiEnabled;
}

class _FakeNotifications extends NotificationService {
  @override
  Future<void> scheduleCheckin(int entryId, String label, DateTime entryTime,
          {int? delayMinutes}) async {}
}

// Storage is not exercised by the parse flow on a new meal; a bare subclass keeps
// the lazy native DB from ever being constructed. searchFoodHistory is stubbed
// because the reuse nudge calls it on every name change — empty = no chip.
class _FakeStorage extends StorageService {
  /// History returned by the reuse-nudge lookup. Empty = no chip.
  List<FoodItemDraft> foodHistory = const [];

  @override
  Future<List<FoodItemDraft>> searchFoodHistory(String query,
          {bool favoritesOnly = false}) async =>
      foodHistory;
}

// ── Fixture-derived drafts ──────────────────────────────────────────────────

List<FoodItemDraft> _draftsFromFixture(String name) {
  final json = File('test/fixtures/import/$name').readAsStringSync();
  final payload = ImportService.parseJson(json);
  return payload.meals.first.foodItems
      .map((fi) => FoodItemDraft(
            name: fi.name,
            portion: fi.portion,
            prep: fi.prep,
            calories: fi.calories,
            protein: fi.protein,
            carbs: fi.carbs,
            fat: fi.fat,
          ))
      .toList();
}

// ── Harness ─────────────────────────────────────────────────────────────────

Widget _screen({
  required AiService ai,
  MealMemoryService? memory,
  SettingsService? settings,
  StorageService? storage,
}) =>
    MaterialApp(
      home: LogMealScreen(
        aiOverride: ai,
        storageOverride: storage ?? _FakeStorage(),
        memoryOverride: memory ?? _FakeMemory(),
        notificationsOverride: _FakeNotifications(),
        settingsOverride: settings ?? _FakeSettings(aiEnabled: true),
      ),
    );

Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Finder _descField() => find.descendant(
      of: _bySemanticsId('log-meal-input'),
      matching: find.byType(TextField),
    );

MealParseResult _ok(List<FoodItemDraft> items, {String? title}) =>
    MealParseResult(success: true, title: title, items: items);

// A valid 1×1 transparent PNG so LogPhotoSection's MemoryImage decodes.
Uint8List _tinyPng() => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );

void main() {
  // ─── AC1 — happy-path text parse (against the fixture) ────────────────────

  testWidgets('AC1: successful parse renders one card per returned item', (tester) async {
    final drafts = _draftsFromFixture('single_meal.json'); // 2 items
    final ai = _FakeAi((_, __) => _ok(drafts));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    await tester.enterText(_descField(), 'two eggs and toast');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(find.byType(EditableFoodItemCard), findsNWidgets(drafts.length));
    expect(drafts.length, 2, reason: 'single_meal.json fixture has 2 food items');
  });

  // ─── AC2 / AC3 — title prefill semantics ──────────────────────────────────

  testWidgets('AC2: fills title from result when title empty', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'Oats')], title: 'Power Bowl'));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    await tester.enterText(_descField(), 'oats');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    final title = tester.widget<TextField>(
      find.descendant(of: _bySemanticsId('log-meal-title'), matching: find.byType(TextField)),
    );
    expect(title.controller?.text, 'Power Bowl');
  });

  testWidgets('AC3: does not overwrite a user-entered title', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'Oats')], title: 'Power Bowl'));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    await tester.enterText(
      find.descendant(of: _bySemanticsId('log-meal-title'), matching: find.byType(TextField)),
      'My Title',
    );
    await tester.enterText(_descField(), 'oats');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    final title = tester.widget<TextField>(
      find.descendant(of: _bySemanticsId('log-meal-title'), matching: find.byType(TextField)),
    );
    expect(title.controller?.text, 'My Title');
  });

  // ─── AC4 — replace, not append ────────────────────────────────────────────

  testWidgets('AC4: parsed items replace existing manual items', (tester) async {
    final ai = _FakeAi((_, __) => _ok([
          const FoodItemDraft(name: 'Salmon'),
          const FoodItemDraft(name: 'Rice'),
          const FoodItemDraft(name: 'Broccoli'),
        ]));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    // Pre-add two manual cards.
    await tester.tap(_bySemanticsId('btn-add-item'));
    await tester.pump();
    await tester.tap(_bySemanticsId('btn-add-item'));
    await tester.pump();
    expect(find.byType(EditableFoodItemCard), findsNWidgets(2));

    await tester.enterText(_descField(), 'salmon dinner');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(find.byType(EditableFoodItemCard), findsNWidgets(3),
        reason: 'AC4: 2 manual cards cleared, replaced by 3 parsed');
  });

  // ─── AC5 — failure non-blocking ───────────────────────────────────────────

  testWidgets('AC5: parse failure shows error, no cards, manual still works', (tester) async {
    final ai = _FakeAi((_, __) => MealParseResult(success: false, errorMessage: 'Worker down'));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    await tester.enterText(_descField(), 'something');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(find.text('Worker down'), findsOneWidget);
    expect(find.byType(EditableFoodItemCard), findsNothing);

    await tester.tap(_bySemanticsId('btn-add-item'));
    await tester.pump();
    expect(find.byType(EditableFoodItemCard), findsOneWidget);
  });

  // ─── AC6 — empty-input guard ──────────────────────────────────────────────

  testWidgets('AC6: empty text + no photo does not call service, prompts', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'X')]));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(ai.calls, 0);
    expect(find.text('Add a description or photo before autofilling.'), findsOneWidget);
    expect(find.byType(EditableFoodItemCard), findsNothing);
  });

  // ─── AC7 — image-only autofill ────────────────────────────────────────────

  testWidgets('AC7: image with empty text calls parseMeal with image, null text', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'Pancakes')]));
    await tester.pumpWidget(_screen(ai: ai));
    await tester.pump();

    // Simulate a picked photo via the section's callback (image_picker can't run in tests).
    // Must be a decodable image — LogPhotoSection renders it via MemoryImage.
    final photo = tester.widget<LogPhotoSection>(find.byType(LogPhotoSection));
    photo.onImagePicked(_tinyPng());
    await tester.pump();

    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(ai.calls, 1);
    expect(ai.lastText, isNull, reason: 'AC7: empty text sent as null');
    expect(ai.lastImage, isNotNull, reason: 'AC7: image bytes passed through');
    expect(find.byType(EditableFoodItemCard), findsOneWidget);
  });

  // ─── AC8 / AC9 — context injection ────────────────────────────────────────

  testWidgets('AC8: referential text injects snippet into mealContext', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'Pizza')]));
    final memory = _FakeMemory(snippet: 'CONTEXT: last night = pizza');
    await tester.pumpWidget(_screen(ai: ai, memory: memory));
    await tester.pump();

    await tester.enterText(_descField(), 'leftovers from last night');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(ai.lastContext, 'CONTEXT: last night = pizza');
  });

  testWidgets('AC9: non-referential text passes null mealContext', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'Eggs')]));
    final memory = _FakeMemory();
    await tester.pumpWidget(_screen(ai: ai, memory: memory));
    await tester.pump();

    await tester.enterText(_descField(), 'two eggs and toast');
    await tester.tap(_bySemanticsId('btn-autofill-meal'));
    await tester.pumpAndSettle();

    expect(ai.lastContext, isNull);
  });

  // ─── AC10 — AI-off fallback ───────────────────────────────────────────────

  testWidgets('AC10: AI disabled hides autofill button, keeps manual controls', (tester) async {
    final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'X')]));
    await tester.pumpWidget(_screen(ai: ai, settings: _FakeSettings(aiEnabled: false)));
    await tester.pump();
    await tester.pump(); // _loadSettings async flip

    expect(_bySemanticsId('btn-autofill-meal'), findsNothing,
        reason: 'AC10: no autofill button when AI is off');
    expect(_bySemanticsId('btn-add-item'), findsOneWidget,
        reason: 'AC10: manual add control remains');
  });

  // ─── Layer B reuse nudge (food_entity_resolution AC15, AC16) ──────────────

  group('[food_entity_resolution] reuse nudge', () {
    Finder itemNameField() => find
        .descendant(
          of: find.byType(EditableFoodItemCard),
          matching: find.byType(TextField),
        )
        .first;

    _FakeStorage withHistory() => _FakeStorage()
      ..foodHistory = const [
        FoodItemDraft(name: 'Turkey Sandwich', calories: 320, protein: 24),
      ];

    Future<void> openCardAndType(WidgetTester tester, String text) async {
      await tester.tap(_bySemanticsId('btn-add-item'));
      await tester.pump();
      await tester.enterText(itemNameField(), text);
      await tester.pump(const Duration(milliseconds: 450)); // fire debounce
      await tester.pumpAndSettle();
    }

    testWidgets('AC15: close match shows chip; unrelated shows none', (tester) async {
      final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'X')]));
      await tester.pumpWidget(
          _screen(ai: ai, storage: withHistory(), settings: _FakeSettings(aiEnabled: false)));
      await tester.pump();
      await tester.pump();

      await openCardAndType(tester, 'turkey sandwich w/ mayo');
      expect(_bySemanticsId('food-reuse-suggestion-0'), findsOneWidget,
          reason: 'AC15: close lexical match surfaces the chip');
      expect(find.byType(ReuseSuggestionChip), findsOneWidget);

      await tester.enterText(itemNameField(), 'oatmeal');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(_bySemanticsId('food-reuse-suggestion-0'), findsNothing,
          reason: 'AC15: no close match → no chip');
    });

    testWidgets('AC16: tapping chip adopts name + macros, chip disappears', (tester) async {
      final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'X')]));
      await tester.pumpWidget(
          _screen(ai: ai, storage: withHistory(), settings: _FakeSettings(aiEnabled: false)));
      await tester.pump();
      await tester.pump();

      await openCardAndType(tester, 'turkey sandwich w/ mayo');
      await tester.tap(find.text('Reuse "Turkey Sandwich"'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(itemNameField()).controller!.text,
          'Turkey Sandwich',
          reason: 'AC16: name replaced with the history item');
      expect(_bySemanticsId('food-reuse-suggestion-0'), findsNothing,
          reason: 'AC16: chip gone after adopt');
      // macros adopted: expand the card and read the calories field.
      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '320'), findsOneWidget,
          reason: 'AC16: calories adopted from the history item');
    });

    testWidgets('compound word matches via full-history fuzzy (LIKE-fix regression)', (tester) async {
      // "hamburger" typed, history has "Burger" — the old LIKE filter returned
      // nothing because "Burger" doesn't contain "hamburger". Full-history fetch
      // lets the fuzzy matcher find it.
      final ai = _FakeAi((_, __) => _ok([const FoodItemDraft(name: 'X')]));
      final storage = _FakeStorage()
        ..foodHistory = const [FoodItemDraft(name: 'Burger', calories: 450)];
      await tester.pumpWidget(
          _screen(ai: ai, storage: storage, settings: _FakeSettings(aiEnabled: false)));
      await tester.pump();
      await tester.pump();

      await openCardAndType(tester, 'hamburger');
      expect(_bySemanticsId('food-reuse-suggestion-0'), findsOneWidget,
          reason: 'hamburger~burger fuzzy match must fire via full-history fetch');
    });

    testWidgets('chip hidden when enabled=false (save-in-progress guard)', (tester) async {
      // Card with a pre-populated match but enabled:false — chip must not show.
      // This mirrors what the meal screen does when _isSaving flips true.
      final storage = withHistory();
      final data = FoodItemFormData.blank()..nameCtrl.text = 'turkey sandwich w/ mayo';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: EditableFoodItemCard(
            data: data,
            onDelete: () {},
            reuseStorage: storage,
            reuseSemanticsId: 'food-reuse-suggestion-0',
            enabled: false,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(_bySemanticsId('food-reuse-suggestion-0'), findsNothing,
          reason: 'chip hidden when enabled=false');
      data.dispose();
    });
  });
}
