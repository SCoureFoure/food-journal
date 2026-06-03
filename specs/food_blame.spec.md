# Spec — Food/medication blame (symptom→item suspicion ledger)

> Status: active · Feature: food_blame · Added: 2026-06-02
> Source of truth for associating a logged symptom with the food items and
> medications that may have caused it — both **manually** (user blames a specific
> item) and **automatically** (every item in the lookback window accrues a quiet
> suspicion). Builds the suspicion *ledger* only; surfacing/flagging is downstream.

## Requirement
When the user logs a feeling with one or more symptoms (e.g. mild Bloating), the
system records which recently-consumed items are *suspect* for each symptom. Two
sources feed one ledger:

- **Auto (discreet).** On save of any check-in carrying ≥1 symptom, every food item
  and medication logged within the **16h** window before the check-in time accrues a
  low-weight suspicion row for each symptom. The user does nothing.
- **Manual (deliberate).** From the check-in screen the user opens a **blame** modal
  (mirrors the food-history sheet) listing food items + medications from the past
  **24h**. Tapping an item blames it for the current log's symptoms with a
  heavier-weighted row.

Suspicions accumulate per `(targetName, symptom)` across all logs. Over time real
triggers re-fire and out-weigh one-off false positives. This spec does **not**
compute flags or surface conclusions — it only writes and aggregates the ledger.

## Out of scope (future work)
- **System flagging.** Crossing an accrued-suspicion threshold → `food_memories.flagged`.
  Ledger must *support* the aggregation query; computing/surfacing the flag is a later
  spec.
- **User flagging.** Explicit "I know this triggers me" mark — separate from accrued
  signal, its own future feature.
- **Decay tuning.** Suspicion weight should bleed off with age; the seam exists
  (`createdAt` per row + a `decay()` factor in the aggregation) but the factor is the
  **identity (1.0)** for now. Half-life is deliberately unpinned (punted by user).
- **Dynamic window.** 16h auto / 24h manual are constants now; later may vary by
  symptom class (GI fast vs systemic slow) or be learned.

## Constraints (inherited)
- **Schema = contract.** New table `food_suspicions` (v11). Shape stable; any change
  needs a drift migration + `migration_*` integration test. Schema version bumps
  10 → 11, `migrationStepVersions` appends `11`.
- **FK + cascade.** `reaction_logs(id) ON DELETE CASCADE` — the check-in *is* the
  association batch. Deleting a feeling removes its suspicions automatically.
- **Not AI.** Pure deterministic local logic (window math + inserts). No worker, no
  AI-optional fallback applies.
- **Side-effects.** Writing suspicions schedules **no** notification and never blocks
  the save — auto-blame is best-effort inside the same save path; a failure to write
  suspicions must not fail the check-in save.
- **Reuse.** Window query combines `meals.date` + `meals.time` (TEXT) via
  `DateTimeUtils.parseTime` into a real timestamp — day-granular `getMealsInRange`
  is too coarse for a window that crosses midnight. Manual modal reuses the
  `FoodHistorySearchSheet` structure/anchors pattern.

## Decisions (pinned 2026-06-02)
- **Auto window = 16h; manual window = 24h.** Auto 16h ≈ one waking day / dinner→
  breakfast overnight. Manual 24h is wider so the user can reach an item auto missed.
  Constants: `kAutoBlameWindow = Duration(hours: 16)`,
  `kManualBlameWindow = Duration(hours: 24)`.
- **Window is timestamp-precise**, anchored on the log's `checkinTime`, half-open
  `[checkinTime − window, checkinTime]`. Item timestamp = its date + parsed time.
- **Targets are items, not meals.** `targetType ∈ {food, medication}`,
  `targetId` = `food_items.id` / `medications.id`, plus denormalized `targetName`
  (lowercased for aggregation, matching `food_memories.foodName` convention).
- **Per-symptom rows.** One suspicion row per `(symptom, target)`. A log with N
  symptoms and M in-window targets writes N×M auto rows.
- **Weight = severity-scaled.** `baseWeight` = that symptom's `ReactionLevel` index
  for this log (mild=1, moderate=2, bad=3). Effective weight on read =
  `baseWeight × sourceMultiplier × decay(age)`.
  `sourceMultiplier`: auto = 1.0, manual = `kManualWeightMultiplier` (placeholder
  3.0). `decay()` = 1.0 stub (see out-of-scope).
- **Manual blame targets the whole log's symptom set.** Tapping an item in the modal
  writes one `manual` row per symptom currently on the log (matches "this caused how
  I feel"). If the log has zero symptoms, the blame modal is unavailable (nothing to
  blame for).
- **`reactionLogId` is the batch id.** Every row (auto + manual) carries it. No
  separate association id is generated — the log id already groups the batch and
  drives edit/cascade.
- **Edit = regenerate.** On `updateReactionLog`, delete all `source=auto` rows for
  that `reactionLogId` and rewrite them from the (possibly changed) `checkinTime` /
  symptom set. `source=manual` rows are **preserved** unless the blamed symptom was
  removed from the log (then the orphaned manual rows for that symptom are deleted).
