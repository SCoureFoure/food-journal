// Tests for the meal-count / day-window grocery-list API on ExportService.
//
// StorageService requires native sqlite3 so a fake subclass replaces the
// DB-touching methods with in-memory implementations. This validates:
//   - buildGroceryCandidates: ingredient/item-name grain, meal-count window
//     selection + sort, day-window boundary, mode isolation, empty/malformed
//     input.
//   - buildGroceryListText: renders buildGroceryCandidates output through
//     formatGroceryList / groceryWindowLabel.
//
// exportGroceryList is not covered here — it hits the share_plus platform
// channel; the two methods above carry the behavior.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/grocery.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/export_service.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Fake StorageService ───────────────────────────────────────────────────────
//
// In-memory fixture recording which of getAllMeals / getMealsInRange was
// invoked and the arguments getMealsInRange was called with, so mode
// isolation and the day-window boundary can be asserted directly.

class _FakeStorage extends StorageService {
  final List<MealEntry> allMeals;
  final List<MealEntry> rangeMeals;
  final Map<int, List<({FoodItem item, List<Ingredient> ingredients})>> rowsByMealId;

  bool getAllMealsCalled = false;
  bool getMealsInRangeCalled = false;
  DateTime? capturedFrom;
  DateTime? capturedTo;

  _FakeStorage({
    this.allMeals = const [],
    this.rangeMeals = const [],
    this.rowsByMealId = const {},
  });

  @override
  Future<List<MealEntry>> getAllMeals() async {
    getAllMealsCalled = true;
    return allMeals;
  }

  @override
  Future<List<MealEntry>> getMealsInRange({DateTime? from, DateTime? to}) async {
    getMealsInRangeCalled = true;
    capturedFrom = from;
    capturedTo = to;
    return rangeMeals;
  }

  @override
  Future<List<({FoodItem item, List<Ingredient> ingredients})>> getFoodItemsWithIngredients(
      int mealId) async {
    return rowsByMealId[mealId] ?? [];
  }
}

// ── Fake AiService ────────────────────────────────────────────────────────────
//
// Records the rawList it was handed and returns a configurable
// GroceryTidyResult. Every other method is never called by ExportService, so
// each throws UnimplementedError.

class _FakeAiService implements AiService {
  @override
  Future<ReceiptParseResult> parseReceipt(String ocrText, {List<String> knownFoods = const []}) async =>
      ReceiptParseResult(success: false, errorMessage: 'not used');

  final GroceryTidyResult result;
  String? capturedRawList;
  bool tidyGroceryListCalled = false;

  _FakeAiService(this.result);

  @override
  Future<GroceryTidyResult> tidyGroceryList(String rawList) async {
    tidyGroceryListCalled = true;
    capturedRawList = rawList;
    return result;
  }

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) =>
      throw UnimplementedError();

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) =>
      throw UnimplementedError();

  @override
  Future<FoodDbSearchResult> searchFoodDatabase(String query) => throw UnimplementedError();
}

MealEntry _meal({int? id, required DateTime date, DateTime? createdAt}) => MealEntry(
      id: id,
      date: date,
      time: '12:00',
      mealType: 'lunch',
      createdAt: createdAt ?? date,
    );

({FoodItem item, List<Ingredient> ingredients}) _row({
  required String itemName,
  int mealId = 1,
  List<String> ingredientNames = const [],
}) {
  final item = FoodItem(mealId: mealId, name: itemName);
  final ingredients = ingredientNames
      .map((n) => Ingredient(foodItemId: 0, name: n))
      .toList();
  return (item: item, ingredients: ingredients);
}

