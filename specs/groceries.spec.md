# Spec — Grocery list export

> Status: active · Feature: groceries · Added: 2026-08-29
> Source of truth for generating a shareable grocery list from logged meals, on
> the Export screen
> ([export_screen.dart](../app/lib/screens/export/export_screen.dart)).

## Requirement

The journal already knows what was eaten. This feature reads that back out as a
shopping aid: on the Export screen the user picks a window, taps **Generate &
share**, and gets a plain-text grocery list of the foods behind those meals,
**most frequent first**, handed to the OS share sheet.

The window has two modes:

- **By meals** (default) — the N most recently logged meals, 10 / 30 / 60,
  default 30. Time-independent, so it still produces a list after a gap in
  logging. This is the mode that makes the feature work for an intermittent
  logger, which is why it is the default.
- **By days** — every meal logged in the last N calendar days, 7 / 14 / 30,
  default 30, counting today. Answers "what have I been eating *lately*" when
  recency matters more than sample size.

Frequency is the ranking signal — a food that showed up in four meals is more
likely to need restocking than one that showed up once — so each line carries its
count.

That plain list is journal data, though, not a shopping list: it reads
`- Butter (x2)` / `- Buttermilk (x2)` / `- Vegetable oil (x4)`. So a second control,
**Tidy with AI & share**, sends it to the Worker's `tidy_grocery_list` task, which
merges duplicates and variants into one item, drops the counts, and groups the
result into supermarket sections. That button exists only when AI is enabled in
Settings; the plain button is always there and never depends on it.

