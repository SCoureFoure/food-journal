---
name: probe_flutter_2026-05-17
description: First flutter+ux layer audit — coverage baseline, new test files created, all pass
metadata:
  type: project
---

## 2026-05-17 layer: flutter + ux

**Probed:** app/lib/services/, app/lib/widgets/, app/lib/models/, app/test/

**Found:**
- Zero test coverage for: ReactionLevel enum, FoodItemDraft.fromJson, ImportSelection.totalCount,
  MealImportRecord.dupeKey edge cases (empty items, duplicates, single item), WorkerAiService
  empty-URL guard, and all widgets in app/lib/widgets/.
- `settings_service.dart`, `storage_service.dart`, `notification_service.dart`, `seed_service.dart`
  all require platform channels (SharedPreferences / SQLite / flutter_local_notifications) — not
  testable as pure unit tests without mocktail. Skipped pending mock infrastructure.
- `worker_ai_service._parseNum` is private — cannot test directly without widening visibility.
  Equivalent coverage lives in food_item_draft_test.dart (FoodItemDraft.fromJson numeric coercion).
- No `mocktail` or `mockito` in pubspec.yaml dev_dependencies — pure logic tests only.
- Semantics anchors on home_screen.dart and log_meal_screen.dart already verified clean (prior work).

**Fixed:**
- Created app/test/models/reaction_level_test.dart (7 tests)
- Created app/test/models/food_item_draft_test.dart (9 tests)
- Created app/test/services/import_selection_test.dart (9 tests)
- Created app/test/services/worker_ai_service_test.dart (4 tests)
- Created app/test/widgets/reaction_badge_test.dart (7 tests — one per ReactionLevel + extras)
- Created app/test/widgets/macro_totals_bar_test.dart (4 tests)
- Created app/test/widgets/day_totals_bar_test.dart (6 tests — includes all-zero collapse path)
- Created app/test/widgets/loading_button_test.dart (6 tests — disabled/enabled/spinner/semantics)
- Created app/test/widgets/error_display_test.dart (6 tests — ErrorBanner + ErrorRetry)
- Created app/test/widgets/symptoms_banner_test.dart (4 tests)
- Created app/test/widgets/medication_tile_test.dart (7 tests — dose formatting int/float/null)
- All 88 tests pass (includes pre-existing 16 export_import tests + 1 widget placeholder).

**Still open:**
- settings_service, storage_service, notification_service, seed_service: need mocktail or
  in-memory DB shim to test. Worth adding mocktail to dev_dependencies in a future pass.
- worker_ai_service context-prepend logic (effectiveText assembly): the string concatenation
  is buried inside parseMeal before the HTTP call. Needs HTTP stub to verify. Document as
  integration test candidate.
- FoodMemoryCard has a hardcoded `ReactionBadge(level: ReactionLevel.mild)` with a TODO comment
  ("derive from reactionPattern") — this is a known bug, not a test gap.

**Patterns:**
- Services that touch platform channels (DB, prefs, notifications) have zero testable surface
  without mocks. Add mocktail before the next service-layer pass.
- Widget tests: use `_wrap(child)` helper returning `MaterialApp(home: Scaffold(...))` consistently.
- MedicationTile requires a Navigator ancestor or tap on expansion will throw; wrap in Navigator
  for widget tests that expand the tile.
- flutter test output repeats test name for each platform variant (vm/chrome/etc) — "+88" with
  only ~13 unique tests is expected behaviour, not duplicates.

**New probe targets:**
- app/lib/screens/ — none of the screens have widget tests yet. Complex state (async load,
  AI-on/off branches) makes them harder but worth adding smoke tests for load/render paths.
- FoodMemoryCard hardcoded ReactionLevel.mild bug — consider a fix or at least a test asserting
  the current (broken) behaviour so regressions are caught.
