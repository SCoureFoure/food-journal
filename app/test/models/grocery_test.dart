import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/grocery.dart';

void main() {
  group('[EQUIV] buildGroceryList — canonical grouping and ordering', () {
    // testTheory: equivalence-class — items with the same canonical form
    // (case-/punctuation-/whitespace-insensitive) are grouped as one entity.
    // contract: grouping by canonicalize, dedupe within meals, sort by
    //   mealCount (desc) then canonicalName (asc).
    // implication: AC1 & AC5 — grouping and meal counting form the foundation;
    //   wrong sort or grouping breaks the entire list.

    test('AC1: grouping, counting, ordering', () {
      const input = [
        MealGroceryInput(mealId: 1, names: ['Chicken breast', 'Olive oil']),
        MealGroceryInput(mealId: 2, names: ['chicken breast', 'Feta cheese']),
        MealGroceryInput(mealId: 3, names: ['Olive oil']),
      ];

      final result = buildGroceryList(input);

      expect(result.length, 3);
      expect(result[0].name, 'Chicken breast');
      expect(result[0].canonicalName, 'chicken breast');
      expect(result[0].mealCount, 2);

      expect(result[1].name, 'Olive oil');
      expect(result[1].canonicalName, 'olive oil');
      expect(result[1].mealCount, 2);

      expect(result[2].name, 'Feta cheese');
      expect(result[2].canonicalName, 'feta cheese');
      expect(result[2].mealCount, 1);
    });

    test('AC5: a meal with only garbage still counts as a meal for other keys', () {
      const input = [
        MealGroceryInput(mealId: 1, names: ['Rice']),
        MealGroceryInput(mealId: 2, names: ['!!!']),
        MealGroceryInput(mealId: 3, names: ['rice']),
      ];

      final result = buildGroceryList(input);

      expect(result.length, 1);
      expect(result[0].name, 'Rice');
      expect(result[0].canonicalName, 'rice');
      expect(result[0].mealCount, 2);
    });
  });

  group('[INV] buildGroceryList — a key counts once per meal', () {
    // testTheory: invariant — a canonical key appearing multiple times
    // within a single meal (in different raw forms) must count as exactly one
    // occurrence in that meal, not multiple.
    // contract: within each meal, dedupe by canonical key before counting.
    // implication: AC2 — without per-meal deduping, the same ingredient
    //   logged 3 times in one meal would inflate the count to 3.

    test('AC2: one meal counts a key once', () {
      const input = [
        MealGroceryInput(mealId: 1, names: ['Olive oil', 'olive oil', 'OLIVE OIL']),
      ];

      final result = buildGroceryList(input);

      expect(result.length, 1);
      expect(result[0].name, 'Olive oil');
      expect(result[0].canonicalName, 'olive oil');
      expect(result[0].mealCount, 1);
    });
  });

  group('[BVA] buildGroceryList — empty and garbage input', () {
    // testTheory: boundary-value — the function handles degenerate inputs:
    // empty lists, empty strings, whitespace, and punctuation-only names.
    // contract: garbage (canonicalize returns '') is dropped; empty input
    //   returns empty list (never null, never throws).
    // implication: AC3 & AC4 — malformed data must not crash or poison output.

    test('AC3: garbage names dropped', () {
      const input = [
        MealGroceryInput(mealId: 1, names: ['', '   ', '!!!', 'Rice']),
      ];

      final result = buildGroceryList(input);

      expect(result.length, 1);
      expect(result[0].name, 'Rice');
      expect(result[0].canonicalName, 'rice');
      expect(result[0].mealCount, 1);
    });

    test('AC4: empty input', () {
      final result = buildGroceryList([]);

      expect(result, isEmpty);
    });
  });

  group('[DIR] formatGroceryList — rendered text', () {
    // testTheory: direct — the output format is text, with precise line
    // structure, date format, and suffix syntax.
    // contract: header (2 lines with windowLabel), blank line, then items
    //   (non-empty) or placeholder (empty); no trailing newline; mealCount
    //   always uses (xN) suffix even when N=1; empty message depends on
    //   mealsUsed.
    // implication: AC6, AC6b, AC7, AC7b, AC8 — export/share must be
    //   character-perfect for readability; wrong label, date format, missing
    //   lines, or trailing whitespace breaks downstream consumers.

    test('AC6: formatted text, meals mode, non-empty', () {
      const candidates = [
        GroceryCandidate(
          name: 'Chicken breast',
          canonicalName: 'chicken breast',
          mealCount: 4,
        ),
        GroceryCandidate(
          name: 'Olive oil',
          canonicalName: 'olive oil',
          mealCount: 1,
        ),
      ];

      final result = formatGroceryList(
        candidates,
        windowLabel: 'from your last 12 meals',
        mealsUsed: 12,
        generatedAt: DateTime(2026, 8, 29, 13, 5),
      );

      const expected = 'Grocery list - from your last 12 meals\n'
          'Generated 2026-08-29\n'
          '\n'
          '- Chicken breast (x4)\n'
          '- Olive oil (x1)';

      expect(result, expected);
    });

    test('AC6b: formatted text, days mode, non-empty', () {
      const candidates = [
        GroceryCandidate(
          name: 'Rice',
          canonicalName: 'rice',
          mealCount: 2,
        ),
      ];

      final result = formatGroceryList(
        candidates,
        windowLabel: 'last 30 days',
        mealsUsed: 5,
        generatedAt: DateTime(2026, 8, 29),
      );

      const expected = 'Grocery list - last 30 days\n'
          'Generated 2026-08-29\n'
          '\n'
          '- Rice (x2)';

      expect(result, expected);
    });

    test('AC7: formatted text, empty, no meals logged', () {
      final result = formatGroceryList(
        [],
        windowLabel: '',
        mealsUsed: 0,
        generatedAt: DateTime(2026, 1, 2),
      );

      const expected = 'Grocery list\n'
          'Generated 2026-01-02\n'
          '\n'
          '(no meals logged yet)';

      expect(result, expected);
    });

    test('AC7b: formatted text, empty, meals found but nothing listable', () {
      final result = formatGroceryList(
        [],
        windowLabel: 'last 7 days',
        mealsUsed: 3,
        generatedAt: DateTime(2026, 1, 2),
      );

      const expected = 'Grocery list - last 7 days\n'
          'Generated 2026-01-02\n'
          '\n'
          '(nothing to list from these meals)';

      expect(result, expected);
    });

    test('AC8: count of 1 still renders a suffix', () {
      const candidates = [
        GroceryCandidate(
          name: 'Rice',
          canonicalName: 'rice',
          mealCount: 1,
        ),
      ];

      final result = formatGroceryList(
        candidates,
        windowLabel: 'last 14 days',
        mealsUsed: 3,
        generatedAt: DateTime(2026, 3, 15),
      );

      expect(result.contains('(x1)'), isTrue);
      expect(result.contains('Rice (x1)'), isTrue);
    });
  });

  group('[EQUIV] groceryWindowLabel — window phrasing', () {
    // testTheory: equivalence-class — the label reflects the window mode and
    // the actual meal count, not the requested window size.
    // contract: days mode always reports size regardless of mealsUsed; meals
    //   mode reports mealsUsed (0 → empty, 1 → singular, >1 → plural).
    // implication: AC-L1 through AC-L4 — the header message must accurately
    //   convey what window produced the list; wrong label confuses the user
    //   about why the list is empty or how many meals it covers.

    test('AC-L1: day label ignores mealsUsed', () {
      expect(
        groceryWindowLabel(
          mode: GroceryWindowMode.days,
          size: 7,
          mealsUsed: 0,
        ),
        'last 7 days',
      );

      expect(
        groceryWindowLabel(
          mode: GroceryWindowMode.days,
          size: 30,
          mealsUsed: 12,
        ),
        'last 30 days',
      );
    });

    test('AC-L2: meal label reports the actual count, not the requested size', () {
      expect(
        groceryWindowLabel(
          mode: GroceryWindowMode.meals,
          size: 30,
          mealsUsed: 12,
        ),
        'from your last 12 meals',
      );
    });

    test('AC-L3: singular', () {
      expect(
        groceryWindowLabel(
          mode: GroceryWindowMode.meals,
          size: 30,
          mealsUsed: 1,
        ),
        'from your last 1 meal',
      );
    });

    test('AC-L4: meals mode with nothing logged', () {
      expect(
        groceryWindowLabel(
          mode: GroceryWindowMode.meals,
          size: 30,
          mealsUsed: 0,
        ),
        '',
      );
    });
  });

  group('[DIR] formatTidiedGroceryList — grouped rendering', () {
    // testTheory: direct — the output format renders sections with items,
    // blank lines between sections (not after the last), and handles empty
    // sections correctly.
    // contract: section name on its own line, then "- item" for each item in
    //   order, blank line between sections only; if all sections empty,
    //   the body is "(nothing to list from these meals)"; no trailing newline.
    // implication: AC-T1 through AC-T6 — the AI tidy pass produces section-grouped
    //   output that must render correctly with proper spacing; wrong blank-line
    //   handling or trailing newlines breaks export/share.

    test('AC-T1: two sections render with blank line between', () {
      const sections = [
        GrocerySection(name: 'Produce', items: ['Onions', 'Spinach']),
        GrocerySection(name: 'Dairy & Eggs', items: ['Butter']),
      ];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: 'from your last 12 meals',
        generatedAt: DateTime(2026, 8, 29, 13, 5),
      );

      final expected = [
        'Grocery list - from your last 12 meals',
        'Generated 2026-08-29',
        '',
        'Produce',
        '- Onions',
        '- Spinach',
        '',
        'Dairy & Eggs',
        '- Butter',
      ].join('\n');

      expect(result, expected);
    });

    test('AC-T2: single section has no trailing blank line', () {
      const sections = [
        GrocerySection(name: 'Pantry', items: ['Olive oil']),
      ];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: 'last 30 days',
        generatedAt: DateTime(2026, 8, 29),
      );

      final expected = [
        'Grocery list - last 30 days',
        'Generated 2026-08-29',
        '',
        'Pantry',
        '- Olive oil',
      ].join('\n');

      expect(result, expected);
    });

    test('AC-T3: empty section is skipped', () {
      const sections = [
        GrocerySection(name: 'Produce', items: ['Onions']),
        GrocerySection(name: 'Frozen', items: []),
      ];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: 'last 7 days',
        generatedAt: DateTime(2026, 8, 29),
      );

      final expected = [
        'Grocery list - last 7 days',
        'Generated 2026-08-29',
        '',
        'Produce',
        '- Onions',
      ].join('\n');

      expect(result, expected);
    });

    test('AC-T4: no sections at all', () {
      final sections = <GrocerySection>[];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: '',
        generatedAt: DateTime(2026, 1, 2),
      );

      final expected = [
        'Grocery list',
        'Generated 2026-01-02',
        '',
        '(nothing to list from these meals)',
      ].join('\n');

      expect(result, expected);
    });

    test('AC-T5: every section empty behaves like none', () {
      const sections = [
        GrocerySection(name: 'Produce', items: []),
        GrocerySection(name: 'Frozen', items: []),
      ];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: 'last 30 days',
        generatedAt: DateTime(2026, 1, 2),
      );

      final expected = [
        'Grocery list - last 30 days',
        'Generated 2026-01-02',
        '',
        '(nothing to list from these meals)',
      ].join('\n');

      expect(result, expected);
    });

    test('AC-T6: item order is preserved, not re-sorted', () {
      const sections = [
        GrocerySection(name: 'Pantry', items: ['Rice', 'Butter']),
      ];

      final result = formatTidiedGroceryList(
        sections,
        windowLabel: '',
        generatedAt: DateTime(2026, 8, 29),
      );

      expect(result.contains('- Rice'), isTrue);
      expect(result.contains('- Butter'), isTrue);
      expect(result.indexOf('- Rice'), lessThan(result.indexOf('- Butter')));
    });
  });
}
