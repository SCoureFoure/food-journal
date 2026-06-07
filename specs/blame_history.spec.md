# Spec — Blame history dashboard (review & dismiss accrued suspicion)

> Status: active · Feature: blame_history · Added: 2026-06-07
> Source of truth for a screen that lets the user review the symptom-episodes
> feeding the suspicion ledger ([food_blame](food_blame.spec.md)) and dismiss the
> ones whose cause was a 3rd party (illness, etc.) rather than food/medication —
> so those episodes stop polluting `getSuspicionScores()` aggregation.

## Requirement
A screen reachable from the home app bar lists every `(check-in, symptom)` pair
that has contributed suspicion rows, most-recently-logged first, showing its
date/time, symptom, severity, and the distinct items it blamed (auto-accrued +
manually-blamed). Example: "you had the flu, vomited, and the ledger quietly
blamed your salad for it — go dismiss that Nausea episode so the salad's score
stops climbing for a cause that wasn't food." The user taps an entry to dismiss
(or re-tap to restore) it; dismissing excludes **all** of that episode's
suspicion contributions — both `auto` and `manual`, across every blamed target —
from aggregation, without touching the underlying check-in record. **Check-in
time editing is explicitly out of this screen** — that stays in `log_feeling`'s
native edit flow, reached from the home feed, not from here.

## Constraints (inherited)
- **Schema = contract.** New table `suspicion_exclusions` (v13). Schema version
  bumps 12 → 13, `migrationStepVersions` appends `13`, needs a drift migration +
  `migration_*` integration test.
- **FK + cascade.** `reaction_logs(id) ON DELETE CASCADE` — deleting a check-in
  drops its exclusion rows automatically, mirroring `food_suspicions`.
- **Not AI.** Pure deterministic local logic (list/toggle/aggregate-filter). No
  worker, no AI-optional fallback applies.
- **Side-effects.** Toggling a dismissal is a plain ledger write — schedules no
  notification, never blocks anything, has no cross-feature consequence beyond
  the aggregation filter.
- **Reuse.** List-tile/`Semantics` shape from `FoodHistorySearchSheet`/
  `BlameSheet`; `ReactionLevel.label` for severity text and the `_titleCase`
  helper pattern from `feeling_tile.dart` for item-name display.

## Decisions (pinned 2026-06-07)

- **Exclusion lives in its own table — NOT a column on `food_suspicions`.**
  Critical finding while reading `StorageService.applyBlame`: it unconditionally
  **deletes and rewrites every `food_suspicions` row for a `reactionLogId` on
  every save of that check-in** — not only when `checkinTime`/symptoms change
  (`checkin_screen.dart` calls `applyBlame` inside `_save` for both create and
  edit, even if the user only touched the notes field). A flag column on
  `food_suspicions` would be silently wiped the next time that check-in is saved
  for any reason. A standalone `suspicion_exclusions` table survives
  `applyBlame`'s wipe-and-rewrite untouched, cascades on log delete via FK just
  like `food_suspicions` does, and lets `getSuspicionScores()` anti-join against
  it without coupling to row identity that churns on every regenerate.

- **Granularity = `(reaction_log_id, symptom)` — the episode, not the item.**
  Per-suspicion-row (per-item) granularity was considered and rejected:
  (a) `auto` rows fan out N symptoms × M in-window candidates per check-in — a
  per-row list would be mostly noise the ledger spec already treats as "discreet
  background signal, not a user-facing claim" (food_blame AC13); (b) the user's
  stated problem — "flu-induced nausea shouldn't blame the salad" — is an
  episode-level judgment ("this symptom that day wasn't food-caused"), not a
  per-item one. One row per `(log, symptom)` is small (bounded by
  symptoms-per-check-in, not fan-out), answers "was this symptom-episode food
  related?" directly, and still lets the user keep e.g. Bloating (real, food)
  while dismissing Nausea (flu) from the very same check-in.

- **Dismissing an episode suppresses BOTH `auto` and `manual` contributions**
  for that `(log, symptom)`, across every target it touched. The user is
  correcting the historical record ("this whole episode wasn't diet-related"),
  not relitigating which specific item they once tapped in the blame modal —
  source shouldn't matter once the episode itself is ruled out.

- **The list shows every `(log, symptom)` pair with ≥1 suspicion row** — both
  auto-only and manually-blamed episodes — so the user can review and prune
  what the ledger quietly accrued, not just what they deliberately blamed.
  Sorted by `checkin_time` DESC, ties by `id` DESC (`reaction_logs` carries no
  separate `created_at`; `checkin_time` is the only — and most meaningful —
  "date" to show, and matches "most recently logged on top").

