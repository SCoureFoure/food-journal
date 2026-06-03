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

The anchor registry lives in **[`specs/anchors.md`](../../../specs/anchors.md)** — the
single source of truth, shared by this rig (ADB/UIAutomator) and Dart
`integration_test`. It holds the full Screen→id→meaning table, the ⚠/✱ legend, and
the "Adding anchors to new screens" steps.

Flutter `Semantics(identifier: 'id')` → `resource-id="id"` under UIAutomator. Tap by
resource-id; ✱-marked ids are absorbed by their Material widget — tap via ui.xml
bounds / `content-desc` / SeekBar (see the legend). Register every new anchor there in
the same commit that adds it.

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
4. Register each in the anchor registry — [`specs/anchors.md`](../../../specs/anchors.md) (same commit).
5. ✱ cases (FAB/Slider absorb the id under UIAutomator): mark ✱ + note the fallback
   (bounds / `content-desc` / SeekBar). The id still works for Dart `integration_test`
   in-process — declared + reach documented is the bar, not ADB-tappable.

This rig is the **discovery arm** of the `/spec` loop: reverse-engineering a workflow
into `specs/<feature>.spec.md` uses these journeys to confirm behavior and surface the
"is it supposed to do that?" decisions. See `.claude/skills/spec/SKILL.md`.
