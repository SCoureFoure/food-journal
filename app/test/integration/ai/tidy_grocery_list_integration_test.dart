// Run with:
//   MEAL_PARSER_URL=https://... flutter test test/integration/ai/tidy_grocery_list_integration_test.dart
//
// Skipped automatically when MEAL_PARSER_URL is not set.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/grocery.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/worker_ai_service.dart';

import 'helpers/test_env.dart';

// ─── Skip guard ──────────────────────────────────────────────────────────────

final _workerUrl = readRootEnv('MEAL_PARSER_URL') ?? '';
final _skip = _workerUrl.isEmpty ? 'Set MEAL_PARSER_URL env var to run AI integration tests' : null;

// ─── Helpers ─────────────────────────────────────────────────────────────────

AiService _makeService() => WorkerAiService(
      workerUrl: _workerUrl,
      authToken: readRootEnv('TEST_AUTH_TOKEN'),
    );

/// Sections from a tidy result, or a test failure that names the real cause.
/// Every assertion below needs sections; when the call failed, the useful
/// message is *why it failed*, not a null-check crash ten lines later.
List<GrocerySection> _sectionsOf(GroceryTidyResult r) {
  if (!r.success || r.sections == null) {
    fail(
      'tidy_grocery_list did not return sections. '
      'Worker said: ${r.errorMessage ?? "(no message)"}. '
      'If this reads "Unknown task", the prompt exists locally but the deployed '
      'Worker has not been redeployed — run `wrangler deploy` from worker/.',
    );
  }
  return r.sections!;
}

// This is the shape ExportService.buildTidyPromptInput actually produces —
// deliberately full of the noise the prompt is meant to remove.
const _rawList = '''
salt (x6)
Peanut butter and fluff sandwich (x4)
vegetable oil (x4)
potatoes (x3)
butter (x2)
unsalted butter (x2)
water (x9)
spinach (x2)''';

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late AiService ai;

  setUpAll(() {
    if (_workerUrl.isNotEmpty) ai = _makeService();
  });

  // ── Schema invariants ──────────────────────────────────────────────────────
  // MFT: binary oracle — if these fail the feature ships nothing.
  // Verify output structure holds for the deployed tidy_grocery_list prompt.

  group('[MFT] tidyGroceryList — schema invariants', () {
    test(
      'success is true and errorMessage is null for the standing raw list',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        expect(
          r.success,
          isTrue,
          reason: 'tidy_grocery_list rejected by the live Worker — has `wrangler deploy` been run from worker/ since the prompt was added?',
        );
        expect(
          r.errorMessage,
          isNull,
          reason: 'tidy_grocery_list rejected by the live Worker — has `wrangler deploy` been run from worker/ since the prompt was added?',
        );
      },
      skip: _skip,
    );

    test(
      'sections is non-null and non-empty',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        expect(r.sections, isNotNull, reason: 'no sections returned at all');
        expect(r.sections, isNotEmpty, reason: 'sections list was empty');
      },
      skip: _skip,
    );

    test(
      'every section has a non-empty name and at least one item',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final sections = _sectionsOf(r);
        for (final section in sections) {
          expect(
            section.name.trim(),
            isNotEmpty,
            reason: 'a section was returned with a blank name',
          );
          expect(
            section.items,
            isNotEmpty,
            reason: 'section "${section.name}" is empty — the prompt forbids empty sections',
          );
        }
      },
      skip: _skip,
    );

    test(
      'every item is a non-empty, non-blank string',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final sections = _sectionsOf(r);
        for (final section in sections) {
          for (final item in section.items) {
            expect(
              item.trim(),
              isNotEmpty,
              reason: 'section "${section.name}" contained a blank item',
            );
          }
        }
      },
      skip: _skip,
    );
  });

  // ── Output contract ────────────────────────────────────────────────────────
  // INV: the tidy pass's output contract (no counts, closed vocabulary, unique
  // sections) must hold for any successful run against the live model.

  group('[INV] tidyGroceryList — output contract', () {
    test(
      'no counts leak into item names',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final sections = _sectionsOf(r);
        final countPattern = RegExp(r'\(x\d+\)');
        for (final section in sections) {
          for (final item in section.items) {
            expect(
              countPattern.hasMatch(item),
              isFalse,
              reason: 'a count leaked into an item name: "$item"',
            );
            expect(
              RegExp(r'\(\d+\)').hasMatch(item),
              isFalse,
              reason: 'a bare digit-in-parens leaked into an item name: "$item"',
            );
          }
        }
      },
      skip: _skip,
    );

    test(
      'every returned section name is in the closed vocabulary',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final sections = _sectionsOf(r);
        for (final section in sections) {
          expect(
            kGrocerySections.contains(section.name),
            isTrue,
            reason: 'unknown section returned: "${section.name}"',
          );
        }
      },
      skip: _skip,
    );

    test(
      'sections are unique — no section name appears twice',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final names = _sectionsOf(r).map((s) => s.name).toList();
        expect(
          names.toSet().length,
          names.length,
          reason: 'a section name appeared more than once: $names',
        );
      },
      skip: _skip,
    );
  });

  // ── Merge and filter behavior ─────────────────────────────────────────────
  // MFT: the whole point of the tidy pass is merging duplicates and dropping
  // non-shoppable items — verify against the live model, not a stub.

  group('[MFT] tidyGroceryList — merge and filter behavior', () {
    test(
      'butter variants merge into at most one item',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final allItems = _sectionsOf(r).expand((s) => s.items).toList();
        final butterItems = allItems.where((i) {
          final lower = i.toLowerCase();
          return lower.contains('butter') && !lower.contains('peanut');
        }).toList();
        expect(
          butterItems.length,
          lessThanOrEqualTo(1),
          reason: '"butter" and "unsalted butter" both survived as separate items: $butterItems',
        );
      },
      skip: _skip,
    );

    test(
      'water is dropped',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final allItems = _sectionsOf(r).expand((s) => s.items).toList();
        for (final item in allItems) {
          final lower = item.toLowerCase().trim();
          expect(
            lower == 'water' || lower == 'tap water',
            isFalse,
            reason: 'water survived the tidy pass as an item: "$item"',
          );
        }
      },
      skip: _skip,
    );

    test(
      'nothing is invented wholesale — total item count does not exceed input lines',
      () async {
        final r = await ai.tidyGroceryList(_rawList);
        final totalItems = _sectionsOf(r).fold<int>(0, (sum, s) => sum + s.items.length);
        final inputLineCount = _rawList.split('\n').length;
        expect(
          totalItems,
          lessThanOrEqualTo(inputLineCount),
          reason: 'tidy pass expanded the list ($totalItems items from $inputLineCount input lines) instead of merging/filtering it',
        );
      },
      skip: _skip,
    );
  });

  // ── Degenerate input ───────────────────────────────────────────────────────
  // BVA: a single-line input must still round-trip successfully.

  group('[BVA] tidyGroceryList — degenerate input', () {
    test(
      'single-line input still returns success with at least one item',
      () async {
        final r = await ai.tidyGroceryList('rice (x1)');
        expect(
          r.success,
          isTrue,
          reason: 'single-line input failed — tidy_grocery_list should handle degenerate lists',
        );
        final totalItems = _sectionsOf(r).fold<int>(0, (sum, s) => sum + s.items.length);
        expect(
          totalItems,
          greaterThanOrEqualTo(1),
          reason: 'single-line input returned no items at all',
        );
      },
      skip: _skip,
    );
  });
}