void main() {
  group(
      '[EQUIV] buildGroceryCandidates — ingredient grain',
      () {
        // Contract: a row with ingredients contributes those ingredient names
        // and NOT the food-item name; a row with no ingredients falls back to
        // the item name. Regression risk: adding both, or dropping the
        // fallback, silently corrupts the grocery list.
        test('ingredients replace the item name; item name is the fallback (AC1)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 29)),
              _meal(id: 2, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              1: [
                _row(
                  itemName: 'Greek salad',
                  mealId: 1,
                  ingredientNames: ['Feta cheese', 'Olive oil'],
                ),
              ],
              2: [_row(itemName: 'Oatmeal', mealId: 2)],
            },
          );
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 30,
          );

          expect(result.mealsUsed, 2);
          expect(result.candidates.length, 3);
          expect(result.candidates[0].name, 'Feta cheese');
          expect(result.candidates[1].name, 'Oatmeal');
          expect(result.candidates[2].name, 'Olive oil');
          expect(
            result.candidates.any((c) => c.canonicalName == 'greek salad'),
            isFalse,
            reason: 'Greek salad had ingredients, so it must be replaced, not added',
          );
        });

        // Contract: buildGroceryListText is a thin pass-through of
        // buildGroceryCandidates into formatGroceryList — no filtering,
        // capping, or reformatting of its own.
        test('text renders from real candidates (AC10)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 29)),
              _meal(id: 2, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
              2: [_row(itemName: 'Rice', mealId: 2)],
            },
          );
          final service = ExportService(storage);

          final text = await service.buildGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(
            text,
            'Grocery list - from your last 2 meals\n'
            'Generated 2026-08-29\n'
            '\n'
            '- Rice (x2)',
          );
        });
      });

  group(
      '[BVA] buildGroceryCandidates — meal-count window',
      () {
        // Contract: the meal window takes the N newest meals by date, not
        // the N meals as returned by getAllMeals. Regression risk: taking
        // straight from getAllMeals (createdAt-ascending within a date) is
        // fine here since dates differ, but a broken sort would mix in the
        // oldest meals — this fails if that sort direction is wrong.
        test('cuts to the N newest meals by date (AC2)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 25)),
              _meal(id: 2, date: DateTime(2026, 8, 26)),
              _meal(id: 3, date: DateTime(2026, 8, 27)),
              _meal(id: 4, date: DateTime(2026, 8, 28)),
              _meal(id: 5, date: DateTime(2026, 8, 29)),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Ancient stew', mealId: 1)],
              2: [_row(itemName: 'Ancient stew', mealId: 2)],
              3: [_row(itemName: 'Rice', mealId: 3)],
              4: [_row(itemName: 'Rice', mealId: 4)],
              5: [_row(itemName: 'Rice', mealId: 5)],
            },
          );
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 3,
          );

          expect(result.mealsUsed, 3);
          expect(result.candidates.length, 1);
          expect(result.candidates[0].name, 'Rice');
          expect(result.candidates[0].mealCount, 3);
          expect(
            result.candidates.any((c) => c.canonicalName == 'ancient stew'),
            isFalse,
          );
        });

        // Contract: meals on the same date are ordered by createdAt
        // descending, not left in the createdAt-ascending order
        // getAllMeals returns. Regression risk: a date-only sort (or no
        // re-sort at all) would pick the earliest meal of the day instead.
        test('same-date ordering uses createdAt descending (AC3)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(
                id: 1,
                date: DateTime(2026, 8, 29),
                createdAt: DateTime(2026, 8, 29, 8, 0),
              ),
              _meal(
                id: 2,
                date: DateTime(2026, 8, 29),
                createdAt: DateTime(2026, 8, 29, 19, 0),
              ),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Early eggs', mealId: 1)],
              2: [_row(itemName: 'Late steak', mealId: 2)],
            },
          );
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 1,
          );

          expect(result.mealsUsed, 1);
          expect(result.candidates.length, 1);
          expect(result.candidates[0].name, 'Late steak');
        });
      });

  group(
      '[BVA] buildGroceryCandidates — day window',
      () {
        // Contract: `size` is calendar days INCLUDING today, so `from` is
        // `today - (size - 1)`. Regression risk: a naive
        // `subtract(Duration(days: size))` shifts the window one day early —
        // this test fails under that wrong reading (2026-08-22 vs 08-23).
        test('window boundary passes from == today - (size - 1) (AC4)', () async {
          final storage = _FakeStorage(rangeMeals: []);
          final service = ExportService(storage);
          final anchor = DateTime(2026, 8, 29, 10, 30);

          await service.buildGroceryCandidates(
            mode: GroceryWindowMode.days,
            size: 7,
            now: anchor,
          );

          expect(storage.capturedFrom, DateTime(2026, 8, 23));
          expect(storage.capturedTo, anchor);
        });

        // Contract: each mode calls exactly one of getAllMeals /
        // getMealsInRange. Regression risk: calling both would waste a query
        // and risks double-counting if a caller ever merges the results.
        test('days mode does not call getAllMeals, meals mode does not call '
            'getMealsInRange (AC5)', () async {
          final daysStorage = _FakeStorage(rangeMeals: []);
          await ExportService(daysStorage).buildGroceryCandidates(
            mode: GroceryWindowMode.days,
            size: 7,
            now: DateTime(2026, 8, 29),
          );
          expect(daysStorage.getAllMealsCalled, isFalse);
          expect(daysStorage.getMealsInRangeCalled, isTrue);

          final mealsStorage = _FakeStorage(allMeals: []);
          await ExportService(mealsStorage).buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 30,
          );
          expect(mealsStorage.getMealsInRangeCalled, isFalse);
          expect(mealsStorage.getAllMealsCalled, isTrue);
        });

        // Contract: an empty day window must never throw; the day label
        // still prints so the rendered text explains itself. Regression
        // risk: dropping the label (or the "no meals logged yet" message)
        // leaves the user staring at a blank export.
        test('nothing in the day window (AC7)', () async {
          final storage = _FakeStorage(rangeMeals: []);
          final service = ExportService(storage);

          final text = await service.buildGroceryListText(
            mode: GroceryWindowMode.days,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(
            text,
            'Grocery list - last 30 days\n'
            'Generated 2026-08-29\n'
            '\n'
            '(no meals logged yet)',
          );
        });
      });

  group(
      '[INV] buildGroceryCandidates — malformed and empty input',
      () {
        // Invariant: no meals logged at all must never throw; it is the
        // empty case, propagated through to the rendered text.
        test('nothing logged, meals mode (AC6)', () async {
          final storage = _FakeStorage(allMeals: []);
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 30,
          );
          expect(result.mealsUsed, 0);
          expect(result.candidates, isEmpty);

          final text = await service.buildGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );
          expect(
            text,
            'Grocery list\n'
            'Generated 2026-08-29\n'
            '\n'
            '(no meals logged yet)',
          );
        });

        // Invariant: meals were selected but contributed no usable names
        // (canonicalize drops non-word content) must still count toward
        // mealsUsed while rendering the "nothing to list" message, not the
        // "no meals logged" one.
        test('meals found but nothing listable (AC8)', () async {
          final storage = _FakeStorage(
            allMeals: [_meal(id: 1, date: DateTime(2026, 8, 29))],
            rowsByMealId: {
              1: [_row(itemName: '!!!', mealId: 1)],
            },
          );
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 30,
          );
          expect(result.mealsUsed, 1);
          expect(result.candidates, isEmpty);

          final text = await service.buildGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );
          expect(
            text,
            'Grocery list - from your last 1 meal\n'
            'Generated 2026-08-29\n'
            '\n'
            '(nothing to list from these meals)',
          );
        });

        // Invariant: a meal with a null id can never be fed to
        // getFoodItemsWithIngredients (it requires a non-null int), so it
        // must be skipped rather than crashing. Regression risk: removing
        // the null check throws a null-check-operator error on real data
        // that has a not-yet-persisted meal in the selection.
        test('null ids skipped (AC9)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: null, date: DateTime(2026, 8, 29)),
              _meal(id: 3, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              3: [_row(itemName: 'Rice', mealId: 3)],
            },
          );
          final service = ExportService(storage);

          final result = await service.buildGroceryCandidates(
            mode: GroceryWindowMode.meals,
            size: 30,
          );

          expect(result.mealsUsed, 1);
          expect(result.candidates.length, 1);
          expect(result.candidates[0].name, 'Rice');
        });
      });

  group(
      '[DIR] buildTidyPromptInput — raw list handed to the AI',
      () {
        // Contract: each candidate renders as `name (xN)`, one per line, in
        // ranked order, no trailing newline. Regression risk: a joining
        // change (trailing newline, different separator) silently corrupts
        // what the AI is asked to tidy.
        test('renders one "name (xN)" line per candidate, in order (AC1)', () {
          final text = ExportService.buildTidyPromptInput([
            const GroceryCandidate(name: 'Butter', canonicalName: 'butter', mealCount: 2),
            const GroceryCandidate(name: 'Rice', canonicalName: 'rice', mealCount: 1),
          ]);

          expect(text, 'Butter (x2)\nRice (x1)');
        });

        // Contract: an empty candidate list produces an empty string, not a
        // header or placeholder — buildTidiedGroceryListText relies on this
        // to skip the AI call entirely.
        test('empty candidate list gives an empty string (AC2)', () {
          final text = ExportService.buildTidyPromptInput([]);
          expect(text, '');
        });

        // Contract: the AI receives exactly the ranked raw list built from
        // real candidates, not some other serialization. Regression risk: if
        // buildTidiedGroceryListText stops calling buildTidyPromptInput, the
        // AI would receive malformed or unranked input.
        test('the AI receives the ranked raw list (AC4)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 29)),
              _meal(id: 2, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
              2: [_row(itemName: 'Rice', mealId: 2)],
            },
          );
          final ai = _FakeAiService(
            GroceryTidyResult(
              success: true,
              sections: [const GrocerySection(name: 'Pantry', items: ['Rice'])],
            ),
          );
          final service = ExportService(storage, ai: ai);

          await service.buildTidiedGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(ai.capturedRawList, 'Rice (x2)');
        });
      });

  group(
      '[INV] buildTidiedGroceryListText — tidy pass and its failure modes',
      () {
        // Contract: on success, the AI's sections are rendered through
        // formatTidiedGroceryList with the same window label the plain list
        // uses. Regression risk: bypassing formatTidiedGroceryList or using
        // the wrong label breaks the rendered header/sections.
        test('happy path renders the AI\'s sections (AC3)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 29)),
              _meal(id: 2, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
              2: [_row(itemName: 'Rice', mealId: 2)],
            },
          );
          final ai = _FakeAiService(
            GroceryTidyResult(
              success: true,
              sections: [const GrocerySection(name: 'Pantry', items: ['Rice'])],
            ),
          );
          final service = ExportService(storage, ai: ai);

          final text = await service.buildTidiedGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(
            text,
            'Grocery list - from your last 2 meals\n'
            'Generated 2026-08-29\n'
            '\n'
            'Pantry\n'
            '- Rice',
          );
        });

        // Contract: an empty candidate set skips the AI call entirely — a
        // network round trip to be told there is nothing to tidy is waste.
        // Regression risk: calling the AI anyway wastes a request and could
        // surface a spurious failure for an empty list.
        test('no candidates skips the AI (AC5)', () async {
          final storage = _FakeStorage(allMeals: []);
          final ai = _FakeAiService(GroceryTidyResult(success: true, sections: const []));
          final service = ExportService(storage, ai: ai);

          final text = await service.buildTidiedGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(ai.tidyGroceryListCalled, isFalse);
          expect(
            text,
            'Grocery list\n'
            'Generated 2026-08-29\n'
            '\n'
            '(nothing to list from these meals)',
          );
        });

        // Contract: an AI failure throws with the AI's own error message —
        // it must not fall back to the plain list. Regression risk: catching
        // and swallowing the failure (or falling back) hides an error the
        // user could otherwise act on.
        test('AI failure throws with the message (AC6)', () async {
          final storage = _FakeStorage(
            allMeals: [_meal(id: 1, date: DateTime(2026, 8, 29))],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
            },
          );
          final ai = _FakeAiService(
            GroceryTidyResult(success: false, errorMessage: 'Worker error 429: busy'),
          );
          final service = ExportService(storage, ai: ai);

          await expectLater(
            () => service.buildTidiedGroceryListText(
              mode: GroceryWindowMode.meals,
              size: 30,
              now: DateTime(2026, 8, 29),
            ),
            throwsA(predicate((e) => e.toString().contains('Worker error 429: busy'))),
          );
        });

        // Contract: success:true with sections:null is still a failure — the
        // AI's own success flag alone is not sufficient. Regression risk:
        // rendering formatTidiedGroceryList with a null-checked empty list
        // would silently hand the user an empty tidied list.
        test('success with null sections is treated as failure (AC7)', () async {
          final storage = _FakeStorage(
            allMeals: [_meal(id: 1, date: DateTime(2026, 8, 29))],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
            },
          );
          final ai = _FakeAiService(GroceryTidyResult(success: true, sections: null));
          final service = ExportService(storage, ai: ai);

          await expectLater(
            () => service.buildTidiedGroceryListText(
              mode: GroceryWindowMode.meals,
              size: 30,
              now: DateTime(2026, 8, 29),
            ),
            throwsException,
          );
        });

        // Contract: buildGroceryListText (the plain path) never touches the
        // AI, even when the injected AiService is configured to fail.
        // Regression risk: sharing tidy-pass wiring with the plain path
        // would make the plain export fail whenever the AI is down.
        test('the plain path is unaffected (AC8)', () async {
          final storage = _FakeStorage(
            allMeals: [
              _meal(id: 1, date: DateTime(2026, 8, 29)),
              _meal(id: 2, date: DateTime(2026, 8, 28)),
            ],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
              2: [_row(itemName: 'Rice', mealId: 2)],
            },
          );
          final ai = _FakeAiService(
            GroceryTidyResult(success: false, errorMessage: 'Worker error 429: busy'),
          );
          final service = ExportService(storage, ai: ai);

          final text = await service.buildGroceryListText(
            mode: GroceryWindowMode.meals,
            size: 30,
            now: DateTime(2026, 8, 29),
          );

          expect(
            text,
            'Grocery list - from your last 2 meals\n'
            'Generated 2026-08-29\n'
            '\n'
            '- Rice (x2)',
          );
          expect(ai.tidyGroceryListCalled, isFalse);
        });

        // Contract: days mode flows through buildTidiedGroceryListText
        // identically to meals mode — same label logic, same tidy call.
        // Regression risk: a mode-specific branch in the tidy path would
        // desync it from the plain path's mode handling.
        test('days mode works identically (AC9)', () async {
          final storage = _FakeStorage(
            rangeMeals: [_meal(id: 1, date: DateTime(2026, 8, 29))],
            rowsByMealId: {
              1: [_row(itemName: 'Rice', mealId: 1)],
            },
          );
          final ai = _FakeAiService(
            GroceryTidyResult(
              success: true,
              sections: [const GrocerySection(name: 'Pantry', items: ['Rice'])],
            ),
          );
          final service = ExportService(storage, ai: ai);

          final text = await service.buildTidiedGroceryListText(
            mode: GroceryWindowMode.days,
            size: 7,
            now: DateTime(2026, 8, 29),
          );

          expect(text.startsWith('Grocery list - last 7 days\n'), isTrue);
        });
      });

  /// [MFT] ExportService.tidyGroceryListText — holds the contract that the AI tidy pass
  /// receives exactly the item names the user is looking at, hand edits included, and is
  /// not called at all for an empty list. If this regresses: the tidied list silently
  /// diverges from the box the user pressed the button on, or an empty box costs a
  /// network round trip and returns AI-shaped noise.
  group('[MFT] ExportService.tidyGroceryListText', () {
    // Contract: the AI receives the parsed item names, not the raw rendered
    // text — headers and blank lines must not leak into the tidy prompt.
    test('sends the parsed items, not the raw text (AC1)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(
        GroceryTidyResult(
          success: true,
          sections: [const GrocerySection(name: 'Pantry', items: ['Salt'])],
        ),
      );
      final service = ExportService(storage, ai: ai);

      await service.tidyGroceryListText(
        'Grocery list\nGenerated 2026-08-30\n\n- salt (x6)\n- potatoes (x3)',
      );

      expect(ai.capturedRawList, 'salt (x6)\npotatoes (x3)');
    });

    // Contract: hand edits (bare lines with no leading dash) are respected —
    // the parse reads back whatever is on screen, not just AI-rendered lines.
    test('hand edits are respected (AC2)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(
        GroceryTidyResult(
          success: true,
          sections: [const GrocerySection(name: 'Pantry', items: ['Salt'])],
        ),
      );
      final service = ExportService(storage, ai: ai);

      await service.tidyGroceryListText('- salt\neggs');

      expect(ai.capturedRawList, 'salt\neggs');
    });

    // Contract: the returned string is formatTidiedGroceryList output for
    // whatever sections the AI returns, with a bare "Grocery list" header
    // (no window label — it is no longer meaningful once hand-edited).
    test('returns formatTidiedGroceryList output for the AI\'s sections (AC3)',
        () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(
        GroceryTidyResult(
          success: true,
          sections: [
            const GrocerySection(name: 'Pantry', items: ['Salt', 'Potatoes']),
          ],
        ),
      );
      final service = ExportService(storage, ai: ai);

      final text = await service.tidyGroceryListText('- salt\n- potatoes');
      final lines = text.split('\n');

      expect(lines.first, 'Grocery list');
      expect(lines[1].startsWith('Generated '), isTrue);
      expect(text.contains('Pantry'), isTrue);
      expect(text.contains('Salt'), isTrue);
      expect(text.contains('Potatoes'), isTrue);
    });

    // Contract: `now` is honoured — passing a fixed DateTime makes the test
    // clock-independent instead of racing DateTime.now().
    test('now is honoured in the Generated header (AC7)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(
        GroceryTidyResult(
          success: true,
          sections: [const GrocerySection(name: 'Pantry', items: ['Salt'])],
        ),
      );
      final service = ExportService(storage, ai: ai);

      final text = await service.tidyGroceryListText(
        '- salt',
        now: DateTime(2026, 1, 2),
      );

      expect(text.split('\n')[1], 'Generated 2026-01-02');
    });
  });

  /// [BVA] ExportService.tidyGroceryListText — empty input and AI-failure
  /// boundaries. If this regresses: an empty box burns a network round trip,
  /// or a failed/malformed AI response is rendered as if it had succeeded.
  group('[BVA] ExportService.tidyGroceryListText — empty and failure', () {
    // Contract: empty input short-circuits before ever calling the AI — a
    // doer that always calls the AI burns a network round trip on an empty box.
    test('empty text never calls the AI (AC4)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(GroceryTidyResult(success: true, sections: const []));
      final service = ExportService(storage, ai: ai);

      final text = await service.tidyGroceryListText('');

      expect(ai.tidyGroceryListCalled, isFalse);
      expect(text.startsWith('Grocery list'), isTrue);
    });

    // Contract: a text with only headers and a placeholder line (no real
    // items) also parses to nothing, so it must also skip the AI call.
    test('headers-and-placeholder-only text never calls the AI (AC4)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(GroceryTidyResult(success: true, sections: const []));
      final service = ExportService(storage, ai: ai);

      final text = await service.tidyGroceryListText(
        'Grocery list\nGenerated 2026-08-30\n\n(no meals logged yet)',
      );

      expect(ai.tidyGroceryListCalled, isFalse);
      expect(text.startsWith('Grocery list'), isTrue);
    });

    // Contract: an AI failure surfaces as a thrown Exception carrying the
    // AI's own error message, not a silent fallback.
    test('AI failure surfaces as an Exception with the message (AC5)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(
        GroceryTidyResult(success: false, errorMessage: 'Worker error 429: busy'),
      );
      final service = ExportService(storage, ai: ai);

      await expectLater(
        () => service.tidyGroceryListText('- salt'),
        throwsA(predicate((e) => e.toString().contains('Worker error 429: busy'))),
      );
    });

    // Contract: success:true with sections:null is still a failure — the
    // success flag alone is not sufficient to trust the response.
    test('success with null sections still throws (AC6)', () async {
      final storage = _FakeStorage();
      final ai = _FakeAiService(GroceryTidyResult(success: true, sections: null));
      final service = ExportService(storage, ai: ai);

      await expectLater(
        () => service.tidyGroceryListText('- salt'),
        throwsException,
      );
    });
  });

  /// [MFT] SettingsService.groceryDraft — the draft round-trips through
  /// SharedPreferences and clears cleanly. If this regresses: the list the
  /// user built at home is gone (or stale) by the time they reach the shop.
  group('[MFT] SettingsService.groceryDraft', () {
    test('round-trips: default empty, set, clear (AC8)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      expect(await settings.groceryDraft, '');

      await settings.setGroceryDraft('- salt');
      expect(await settings.groceryDraft, '- salt');

      await settings.clearGroceryDraft();
      expect(await settings.groceryDraft, '');
    });
  });
}