- **Each row displays:** date + time (`checkin_time`), symptom name + its
  `ReactionLevel` (severity, from `symptomLevels`), and the distinct blamed item
  names for that pair, title-cased. Unlike the feeling tile's manual-only
  "Blamed" section (food_blame AC13), **this view shows `auto` + `manual`
  targets together** — the entire point is letting the user see what quietly
  accrued so they can judge the episode as a whole.

- **Toggle is idempotent + reversible, no confirm dialog.** Tap dismisses
  (`INSERT OR IGNORE` against `UNIQUE(reaction_log_id, symptom)`); tap again
  restores (deletes the row). Reversible actions on advisory data don't need a
  destructive-confirm gate — mirrors the ledger's own "best-effort... advisory,
  not the user's primary record" status (food_blame).

- **No time editing, no navigation into the check-in.** Rows are read-only
  summaries plus a dismiss/restore toggle — nothing here opens the check-in
  editor, the blame modal, or a date/time picker. Editing the underlying
  check-in (including its time) stays exclusively in `log_feeling`'s native
  flow, reached from the home feed. Keeps this screen single-purpose and avoids
  duplicating edit/blame UI the user explicitly didn't want surfaced here.

- **Stale-exclusion cleanup mirrors AC9.** If editing a check-in removes a
  symptom that has a dismissal on file, `applyBlame` also deletes the orphaned
  `suspicion_exclusions` row for that `(reactionLogId, symptom)` — no suspicion
  row will ever match it again. Same spirit as food_blame AC9's "orphaned manual
  rows for a removed symptom are deleted."

- **Entry point: `btn-blame-history` in the home app bar**, beside
  `btn-export`/`btn-settings` — pushes named route `/blame-history`.

## Schema (v13)
```text
suspicion_exclusions
  id              INTEGER PK AUTOINCREMENT
  reaction_log_id INTEGER NOT NULL REFERENCES reaction_logs(id) ON DELETE CASCADE
  symptom         TEXT NOT NULL
  created_at      INTEGER NOT NULL          -- unix ms; when the user dismissed it
  UNIQUE(reaction_log_id, symptom)          -- one exclusion per episode-symptom
INDEX idx_exclusion_log ON (reaction_log_id) -- cascade / lookup / toggle
```

`getSuspicionScores()` (food_blame) gains an anti-join filter:
```sql
WHERE NOT EXISTS (
  SELECT 1 FROM suspicion_exclusions se
  WHERE se.reaction_log_id = food_suspicions.reaction_log_id
    AND se.symptom = food_suspicions.symptom
)
```

## Acceptance criteria (Given / When / Then)
1. **AC1 — migration.** Given a v12 DB, when opened at v13 →
   `suspicion_exclusions` exists with the columns/index/unique constraint above,
   `currentSchemaVersion == 13`, `migrationStepVersions` ends with `13`. Existing
   rows untouched.
2. **AC2 — list happy path.** Given two check-ins that produced suspicion rows
   (one with Nausea(bad)+Bloating(mild), one with Bloating(mild)), when the
   dashboard opens → entries are listed newest-`checkin_time`-first; each shows
   date/time, symptom, severity label, and the distinct blamed item names
   (title-cased, `auto`+`manual` both present).
3. **AC3 — dismiss excludes the whole episode from aggregation.** Given an entry
   `(logA, 'Nausea')` with both an `auto` row (salad) and a `manual` row
   (yogurt), when dismissed → `getSuspicionScores()` no longer includes any row
   originating from `(logA, 'Nausea')` for either target, while `(logA,
   'Bloating')` rows from the *same log* keep scoring normally.
4. **AC4 — restore re-includes with original weight.** Given a dismissed entry,
   when restored (tapped again) → its rows count again in
   `getSuspicionScores()` with the same effective weight as before dismissal
   (the exclusion row is deleted; no `food_suspicions` data was touched/lost).
5. **AC5 — dismissal survives unrelated re-saves.** Given a dismissed `(logA,
   'Nausea')`, when the user opens that check-in and saves again for an
   unrelated reason (e.g. only edits notes — `applyBlame` regenerates every
   `food_suspicions` row for `logA` from scratch) → the exclusion row is
   untouched (separate table) and `(logA, 'Nausea')` remains excluded from
   aggregation afterward.
6. **AC6 — orphaned exclusion cleanup.** Given a dismissed `(logA, 'Nausea')`,
   when the check-in is edited so Nausea is no longer one of its symptoms →
   `applyBlame` deletes the now-orphaned `suspicion_exclusions` row for
   `(logA, 'Nausea')`.
