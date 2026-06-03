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
| Home         | `home-meal-list`                | Has meals — home screen ready                  |
| Home         | `btn-export`                    | Export icon in app bar                         |
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
| Log Meal     | `btn-save-meal`                 | Save / Save Changes. ✱ absorbed; tap via bounds |
| Export       | `export-screen`                 | Export screen root                             |
| Export       | `btn-date-from`                 | From date picker tile                          |
| Export       | `btn-date-to`                   | To date picker tile                            |
| Export       | `btn-export-json`               | Export as JSON button                          |
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
| Create item  | `saved-item-name-field`         | Saved-item name field                          |
| Create item  | `saved-item-ai-field`           | AI description field (text → parse)            |
| Create item  | `btn-parse-saved-item-ai`       | Parse-with-AI button                           |
| Create item  | `btn-create-item-add-blank`     | Add a blank component card                     |
| Create item  | `saved-item-search-field`       | Search past items to add                       |
| Create item  | `btn-save-saved-item`           | Save the composite item                        |
| Medication   | `log-medication-screen`         | Log/Edit medication screen root                |
| Medication   | `log-med-name`                  | Medication name field                          |
| Medication   | `btn-autofill-medication`       | Autofill-with-AI button (shared LogDescriptionSection) |
| Medication   | `log-med-dose`                  | Dose field                                     |
| Medication   | `log-med-unit`                  | Unit dropdown                                  |
| Medication   | `log-med-route`                 | Route dropdown                                 |
| Medication   | `log-med-notes`                 | Notes field                                    |
| Medication   | `log-med-checkin-delay`         | Check-in delay field                           |
| Medication   | `btn-delete-medication`         | Delete (edit mode)                             |
| Medication   | `btn-save-medication`           | Save / Save Changes                            |

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
