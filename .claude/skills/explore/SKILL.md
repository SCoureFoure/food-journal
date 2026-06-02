---
name: explore
description: >
  Build, install, and run the food-journal app on the Android emulator. Navigates to a target
  screen, captures a screenshot and UIAutomator hierarchy, reads flutter logs, and analyzes
  findings — fully autonomous, no user prompts.
  Trigger when user says "run explore", "check the app", "/explore <screen>", or asks to
  investigate a specific screen or behavior.
---

You are the food-journal ADB debugging rig. Execute this loop fully without prompting the user.

## Constants

```
ADB      = C:\Users\SCora\AppData\Local\Android\Sdk\platform-tools\adb.exe
PKG      = com.foodjournal.app
REPO     = c:\Users\SCora\Documents\Repositories\food-journal
SCRIPT   = c:\Users\SCora\Documents\Repositories\food-journal\test_explore.ps1
SHOTS    = c:\Users\SCora\Documents\Repositories\food-journal\scratch
```

## Step 1 — Resolve scenario

Argument maps to `-Scenario` param:

| User says                          | `-Scenario` value |
|------------------------------------|-------------------|
| home / (none)                      | `home`            |
| log meal                           | `log-meal`        |
| export                             | `export`          |
| collapsible / expandable / tiles   | `collapsible`     |

## Step 2 — Run the rig

```powershell
powershell -ExecutionPolicy Bypass -File "SCRIPT" -Scenario "<value>"
```

The script handles: detect device → build → install → pre-grant permissions → launch →
wait for foreground → wait for anchor element → wait for splash gone → navigate → screenshot → logs.

If device not found, tell user to start emulator and stop.

## Step 3 — Find task folder and read outputs

Each run creates `scratch\explore-<scenario>-<timestamp>\`. Last run's folder name is in:
```
scratch\.last
```

Read `scratch\.last` to get the task folder. Then read:

1. `scratch\<task>\<scenario>.png` — screenshot (Read tool reads images)
2. `scratch\<task>\ui.xml` — UIAutomator hierarchy
3. `scratch\<task>\flutter_log_latest.txt` — flutter logcat

Past task runs are retained in `scratch\` subfolders for reference.

## Step 4 — Element navigation (beyond what the script handles)

Always tap by resource-id — never hardcode coordinates. Use this inline `Tap-Element` pattern:

```powershell
$adb = "C:\Users\SCora\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$dev = "emulator-5554"
$Id  = "some-anchor-id"   # resource-id to tap
& $adb -s $dev shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
$xml = & $adb -s $dev shell cat /sdcard/ui.xml | Out-String
if ($xml -match "resource-id=""$([regex]::Escape($Id))""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]""") {
    $cx = [int](([int]$Matches[1] + [int]$Matches[3]) / 2)
    $cy = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
    & $adb -s $dev shell input tap $cx $cy
}
Start-Sleep -Seconds 1   # wait for animation
```

Flutter `Semantics(identifier: 'id')` → `resource-id="id"` in UIAutomator. ADB taps at the center of the element's bounds. For `ExpansionTile`, tap the header-specific anchor (`item-header-<id>`) not the whole tile, so the tap lands on the header even when expanded.

Then wait for the next screen's anchor before screenshotting.

## Known anchors (resource-id)

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
| Log Meal     | `log-meal-input`                | ⚠ not yet added to widget                      |
| Export       | `export-screen`                 | Export screen root                             |
| Export       | `btn-date-from`                 | From date picker tile                          |
| Export       | `btn-date-to`                   | To date picker tile                            |
| Export       | `btn-export-json`               | Export as JSON button                          |
| Check-in     | `checkin-screen`                | Feeling check-in screen root                   |
| Check-in     | `mood-selector`                 | Row of 5 mood faces                            |
| Check-in     | `mood-<name>`                   | Mood face (great/good/okay/low/awful)          |
| Check-in     | `symptom-intensity-sheet`       | Notebook-paper panel of per-symptom sliders    |
| Check-in     | `symptom-slider-<name>`         | Per-symptom intensity slider. ✱ absorbed; surfaces as SeekBar w/ content-desc "<pct>%, <label>" |
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

⚠ = anchor defined in script scenario but not yet added to Flutter widget. Add
`Semantics(identifier: 'id')` to the relevant widget before relying on it.
✱ = `Semantics(identifier:)` is set but the Material widget (FAB/Slider) merges its
own semantics over it, so the id does NOT surface as a resource-id. Tap via ui.xml
bounds (clickable/SeekBar node) or `content-desc` instead.

## Adding anchors to new screens

When you build a new screen or navigate somewhere new:
1. Wrap the screen's root or key interactive widget with `Semantics(identifier: 'screen-name')`.
2. Add the anchor to the table above.
3. Add a scenario function in `test_explore.ps1` if it needs multi-step navigation.

## Step 5 — Analyze and report

- **Screen** — describe screenshot (layout, text, widgets, any visual anomalies)
- **Logs** — flutter output, errors, exceptions
- **Anomalies** — unexpected state in screenshot or ui.xml
- **Next step** — concrete action to investigate or fix

Do not ask the user for output at any step. Complete the full loop and report.

## Step 6 — Trail-blaze (side objective — always)

Exploration's deliverable is **{findings + anchors + registry}**, not just findings.
Leave every screen you reached more reachable than you found it:

1. Any interactive widget you had to tap by bounds / `content-desc` (no id surfaced)
   → add a `Semantics(identifier: '...')` in Dart, or document why it can't surface.
2. Screen root missing an anchor → add `Semantics(identifier: 'screen-name')`.
3. Prefer anchors on SHARED widgets — one change blazes trail for every screen.
4. Register each in the Known anchors table above (same commit).
5. ✱ cases (FAB/Slider absorb the id under UIAutomator): mark ✱ + note the fallback
   (bounds / `content-desc` / SeekBar). The id still works for Dart `integration_test`
   in-process — declared + reach documented is the bar, not ADB-tappable.

This rig is the **discovery arm** of the `/spec` loop: reverse-engineering a workflow
into `specs/<feature>.spec.md` uses these journeys to confirm behavior and surface the
"is it supposed to do that?" decisions. See `.claude/skills/spec/SKILL.md`.