7. **AC7 — cascade delete.** Given a log with an exclusion row, when the
   check-in is deleted (`deleteReactionLog`) → its `suspicion_exclusions` row is
   gone (FK cascade) and other logs' exclusion rows are untouched.
8. **AC8 — empty state.** Given no check-in has produced any suspicion rows,
   when the dashboard opens → an empty-state message renders; no crash on an
   empty ledger.
9. **AC9 — entry point + screen root.** The home app bar shows
   `btn-blame-history`; tapping it pushes `/blame-history` and
   `blame-history-screen` renders as the root.

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->
- `btn-blame-history` — home app-bar button opening the dashboard — **new**
- `blame-history-screen` — screen root — **new**
- `blame-history-item-<logId>-<symptom-slug>` — one episode-symptom row (date,
  severity, blamed item names). `symptom-slug` = symptom name lowercased with
  spaces→dashes (e.g. "Stomach pain" → `stomach-pain`) — anchor ids can't carry
  spaces — **new**
- `btn-blame-history-toggle-<logId>-<symptom-slug>` — dismiss/restore control on
  a row (toggles between dismissed/active state) — **new**

## Verifies-with
- Migration (AC1): `app/test/services/migration_order_test.dart` (version
  constant `13` + step). Actual v12→v13 SQL + FK/index (full open-at-v13 path)
  deferred to on-device integration — same split as food_blame AC1.
- Pure exclusion-aggregation math (AC3, AC4): `app/test/models/food_suspicion_test.dart`
  groups `[MFT] excludeDismissedSuspicions` / `[MFT] buildBlameHistory` —
  episode-level filter + grouping/dedupe/sort/dismissed-flag mirror the SQL and
  storage assembly, tested without native sqlite3 (matches the existing
  aggregation-math split).
- Dashboard list + toggle + empty/error states + screen root (AC2, AC4, AC8,
  AC9-screen-root): `app/test/screens/blame_history_screen_test.dart` via
  `storageOverride` fake (`_FakeStorage` records `toggleSuspicionExclusion`
  calls and flips `dismissed` in place, mirroring `blame_sheet_test`'s pattern).
  AC9's *entry-point* half (the home app-bar button) is **not** covered by a
  `home_screen_test.dart` — `HomeScreen` has no `storageOverride` seam, and
  none of its 5 concurrent loaders are faked anywhere; adding one solely for a
  one-button nav assertion would be needless surface area ([[feedback_code_surface_area]]).
  Verified instead by reading the route registration (`main.dart`) and via the
  explore rig below.
- AC5 (dismissal survives `applyBlame`'s wipe-and-rewrite): not independently
  re-tested — it follows directly from the exclusion table living outside
  `food_suspicions` (the architectural premise of the whole feature, proven by
  `_pruneOrphanedExclusions` reading/writing `suspicion_exclusions` in its own
  pass inside `applyBlame`'s transaction without touching ledger rows).
- Orphan cleanup (AC6) + cascade (AC7): both are DB/FK-level behaviors
  (`_pruneOrphanedExclusions`, `ON DELETE CASCADE`) that need native sqlite3 —
  deferred to on-device integration, mirroring food_blame AC10's precedent
  ("Actual v10→v11 SQL + FK/cascade deferred to on-device integration").
- e2e (explore rig, `Go-BlameHistory` in `test_explore.ps1 -Scenario blame-history`,
  run 2026-06-07): confirmed live on a fresh v13 install — `btn-blame-history` taps
  through to `blame-history-screen` (AC9 entry point + root, both live), the v12→v13
  migration opens without error (AC1's "doesn't crash on open" half), and the empty
  ledger renders the real empty-state copy verbatim (AC8, live `getBlameHistory()`
  wiring against an empty `suspicion_exclusions`/`food_suspicions` join — not the
  `_FakeStorage` stand-in). Screenshot: `scratch/explore-blame-history-20260607-1048/01-list.png`.
  Did **not** seed live suspicion rows to exercise dismiss/restore on-device — that
  needs a multi-screen setup flow (create food item → log meal → log feeling with a
  `bad`/`moderate` symptom inside the 16h auto-blame window) that exists nowhere in
  the rig yet, and would only re-prove, against real SQLite, a round-trip already
  pinned at the cheapest layer by the 8 `_FakeStorage` widget tests (AC4, including
  the failure-snackbar path) and the 26 pure-logic tests (`excludeDismissedSuspicions`/
  `buildBlameHistory`). Building that seed flow solely to re-confirm it would be
  needless surface area ([[feedback_code_surface_area]]).
