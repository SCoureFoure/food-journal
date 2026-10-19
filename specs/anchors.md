# Known anchors (resource-id) — registry

The map of every `Semantics(identifier: …)` anchor in the app. **This file is the
single source of truth.** Two consumers read it:

- **Explore rig** (ADB / UIAutomator) — taps by `resource-id`; some ids are absorbed
  by their Material widget and need a documented fallback (see ✱).
- **Dart `integration_test`** — reads ids in-process; absorbed ids work fine here.

Register every new anchor here in the same commit that adds it (the trail-blaze rule
in `.claude/skills/explore/SKILL.md` Step 6 and the `/spec` loop Step 5b).

**Canonical vs view.** This registry is canonical: it holds the full row (screen ·
meaning · ✱/fallback) and is the one home for **shared-widget** anchors that span
screens (e.g. `log-meal-input`, `btn-autofill-*` from `LogDescriptionSection`). A
feature spec's `## Anchors` section is a *view* — it lists only the ids that feature
touches and links back here; it does not redefine meaning or fallback.

## Anchors

| Screen       | Anchor id                       | Meaning                                        |
|--------------|---------------------------------|------------------------------------------------|
| Home         | `btn-log-entry`                 | FAB — toggles speed-dial. ✱ absorbed; tap via bounds |
| Home         | `btn-fab-<slug>`                | Speed-dial option (feeling/medication/weighin/water/food). ✱ absorbed |
| Home         | `home-empty-state`              | No meals — home screen ready                   |
| App shell    | `btn-blame-history`             | App-bar button → blame history dashboard (blame_history) — app-shell app bar, journal tab only (absent on Meal Planning) |
| Blame history| `blame-history-screen`          | Dashboard screen root (blame_history)          |
| Blame history| `blame-history-item-<logId>-<symptom-slug>` | Episode-symptom row: date, severity, blamed item names. `symptom-slug` = lowercase, spaces→dashes (e.g. "Stomach pain" → `stomach-pain`) (blame_history) |
| Blame history| `btn-blame-history-toggle-<logId>-<symptom-slug>` | Dismiss/restore control on a row — toggles its exclusion (blame_history) |
| Blame history| `blame-history-empty-state`     | Empty-state message when no blamed episodes exist. Reach unverified. |
| App shell    | `app-shell`                     | Two-tab shell root at route `/` — owns the AppBar, the folder tabs, and the lined-paper background (meal_planning) |
| App shell    | `tab-food-journal`              | Folder tab 0 — selects the journal. Verified on device 2026-08-30: surfaces its own resource-id, directly ADB-tappable (content-desc "Food Journal") (meal_planning) |
| App shell    | `tab-meal-planning`             | Folder tab 1 — selects the planning surface. Verified on device 2026-08-30: surfaces its own resource-id, directly ADB-tappable (content-desc "Meal Planning") (meal_planning) |
| App shell    | `btn-settings`                  | Settings icon in the app-shell app bar — shell-level, present on BOTH tabs (meal_planning) |
| Meal Planning| `meal-planning-screen`          | Meal Planning tab body root (meal_planning) |
| Meal Planning| `planner-stub-card`             | Inert "This week's meals" placeholder — copy only, no controls; the planner itself is a later slice (meal_planning) |
| Home         | `home-meal-list`                | Has meals — home screen ready                  |
| App shell    | `btn-export`                    | Export icon in app bar — app-shell app bar, journal tab only (absent on Meal Planning) |
| Home         | `home-loading`                  | Still loading                                  |
| Home         | `home-error`                    | Error state                                    |
| Home         | `week-section-YYYY-MM-DD`       | Week summary header + its day sections         |
| Home         | `date-section-YYYY-MM-DD`       | Collapsible date group card                    |
| Home         | `meal-tile-<id>`                | Collapsible meal tile (whole tile)             |
| Home         | `meal-tile-header-<id>`         | Meal tile header only — use this to tap toggle |
| Home         | `feeling-tile-<id>`             | Collapsible feeling/check-in tile (whole tile) |
| Home         | `feeling-tile-header-<id>`      | Feeling tile header (title) — tap toggles expansion |
| Home         | `btn-edit-feeling-<id>`         | Edit button in feeling tile expanded body (TextButton). Reach: expand tile (`feeling-tile-<id>`), then tap — surfaces as `content-desc="Edit"` (TextButton label merges over the id). Moved out of header `trailing` to escape ExpansionTile InkWell contention |
| Log Meal     | `log-meal-screen`               | Screen root                                    |
| Log Meal     | `log-meal-title`                | Title field                                    |
| Log Meal     | `log-meal-input`                | Description field (shared `LogDescriptionSection`, `inputSemanticsId`) |
| Log Meal     | `btn-autofill-meal`             | Autofill-with-AI button (shared section, meal variant) |
| Log Meal     | `btn-add-item`                  | Add a blank food-item card                     |
| Log Meal     | `btn-create-item`               | Open Create-saved-item sheet                   |
| Log Meal     | `btn-add-from-history`          | Open food-history search sheet                 |
| Log Meal     | `btn-add-from-favorites`        | Open history sheet, favorites-only             |
| Log Meal     | `btn-my-items`                  | Open saved-items sheet                         |
| Log Meal     | `btn-search-food-db`            | Open external food-database (USDA FDC) search sheet |
| Log Meal     | `btn-servings-edit`             | Servings count in a food-item card header (shared `EditableFoodItemCard`); − / + step by 0.5, tap the count to type an exact value (`servings-input-field` dialog). Snaps to 0.25 grid, min 0.25 |
| Log Meal     | `food-reuse-suggestion-<i>`     | Reuse-nudge chip under food-item card `i` (Layer B). Appears only on a close history match; tap adopts, `…-dismiss` child × hides. Reach: type a name matching history into card `i` |
| Log Meal     | `btn-save-meal`                 | Save / Save Changes. ✱ absorbed; tap via bounds |
| Log Meal     | `btn-favorite-<id>`             | Favorite heart toggle on a food item card. Reach unverified. |
| Log Meal     | `servings-input-field`          | Exact servings text field in the Servings dialog. Reach unverified. |
| Food DB      | `food-db-search-sheet`          | Food-database search sheet root (opened from `btn-search-food-db`) |
| Food DB      | `food-db-search-field`          | Query field; debounced, min 2 chars            |
| Food DB      | `food-db-item-<i>`              | Result row `i`; tap inserts a food item with estimated macros |
| Export       | `export-screen`                 | Export screen root                             |
| Export       | `btn-date-from`                 | From date picker tile                          |
| Export       | `btn-date-to`                   | To date picker tile                            |
| Export       | `toggle-include-photos`         | "Photos" switch — embed base64 images in export. Default **off** (export_import_size). ✱ absorbed (Switch); Dart: ancestor `SwitchListTile` of title "Photos" |
| Export       | `btn-export-json`               | Export as JSON button                          |
| Export       | `btn-import-json`               | Import-from-JSON button — opens OS file picker |
| Export       | `toggle-include-meals`          | "Meals" switch — includes meal entries in export. Reach unverified. |
| Export       | `toggle-include-medications`    | "Medications" switch — includes medication entries in export. Reach unverified. |
| Export       | `toggle-include-memories`       | "Food Memories" switch — includes food memories in export. Reach unverified. |
| Meal Planning| `chip-grocery-mode-meals`       | Grocery window mode — last N logged meals, the default (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "By meals" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-mode-days`        | Grocery window mode — last N calendar days (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "By days" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-meals-10`         | Meal-count window preset — 10 meals; present only in meals mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "10 meals" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-meals-30`         | Meal-count window preset — 30 meals, the default; present only in meals mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "30 meals" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-meals-60`         | Meal-count window preset — 60 meals; present only in meals mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "60 meals" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-days-7`           | Day window preset — 7 days; present only in days mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "7 days" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-days-14`          | Day window preset — 14 days; present only in days mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "14 days" (verified on emulator 2026-08-29) |
| Meal Planning| `chip-grocery-days-30`          | Day window preset — 30 days, the default; present only in days mode (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "30 days" (verified on emulator 2026-08-29) |
| Meal Planning| `btn-generate-grocery-list`     | Builds the frequency-ranked grocery list and opens the share sheet (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "Generate & share" (verified on emulator 2026-08-29) — present only while the box is empty; fills the box, shares nothing |
| Meal Planning| `btn-tidy-grocery-list`         | Sends the generated list to the AI tidy pass and shares the grouped result. Present only when AI is enabled in Settings (groceries) ✱ absorbed — the id merges onto the **grocery card container**, not the control; tap via `content-desc` "Tidy with AI & share" (verified on emulator 2026-08-29) — transforms the box contents in place (never re-reads the journal); present only when a list exists and AI is on |
| Meal Planning| `grocery-list-field`            | The generated grocery list, editable in place. Copy/Share/Tidy all act on its current contents (groceries) |
| Meal Planning| `btn-copy-grocery-list`         | Copies the list box to the clipboard; confirms with a SnackBar (groceries) |
| Meal Planning| `btn-share-grocery-list`        | Hands the list box to the OS share sheet — on request only, never automatic (groceries) |
| Meal Planning| `btn-retry-grocery-list`        | Regenerates from the journal using the current window chips, replacing the box (groceries) |
| Meal Planning| `btn-clear-grocery-list`        | Empties the box and drops the saved draft, returning the card to its Generate state (groceries) |
| Meal Planning| `pantry-card`                   | Pantry panel, between the planner stub and the grocery card (receipt_scan) |
| Meal Planning| `btn-scan-receipt`              | Camera (one photo) / gallery (several) choice; queues the photos for background reading (receipt_scan, receipt_queue) ✱ absorbed — the id merges onto the **pantry card container**, not the control; tap via `content-desc` "Scan receipt". Reach unverified. |
| Meal Planning| `btn-pantry-add`                | Adds one pantry item by hand — opens the review screen in manual mode (receipt_scan) ✱ absorbed — the id merges onto the **pantry card container**; tap via `content-desc` "Add item". Reach unverified. |
| Meal Planning| `item-pantry-<id>`              | One pantry row (receipt_scan) ✱ merges into the pantry card container; reach unverified |
| Meal Planning| `btn-pantry-delete-<id>`        | Deletes one pantry row (receipt_scan) ✱ absorbed — the id merges onto the **pantry card container**; tap via `content-desc` "Remove". Reach unverified. |
| Meal Planning| `receipt-queue-status`          | "N reading… · N ready to review" line on the pantry card; absent when the queue is empty (receipt_queue). Reach unverified. |
| Meal Planning| `btn-receipt-review-next`       | Opens the oldest ready receipt in the review screen; absent when none is ready (receipt_queue). Reach unverified. |
| Meal Planning| `receipt-queue-failed`          | "N receipt(s) couldn't be read" notice (receipt_queue). Reach unverified. |
| Meal Planning| `btn-receipt-failed-dismiss`    | Hides the couldn't-be-read notice (receipt_queue). Reach unverified. |
| Receipt review| `receipt-review-screen`        | Receipt review / manual add screen root (receipt_scan) |
| Receipt review| `item-receipt-row-<index>`     | One review row: include checkbox, name, quantity, unit (receipt_scan). Reach unverified. |
| Receipt review| `btn-receipt-ai-names`         | AI name clean-up; absent when AI is off, source is manual, or no OCR text (receipt_scan). Reach unverified. |
| Receipt review| `btn-receipt-add-row`          | Appends a blank review row (receipt_scan). Reach unverified. |
| Receipt review| `btn-receipt-save`             | Saves checked, named rows to the pantry and pops (receipt_scan). Reach unverified. |
| Receipt review| `btn-receipt-discard`         | Discards a queued receipt without saving; only shown when review was opened from the queue (receipt_queue). Reach unverified. |
| Receipt review| `receipt-review-empty`         | "Couldn't find any items" message, shown when there are zero rows (receipt_scan) |
| Import       | `import-wizard-screen`          | Import wizard root (per-record selection)      |
| Import       | `btn-import-confirm`            | Confirm import of selected records. ✱ absorbed (ElevatedButton); tap via bounds/label |
| Check-in     | `checkin-screen`                | Feeling check-in screen root                   |
| Check-in     | `mood-selector`                 | Row of 5 mood faces                            |
| Check-in     | `mood-<name>`                   | Mood face (great/good/okay/low/awful)          |
| Check-in     | `symptom-intensity-sheet`       | Notebook-paper panel of per-symptom sliders    |
| Check-in     | `symptom-slider-<name>`         | Per-symptom intensity slider. ✱ absorbed; surfaces as SeekBar w/ content-desc "<pct>%, <label>" |
| Check-in     | `btn-delete-feeling-<id>`       | Inline delete (edit mode, LogDateTimeRow trailing). Tap via `delete_outline` icon bounds; Dart in-process via finder |
| Check-in     | `btn-blame-foods`               | Opens blame modal (food_blame). Gated: present only when ≥1 symptom selected |
| Blame        | `blame-sheet`                   | Blame modal root (food_blame) — list of recent food/med suspects |
| Blame        | `blame-search-field`            | Search field in blame modal. ✱ absorbed (TextField) — Dart: `find.byType(TextField)`; ADB: bounds/edit-text |
| Blame        | `blame-item-<type>-<id>`        | Blamable suspect row (`type` = food\|med, id = item/med id). Tap blames item for current log's symptoms |
| Blame        | `btn-blame-confirm`             | Confirm/Done button — returns selected suspects. ✱ absorbed (FilledButton) — Dart: `find.widgetWithText(FilledButton, …)`; ADB: content-desc/bounds |
| Home         | `feeling-blamed-items-<id>`     | "Blamed" section in expanded feeling tile body (food_blame AC13) — manual-blamed item chips, lazy-loaded on expand. Built only when ≥1 manual blame exists |
| Home         | `med-tile-<id>`                 | Collapsible medication tile (whole tile). Reach unverified. |
| Home         | `med-tile-header-<id>`          | Medication tile header (name) — tap toggles expansion. Reach unverified. |
| Home         | `btn-edit-med-<id>`             | Edit icon on medication tile; opens edit medication. Reach unverified. |
| Home         | `water-row-<id>`                | Water log row in the home water summary. Reach unverified. |
| Home         | `weight-tile-<id>`              | Collapsible weigh-in tile (whole tile). Reach unverified. |
| Home         | `weight-tile-header-<id>`       | Weigh-in tile header — tap toggles expansion. Reach unverified. |
| Home         | `btn-edit-weight-<id>`          | Edit icon on weigh-in tile; opens edit weight. Reach unverified. |
| Home         | `home-screen`                   | Home screen root. Reach unverified. |
| Create item  | `saved-item-name-field`         | Saved-item name field                          |
| Create item  | `saved-item-ai-field`           | AI description field (text → parse)            |
| Create item  | `btn-parse-saved-item-ai`       | Parse-with-AI button                           |
| Create item  | `btn-create-item-add-blank`     | Add a blank component card                     |
| Create item  | `btn-create-item-search-db`     | Open food-database (USDA FDC) search; result added as a component |
| Create item  | `saved-item-search-field`       | Search past items to add                       |
| Create item  | `btn-save-saved-item`           | Save the composite item                        |
| Medication   | `log-medication-screen`         | Log/Edit medication screen root                |
| Medication   | `log-med-name`                  | Medication name field                          |
| Medication   | `med-reuse-suggestion`          | Reuse-nudge chip under the name field (Layer B). Appears only on a close history match; tap adopts name/dose/unit/route, `…-dismiss` child × hides |
| Medication   | `btn-autofill-medication`       | Autofill-with-AI button (shared LogDescriptionSection) |
| Medication   | `log-med-dose`                  | Dose field                                     |
| Medication   | `log-med-unit`                  | Unit dropdown                                  |
| Medication   | `log-med-route`                 | Route dropdown                                 |
| Medication   | `log-med-notes`                 | Notes field                                    |
| Medication   | `log-med-checkin-delay`         | Check-in delay field                           |
| Medication   | `btn-delete-medication`         | Delete (edit mode)                             |
| Medication   | `btn-save-medication`           | Save / Save Changes                            |
| Log Water    | `log-water-sheet`               | Log/edit water sheet root. Reach unverified.   |
| Log Water    | `btn-water-<ml>ml`              | Water amount preset chip, by millilitres. Reach unverified. |
| Log Water    | `log-water-custom-oz`           | Custom amount (oz) text field. Reach unverified. |
| Log Water    | `btn-save-water`                | Save / Save Changes for the water log. Reach unverified. |
| Log Weight   | `log-weight-value`              | Weight value text field. Reach unverified.     |
| Log Weight   | `log-weight-unit-toggle`        | lbs/kg segmented unit toggle. Reach unverified. |
| Log Weight   | `btn-save-weight`               | Save / Save Changes for the weight log. Reach unverified. |
| Meal Detail  | `btn-share-meal`                | App-bar share icon; shares the meal. Reach unverified. |
| Food History | `btn-history-filter-all`        | "All" filter chip in the history sheet. Reach unverified. |
| Food History | `btn-history-filter-favorites`  | "Favorites" filter chip; favorites-only results. Reach unverified. |
| Food History | `food-history-search-field`     | Search field for past items. Reach unverified. |
| Food History | `history-item-<i>`              | History result row `i`. Reach unverified.      |
| Food History | `btn-delete-saved-<name>`       | Delete control on a saved composite history row. Reach unverified. |
| Food History | `btn-favorite-<name>`           | Star toggle on a non-composite history row. Reach unverified. |
| Saved Items  | `saved-items-search-field`      | Search field in the My Items sheet. Reach unverified. |
| Saved Items  | `saved-item-<i>`                | Saved item row `i`. Reach unverified.          |
| Saved Items  | `btn-delete-saved-item-<i>`     | Delete control on saved item row `i`. Reach unverified. |

Symptom chips have no anchor — tap by `content-desc="<SymptomName>"`.

## Legend

⚠ = anchor defined in script scenario but not yet added to Flutter widget. Add
`Semantics(identifier: 'id')` to the relevant widget before relying on it.

✱ = `Semantics(identifier:)` is set but the Material widget (FAB/Slider) merges its
own semantics over it, so the id does NOT surface as a resource-id. Tap via ui.xml
bounds (clickable/SeekBar node) or `content-desc` instead. The id still works for
Dart `integration_test` in-process — declared + reach documented is the bar, not
ADB-tappable.

## Adding anchors to new screens

When you build a new screen or navigate somewhere new:

1. Wrap the screen's root or key interactive widget with `Semantics(identifier: 'screen-name')`.
2. Add the anchor to the table above.
3. Add a scenario function in `test_explore.ps1` if it needs multi-step navigation.
