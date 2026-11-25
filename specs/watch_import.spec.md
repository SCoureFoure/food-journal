# Spec — Watch import: steps, sleep and heart rate from Gadgetbridge

> Status: active · Feature: watch_import · Added: 2026-11-25
> Source of truth for importing wearable data from a Gadgetbridge database export
> and showing a per-day watch summary in the journal.

## Requirement

The user wears a C60 band paired to Gadgetbridge (no internet, no vendor app). Gadgetbridge
can export its whole SQLite database to `Documents/Gadgetbridge/Gadgetbridge.db`. The user
picks that file from the Export / Import screen; the app copies the steps, sleep and
heart-rate samples into its own database, and each journal day shows one line: steps,
hours slept and heart-rate range. This is the first slice of FEATURES S6 (biometrics). It
puts the data next to the food log; correlating it with meals or reactions is later work.

Keeping the export fresh is a Gadgetbridge setting, not app behavior: the user turns on
automatic activity fetch and automatic database export in Gadgetbridge.

## Constraints (inherited)

- **Schema = contract:** new table `WatchSamples` in schema **v19**, created by a drift
  migration step with a migration test. No change to existing tables.
- **Local only:** the file is read from device storage. No network, no Gadgetbridge
  Intent API, no Bluetooth in this feature.
- **Read-only source:** the Gadgetbridge file is opened read-only and never modified.
- **AI-optional:** no AI in this feature.
- **Services as tool interface:** import lives in one service method with typed input
  (file path) and typed output (result counts / error).
- **Anchors:** every new interactive widget gets `Semantics(identifier:)`, registered in
  `specs/anchors.md`.

## Source format (observed 2026-11-25, Gadgetbridge 2026.11.1, C60)

- `KEEPHEALTH_ACTIVITY_SAMPLE` — 10-minute slots. `TIMESTAMP` in **seconds**. `STEPS`,
  `RAW_KIND` (sleep stage: 1 fall asleep, 2 light, 3 deep, 4 awake, 5 REM; 0 none).
  Its `HEART_RATE` column is always 0 on this band — not used.
- `GENERIC_HEART_RATE_SAMPLE` — 15-minute slots. `TIMESTAMP` in **milliseconds**,
  `HEART_RATE` bpm.
- Gadgetbridge pre-fills days with zero rows, including future slots. **0 means missing.**
- `GENERIC_SPO2_SAMPLE`, `KEEPHEALTH_BLOOD_PRESSURE_SAMPLE`,
  `KEEPHEALTH_TEMPERATURE_SAMPLE` exist but are **not imported** in v1.

## Decisions (pinned 2026-11-25)

- **Input:** the bare `.db` file only. A manual-export `.zip` is rejected with a message
  saying to pick `Gadgetbridge.db`. The picker uses `FileType.any` (Android does not map
  `.db` to a filterable type); the file is validated by content, not extension.
- **Valid file:** opens as SQLite and contains `KEEPHEALTH_ACTIVITY_SAMPLE` or
  `GENERIC_HEART_RATE_SAMPLE`. Anything else is an error and nothing is written.
- **Stored kinds:** `steps` (value = steps in slot), `sleep` (value = stage code 1–5),
  `hr` (value = bpm). Rows with value 0 are skipped. HR outside 25–240 bpm is skipped.
- **One row per (kind, slot start).** Re-import upserts: same kind + timestamp replaces
  the value. Re-importing the same file changes nothing.
- **All devices in the file** are imported (there is one today); no device picker.
- **Steps for day D** = sum of `steps` slots in local calendar day D.
- **Sleep for day D** = slots with stage 1, 2, 3 or 5 from **D-1 18:00 to D 18:00**
  local, × 10 min. A night belongs to the morning you wake up. Stage 4 (awake) does not
  count.
- **Heart rate for day D** = min–max of `hr` samples in local calendar day D.
- **Display (amended 2026-11-25, user):** a **Biometrics** line item, built like the other
  day line items (`MealTile` pattern: leading icon, title, subtitle, expand chevron). It is
  the first line item of the day, after the day totals and water summary and before the
  time-sorted entries, because it covers the whole day. Collapsed subtitle is the summary
  line `👣 3,360 · 😴 7h 10m · ♥ 62–109` (each part only when it has data). Expanded it shows:
  - **Sleep:** total, asleep–awake clock times (first counted slot start – last counted
    slot end), and minutes per stage: light, deep, REM, awake.
  - **Steps:** total, and the busiest hour (`busiest 8–9 AM · 410`).
  - **Heart rate:** lowest, highest, average, and the reading count.
  Rows for a missing metric are omitted. The tile is absent when the day has no watch data.
- **Watch data creates day sections (reversed 2026-11-25, user).** The watch logs
  passively, so a day with watch data and no journal entries appears in the feed with only
  the Biometrics tile; its day subtitle reads `Biometrics` instead of `No entries`.
- **Load range:** the journal loads all stored watch samples on each reload (small volume
  in v1: about 250 rows per day).
