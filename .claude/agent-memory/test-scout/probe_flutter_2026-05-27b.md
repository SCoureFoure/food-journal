---
name: probe_flutter_2026-05-27b
description: Gap closure audit — CreateSavedItemSheet widget tests + searchFoodHistory path tests; 498 pass (1 pre-existing AI network failure unchanged)
metadata:
  type: project
---

## 2026-05-27 layer: flutter (targeted — gap closure from v7 audit)

**Probed:** Two specific open items from [[probe_flutter_2026-05-27]]:
- CreateSavedItemSheet widget (no test existed)
- searchFoodHistory UNION SQL execution paths (no unit-level test existed)

**Found:**

1. CreateSavedItemSheet had zero test coverage despite containing non-trivial logic:
   - Two validation guards (empty name, empty components), each needing separate test
   - Debounced history search that calls searchFoodHistory after 300ms
   - Live macro totals that update via TextEditingController listeners
   - onCreated callback that must pass isComposite=true and savedItemId
   - The ListTile title for search results is `item.name + calStr` — `find.text(name)` fails
     when calories is non-null because the suffix `" · N cal"` is part of the same Text widget.
     Tests must use `FoodItemDraft(name: ..., calories: null)` or `find.textContaining`.

2. searchFoodHistory has two SQL branches (favoritesOnly=true: single-table; false: UNION ALL)
   with no in-memory DB infrastructure (no drift_testability, no sqlite3_flutter_libs dev dep).
   The path-selection logic was untested at any level.

**Fixed:**

- Created app/test/widgets/create_saved_item_sheet_test.dart (43 tests):
  * Structure: title, subtext description, all four Semantics anchors present on open
  * Add item button: single and double tap add correct number of Card widgets
  * Validation: empty name → "Name is required.", name-but-no-components → "Add at least one item.",
    name error takes priority, no error on fresh open
  * Successful save: onCreated fires with isComposite=true, draft name matches input,
    saveSavedItem called on storage, savedItemId on draft matches fake storage id
  * History search: typing triggers search after 300ms debounce, empty query clears results,
    tapping result adds a component card, tapping result clears search field,
    composite result shows bookmark_outline icon
  * Live totals: absent when no components, appears (showing "0 cal") after adding a blank component
  * BVA: whitespace-only name rejected (trim().isEmpty guard)
  * FP: no error text visible on fresh open

- Created app/test/services/search_food_history_test.dart (21 tests):
  * favoritesOnly=true branch: only favorited regular items returned, composites excluded,
    empty list when no favorites, query filters within favorited set, empty query = % wildcard
  * favoritesOnly=false branch: both regular and composite returned, unfavorited included,
    isComposite=true on composite results, non-null savedItemId on composites,
    isComposite=false+null savedItemId on regular, empty query returns all,
    query string filters both types
  * INV: same data — favoritesOnly=true result is strict subset of false result; flag recorded;
    default value is false
  * favorited field on returned drafts: true/false correctly propagated
  * BVA: whitespace-only query → trimmed to empty → returns all items (% wildcard behaviour)

**Test count:** 498 pass, 1 fail (pre-existing: image smoke test requires live CF Worker network).
Previous baseline was 426 pass. Delta: +72 tests.

**Still open:**
- searchFoodHistory UNION SQL correctness at DB level (LIKE semantics, MAX(m.date) ordering,
  COALESCE) still needs NativeDatabase.memory(). Requires adding sqlite3_flutter_libs as
  a dev_dependency. Documented with TODO in search_food_history_test.dart line 11.
- SavedItemsSheet._delete confirmation dialog path untested (AlertDialog interaction complexity).

**Patterns:**
- find.text(name) fails when a ListTile title is constructed as `name + calStr` with non-null
  calories. Always use null-calories drafts in search result fakes, or use find.textContaining.
- The ListTile in CreateSavedItemSheet concatenates name and calStr in a single Text widget —
  not two separate widgets. This differs from FoodHistorySearchSheet which uses subtitle for
  macro info, so the same `find.text(name)` approach does work there.
