# food-journal as a host surface for a virtual pet

Scope: map where journaling events happen and where a pet could read or show state. No pet design. Paths are repo-relative with the `food-journal/` prefix. "Fact" is seen in code or docs. "Inference:" is my reading.

## 1. Stack

Facts:

- Flutter app, Dart SDK `^3.9.2` (`food-journal/app/pubspec.yaml:7`). `flutter_local_notifications` is pinned at `^18.0.1` because v21+ needs Dart 3.10 (`food-journal/.claude/CLAUDE.md:226`).
- State management is plain `StatefulWidget` + `setState`. There is no Riverpod, Bloc or Provider (`food-journal/docs/STACK.md:16-18`; none of them is in `food-journal/app/pubspec.yaml:9-27`).
- Service injection is direct instantiation. Each screen builds its own `StorageService()` (`food-journal/docs/STACK.md:51-61`; `food-journal/app/lib/screens/home/home_screen.dart:26-27`). Widgets take an optional storage override as a test seam (`food-journal/app/lib/screens/home/home_screen.dart:17`, `food-journal/app/lib/screens/shell/app_shell.dart:14`).
- Persistence is drift on SQLite. `AppDatabase.currentSchemaVersion = 16` (`food-journal/app/lib/services/database/app_database.dart:187`). The database is a process-wide singleton (`food-journal/app/lib/services/database/app_database.dart:176-178`). It is opened with `driftDatabase(name: 'food_journal')` in the app documents directory (`food-journal/docs/STACK.md:153-155`).
- Settings use `shared_preferences` through `SettingsService` (`food-journal/app/lib/services/settings_service.dart:1`).
- Backend: a Cloudflare Worker, `food-journal/worker/src/index.js`. It only does AI parsing (`parse_meal`, `parse_medication`) and `food_search`. The Gemini key stays server-side (`food-journal/README.md:26`). The app reaches it through `WorkerAiService` using `MEAL_PARSER_URL` from `.env` (`food-journal/app/lib/services/worker_ai_service.dart:28`).
- Auth: there is no user account. The Worker states "No auth on the Worker endpoint, rate limiting via Cloudflare only" (`food-journal/worker/src/CONTEXT.md:101`). An optional bearer token selects a paid Gemini key (`food-journal/worker/src/gemini.js:24`). The app's only construction of `WorkerAiService` is `AiService.fromEnv()` with no token (`food-journal/app/lib/services/ai_service.dart:80`). A grep for login/account/sign-in/firebase in `app/lib` hits only `storage_service.dart` (a loose string match, not auth).
- Local-first: yes. All journal data is on device, with no cloud sync (`food-journal/README.md:3`, `food-journal/docs/FEATURES.md:190`). Only AI parsing uses the network, and every AI flow has a manual fallback (`food-journal/.claude/CLAUDE.md:153`). Settings can turn AI off (`food-journal/app/lib/services/settings_service.dart:7-10`).
- OCR for receipts runs on device with ONNX models, not the Worker (`food-journal/app/pubspec.yaml:26,42-44`).

Inference: a pet with no backend and no account fits the existing "all local" promise. Any pet state would have to live in the local DB or in SharedPreferences.

## 2. Journal event inventory

All "persists" paths are `food-journal/app/lib/...`. `StorageService` is `services/storage_service.dart`.