The list leaves the app; nothing is consumed back in. There is no receipt scanner,
no pantry, no persisted list, and no reaction filtering in this scope — see
[Deferred](#deferred-not-in-this-scope).

## Constraints (inherited)

- **AI-optional** — the whole generation path makes **no AI call at all**: local SQL
  plus pure Dart, working identically with the network off and AI disabled. The AI
  tidy pass is strictly additive — a second button that is *absent* when AI is off,
  exactly as Log Meal hides "Autofill with AI". A failed tidy surfaces an error and
  shares nothing; it never blocks or replaces the plain export.
- **Schema = contract** — **no schema change.** Reads `meals`, `food_items`, and
  `ingredients` through existing `StorageService` methods. Schema stays at v14.
- **Services as tool interface** — `ExportService.buildGroceryCandidates` /
  `buildGroceryListText` / `exportGroceryList` are typed, single-responsibility, and
  injectable (`now` for tests); the aggregation and the header phrasing are pure
  functions so the meaningful logic is unit-testable without native sqlite3 — the
  same split `food_suspicion.dart` uses.
- **Side-effects** — read-only. Generating a list writes nothing, schedules no
  notification, and creates no journal entry.
- **Local storage only** — the list is built on the device and leaves only through
  the share sheet the user invokes.

## Decisions (pinned 2026-08-29)

1. ~~**It lives on the Export screen**, not a new home app-bar icon and not a new
   route.~~ **SUPERSEDED 2026-08-30 — the grocery list lives on the Meal Planning
   tab.** The original reasoning (Export already owned "pick a window → generate →
   share sheet", and reusing it meant zero new navigation surface) was a placement
   of convenience, and the fiat was called correctly: the user ruled the other way.
   Planning is where a shopping list belongs. The UI now lives in the self-contained
   `GroceryListCard` widget mounted by `MealPlanningScreen`; Export/Import keeps JSON
   export and import only. `ExportService`'s grocery methods did not move. See
   [meal_planning.spec.md](meal_planning.spec.md) decisions 9-12. *(ruled)*
2. **Ingredients are the grain, food-item name is the fallback.** A food item with
   ingredients contributes its ingredient names ("feta cheese", "olive oil"); one
   with none contributes its own name ("Oatmeal"). A dish name is useless in a
   store aisle, and F5 already earmarks the ingredient list for exactly this. The
   two are never both added for one item.
3. **Frequency = distinct meals, not raw occurrences.** A key counts at most once
   per meal, so listing "olive oil" three times inside one meal does not out-rank a
   food genuinely eaten on three separate occasions. *(fiat)*
4. **Sort by count descending, then canonical name ascending.** Ties resolve
   alphabetically so the output is deterministic and diffable.
5. **Identity is the existing canonical key.** `canonicalize()` from
   [food_entity.dart](../app/lib/models/food_entity.dart) groups the rows — the same
   key the blame ledger and the reuse nudge use. No second normalizer, so "Chicken
   Breast" and "chicken breast" are one line here exactly as they are one bucket
   there. The display name is the raw name from the most recent contributing meal.
6. **Two window modes, meals by default.** A day window silently returns nothing
   after a logging gap, which is the failure mode that motivated the second mode.
   The meal window cannot do that while any meal exists, so it leads. *(fiat)*
7. **Fixed presets per mode, not a free date range.** 10 / 30 / 60 meals and
   7 / 14 / 30 days. The screen's existing from/to pickers belong to the JSON
   export and are deliberately **not** wired to this — a grocery list defaulting to
   "all time" is noise. *(fiat)*
8. **Each mode remembers its own size.** Switching By meals → By days → By meals
   returns to the meal size the user last picked; it does not reset. *(fiat)*
9. **"Last N days" includes today.** The window starts at `today - (N - 1) days`,
   so `7` means this calendar day plus the six before it. *(fiat)*
10. **"Last N meals" is newest-first by `(date, createdAt)`.** `getAllMeals`
    returns `createdAt` *ascending* within a date, so the selection re-sorts
    descending before taking N — otherwise "my last meal" would be the *earliest*
    meal of the most recent day. The sort lives in Dart, not SQL, so it is
    unit-testable against a fake storage without native sqlite3.
11. **The meals-mode header reports what was found, not what was asked for.**
    Requesting the last 30 meals when only 12 exist prints
    `from your last 12 meals`. The days-mode header always prints the requested
    window (`last 30 days`) even when nothing matched — that is precisely how an
    empty day-window result explains itself. *(fiat)*
12. **Quantities and units are dropped.** A receipt-grade list would need to sum
    "2 tbsp" against "50 g", which the schema cannot do meaningfully. The
    occurrence count is the honest proxy for "how much do I need". *(fiat)*
13. **Every line carries its count, including one.** `- Olive oil (x1)` — no
    special-casing, so the format has no branch and the user can always see the
    evidence behind the ordering. *(fiat)*
14. **Plain text via the share sheet**, not a file. A grocery list wants to paste
    into notes or a message; `exportJson` keeps the write-a-file-and-share-it path
    for structured data.
15. **An empty result still shares.** The sheet opens with a header and a body line
    — `(no meals logged yet)` when no meals were found at all,
    `(nothing to list from these meals)` when meals were found but every name in
    them was blank or punctuation-only. Two distinct messages because they mean
    different things to the user. *(fiat)*
16. **The list is ephemeral.** Generated on demand, never persisted, no check-off
    state. Persisting named lists earns its schema only once generation is proven
    in real use.
17. **No reaction filtering in this scope.** Cross-referencing the suspicion ledger
    to badge reactive foods is a real feature and a separate one — see Deferred.
18. **The tidy pass is a Worker prompt, not app logic.** `tidy_grocery_list` is a
    new key in `worker/src/prompts.json` and **nothing else** — `isKnownTask` is
    `Boolean(prompts[task])` and `handleParse` is generic text-in / JSON-out, so no
    Worker JavaScript changed. New AI capability, zero new routing surface.
19. **Fixed section vocabulary.** Produce, Meat & Seafood, Dairy & Eggs, Bakery,
    Pantry, Frozen, Beverages, Other — rendered in that order, empty sections
    omitted. A closed set keeps the output stable across calls; an open one lets
    the model invent a new aisle every run. *(fiat)*
20. **The tidied list carries no numbers.** Counts rank the raw list; on a shopping
    list they are noise ("Butter (x2)" is not two butters). The tidy prompt is told
    to drop them outright. *(fiat)*
21. **AI failure throws; it does not fall back.** The user asked for a tidied list —
    silently handing them the plain one is a different artifact. The error surfaces
    on-screen and the plain button still works. *(fiat)*
22. **An empty candidate set skips the AI call.** Nothing to tidy means no network
    round trip; the empty-state text renders locally.
23. **The tidy button is absent when AI is off, not disabled.** Matches Log Meal's
    autofill precedent. *(fiat)*
24. **Grocery failures surface as a SnackBar, not the inline `_error` text.**
    Found on the emulator: both grocery buttons sit at the bottom of the card, and
    the `if (_error != null)` block renders *below* that card — so a failed tidy
    printed its message entirely off-screen and the tap looked like a no-op. The
    SnackBar is scroll-independent. The JSON export keeps the inline text, which
    sits directly above its own button and is visible there. The `Exception: `
    prefix is stripped before display. *(fiat)*
25. **The list renders inline in an editable text field; sharing is a choice, not a
    side effect.** (pinned 2026-08-30) Generating fills a multiline `TextField` in the
    card. Nothing leaves the app until the user asks. Rationale: the share sheet fired
    before the user had seen the list, so a wrong window or a bad parse was only
    discoverable after a full share round trip, and the only remedy was to run it again.
    *(ruled)*
26. **The list is editable, and edits are what the other actions act on.** Copy, Share
    and Tidy all operate on the box contents, not on a regenerated list. Striking the
    things already in the cupboard and then grouping what is left is the intended
    workflow. *(ruled)*
27. **Copy is the primary action, Share is secondary.** Clipboard first, share sheet
    still available. Removing Share entirely was declined — it is how the list reaches a
    messaging app or notes. *(ruled)*
28. **The draft is persisted** in `SharedPreferences` under `grocery_draft`, via
    `SettingsService.groceryDraft` / `setGroceryDraft` / `clearGroceryDraft`. The list is
    generated at home and read in the shop, which is exactly where there may be no signal
    to regenerate. It is not a user preference; it lives on `SettingsService` only because
    that is the app's single SharedPreferences wrapper. No schema change — still v14.
    *(fiat: the storage location, not the persistence itself)*
29. **No redundant actions.** With an empty box there is exactly one control,
    `Generate list`. Tidy, Copy, Share, Retry and Clear appear only once a list exists,
    because there is nothing to tidy, copy, share or clear before then. *(ruled — the
    user asked specifically that a second generate button not sit alongside the first)*
30. **"Tidy with AI" is a transform, not a second generate.** It sends the box contents
    to the Worker and replaces the box with the grouped result; it never re-reads the
    journal, so hand edits survive it. Regenerating is `Retry`, which is a separate,
    explicitly-labelled action. *(ruled)*
31. **`parseGroceryListItems` is the round-trip seam.** A rendered list — plain or
    tidied, hand-edited or not — reads back as bare item names: header lines, blank lines,
    parenthetical placeholders and any line exactly matching `kGrocerySections` drop out;
    everything else is an item with a leading `- ` stripped. A line is a section heading
    only on an exact whole-line match, so a hand-typed `Produce from the market` stays an
    item. *(fiat: the exact-match rule)*

**Superseded 2026-08-30.** The original "generate and share in one step" flow
(`ExportService.exportGroceryList` / `exportTidiedGroceryList`) is no longer what the UI
calls — the card builds the text, shows it, and shares only on request. Those two service
methods remain, unchanged and still tested: they are the tool-callable interface, and
"build a list and share it" stays a legitimate single operation for a caller that is not
the UI.

## Output format

```
Grocery list - from your last 12 meals
Generated 2026-08-29

- Chicken breast (x4)
- Olive oil (x1)
```

Line 1 is `Grocery list - <window label>`, or bare `Grocery list` when the label is
empty (meals mode with nothing logged). Line 2 is the ISO date. Line 3 is blank.
Then one line per candidate, or a single parenthesised body line per decision 15.
No trailing newline. ASCII hyphen throughout — the formatter takes a finished label
string and never branches on mode.

The AI-tidied variant keeps the same two header lines and groups the body:

```
Grocery list - from your last 12 meals
Generated 2026-08-29

Produce
- Onions
- Spinach

Dairy & Eggs
- Butter
```

One blank line between sections, none after the last, empty sections omitted
entirely. No counts anywhere (decision 20).

## Reuse (what this wires, not rebuilds)

| Need | Existing thing used |
|------|---------------------|
| Name identity / grouping key | `canonicalize` (`food_entity.dart`) |
| Meals for the meal window | `StorageService.getAllMeals` (re-sorted in Dart, decision 10) |
| Meals for the day window | `StorageService.getMealsInRange` |
| Items + their ingredients | `StorageService.getFoodItemsWithIngredients` |
| Share sheet | `share_plus`, already a dependency of `ExportService` |
| Screen chrome, loading + error handling | `ExportScreen`'s existing `_isLoading` / `_error` pattern |
| Fake-storage test seam | `_FakeStorage extends StorageService` pattern from `storage_saved_items_test.dart` |

No new `StorageService` method was added — keeping the meal sort in Dart bought
both a smaller surface and a testable membrane.

## Acceptance criteria (Given / When / Then)

**Aggregation (pure — `app/lib/models/grocery.dart`)**

1. **AC1 — grouping, counting, ordering.** Given three meals contributing
   `Chicken breast`/`Olive oil`, `chicken breast`/`Feta cheese`, and `Olive oil`,
   then the list is exactly `Chicken breast (2)`, `Olive oil (2)`,
   `Feta cheese (1)` — ties broken by canonical name ascending.
2. **AC2 — a key counts once per meal.** Given one meal listing `Olive oil`,
   `olive oil`, `OLIVE OIL`, then the result is a single candidate with count
   **1**, not 3.
3. **AC3 — garbage names dropped.** Given names `''`, `'   '`, `'!!!'`, `'Rice'`,
   then only `Rice` survives.
4. **AC4 — empty input.** Given no meals, then the result is an empty list and
   nothing throws.
5. **AC5 — an all-garbage meal still counts as a meal.** Given meals `Rice`,
   `!!!`, `rice`, then `Rice` has count 2.

**Window phrasing (pure — `groceryWindowLabel`)**

6. **AC6 — day label ignores what was found.** Given days mode, size 7, 0 meals
   used, then the label is `last 7 days`.
7. **AC7 — meal label reports the actual count.** Given meals mode, size 30, 12
   meals used, then the label is `from your last 12 meals` — not `30`.
8. **AC8 — singular.** Given meals mode and 1 meal used, then the label is
   `from your last 1 meal`.
9. **AC9 — meals mode with nothing logged.** Given meals mode and 0 meals used,
   then the label is empty, and the header renders as bare `Grocery list`.

**Text rendering (pure — `formatGroceryList`)**

10. **AC10 — rendered list.** Given two candidates, the label
    `from your last 12 meals`, and 2026-08-29, then the text is exactly the
    [Output format](#output-format) block, with no trailing newline.
11. **AC11 — nothing logged at all.** Given no candidates and 0 meals used, then
    the body is `(no meals logged yet)`.
12. **AC12 — meals found but nothing listable.** Given no candidates but 3 meals
    used, then the body is `(nothing to list from these meals)`.
13. **AC13 — a count of one still renders `(x1)`.** No bare-name special case.

**Service (`ExportService`)**

14. **AC14 — ingredient grain.** Given a meal whose item `Greek salad` has
    ingredients `Feta cheese`, `Olive oil`, and a second meal whose item `Oatmeal`
    has none, then the candidates are `Feta cheese`, `Oatmeal`, `Olive oil` — and
    `Greek salad` does **not** appear.
15. **AC15 — the meal window cuts to the N newest.** Given five meals across five
    dates where only the two oldest contain `Ancient stew`, when the window is 3
    meals, then `mealsUsed` is 3 and `Ancient stew` is absent.
16. **AC16 — same-date ordering uses `createdAt` descending.** Given two meals on
    one date — `Early eggs` at 08:00 and `Late steak` at 19:00, returned
    ascending — when the window is 1 meal, then the only candidate is `Late steak`.
17. **AC17 — day window boundary.** Given days mode, size 7, and an anchor of
    2026-08-29, then `getMealsInRange` is called with `from == 2026-08-23`
    (decision 9).
18. **AC18 — modes use disjoint queries.** Given days mode, then `getAllMeals` is
    never called; given meals mode, then `getMealsInRange` is never called.
19. **AC19 — nothing logged, meals mode.** Given `getAllMeals` returns empty, then
    `mealsUsed` is 0 and the text is the bare-header `(no meals logged yet)` block.
20. **AC20 — nothing in the day window.** Given `getMealsInRange` returns empty,
    then the text still reads `Grocery list - last 30 days` above
    `(no meals logged yet)` — the empty result explains itself (decision 11).
21. **AC21 — meals found but nothing listable.** Given one meal whose only item is
    named `!!!`, then `mealsUsed` is 1 and the body is
    `(nothing to list from these meals)`.
22. **AC22 — malformed rows skipped.** Given a meal with a null id alongside a
    valid one, then the valid meal still contributes and nothing throws.
23. **AC23 — text renders from real candidates.** Given two meals each containing
    `Rice`, meals mode, then the text reads `from your last 2 meals` above
    `- Rice (x2)`.

**Screen (`ExportScreen`)**

24. **AC24 — mode chips render, meals is default.** Given the Export screen, then
    `By meals` and `By days` both render and `By meals` is selected.
25. **AC25 — meal presets.** Given meals mode, then `10 meals`, `30 meals`,
    `60 meals` render and `30 meals` is selected.
26. **AC26 — the inactive mode's chips are absent.** Given meals mode, then
    `7 days` is not in the tree at all — not merely unselected.
27. **AC27 — switching modes swaps the row.** Given the user taps `By days`, then
    `7 days` / `14 days` / `30 days` render with `30 days` selected, and
    `10 meals` is gone.
28. **AC28 — selection moves within a mode.** Given the user taps `10 meals`, then
    `10 meals` is selected and `30 meals` is not.
29. **AC29 — generate control present.** Given the Export screen, then
    `btn-generate-grocery-list` exists, labelled `Generate & share`.
30. **AC30 — the JSON export is untouched.** Given the grocery section is added,
    then the existing Photos-off and Meals-on defaults still hold.

**AI tidy pass**

31. **AC31 — the Worker routes the task.** Given `{task: 'tidy_grocery_list', text}`,
    then the Worker returns the model's JSON and does **not** answer
    `Unknown task` — proving the prompt entry alone is sufficient routing.
32. **AC32 — no-input guard.** Given the task with neither text nor image, then the
    Worker returns 400 `Provide text or image` and never calls Gemini.
33. **AC33 — the tidy system prompt is forwarded.** Given a tidy request, then
    `system_instruction` carries `prompts.tidy_grocery_list.systemPrompt`.
34. **AC34 — grouped rendering.** Given sections Produce `[Onions, Spinach]` and
    Dairy & Eggs `[Butter]`, then the text matches the grouped block in
    [Output format](#output-format) — one blank line between sections, none after
    the last.
35. **AC35 — empty sections are skipped.** Given a section with no items, then its
    name does not appear and no stray blank line is left behind.
36. **AC36 — item order is preserved.** The renderer never re-sorts; ordering is
    the model's job.
37. **AC37 — blank input is rejected before the URL is consulted.** Given
    `tidyGroceryList('   ')` with a URL configured, then it fails with a "tidy"
    message — a URL-check-first implementation fails this.
38. **AC38 — the AI receives the ranked raw list.** Given two meals containing
    `Rice`, then `tidyGroceryList` is called with exactly `Rice (x2)`.
39. **AC39 — no candidates skips the AI entirely.** Given an empty window, then the
    AI is never invoked and the empty-state text renders locally.
40. **AC40 — tidy failure throws with the message.** Given the service returns
    `success: false`, then `buildTidiedGroceryListText` throws carrying that
    message; `success: true` with null sections is treated the same way.
41. **AC41 — the plain path is unaffected by a failing AI.** Given a failing AI
    service, then `buildGroceryListText` still returns the plain list and never
    calls it.
42. **AC42 — the tidy button appears only with AI enabled.** Given AI on, then
    `btn-tidy-grocery-list` renders labelled `Tidy with AI & share`; given AI off,
    then it is absent from the tree entirely.
43. **AC43 — the plain button survives AI being off.** Given AI off, then
    `btn-generate-grocery-list` and the mode/window chips are unchanged.

## Deferred (not in this scope)

Written down so the shape is settled before the work starts, not to imply it is
queued.

- **Reaction badges.** Cross-reference each candidate against `food_suspicions`
  (honoring `suspicion_exclusions`) and `food_memories.flagged`, badge it with the
  evidence ("bloating — 3 check-ins"), and sort it toward attention. Advisory only;
  never silently drop a food from the list. Buildable today against the existing
  ledger at name level.
- **Ingredient-level reaction evidence.** The ledger keys on meal-item names
  ("greek salad") while this list keys on ingredients ("feta cheese"), so the badge
  above would miss ingredient-level culprits. Closing that means propagating
  suspicion weight from `food_items` down to `ingredients` — stretch feature S1.
- **Receipt scanning + pantry.** Photograph a receipt, AI-parse it into line items,
  review, and save as a purchase history; then demote already-bought candidates out
  of the generated list. Needs two new tables (`receipts`, `pantry_items`) and a
  `parse_receipt` worker task. Deliberately dropped from the first cut — exporting a
  list out is worth more than consuming one in.
- **Category grouping (S3).** Group lines under produce / dairy / proteins / pantry.
  Needs a category source; AI is the obvious one, which would make this the first
  part of the feature that is not AI-free.
- **Persisted lists + check-off.** Requires a `grocery_lists` table (decision 16).
- **Staples never logged as eaten.** Olive oil, spices, and the like are bought
  repeatedly but under-logged; a purchase-aware candidate source would catch them.
  Blocked on receipts.

## Open forks (WARBOSS fiat — user ruling still owed)

These were decided arbitrarily to make the slices buildable. Each is cheap to flip.

- ~~**F1** — Export screen vs. a new home app-bar icon (decision 1).~~ **RULED
  2026-08-30: neither — the grocery list moved to its own Meal Planning tab.** See
  [meal_planning.spec.md](meal_planning.spec.md) decision 9.
- **F2** — count = distinct meals rather than raw occurrences (decision 3).
- **F3** — preset sizes 10/30/60 meals and 7/14/30 days (decision 7).
- **F4** — each mode remembers its own size instead of sharing one number
  (decision 8).
- **F5** — quantities/units dropped entirely (decision 12).
- **F6** — `(xN)` suffix printed on every line including `(x1)` (decision 13).
- **F7** — an empty result opens the share sheet anyway rather than reporting
  on-screen (decision 15).
- **F8** — the fixed eight-section vocabulary (decision 19).
- **F9** — the tidied list drops counts entirely rather than keeping a quantity
  hint for high-frequency items (decision 20).
- **F10** — a failed tidy errors rather than falling back to the plain list
  (decision 21).
- **F11** — the tidy button is absent, not disabled-with-a-tooltip, when AI is off
  (decision 23).

## Anchors (explore rig)

<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->

- `meal-planning-screen` — screen root (the grocery card's home since 2026-08-30;
  it previously lived under `export-screen`)
- `chip-grocery-mode-meals` / `chip-grocery-mode-days` — window mode
- `chip-grocery-meals-10` / `-30` / `-60` — meal-count presets (meals mode only)
- `chip-grocery-days-7` / `-14` / `-30` — day presets (days mode only)
- `grocery-list-field` — the editable list itself
- `btn-copy-grocery-list` — copy the box contents to the clipboard
- `btn-share-grocery-list` — hand the box contents to the OS share sheet
- `btn-retry-grocery-list` — regenerate from the journal, replacing the box
- `btn-clear-grocery-list` — empty the box and drop the saved draft
- `btn-generate-grocery-list` — generate into the box; present only when the box is empty
- `btn-tidy-grocery-list` — tidy the box contents in place; present only when a list exists and AI is on

Relocated 2026-08-30: these ids moved from the Export screen to the Meal Planning tab
along with the widgets. The canonical rows in [anchors.md](anchors.md) carry the new
screen. See [meal_planning.spec.md](meal_planning.spec.md).

**✱ All ten of these are absorbed under UIAutomator** — verified on the emulator
2026-08-29. Flutter merges each `Semantics(identifier:)` onto the **grocery card
container** (`[42,1497][1038,2337]`), not onto the control, so a resource-id tap
lands in the middle of the card rather than on the button. The controls surface
with an empty `resource-id` and a correct `content-desc`, so the documented
fallback for the ADB rig is **tap by `content-desc`** (`By meals`, `30 meals`,
`Generate & share`, `Tidy with AI & share`, …). Dart `integration_test` reads the
ids in-process and is unaffected — declared plus reach-documented is the bar. The
registry rows carry the same note.

## Verifies-with

- Pure logic: [app/test/models/grocery_test.dart](../app/test/models/grocery_test.dart)
  — AC1–AC13 and AC34–AC36, no native sqlite3 needed.
- Service: [app/test/services/export_grocery_test.dart](../app/test/services/export_grocery_test.dart)
  — AC14–AC23 and AC38–AC41 against a `_FakeStorage extends StorageService` plus a
  fake `AiService`.
- AI guards: [app/test/services/worker_ai_service_test.dart](../app/test/services/worker_ai_service_test.dart)
  — AC37, in-process only (the guards short-circuit before any HTTP).
- Worker: [worker/src/index.test.js](../worker/src/index.test.js) — AC31–AC33 via
  `vitest`, with Gemini stubbed.
- Widget: [app/test/widgets/export_screen_test.dart](../app/test/widgets/export_screen_test.dart)
  — AC24–AC30 and AC42–AC43, driving the AI gate through
  `SharedPreferences.setMockInitialValues`.
- Card widget: [app/test/widgets/grocery_list_card_test.dart](../app/test/widgets/grocery_list_card_test.dart)
  — inline editing, copy/share/retry/clear actions, persistence of drafts (decisions 25–31).
- e2e: the plain path is blocked by nothing (no worker, no AI); the tidy path is
  worker-dependent. Explore-rig journey: seed via import, open `btn-export`, tap
  `chip-grocery-mode-days`, tap `chip-grocery-days-7`, tap
  `btn-generate-grocery-list`, assert the share sheet opens. Not yet run.
- **Emulator run 2026-08-29** (`scratch/explore-export-20260829-1914/`). The plain
  path was exercised end to end on device against seeded data and shared correctly:
  ```
  Grocery list - from your last 30 meals
  Generated 2026-08-29

  - salt (x6)
  - Peanut butter and fluff sandwich (x4)
  - vegetable oil (x4)
  ```
  That output is also the case for the tidy pass: `salt`/`spices` are seasoning
  noise nobody shops for, and `Peanut butter and fluff sandwich` is a dish name
  leaking in because that food item carried no ingredients (decision 2's fallback
  working as designed). Both are exactly what the tidy prompt is told to fix.
- **The tidy path is NOT yet verified against the live Worker.** On device it
  returns `Worker error 400: {"error":"Unknown task: tidy_grocery_list"}` because
  the prompt exists only in the local `prompts.json` — the deployed Worker has not
  been redeployed since. `wrangler deploy` (from `worker/`) is the missing step;
  `parse_meal` returns 200 against the same deployment, confirming the deployment
  itself is healthy. Until then the prompt's real-world merge quality is unproven.
