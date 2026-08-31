/// Grocery list aggregation. See specs/groceries.spec.md.
library;

import 'food_entity.dart' show canonicalize;

/// How the grocery window is measured.
enum GroceryWindowMode {
  /// The N most recently logged meals, regardless of when they were logged.
  meals,

  /// Every meal logged in the last N calendar days.
  days,
}

/// One meal's grocery-relevant names, as gathered from storage. [names] is
/// every candidate name the meal contributes.
class MealGroceryInput {
  final int mealId;
  final List<String> names;
  const MealGroceryInput({required this.mealId, required this.names});
}

/// One line on a generated grocery list.
class GroceryCandidate {
  final String name;          // display name, raw as logged
  final String canonicalName; // canonicalize(name) — the grouping key
  final int mealCount;        // distinct meals this key appeared in
  const GroceryCandidate({
    required this.name,
    required this.canonicalName,
    required this.mealCount,
  });
}

/// Builds a grocery list from meal inputs.
///
/// Rules:
/// 1. Process [meals] in order given (newest-first).
/// 2. For each meal, canonicalize every name entry, dropping any whose
///    canonical form is empty.
/// 3. Within one meal, dedupe by canonical key — a key contributes at most
///    once per meal.
/// 4. [mealCount] = number of meals whose deduped key set contains this key.
/// 5. [name] = raw name from the first meal in input order that contributed
///    this key; within that meal, the first matching entry in [names] order.
/// 6. Sort result: [mealCount] descending, then [canonicalName] ascending.
List<GroceryCandidate> buildGroceryList(List<MealGroceryInput> meals) {
  final candidatesByKey = <String, GroceryCandidate>{};
  final keysByMeal = <int, Set<String>>{};

  // Process meals in order, deduplicate by canonical key within each meal
  for (final meal in meals) {
    final mealKeys = <String>{};

    for (final rawName in meal.names) {
      final canonical = canonicalize(rawName);
      if (canonical.isEmpty) continue;

      // First occurrence of this canonical key in this meal — record as display name
      if (!mealKeys.contains(canonical)) {
        mealKeys.add(canonical);
        if (!candidatesByKey.containsKey(canonical)) {
          candidatesByKey[canonical] = GroceryCandidate(
            name: rawName,
            canonicalName: canonical,
            mealCount: 0,
          );
        }
      }
    }

    keysByMeal[meal.mealId] = mealKeys;
  }

  // Count distinct meals per key
  final countByKey = <String, int>{};
  for (final keys in keysByMeal.values) {
    for (final key in keys) {
      countByKey[key] = (countByKey[key] ?? 0) + 1;
    }
  }

  // Build result with updated meal counts
  final result = candidatesByKey.entries.map((e) {
    final original = e.value;
    return GroceryCandidate(
      name: original.name,
      canonicalName: original.canonicalName,
      mealCount: countByKey[e.key] ?? 0,
    );
  }).toList();

  // Sort: mealCount descending, then canonicalName ascending
  result.sort((a, b) {
    final byCount = b.mealCount.compareTo(a.mealCount);
    if (byCount != 0) return byCount;
    return a.canonicalName.compareTo(b.canonicalName);
  });

  return result;
}

/// Human phrase describing the window a list was built from, for the header.
/// Empty string means "say nothing" — the header then reads just "Grocery list".
String groceryWindowLabel({
  required GroceryWindowMode mode,
  required int size,
  required int mealsUsed,
}) {
  if (mode == GroceryWindowMode.days) {
    return 'last $size days';
  }
  // mode == GroceryWindowMode.meals
  if (mealsUsed == 0) {
    return '';
  }
  if (mealsUsed == 1) {
    return 'from your last 1 meal';
  }
  return 'from your last $mealsUsed meals';
}