| Event | Screen (save point) | Service method that persists | Tables written |
| --- | --- | --- | --- |
| Meal logged (create) | `screens/log_meal/log_meal_screen.dart:353` | `StorageService.saveMeal` `services/storage_service.dart:33` | `meals`, `food_items`, `ingredients` in one transaction (`:38-83`). Then `meal_fingerprints`, unawaited (`:85` → `services/meal_memory/meal_memory_service.dart:201`) |
| Meal edited | `screens/log_meal/log_meal_screen.dart:343` | `StorageService.updateMeal` `services/storage_service.dart:162` | `meals`, delete and reinsert `food_items` and `ingredients` |
| Meal deleted | `screens/meal_detail/meal_detail_screen.dart` (not opened; caller not verified) | `StorageService.deleteMeal` `services/storage_service.dart:221` | deletes `ingredients`, `food_items`, `reaction_logs`, `meals` |
| Medication logged | `screens/log_medication/log_medication_screen.dart:267` | `StorageService.saveMedication` `services/storage_service.dart:285` | `medications` |
| Medication edited | `screens/log_medication/log_medication_screen.dart:261` | `StorageService.updateMedication` `services/storage_service.dart:263` | `medications` |
| Feeling check-in (standalone or meal-linked) | `screens/checkin/checkin_screen.dart:311` | `StorageService.saveReactionLog` `services/storage_service.dart:696` | `reaction_logs` (`mealId` null means standalone, `app_database.dart:51`) |
| Feeling side effects | `screens/checkin/checkin_screen.dart:325,334` | `updateMealSymptoms` `services/storage_service.dart:157`; `applyBlame` `services/storage_service.dart:491` | `meals.overall_symptoms`; `food_suspicions`. `applyBlame` is wrapped in try/catch and is advisory (`checkin_screen.dart:332-340`) |
| Feeling edited | `screens/checkin/checkin_screen.dart:300` | `StorageService.updateReactionLog` `services/storage_service.dart:372` | `reaction_logs` |
| Water logged | `screens/log_water/log_water_sheet.dart:99` | `StorageService.saveWaterLog` `services/storage_service.dart:846` | `water_logs` |
| Weight logged | `screens/log_weight/log_weight_screen.dart:101` | `StorageService.saveWeightLog` `services/storage_service.dart:885` | `weight_logs` |
| Receipt scan (confirmed items into pantry) | `screens/receipt_review/receipt_review_screen.dart:243` | `StorageService.addPantryItems` `services/storage_service.dart:987` | `pantry_items`. The photo and OCR result queue as files in the cache dir, not the DB (`services/receipt_queue.dart:50-53,67`) |
| Saved item (food template) created | `widgets/create_saved_item_sheet.dart:195` | `StorageService.saveSavedItem` `services/storage_service.dart:949` | `saved_items` |
| Food favorite toggled | not traced (screen not opened) | a method just above `services/storage_service.dart:837` (name not read) | `food_memories.favorited` (`:837-839`) |
| Grocery list | `widgets/grocery_list_card.dart:91` | `SettingsService.setGroceryDraft` `services/settings_service.dart:49` | none. It is a SharedPreferences string `grocery_draft` (`services/settings_service.dart:39`) |
| Meal plan | `screens/meal_planning/meal_planning_screen.dart:62` | NOT FOUND. The screen text says "Planning lands in the next update" and no storage call appears in that file | none |
| Body output (WC) | none | NOT FOUND. Documented as "planned, not implemented" (`.claude/CLAUDE.md:184`, `docs/FEATURES.md:122`) | none |

Other writers (same service methods, but not user journaling):

- JSON import calls `saveMeal`, `saveReactionLog`, `saveMedication`, `saveWaterLog`, `saveWeightLog` and `saveSavedItem` in bulk (`services/import_service.dart:359-391`).
- The debug seed calls `saveMeal` (`services/seed_service.dart:35`), run from `main.dart:25-27` only in debug builds when there are no meals.
- `saveMeal`'s fingerprint write goes straight to the database from `services/meal_memory/meal_memory_service.dart:201,219`, not through `StorageService`.

Check-in notification scheduling happens in the screens, not in storage. Meal save calls `_notifications.scheduleCheckin` (`screens/log_meal/log_meal_screen.dart:358`). Medication save and edit call it (`screens/log_medication/log_medication_screen.dart:264-268`). Water and weight saves do not schedule anything (grep of `scheduleCheckin` in those two folders found no match).

## 3. Single choke point

Facts:

- There is no single event hook today. Every table write for journal entries goes through `StorageService` methods, with one exception: `MealMemoryService` writes `meal_fingerprints` directly (`services/meal_memory/meal_memory_service.dart:201`). A grep for `_db.into/insert/update/delete` outside `storage_service.dart` found only that file.
- `StorageService` is not a singleton. Each screen constructs its own (`docs/STACK.md:51-61`) and `dispose()` is a no-op (`services/storage_service.dart:1066`). The shared object is `AppDatabase` (`services/database/app_database.dart:176-178`).
- `main.dart:24-28` creates a throwaway `StorageService` for the seed and then calls `dispose()`.
- The README claims "service methods are designed to be exposable as Claude tool-use functions" (`README.md:100`). That is an interface goal, not an event bus.

Minimum set of methods for a "journal event happened" hook, user-created entries only:

1. `saveMeal` (`services/storage_service.dart:33`)
2. `saveMedication` (`:285`)
3. `saveReactionLog` (`:696`)
4. `saveWaterLog` (`:846`)
5. `saveWeightLog` (`:885`)
6. Optionally `addPantryItems` (`:987`), if receipt scans count, and `saveSavedItem` (`:949`).

Caveats on that set:

- Import and seed call the same six methods (`services/import_service.dart:359-391`, `services/seed_service.dart:35`). A hook there would fire on every imported row unless it can tell the callers apart. NOT FOUND: any parameter or flag that marks a call as an import.
- A hook on `StorageService` instances would not be shared across screens, because each screen owns its own instance. Inference: a hook would need a static or global notifier, or it would need to watch the singleton `AppDatabase` tables (drift supports table watch streams) instead of the service.
- The save methods return the new row id (`saveMeal`, `saveMedication`, `saveReactionLog`, `saveWaterLog`, `saveWeightLog`), so a wrapper could act on the id.

## 4. Streak and consistency data

Fact: I found no method that computes streaks, "days journaled" or "last log time". `StorageService` exposes list getters only (`services/storage_service.dart:89-155,304,336,357,873,914`). The home screen derives its day groups in Dart (`screens/home/home_screen.dart:78-114`).

All three requested measures are computable from existing columns:

| Source | "Which day" column | Time columns | Notes |
| --- | --- | --- | --- |
| `meals` | `date` (DateTime, `app_database.dart:13`) | `time` (text, `:14`); `created_at` (`:18`) | `date` is user-picked and can be backdated (`log_meal_screen.dart:331-336` uses `_mealDate` and `_mealTime`) |
| `medications` | `date` (`:103`) | `time` (`:105`); `created_at` (`:114`) | |
| `water_logs` | `date` (`:131`) | `time` (`:133`); `created_at` (`:136`); `amount_ml` (`:134`) | |
| `weight_logs` | `date` (`:140`) | `time` (`:142`); `created_at` (`:146`) | |
| `reaction_logs` | `checkin_time` (DateTime, `:52`) | `mood` (`:55`), `severity` (`:54`) | No separate created_at. Standalone rows have `meal_id` null (`:51`) |
| `pantry_items` | `added_at` (`:168`) | `created_at` (`:169`) | receipt and pantry side |

- Days journaled: the distinct calendar days over `meals.date`, `medications.date`, `water_logs.date`, `weight_logs.date` and `reaction_logs.checkin_time`. `home_screen.dart:108-114` already unions the same five into one sorted date set.
- Meals logged today: count rows in `meals` where `date` is today. `getMealsInRange` takes `from`/`to` (`services/storage_service.dart:104`).
- Gap since last log: the maximum of those date columns, or `created_at` for the real moment of logging. The `time` columns are formatted strings, so they are not sortable. For meals it is `_mealTime.format(context)` (`log_meal_screen.dart:336`), which depends on locale.
- Backdating risk: `date` is the event date, `created_at` is the save moment. They differ when a user logs yesterday's meal. A pet reading "last log" would need to choose between them (a fork for the rank above, not decided here).
- There is no delete tombstone. Deleting an entry removes its row (`services/storage_service.dart:221,281,869,910`), so anything derived from rows can go backward.
- Index coverage: `idx_meals_date` and `idx_medications_date` exist (`app_database.dart:401,404`). There are no indexes on `water_logs.date` or `weight_logs.date` in `_createIndexes` (`:398-410`).

## 5. UI surfaces

`food-journal/app/lib/main.dart:47-54` mounts `AppShell` at `/` and defines routes `/log`, `/log_medication`, `/log_weight`, `/export`, `/blame-history`. `/meal`, `/checkin`, `/edit_*` are in `onGenerateRoute` (`main.dart:55-91`).

App shell (`screens/shell/app_shell.dart`):

- A `LinedPaperBackground` wraps a `Stack`. The bottom layer is a tinted "folder body" for the active tab (`app_shell.dart:44-47,142-180`). The top layer is a transparent `Scaffold` (`:48-49`).
- Navigation is two folder tabs in the AppBar title: "Food Journal" and "Meal Planning" (`:23-34,58-64`). It is not a bottom nav bar.
- The body is an `IndexedStack` of `HomeScreen` and `MealPlanningScreen` (`:67-75`). Both stay mounted.
- AppBar actions, right side: Export and Blame history (journal tab only), then Settings last so it stays fixed on both tabs (`:84-115`).

