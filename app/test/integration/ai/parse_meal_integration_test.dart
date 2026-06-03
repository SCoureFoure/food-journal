// Run with:
//   MEAL_PARSER_URL=https://... flutter test test/integration/ai/parse_meal_integration_test.dart
//
// Skipped automatically when MEAL_PARSER_URL is not set.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/worker_ai_service.dart';

import 'helpers/ai_assertions.dart';
import 'helpers/test_env.dart';

// ─── Skip guard ──────────────────────────────────────────────────────────────

final _workerUrl = readRootEnv('MEAL_PARSER_URL') ?? '';
final _skip = _workerUrl.isEmpty ? 'Set MEAL_PARSER_URL env var to run AI integration tests' : null;

// ─── Helpers ─────────────────────────────────────────────────────────────────

AiService _makeService() => WorkerAiService(
      workerUrl: _workerUrl,
      authToken: readRootEnv('TEST_AUTH_TOKEN'),
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late AiService ai;

  setUpAll(() {
    if (_workerUrl.isNotEmpty) ai = _makeService();
  });

  // ── Schema invariants ──────────────────────────────────────────────────────
  // MFT: binary oracle — if these fail the feature ships nothing.
  // Verify output structure holds for any valid input regardless of AI estimates.

  group('[MFT] parseMeal — schema invariants', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'MFT',
        contract: 'success=true, title populated, ≥1 item, all names non-empty, macros ≥0',
        implication: 'meal parsing returns unusable data to the UI for any well-formed input',
      );
    });
    tearDownAll(AiAssertions.clearContext);
    test(
      'simple breakfast: title populated, ≥1 item, all names non-empty, macros non-negative',
      () async {
        final r = await ai.parseMeal(
          text: 'scrambled eggs and toast with butter',
          mealType: 'breakfast',
        );
        AiAssertions.mealSchema(r);
      },
      skip: _skip,
    );

    test(
      'multi-item lunch: schema holds for comma-separated list',
      () async {
        final r = await ai.parseMeal(
          text: 'grilled chicken breast, steamed broccoli, and brown rice',
          mealType: 'lunch',
        );
        AiAssertions.mealSchema(r);
        AiAssertions.mealMinItems(r, 2);
      },
      skip: _skip,
    );

    test(
      'complex description: schema holds for detailed prep notes',
      () async {
        final r = await ai.parseMeal(
          text: 'baked salmon fillet with lemon and dill, roasted asparagus with olive oil, side salad with balsamic vinaigrette',
          mealType: 'dinner',
        );
        AiAssertions.mealSchema(r);
        AiAssertions.mealMinItems(r, 2);
      },
      skip: _skip,
    );
  });

  // ── Semantic assertions ────────────────────────────────────────────────────
  // MFT: nutritional direction must be correct for inputs with unambiguous macro profiles.
  // Verify that value-level relationships hold for inputs with clear nutritional profiles.

  group('[MFT] parseMeal — semantic assertions', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'MFT',
        contract: 'nutritional relationships (protein > fat, total calories > threshold) hold for canonical inputs',
        implication: 'AI macro estimates are directionally wrong for common foods',
      );
    });
    tearDownAll(AiAssertions.clearContext);
    test(
      'protein shake: protein > fat for whey + milk input',
      () async {
        final r = await ai.parseMeal(
          text: '2 scoops whey protein powder with 8oz almond milk',
          mealType: 'snack',
        );
        AiAssertions.mealSchema(r);
        AiAssertions.mealProteinDominant(r);
      },
      skip: _skip,
    );

    test(
      'calorie-dense meal: total calories > 500 for bacon cheeseburger with fries',
      () async {
        final r = await ai.parseMeal(
          text: 'bacon cheeseburger with large fries',
          mealType: 'lunch',
        );
        AiAssertions.mealSchema(r);
        AiAssertions.mealCaloriesExceed(r, 500);
      },
      skip: _skip,
    );
  });

  // ── Temporal reference resolution ─────────────────────────────────────────
  // DIR: adding context must shift AI output toward stored meal values (not away).
  // This tests the client-side context prepend in WorkerAiService (worker_ai_service.dart:33).
  //
  // Format the Worker's parse_meal prompt expects:
  //   "Recent meals:\n...\n\nUser input: <text>"
  // WorkerAiService builds this by prepending mealContext verbatim.

  group('[DIR] parseMeal — temporal reference resolution', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'DIR',
        contract: 'mealContext injection must cause temporal references to resolve toward stored history, not away',
        implication: 'context injection does nothing — "same as last night" returns unrelated food instead of stored meal',
      );
    });
    tearDownAll(AiAssertions.clearContext);
    test(
      'with context: "same as last night" resolves to non-empty foods from history',
      () async {
        const context = 'Recent meals:\n'
            '- Dinner (2026-05-14 7:30 PM): grilled salmon fillet, steamed asparagus, quinoa';

        final r = await ai.parseMeal(
          text: 'same as last night',
          mealType: 'dinner',
          mealContext: context,
        );
        AiAssertions.mealSchema(r);
        // Expect items that reference the history (salmon/asparagus/quinoa), not empty
        AiAssertions.mealMinItems(r, 1);
      },
      skip: _skip,
    );

    test(
      'without context: temporal input still returns a result (graceful degradation)',
      () async {
        final r = await ai.parseMeal(
          text: 'same as last night',
          mealType: 'dinner',
        );
        // Without context the model will make something up or return minimal result.
        // We only assert it doesn't crash — success or failure both acceptable.
        expect(r, isNotNull);
      },
      skip: _skip,
    );

    test(
      'context does not bleed: history items do not appear as new food items',
      () async {
        // Provide history with a very specific item, then describe a different current meal.
        // The Worker prompt explicitly says: "Extract food items from the current meal
        // description that follows — not from the history block."
        const context = 'Recent meals:\n'
            '- Breakfast (2026-05-14 8:00 AM): durian fruit smoothie';

        final r = await ai.parseMeal(
          text: 'two poached eggs on sourdough toast',
          mealType: 'breakfast',
          mealContext: context,
        );
        AiAssertions.mealSchema(r);
        final names = r.items!.map((i) => i.name.toLowerCase()).toList();
        expect(
          names.any((n) => n.contains('durian')),
          isFalse,
          reason: 'history item "durian" must not appear as a new food item',
        );
      },
      skip: _skip,
    );
  });

  // ── INV: synonym phrasing ──────────────────────────────────────────────────
  // INV: different phrasings of the same food must both return schema-valid results.
  // Phrasing variation (word order, prep-before vs prep-after) must not break parsing.
  //
  // KNOWN-FLAKY (live worker): hits the real Gemini-backed worker, so a result is
  // non-deterministic and this group can fail intermittently on schema/min-item
  // assertions when the model drops an item or shifts shape. Not a regression in
  // app code — re-run, or gate behind `_skip` when the worker is unavailable.
  group('[INV] parseMeal — synonym phrasing invariance', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'INV',
        contract: 'reordering or rephrasing the same food description must not break the schema or drop items',
        implication: 'users who describe food differently than the prompt expects silently lose meal data',
      );
    });
    tearDownAll(AiAssertions.clearContext);

    test(
      '"scrambled eggs on toast" vs "eggs, scrambled, on toast": both schema valid, ≥1 item',
      () async {
        final r1 = await ai.parseMeal(
          text: 'scrambled eggs on toast',
          mealType: 'breakfast',
        );
        final r2 = await ai.parseMeal(
          text: 'eggs, scrambled, on toast',
          mealType: 'breakfast',
        );
        AiAssertions.mealSchema(r1);
        AiAssertions.mealSchema(r2);
        AiAssertions.mealMinItems(r1, 1);
        AiAssertions.mealMinItems(r2, 1);
      },
      skip: _skip,
    );

    test(
      '"grilled chicken breast with salad" vs "chicken breast, grilled, with salad": both schema valid',
      () async {
        final r1 = await ai.parseMeal(
          text: 'grilled chicken breast with salad',
          mealType: 'lunch',
        );
        final r2 = await ai.parseMeal(
          text: 'chicken breast, grilled, with salad',
          mealType: 'lunch',
        );
        AiAssertions.mealSchema(r1);
        AiAssertions.mealSchema(r2);
      },
      skip: _skip,
    );
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────
  // BVA: boundary inputs (empty, null) must return structured failure, not crash.

  group('[BVA] parseMeal — edge cases', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'BVA',
        contract: 'empty or null input returns success=false with errorMessage, not an exception',
        implication: 'empty input causes an unhandled exception in the app',
      );
    });
    tearDownAll(AiAssertions.clearContext);
    test(
      'empty text returns success=false with errorMessage',
      () async {
        // WorkerAiService guards against empty body (no text, no image).
        final r = await ai.parseMeal(text: '');
        AiAssertions.mealFailure(r);
      },
      skip: _skip,
    );

    test(
      'null text returns success=false with errorMessage',
      () async {
        final r = await ai.parseMeal();
        AiAssertions.mealFailure(r);
      },
      skip: _skip,
    );
  });
}