/// Formats a grocery list into a human-readable string.
///
/// For non-empty [candidates]:
/// ```
/// Grocery list - {windowLabel}
/// Generated {date}
///
/// - {name} (x{mealCount})
/// - {name} (x{mealCount})
/// ```
///
/// For empty [candidates]:
/// ```
/// Grocery list - {windowLabel}
/// Generated {date}
///
/// (no meals logged yet) or (nothing to list from these meals)
/// ```
///
/// [generatedAt] is formatted as ISO 8601 date only (YYYY-MM-DD).
/// No trailing newline.
String formatGroceryList(
  List<GroceryCandidate> candidates, {
  required String windowLabel,
  required int mealsUsed,
  required DateTime generatedAt,
}) {
  final dateStr = generatedAt.toIso8601String().substring(0, 10);
  final headerLine1 = windowLabel.isEmpty
      ? 'Grocery list'
      : 'Grocery list - $windowLabel';
  final header = '$headerLine1\nGenerated $dateStr';

  if (candidates.isEmpty) {
    final emptyMessage = mealsUsed == 0
        ? '(no meals logged yet)'
        : '(nothing to list from these meals)';
    return '$header\n\n$emptyMessage';
  }

  final lines = candidates
      .map((c) => '- ${c.name} (x${c.mealCount})')
      .toList();

  return '$header\n\n${lines.join('\n')}';
}

/// The closed set of supermarket sections the AI tidy pass may return, in
/// render order. Mirrors the vocabulary pinned in the Worker's
/// `tidy_grocery_list` prompt — see specs/groceries.spec.md decision 19.
const List<String> kGrocerySections = [
  'Produce',
  'Meat & Seafood',
  'Dairy & Eggs',
  'Bakery',
  'Pantry',
  'Frozen',
  'Beverages',
  'Other',
];

/// One supermarket section of a tidied grocery list.
class GrocerySection {
  final String name;
  final List<String> items;
  const GrocerySection({required this.name, required this.items});
}

/// Renders an AI-tidied, section-grouped list as shareable plain text.
String formatTidiedGroceryList(
  List<GrocerySection> sections, {
  required String windowLabel,
  required DateTime generatedAt,
}) {
  final dateStr = generatedAt.toIso8601String().substring(0, 10);
  final headerLine1 = windowLabel.isEmpty
      ? 'Grocery list'
      : 'Grocery list - $windowLabel';
  final header = '$headerLine1\nGenerated $dateStr';

  // Filter to non-empty sections
  final nonEmptySections = sections.where((s) => s.items.isNotEmpty).toList();

  if (nonEmptySections.isEmpty) {
    return '$header\n\n(nothing to list from these meals)';
  }

  // Build section lines
  final sectionLines = <String>[];
  for (int i = 0; i < nonEmptySections.length; i++) {
    final section = nonEmptySections[i];
    sectionLines.add(section.name);
    for (final item in section.items) {
      sectionLines.add('- $item');
    }
    // Add blank line between sections, but not after the last one
    if (i < nonEmptySections.length - 1) {
      sectionLines.add('');
    }
  }

  return '$header\n\n${sectionLines.join('\n')}';
}

/// Reads item names back out of a rendered (and possibly hand-edited) grocery
/// list, so an edited list can be fed to the AI tidy pass.
///
/// Drops the two header lines, blank lines, parenthetical placeholders, and any
/// line that is exactly one of [kGrocerySections] (a heading from an earlier
/// tidy). Everything else is an item, with a leading "- " removed if present.
List<String> parseGroceryListItems(String text) {
  final result = <String>[];
  final lines = text.split('\n');

  for (final line in lines) {
    var trimmed = line.trim();

    // Rule 1: Empty after trimming → drop
    if (trimmed.isEmpty) continue;

    // Rule 2: Starts with "Grocery list" → drop
    if (trimmed.startsWith('Grocery list')) continue;

    // Rule 3: Starts with "Generated " → drop
    if (trimmed.startsWith('Generated ')) continue;

    // Rule 4: Starts with "(" and ends with ")" → drop
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) continue;

    // Rule 5: Exactly equals one of kGrocerySections → drop
    if (kGrocerySections.contains(trimmed)) continue;

    // Rule 6: Otherwise it's an item. Remove "- " prefix if present, then trim.
    if (trimmed.startsWith('- ')) {
      trimmed = trimmed.substring(2).trim();
    }

    // Only add if non-empty after processing
    if (trimmed.isNotEmpty) {
      result.add(trimmed);
    }
  }

  return result;
}