Home screen (`screens/home/home_screen.dart`):

- The body is one of: loading spinner, error with retry, "Nothing logged yet." empty state, or a `ListView` of `WeekSummarySection` per week (`:215-267`). The list has `bottom: 100` padding (`:246`) so the FAB does not cover the last row.
- Week sections hold date sections and tiles (`widgets/home/week_summary_section.dart`, `date_section.dart`, `water_summary.dart`, `weight_tile.dart`, `feeling_tile.dart`, `medication_tile.dart`). I did not open those widget files.
- The FAB is a speed-dial with five options in this order (top to bottom): Medication, Feeling, Weigh-in, Water, Food (`:291-330`). It sits at `endFloat` or `startFloat` when left-handed (`:208-210`).
- There is no header or banner region on the home screen itself. The AppBar belongs to the shell.
- The home screen reloads its feed on return from every navigation (`:159-163`) and after the water dialog (`:165-175`). Anything that wants to refresh after a log can piggyback on that reload.

Where a small persistent widget could fit (description only):

- The shell `Stack` (`app_shell.dart:45`) is above the Scaffold, so a `Positioned` child there would persist across both tabs.
- The AppBar `actions` list (`:87-115`) takes small widgets, but the settings gear is deliberately pinned last.
- The home `Stack` (`home_screen.dart:194-206`) already holds the body and a tap-catcher. The FAB occupies one corner and left-handed mode moves it to the other, so a widget in a bottom corner would have to follow `_leftHanded`.

## 6. Notifications

Fact (`services/notification_service.dart`):

- It does one thing: schedule a local "How did you feel after $label?" notification at entry time plus a delay (`:35-68`). The delay is the `delayMinutes` argument, else `CHECKIN_DELAY_MINUTES` from `.env`, else 90 (`:13-16,41`).
- It skips scheduling if the time is already past (`:47`).
- The notification id is the entry id and the payload is `checkin:$entryId` (`:50,66`). `cancelCheckin(entryId)` cancels by id (`:70-72`).
- `initialize()` sets up timezones and asks for the Android notification permission at startup (`:18-33`, called from `main.dart:30`).
- Not found: recurring or daily reminders, a "you haven't logged" nudge, a payload tap handler. The `initialize` call passes no `onDidReceiveNotificationResponse` (`:25-27`), so I could not see where a tap opens the check-in screen. That is a doc claim (`README.md:73-74`, `docs/ARCHITECTURE.md:286-288`) I could not confirm in code. NOT FOUND in `notification_service.dart` or `main.dart`.
- Id collision risk, an Inference: a meal id and a medication id share one id space (`:50` uses `entryId` directly), so meal 5 and medication 5 would overwrite each other's reminder. Existing behavior, not a pet concern unless pet notifications reuse the service.

## 7. Settings

Fact:

- `SettingsService` is the only `SharedPreferences` wrapper (`services/settings_service.dart:41-43`). Each getter and setter calls `SharedPreferences.getInstance()` and reads or writes one key, with the default in the getter. Example: `isAiEnabled` defaults to `true` (`:7-10`), `isLeftHanded` defaults to `false` (`:17-20`). Keys: `ai_enabled`, `left_handed`, `card_collapsed_<card>`, `grocery_draft` (`:4-5,31,39`).
- `SettingsDialog` loads both booleans with `Future.wait` and renders one `SwitchListTile` each (`widgets/settings_dialog.dart:20-31,43-60`). The shell opens it and then calls `HomeScreen.reloadSettings()` (`screens/shell/app_shell.dart:117-123`, `home_screen.dart:179-182`). `reloadSettings` re-reads only left-handed mode.

Adding a feature flag, following the existing pattern (Inference, from reading the above):

1. Add a key constant and a getter/setter pair with a default in `SettingsService`.
2. Add a third entry to the `Future.wait` list and a `SwitchListTile` in `SettingsDialog`.
3. Make the host (shell or home) re-read the flag after the dialog closes, the same way `reloadSettings` does.
4. SharedPreferences does not enter the JSON export or import (`ExportTypes` has no settings field, `services/export_service.dart:32-53`), so a flag is device-local.

## 8. Schema rules

Rules as documented:

