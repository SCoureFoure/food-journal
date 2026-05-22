---
name: probe_flutter_2026-05-22
description: v6 favorites feature audit — migration bug fixed, FoodMemory/widget tests added, StorageService made lazy, pre-existing WeekSummarySection test fixed
metadata:
  type: project
---

## 2026-05-22 layer: flutter (targeted — v6 feature audit)

**Probed:** app/lib/models/food_memory.dart, app/lib/services/storage_service.dart,
app/lib/services/database/app_database.dart, app/lib/widgets/food_history_search_sheet.dart,
app/lib/screens/log_meal/log_meal_screen.dart, all test/ files.

**Found:**

1. REAL BUG — migration block ordering: `if (from < 6)` appeared BEFORE `if (from < 5)` in
   `AppDatabase.onUpgrade`. These two blocks are currently independent (different tables), but the
   wrong order is a latent hazard — any future v7 migration that depends on v5 tables existing
   would silently execute in the wrong order for users upgrading from v4 directly.

2. `FoodHistorySearchSheet` was not testable — it created `StorageService()` eagerly in a field
   initializer. Since `StorageService._db = AppDatabase()` triggers `driftDatabase` (native sqlite3),
   any subclass in tests would crash with a pending-timer assertion failure.

3. `StorageService._db` and `_memory` were eagerly initialized — forced the singleton DB connection
   at instantiation time, blocking all subclass-based fakes in headless tests.

4. `WeekSummarySection` constructor gained two required parameters (`waterByDate`, `weightByDate`)
   since its test was written, causing a pre-existing compile failure.

5. Zero test coverage for: FoodMemory.favorited field, FoodMemory.copyWith, searchFoodHistory
   query/result behavior, FoodHistorySearchSheet widget states (empty, results, selection,
   debounce, semantics anchors), and migration version ordering.

6. `AppDatabase` had no static surface accessible from tests — schemaVersion is an instance
   getter on a singleton that requires native sqlite3 to instantiate.

**Fixed:**

- `app_database.dart`: swapped `< 6` and `< 5` blocks to be in ascending order; added
  `static const int currentSchemaVersion = 6` and `static const List<int> migrationStepVersions`
  so tests can assert version and ordering without touching the singleton.

- `storage_service.dart`: changed `final _db = ...` and `final _memory = ...` to `late final`
  so subclasses never trigger the native DB connection unless they actually call DB methods.

- `food_history_search_sheet.dart`: added optional `storageOverride` constructor parameter;
  `_storage` changed to `late final` assigned in `initState`. Production path unchanged
  (falls back to `StorageService()` singleton).

- `week_summary_section_test.dart`: added `waterByDate: const {}` and `weightByDate: const {}`
  to `_section()` helper to match the updated constructor.

- Created `app/test/models/food_memory_test.dart` — 14 tests covering: default values
  (favorited=false, reactionPattern=null, id=null), favorited field construction/read,
  favorited independence from flagged, copyWith behavior (flip, preserve, no mutation),
  BVA occurrences=0 and 1.

- Created `app/test/services/migration_order_test.dart` — 2 REGRESSION tests: currentSchemaVersion
  == 6, and migrationStepVersions is non-decreasing.

- Created `app/test/widgets/food_history_search_sheet_test.dart` — 13 tests covering: empty state
  message, search field presence, result list rendering, subtitle parts (portion/cal/protein),
  null subtitle when no optionals, selection callback fires with correct draft, no-match message
  with quoted query, initial+typed search wires to storageOverride, Semantics anchors for
  search field and each result item, empty-portion-string BVA.

**Test count:** 305 non-integration tests, all pass. Pre-existing integration failures
(image_smoke_test — invalid JPEG rejected by Gemini, parse_meal tests hitting live API)
are unrelated to this work.

**Still open:**
- `searchFoodHistory` SQL logic (GROUP BY LOWER(name), MAX(date) ordering, LIMIT 30) is not
  covered at the DB level — needs an in-memory NativeDatabase test. Requires sqlite3 native
  plugin or drift `DatabaseConnection.delayed` with memory executor. Deferred pending
  mocktail/in-memory DB infrastructure work.
- `toggleFoodFavorite` flip logic not tested at DB level (same constraint).
- `insertFoodMemory` does not write the `favorited` field — it uses `FoodMemoriesCompanion.insert`
  without a `favorited:` param, so inserts always write the DB default (0=false). This means
  `insertFoodMemory` silently drops the favorited state if called after a favorite is set.
  Logged as a known bug, not fixed here (no caller sets favorited before calling insertFoodMemory
  in current code, so no user-visible regression yet).

**Patterns:**
- Services that touch platform channels: make fields `late final` so test subclasses can extend
  without triggering native connections. This is the right pattern going forward.
- Widget injectable services: add `final FooService? fooOverride` + `storageOverride ?? FooService()`
  in `initState`. Keeps production path clean, makes widgets testable.
- Migration blocks must be in ascending `from < N` order. Enforce with `migrationStepVersions`
  constant and regression test.

**New probe targets:**
- `app/lib/widgets/home/date_section.dart` — referenced in week_summary_section_test comment as
  having its own test file; verify that file exists and covers the new waterByDate/weightByDate params.
- `insertFoodMemory` favorited-drop bug — if a future PR adds favorites UI before memory is
  re-inserted, this will silently reset the favorite flag.