- **Delete = cascade.** Deleting the check-in drops all its suspicion rows via FK.
- **Best-effort, never blocks save.** Auto-blame runs after the log row is written,
  in the same transaction where practical; if the window query/insert throws, the
  save still succeeds (suspicions are advisory, not the user's primary record).

## Schema (v11)
```text
food_suspicions
  id            INTEGER PK AUTOINCREMENT
  reaction_log_id INTEGER NOT NULL REFERENCES reaction_logs(id) ON DELETE CASCADE
  symptom       TEXT NOT NULL                 -- e.g. 'Bloating'
  target_type   TEXT NOT NULL                 -- 'food' | 'medication'
  target_id     INTEGER NOT NULL              -- food_items.id | medications.id
  target_name   TEXT NOT NULL                 -- denormalized, lowercased for GROUP BY
  base_weight   REAL NOT NULL                 -- ReactionLevel index at log time
  source        TEXT NOT NULL                 -- 'manual' | 'auto'
  created_at    INTEGER NOT NULL              -- unix ms; decay input
INDEX idx_suspicion_target ON (target_name, symptom)   -- aggregation
INDEX idx_suspicion_log    ON (reaction_log_id)        -- edit / cascade lookup
```

## Acceptance criteria (Given / When / Then)
1. **AC1 — migration.** Given a v10 DB, when opened at v11 → `food_suspicions` exists
   with the columns/indexes above, `currentSchemaVersion == 11`, and
   `migrationStepVersions` ends with `11`. Existing rows untouched.
2. **AC2 — auto-blame happy path.** Given a food item logged 3h before and a
   medication logged 10h before `checkinTime`, when a feeling with Bloating(mild) is
   saved → two `auto` rows exist (one food, one medication), each
   `symptom='Bloating'`, `base_weight==1`, `source='auto'`, `reaction_log_id` = the
   new log id, `target_type`/`target_id`/`target_name` correct.
3. **AC3 — auto window boundary (16h).** Given items at 15h and 17h before
   `checkinTime`, when saved → only the 15h item is blamed; the 17h item gets no row.
   Boundary is half-open: an item exactly at 16h0m is excluded.
4. **AC4 — multi-symptom fan-out.** Given 2 in-window targets and a log with
   {Bloating: mild, Nausea: bad}, when saved → 4 auto rows; Bloating rows carry
   `base_weight==1`, Nausea rows `base_weight==3`.
5. **AC5 — no symptoms → no auto rows.** Given a feeling saved with zero symptoms
   (severity none), when saved → no `food_suspicions` rows written.
6. **AC6 — manual modal window (24h) + sources.** Given items at 20h and 26h before
   now, when the blame modal opens → it lists the 20h item (food + meds in range) and
   omits the 26h item.
7. **AC7 — manual blame writes weighted rows.** Given a log with Bloating, when the
   user blames an item in the modal → one `manual` row per log symptom for that item,
   `source='manual'`; its effective weight = `base_weight × kManualWeightMultiplier`
   (> the same item's auto contribution).
8. **AC8 — manual reaches past auto window.** Given an item logged 20h before (inside
   24h manual, outside 16h auto) with no auto row, when manually blamed → a `manual`
   row is created for it.
9. **AC9 — edit regenerates auto, preserves manual.** Given a saved log with auto +
   manual rows, when the check-in's `checkinTime`/symptoms are edited and saved →
   `auto` rows for that `reaction_log_id` are deleted and rewritten from the new
   window/symptoms; `manual` rows survive except those whose symptom was removed from
   the log.
10. **AC10 — delete cascades.** Given a log with suspicion rows, when the log is
    deleted (`deleteReactionLog`) → all its `food_suspicions` rows are gone (FK
    cascade), and rows for other logs are untouched.
11. **AC11 — aggregation read.** `getSuspicionScores()` returns effective weight
    summed and grouped by `(targetName, symptom)`; given the same item blamed once
    auto (weight 1) and once manual (weight 1×3), its Bloating score == 4.
12. **AC12 — blame entry point gating.** Given the check-in screen with ≥1 symptom
    selected, then `btn-blame-foods` is present; given zero symptoms, the blame entry
    point is absent/disabled (nothing to blame for).

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->
- `btn-blame-foods` — opens the blame modal from the check-in screen (gated on
  ≥1 symptom) — **new, trail-blazed with this spec**
- `blame-sheet` — blame modal root — **new**
- `blame-search-field` — search field in the blame modal — **new**
- `blame-item-<type>-<id>` — a blamable food/medication row (`type` = food|med) —
  **new**
- `checkin-screen` — host screen root (existing, from log_feeling)

## Verifies-with
- Migration (AC1): `app/test/services/migration_*` (v10→v11 integration).
- Storage logic (AC2–AC5, AC8–AC11): `app/test/services/food_suspicion_test.dart`
  via in-memory DB / fake storage — seed items+meds at controlled timestamps, save
  a log, assert rows. Window boundary, fan-out, regenerate, cascade, aggregation.
- Blame modal + entry-point gating (AC6, AC7, AC12):
  `app/test/widgets/blame_sheet_test.dart` via `storageOverride` fake.
- e2e: feeling→(symptom)→blame→pick item→save journey via the explore rig once the
  modal anchors land; auto-blame has no UI surface (assert via storage in widget/
  integration layer).