- "No column rename or removal without a drift migration." "Every new table or migration must have a corresponding integration test in `migration_order_test.dart`" (`docs/ARCHITECTURE.md:10-13`). `.claude/CLAUDE.md:154` states the same contract.
- Migrations are an `onUpgrade` chain of `if (from < N)` blocks, one per version, in order (`services/database/app_database.dart:202-391`). Additive changes use `CREATE TABLE IF NOT EXISTS` plus `customStatement` (v16, `:376-391`; v13, `:350-363`).
- `onCreate` runs `createAll()` and then `_createIndexes()` (`:198-201`).
- `migrationStepVersions` must list every step in non-decreasing order (`:189-191`).
- Fresh installs and upgrades take different code paths. Each new table therefore needs both a drift `Table` class, registered in `@DriftDatabase(tables: [...])` (`:174`), and a matching hand-written `CREATE TABLE` in the upgrade block.
- Generated code is `app_database.g.dart`, which drift codegen produces (`start.bat` runs it, `README.md:268`).

What the tests actually check:

- `app/test/services/migration_order_test.dart:20-26` asserts `currentSchemaVersion == 16`. Lines `28-31` assert `migrationStepVersions.last == 16`. Lines `38-50` assert the steps are non-decreasing. The file says a real DB migration path needs native sqlite3 and is covered on-device (`:13-17`).
- A bump to version 17 therefore requires editing both literal `16`s in that test.
- `app/test/services/migration_v15_indexes_test.dart` also exists (not opened).

Export and import coverage today:

- Export payload `version: 3` carries `meals` (with nested per-meal reaction logs), `medications`, `food_memories`, `water_logs`, `weight_logs`, `saved_items` (`services/export_service.dart:164-176`). `ExportTypes` gates each (`:32-53`).
- Not exported: `pantry_items`, `food_suspicions`, `suspicion_exclusions`, `meal_fingerprints`. Also standalone feelings: `buildPayload` only reads reaction logs per meal via `getReactionLogsForMeal` (`:112`), and no call fetches `getStandaloneReactionLogs`. Inference: standalone check-ins are missing from the export (I did not read `mealToJson`).
- Import parses `water_logs`, `weight_logs`, `saved_items` and others from the same keys (`services/import_service.dart:185-232`), detects dupes (`:300-339`) and writes through `StorageService` (`:351-393`).
- A new table needs: a `Table` class and registration, a migration block plus `migrationStepVersions` entry, `currentSchemaVersion` bump, the two test constants, getter/save methods on `StorageService`, a decision on export and import (new `ExportTypes` flag, JSON key, import dupe key, `ImportSelection` index set), and updated docs. Docs already disagree on the version (see Doc vs code).
- If pet state were in SharedPreferences instead, none of the migration or export rules would apply. Inference: that also means it would not survive export and import, and not a reinstall.

## 9. Project conventions

- Spec loop: `SPEC → REUSE-SCAN → CRITERIA→TESTS → BUILD → VERIFY → DEPOSIT` via the `/spec` skill (`specs/README.md:13-14`). Every non-trivial feature deposits `{spec, test}` (`specs/README.md:18`). Specs are `specs/<feature>.spec.md` with sections: Requirement, Constraints (inherited), Decisions, Acceptance criteria (Given/When/Then), Anchors, Verifies-with (`specs/README.md:31-59`). "New behavior on an existing screen gets its own AC / spec amendment, never bundle silently" (`specs/README.md:21-22`). Existing specs for the surfaces above: `log_medication`, `log_feeling`, `meal_planning`, `receipt_scan`, `receipt_queue`, `groceries` (all in `specs/`).
- Workflow gates: Intake → Plan (user approves) → Spec → Develop → Test → Iterate → Deposit (`.claude/CLAUDE.md:110-120`). PLAN is required for multi-file or architectural work (`:34-49`).
- Tests: acceptance criteria map 1:1 to tests at the cheapest layer, widget with a fake before integration before e2e (`specs/README.md:19-20`). Tests are "behavioral contracts (MFT/INV/DIR/BVA/EQUIV)" and every test carries metadata (testTheory + contract + implication) (`.claude/CLAUDE.md:99-102`).
- Coverage gate hook: PostToolUse on Write/Edit runs `.claude/hooks/dart-coverage-gate.js`. For any `.dart` under `/app/lib/` that is not a test or generated file, it prints an instruction to spawn the `test-scout` agent before calling the task complete (`dart-coverage-gate.js:26-38`). It always exits 0, so it only nudges and never blocks. SessionStart runs `test-health.js` (`.claude/settings.json`, grep lines 3-20).
- Anchors: every new interactive widget gets `Semantics(identifier: '...')` and a row in `specs/anchors.md` in the same commit (`.claude/CLAUDE.md:206-215`; `specs/anchors.md:10-11`). Naming: `screen-name`, `btn-action`, `item-<id>`.
- Style: `StatefulWidget` + `setState`, direct service construction, typed result objects instead of exceptions at the UI (`docs/STACK.md:16-71`). Schema is a contract, AI-optional (`.claude/CLAUDE.md:153-155`). Comments only for non-obvious algorithms or "why" (`.claude/CLAUDE.md:83`).
- Test seams: widgets take optional storage overrides, and tests use fake storage (`screens/shell/app_shell.dart:12-14`; `app/.claude/agent-memory/test-scout/feedback_fake_storage_pattern.md` exists, not opened).
- Pinned constraints: notifications v18 (Dart 3.9.2 ceiling), `flutter_timezone` v5 uses `.identifier`, core library desugaring in `build.gradle.kts` (`.claude/CLAUDE.md:224-228`).
- Flagged for the rank above, not decided here: the repo's non-goals include "No social features" and "No calorie goals or diet plans" (`docs/FEATURES.md:190-193`). A pet is not listed either way. Every other feature rides the spec process, so a pet would need its own spec file.

