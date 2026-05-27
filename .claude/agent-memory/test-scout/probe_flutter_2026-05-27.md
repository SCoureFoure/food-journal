---
name: probe_flutter_2026-05-27
description: v7 feature audit — SavedItems/FoodItemDraft composite fields/MealTile calorie subtitle/favorites shortcut tests added; 426 tests all pass
metadata:
  type: project
---

## 2026-05-27 layer: flutter (targeted — v7 feature audit)

**Probed:** app/lib/models/saved_item.dart, app/lib/models/food_item.dart (isComposite/savedItemId),
app/lib/services/storage_service.dart (searchSavedItems/saveSavedItem/deleteSavedItem),
app/lib/widgets/food_history_search_sheet.dart (initialFavoritesOnly, composite rendering),
app/lib/widgets/saved_items_sheet.dart, app/lib/widgets/home/meal_tile.dart (_totalCalories),
app/lib/screens/log_meal/log_meal_screen.dart (_addFromFavorites), all existing test files.

**Found:**

1. Zero coverage for SavedItem model (new v7 model — no test file existed).

2. FoodItemDraft.isComposite and FoodItemDraft.savedItemId had no tests.
   The fields exist since v7 but food_item_draft_test.dart only covered favorited
   and fromJson parsing, not the composite fields.

3. MealTile._totalCalories getter (calorie total on collapsed tile subtitle) had no
   widget tests. The getter's null-for-zero behaviour was untested — this matters
   because "0 cal" subtitle would be wrong UX for items with no calorie data.

4. FoodHistorySearchSheet.initialFavoritesOnly param was untested: no test verified
   the sheet pre-selects the Favorites chip or calls searchFoodHistory with
   favoritesOnly=true on initial load.

5. FoodHistorySearchSheet composite item rendering was untested: bookmark_outline
   leading icon, delete button replacing star button, and mixed-list (one regular +
   one composite) were not covered.

6. StorageService.searchSavedItems / saveSavedItem / deleteSavedItem had no unit
   tests. The JSON encode/decode round-trip for componentsJson was untested.

7. SavedItemsSheet widget had no test file at all.

8. _FakeStorage in food_history_search_sheet_test.dart was missing deleteSavedItem
   override — would have crashed if composite delete tests tried to call it.

**Fixed:**

- Created app/test/models/saved_item_test.dart (15 tests):
  field construction, null id/macros, empty/single/special-char components, zero macros.

- Appended to app/test/models/food_item_draft_test.dart (14 new tests):
  isComposite defaults false, savedItemId defaults null, fromJson produces both false/null,
  isComposite=true construction, isComposite independent of favorited, BVA savedItemId=0/1.

- Appended to app/test/widgets/meal_tile_test.dart (5 new tests):
  subtitle shows "time · N cal" when loaded, null-cal items, empty items, zero-sum suppressed,
  mixed null+non-null (null contributes 0).

- Appended to app/test/widgets/food_history_search_sheet_test.dart (13 new tests):
  initialFavoritesOnly=true pre-selects chip, initial load passes favoritesOnly=true,
  default opens on All, empty-favorites message; composite shows bookmark icon not star,
  composite shows delete button, non-composite shows star not delete, mixed list,
  tapping composite preserves isComposite+savedItemId in onSelect callback.
  Also added deleteSavedItem override to _FakeStorage.

- Created app/test/widgets/saved_items_sheet_test.dart (11 tests):
  empty state, search field present, results list, subtitle parts, ingredients shown,
  Semantics identifiers per item and delete button, search filtering, no-match message,
  selection callback preserves isComposite+savedItemId, search-field Semantics anchor.

- Created app/test/services/storage_saved_items_test.dart (22 tests):
  saveSavedItem returns positive id, distinct ids, item appears in search, isComposite=true,
  macros preserved, components JSON round-trip; searchSavedItems empty/whitespace query,
  filtering case-insensitive/no-match/partial; savedItemId populated correctly, two items
  distinct ids; deleteSavedItem removes item, preserves others, no-op on unknown id;
  BVA: empty components, null macros.

**Test count:** 426 non-integration tests, all pass.

**Still open:**
- searchFoodHistory UNION SQL (food_items + saved_items combined query) not tested at DB
  level — needs in-memory NativeDatabase. Same constraint as before.
- SavedItemsSheet._delete confirmation dialog path not tested (requires dialog interaction
  in widget test; the delete-button Semantics identifier is asserted but the dialog flow
  is not driven because AlertDialog requires pumpAndSettle over Navigator.pop).
- CreateSavedItemSheet has no widget test — its logic (EditableFoodItemCard components,
  live macro totals, save callback) is not covered.

**Patterns:**
- Any new sheet widget needs: storageOverride param, empty-state test, results-list test,
  selection callback test, Semantics anchor test. This is the established pattern now.
- Fake StorageService subclasses must override ALL methods called by the widget under
  test, including delete methods, or tests will compile but crash at runtime.
- _totalCalories returning null (not 0) for zero-sum is intentional UX decision —
  test documents this so future devs don't accidentally "fix" it.