- **Linked folder + auto import (amended 2026-11-25, user).** The Export / Import screen
  has a **Watch data** card: the linked folder's path (or `Not set`), a **Set folder**
  button, an **Import now** button (imports `Gadgetbridge.db` from the linked folder), and
  the manual **Import file…** picker as a fallback. Set folder uses Android's folder grant
  (`ACTION_OPEN_DOCUMENT_TREE` + persisted read permission), opening at
  `Documents/Gadgetbridge`; no broad storage permission. The app checks the linked
  folder's `Gadgetbridge.db` **on start and whenever it returns to the foreground**: when
  its last-modified time differs from the last imported one it imports it and reloads the
  journal, showing `Watch data updated` when samples changed. No folder, a missing file
  or a lost grant is silent on start; the card shows the state. The file name is fixed
  (`Gadgetbridge.db`), only the folder is chosen.
- **JSON export / import does not include watch samples** in v1.
- **Result message:** a SnackBar `Imported <n> watch samples (<first date> – <last date>)`,
  or `No new watch data` when every row was already stored with the same value.

## Acceptance criteria (Given / When / Then)

1. **AC1 — import:** Given a Gadgetbridge file with steps, sleep stages and heart-rate
   rows (seconds and milliseconds timestamps), When it is imported, Then `WatchSamples`
   holds one `steps` / `sleep` / `hr` row per non-zero slot with the correct local time,
   and zero rows are absent.
2. **AC2 — idempotent re-import:** Given a file already imported, When it is imported
   again, Then the row count is unchanged; When a slot's value changed in the newer file,
   Then the stored value is the new one.
3. **AC3 — invalid file:** Given a file that is not SQLite, or SQLite without the
   Gadgetbridge tables, When it is imported, Then the result is an error and
   `WatchSamples` is unchanged.
4. **AC4 — HR range filter:** Given heart-rate rows of 0, 12 and 300 bpm, When imported,
   Then none of them are stored.
5. **AC5 — day summary math:** Given samples for a night spanning midnight and a day of
   steps and HR, When the summary for day D is computed, Then steps = calendar-day sum,
   sleep = stage 1/2/3/5 slots from D-1 18:00 to D 18:00 × 10 min, HR = calendar-day
   min–max.
6. **AC6 — Biometrics tile:** Given a day section with watch data, When expanded, Then
   the `biometrics-tile-<yyyy-mm-dd>` line item shows title `Biometrics` and the summary
   subtitle with only the parts that have data; When the tile itself is expanded, Then the
   sleep, steps and heart-rate detail rows show; Given no watch data, Then the tile is absent.
7. **AC7 — watch-only days:** Given watch samples on a day with no journal entries,
   When the journal loads, Then a section exists for that day, its subtitle is
   `Biometrics`, and its only line item is the Biometrics tile.
11. **AC11 — auto import only when newer:** Given a linked folder whose `Gadgetbridge.db`
   last-modified time differs from the stored one, When the sync runs, Then it imports
   and stores the new time; Given the same time, Then it copies and imports nothing.
12. **AC12 — silent failure states:** Given no linked folder, a missing file, or a
   failed import, When the sync runs, Then it returns that state without throwing and
   stores no new time.
13. **AC13 — watch card:** Given a linked folder, Then `watch-folder-path` shows its
   label and `btn-watch-set-folder`, `btn-watch-import-now`, `btn-import-watch` are
   present; Given none, Then the path reads `Not set` and Import now is disabled.
10. **AC10 — detail math:** Given a night with light, deep, REM and awake slots and a day
   of steps and HR, When the summary is computed, Then stage minutes, asleep–awake times,
   busiest hour and its steps, HR average (rounded) and reading count are exact.
8. **AC8 — migration:** Given a v18 database with data, When it opens at v19, Then
   `watch_samples` exists with its unique (kind, timestamp) index and the old data is
   intact.
9. **AC9 — import button:** Given the Export / Import screen, Then
   `btn-import-watch` is present; When the picked file is a `.zip`, Then the zip message
   is shown and nothing is imported.

## Anchors (explore rig)

- `btn-import-watch` — Export / Import screen: pick and import `Gadgetbridge.db`.
- `watch-folder-path` — Export / Import screen: the linked folder label.
- `btn-watch-set-folder` — Export / Import screen: choose the Gadgetbridge folder.
- `btn-watch-import-now` — Export / Import screen: import from the linked folder now.
- `biometrics-tile-<yyyy-mm-dd>` — per-day Biometrics line item inside a day section
  (replaces `watch-summary-<yyyy-mm-dd>`).
- `biometrics-tile-header-<yyyy-mm-dd>` — its title, the tap target to expand.

## Verifies-with

- Service tests: `app/test/services/watch_import_service_test.dart` (AC1–AC4)
- Model tests: `app/test/models/watch_summary_test.dart` (AC5, AC10)
- Widget tests: `app/test/widgets/biometrics_tile_test.dart` (AC6, AC9),
  `app/test/screens/home_watch_days_test.dart` (AC7)
- Service tests: `app/test/services/watch_sync_service_test.dart` (AC11, AC12)
- Widget tests: `app/test/widgets/export_watch_card_test.dart` (AC13)
- Migration: `app/test/services/migration_v19_watch_samples_test.dart` (AC8)
- e2e: manual on device with the real export (2026-11-22/23 data).