## Doc vs code

| Claim | Where | Reality |
| --- | --- | --- |
| Schema is v12 | `README.md:88,98,190` | Code is v16 (`services/database/app_database.dart:187`); `.claude/CLAUDE.md:166` agrees with code |
| Schema is v15 | `docs/ARCHITECTURE.md:110,137`; `docs/STACK.md:95`; `.claude/CLAUDE.md:184` | Code is v16. `pantry_items` (v16) is missing from the ARCHITECTURE.md schema diagram |
| "Three entry types: meal, medication, body_output" | `docs/ARCHITECTURE.md:20-25`; `docs/FEATURES.md:11` | Code has meal, medication, water, weight and standalone feeling; no body_output table. `.claude/CLAUDE.md:156` is the accurate version |
| `AiService` has a "Claude direct impl" fallback | `docs/ARCHITECTURE.md:101,261`; `docs/STACK.md:137-141` | `AiService.fromEnv()` returns `WorkerAiService` only (`services/ai_service.dart:80`). `README.md:107` calls Worker the "sole implementation" |
| "Provider is declared in the existing repo but unused" | `docs/STACK.md:18` | Not in `app/pubspec.yaml` dependencies |
| CSV export with `entry_type` column | `README.md:48` | `docs/FEATURES.md:70` says the export produces JSON, not CSV. Export code builds JSON (`services/export_service.dart:164-176`) |
| Export covers "all entry types" | `.claude/CLAUDE.md:161` | Excludes pantry, suspicions, fingerprints, and (per `buildPayload`) standalone feelings |
| Tap on a check-in notification opens the check-in screen | `README.md:73-74`; `docs/ARCHITECTURE.md:286-288` | No tap handler visible in `services/notification_service.dart:25-27` or `main.dart` |
| "No backend" | `.claude/CLAUDE.md:162`; `docs/FEATURES.md:190` | A Worker exists for AI parsing (`worker/src/index.js`). User data is still local only, so this is wording, not substance |
| Meal Planning is a feature tab | `app_shell.dart:29-33` | Screen says planning "lands in the next update"; only pantry and grocery cards exist (`screens/meal_planning/meal_planning_screen.dart:27,62`) |

## Open questions

1. Where does the user delete or edit from, and do any of those paths bypass the `StorageService` methods listed? I traced creates in detail but only grepped deletes (`services/storage_service.dart:221,281,388,869,910`), and I did not read `meal_detail_screen.dart` or the home tiles.
2. Does notification tap routing exist somewhere I did not read (for example `main.dart` is silent)? I found no handler.
3. Is `food_memories` updated on each reaction save? The doc says so (`docs/ARCHITECTURE.md:299-306`), but I did not find the code in the sections I read. This affects whether a "reaction" event touches more tables than listed in section 2.
4. Which time should a pet treat as "the log moment": event `date`/`time` (backdatable) or `created_at`? Not decided by anything I read.
5. Whether import and seed writes should count as events for a hook. No flag distinguishes them today.
6. Which widget files under `widgets/home/` (week and day sections) are the right place to read per-day state. I did not open them.
