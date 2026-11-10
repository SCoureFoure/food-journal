# Spec — Daily goals (calories, macros, water)

> Status: draft · Feature: calorie_goals · Added: 2026-11-10
> Source of truth for daily nutrition/water targets and the Goals panel on the journal tab.

## Requirement

The user can set optional daily targets for calories, protein, carbs, fat and water.
A collapsible Goals panel, fixed above the journal list, shows today's intake against
each target as a green fill bar (the water bar stays blue). Targets are kept as dated
history so later features (the virtual pet, weekly averages) can rate a past day against
the target that applied on that day. This is layer 0 of the pet build order
(`docs/virtual-pet/03-concept-and-feasibility.md` §4a, §5) and is useful without a pet.

## Constraints (inherited)

- **Product amendment:** `docs/FEATURES.md` non-goal "No calorie goals or diet plans"
  becomes "Calorie, macro and water goals: yes. Prescriptive diet plans or meal
  prescriptions: still no." Amended in the same change set.
- **Schema = contract:** new table means schema v16 → v17 with an additive `onUpgrade`
  step, a matching `onCreate`, `migrationStepVersions` extended, and the migration
  order test updated.
- **AI-optional:** no AI in this feature. Targets are typed in by hand.
- **No judgement:** going over a target is shown neutrally. No warning colour, no
  "over by" message styled as an error (docs/virtual-pet/03 risk 3).
- **Reuse:** fill bar reuses `LiquidLinearProgressIndicator` (as in
  `widgets/home/water_summary.dart`); collapse reuses `CardExpansionTile` +
  `SettingsService.setCardCollapsed`; intake reuses `StorageService.getMacroTotalsForMeals`.
- **Anchors:** every new interactive widget gets `Semantics(identifier:)`, registered in
  `specs/anchors.md`.

## Decisions (pinned 2026-11-10)

- **Placement:** Goals panel is fixed above the scrolling journal list (outside the
  `ListView`). It never scrolls. Collapsed, it shows a one-line header. *(user)*
- **Metrics in v1:** calories (kcal), protein (g), carbs (g), fat (g), water. *(user)*
- **Storage:** `goal_history` table, schema v17. Each save inserts one snapshot row
  holding all five targets. *(user: history table now)*
- **Over target:** bar stays full; text reads `current / target` in the normal colour. *(user)*
- **Unset target:** a metric with a null target has no row in the panel. *(user)*
- **Target for a day D:** the snapshot with the greatest `(effectiveDate, id)` where
  `effectiveDate <= D`. No such row: all targets null, except water (see next). *(intent)*
- **Water default:** with no water target saved, `waterMl` is null (no water row in the
  Goals panel), and each day's `WaterSummary` fills toward 1893 ml (64 oz), the current
  hard-coded goal, via `DailyGoals.effectiveWaterMl`. Existing behaviour does not change.
  `WaterSummary` reads the target for its own day instead of the constant. *(intent)*
- **Seam:** `app/lib/models/daily_goals.dart` — `DailyGoals`, `GoalSnapshot`, `GoalIntake`,
  and the pure `goalsForDate(history, day)` that implements the "target for a day D" rule.
- **Water unit:** stored in ml, entered and shown in oz (1 oz = 29.5735 ml), as the
  water sheet does today. *(intent)*
- **effectiveDate:** the local calendar day of the save (midnight). Saving twice on one
  day inserts two rows; the later `id` wins. *(intent)*
- **Panel shows today only.** Intake = today's meals (by `meals.date`) and today's water logs. *(intent)*
- **Edit entry point:** an edit (pencil) button, first row inside the expanded panel,
  opens an edit dialog with five optional whole-number fields, pre-filled with today's
  targets. Empty field = clear that target. 0 is rejected. *(fiat — confirm)*
- **No goals set:** the panel header shows a "Set goals" button instead of bars. *(fiat — confirm)*
- **Export/import:** goal history is NOT in the JSON export in v1. *(fiat — confirm)*
- **Colour:** goal bars use a green fill (`Colors.green.shade400` at alpha 110 on
  `Colors.green` alpha 22), mirroring the water bar's blue values. *(fiat — tune on screen)*

## Acceptance criteria (Given / When / Then)

1. **AC1 — migration.** Given a v16 database, when the app opens at v17, then
   `goal_history` exists and all v16 rows are unchanged.
2. **AC2 — save and read.** Given no goals, when the user saves calories 2000 and protein
   140 on 2026-11-10, then `getGoalsForDate(2026-11-10)` returns calories 2000, protein 140,
   carbs/fat/water null, and `effectiveWaterMl` is 1893 (default).
3. **AC3 — history is dated.** Given calories 2000 saved on 2026-11-01 and 1800 saved on
   2026-11-10, then the target for 2026-11-05 is 2000 and for 2026-11-10 is 1800. A day
   before 2026-11-01 has a null calorie target.
4. **AC4 — same-day resave.** Given two saves on one day (2000 then 2100), the target for
   that day is 2100.
5. **AC5 — fill bar.** Given intake 1450 of target 2000, the calorie bar fills 72.5% and
   reads `1450 / 2000 kcal`. Given intake 2150 of 2000, the bar is 100% full, reads
   `2150 / 2000 kcal`, and uses the same colour as below target.
6. **AC6 — hidden metrics.** Given only calories and water set, the panel shows exactly
   two rows: calories and water.
7. **AC7 — empty state.** Given no targets saved (water default only), the panel shows
   the "Set goals" button and no bars.
8. **AC8 — edit.** Given the edit dialog open, when the user enters fat 70, clears
   calories, and saves, then a new snapshot is stored with fat 70, calories null, other
   values carried over, and the panel updates without leaving the screen.
9. **AC9 — collapse persists.** Given the panel collapsed, when the journal is rebuilt
   (tab switch or app restart), then the panel is still collapsed.
10. **AC10 — fixed placement.** Given a journal long enough to scroll, when the list scrolls,
    the Goals panel stays at the same position on screen.
11. **AC11 — today's intake.** Given meals today totalling 1450 kcal and a meal yesterday,
    the calorie row shows 1450 (yesterday is not counted). Logging a new meal and
    returning to the journal updates the row.
12. **AC12 — water reuses target.** Given water target 2366 ml (80 oz) saved, then the
    Goals panel water row and today's `WaterSummary` both read `/ 80 oz`.

## Goal calculator (amendment, 2026-11-10)

A "Calculate" button in the edit dialog opens a calculator that estimates calorie and
macro targets from body stats. The result only pre-fills the edit dialog; the user still
reviews and saves. Seam: `app/lib/models/goal_estimate.dart` (`GoalProfile`,
`estimateGoals`).

Decisions:

- **Formula:** Mifflin-St Jeor. BMR = 10×kg + 6.25×cm − 5×age + (5 male formula | −161
  female formula). TDEE = BMR × activity (1.2 / 1.375 / 1.55 / 1.725). *(intent)*
- **Goal delta:** lose 1 lb/wk −500, lose 0.5 lb/wk −250, maintain 0, gain 0.5 lb/wk +250. *(intent)*
- **Floor:** calories never below 1200. *(intent — safety)*
- **Macros:** protein 0.8 g per lb; fat 30% of calories; carbs take the rest. *(user: calories + macros)*
- **Water:** the calculator does not change the water field. *(intent)*
- **Units:** weight in lb, height in ft + in. A kg weight log is converted. *(user)*
- **Profile saved:** inputs are saved in SharedPreferences (`goal_profile`) and pre-fill the
  next run. Weight pre-fills from the latest weight log when one exists, else the saved
  profile. *(user)*
- **Valid ranges:** weight 50–700 lb, height 4 ft 0 in – 8 ft 0 in (48–96 in), inches 0–11,
  age 18–100. Out of range or empty: field error, no result. *(fiat — confirm)*
- **Disclaimer:** "Estimate only, not medical advice." shown in the calculator. *(intent)*
- **Labels:** formula choice reads "Male formula" / "Female formula". *(fiat — confirm)*

13. **AC13 — estimate.** Given 180 lb, 5 ft 10 in, age 30, male formula, moderate, lose 1
    lb/wk, then the estimate is 2263 kcal, protein 144 g, carbs 253 g, fat 75 g.
14. **AC14 — floor.** Given 110 lb, 5 ft 0 in, age 60, female formula, sedentary, lose 1
    lb/wk, then calories are 1200 (not 689), protein 88, carbs 122, fat 40.
15. **AC15 — prefill only.** Given the edit dialog with water 80 oz, when the user runs the
    calculator and taps "Use these", then calories/protein/carbs/fat fields hold the
    estimate, water still reads 80, and nothing is saved until the user taps Save.
16. **AC16 — profile remembered.** Given a calculator run, when the calculator opens
    again, then height, age, formula, activity and goal are pre-filled. Weight comes from
    the latest weight log when one exists.
17. **AC17 — invalid input.** Given age 15 (or an empty height), when the user taps
    "Use these", then the field shows an error and the calculator stays open.

## Past days show their own goal (amendment, 2026-11-10)

An opened journal day's DAY TOTALS bar reads `<total> / <goal>` for each metric that had
a target on THAT day (`goalsForDate(history, day)`), not today's target. Computed on
open from existing data; no end-of-day job, works for days before the feature shipped
only if a goal applied then. *(user)*

- Metric with a goal on that day: cell shows even at 0 (`0 / 70g`). Without one: as before (hidden at 0). *(intent)*
- Cells wrap to a second line instead of overflowing. *(intent)*
- `DateSection` takes the day's `DailyGoals`; water reads `goals.effectiveWaterMl` (replaces `waterGoalMl`). *(intent — one source)*

18. **AC18 — past day uses its own goal.** Given calories 2000 saved on 2026-11-01 and 1800
    on 2026-11-10, when the user opens 2026-11-05 with 1450 kcal logged, then DAY TOTALS
    reads `1450 / 2000`. On 2026-10-30 (before any goal) it reads `1450`.

## Weight goal (amendment, 2026-11-10)

A calorie goal already carries over day to day until the user saves a new one. A goal set
from the calculator can now also carry a **target weight**. When a weigh-in reaches it, the
Goals panel asks whether to set a new goal. Nothing changes until the user saves. *(user)*

Decisions:

- **Where it's set:** an optional "Target weight (lb)" field in the calculator, shown only
  for a lose or gain pace. Maintain means no target. *(user)*
- **Direction:** comes from the pace: lose paces give `lose`, gain paces give `gain`. *(intent)*
- **Wrong side rejected:** with `lose`, the target must be below the calculator weight; with `gain`,
  above it. Otherwise the field shows an error and the calculator stays open. Range 50–700 lb. *(user)*
- **Storage:** `goal_history` gains nullable `target_weight_lb` (REAL) and `weight_direction`
  (TEXT `lose|gain`), schema v17 → v18, additive. They live in `DailyGoals`, so
  `goalsForDate` carries them forward like every other target. *(intent: "saved with the goal history")*
- **Edit dialog:** shows "Weight goal: <n> lb" with a Clear button while a target is set.
  Saving manual edits keeps the target. *(intent)*
- **Met:** the first weigh-in at or past the target (≤ for lose, ≥ for gain), dated on or
  after the start of the current target. "Start" is the effective date of the earliest
  snapshot in the unbroken run of snapshots carrying the same target and direction, so
  editing calories mid-goal does not reset it. kg weigh-ins are converted (× 2.20462). *(user: one weigh-in is enough)*
- **Prompt:** above the Goals panel's collapsible header (visible collapsed or expanded):
  "You reached <n> lb! Set a new goal?" with "Set new goal" and "Not now". *(user: ask me first)*
- **Set new goal:** opens the calculator (weight pre-filled from the latest weigh-in), then
  the edit dialog pre-filled with its result plus today's water target. Saving stores a new
  snapshot; the new pace/target replaces the old one, so the prompt goes away. Cancel at
  either step changes nothing and the prompt stays. *(intent)*
- **Not now:** hides the prompt until a newer weigh-in exists (SharedPreferences
  `weight_goal_dismissed_log_id` = highest weight-log id at dismissal). *(user)*
- **Pet:** the pet sheet does not show the prompt. *(user)*

19. **AC19 — migration.** Given a v17 database with goal rows, when the app opens at v18,
    then `goal_history` has `target_weight_lb` and `weight_direction`, old rows read them as
    null, and other columns are unchanged.
20. **AC20 — round trip.** Given a save with target 170 lb, direction lose, then
    `getGoalHistory().last.goals` has `targetWeightLb` 170.0 and `weightDirection` lose,
    and `goalsForDate` for a later day returns them.
21. **AC21 — calculator target.** Given weight 180, pace "Lose 1 lb a week", target 170,
    when "Use these" is tapped, then the result carries target 170 / lose. Given target 185
    with a lose pace, the target field shows an error and the calculator stays open. Given
    pace "Maintain weight", the target field is not shown and the result has no target.
22. **AC22 — met (lose).** Given a lose target 170 set 2026-11-01 and weigh-ins 175 lb
    (11-03) and 169.5 lb (11-08), then the goal is met on 11-08. Given only 171 lb, not met.
    A 165 lb weigh-in dated 10-30 (before the target started) does not count.
23. **AC23 — met (gain, kg).** Given a gain target 150 lb and a weigh-in of 68.5 kg
    (151.0 lb), then the goal is met.
24. **AC24 — run start.** Given target 170/lose saved 11-01, then calories edited 11-05
    (same target carried), and a 169 lb weigh-in on 11-03, then the goal is met.
25. **AC25 — prompt.** Given a met goal, the Goals panel shows `goal-weight-met` with
    "You reached 170 lb! Set a new goal?". "Not now" hides it; it stays hidden after a
    reload and comes back after a newer weigh-in.
26. **AC26 — set new goal.** Given the prompt, tapping "Set new goal" opens the calculator;
    "Use these" then opens the edit dialog with the estimate and today's water; Save stores
    a snapshot with the new target (or none for maintain) and the prompt disappears.

## Anchors (explore rig)

- `goals-panel` — panel root
- `item-header-goals` — `CardExpansionTile` title (collapse toggle)
- `btn-edit-goals` — edit button, first row of the expanded panel
- `btn-set-goals` — empty-state button
- `goal-row-<metric>` — one per shown metric (`calories|protein|carbs|fat|water`)
- `edit-goals-dialog` — dialog root
- `field-goal-<metric>` — dialog fields
- `btn-save-goals` — dialog save
- `btn-calc-goals` — "Calculate" button in the edit dialog
- `goal-calculator-dialog` — calculator root
- `field-calc-<input>` — `weight|height-ft|height-in|age|formula|activity|goal`
- `calc-result` — live estimate line
- `btn-calc-apply` — "Use these"
- `field-calc-target` — calculator target weight (lose/gain pace only)
- `goal-weight-target` — edit dialog "Weight goal: <n> lb" line
- `btn-clear-weight-goal` — edit dialog Clear for the weight goal
- `goal-weight-met` — "You reached <n> lb!" prompt above the Goals header
- `btn-weight-goal-new` — prompt "Set new goal"
- `btn-weight-goal-later` — prompt "Not now"

## Verifies-with

- Service: `app/test/services/goals_storage_test.dart` (AC2–AC4), `migration_order_test.dart` + `app/test/services/migration_v17_goals_test.dart` (AC1)
- Widget: `app/test/widgets/goal_fill_bar_test.dart` (AC5), `app/test/widgets/goals_panel_test.dart` (AC6–AC9, AC12), home layout test (AC10–AC11)
- e2e: explore rig screenshot of the journal tab with goals set, collapsed and expanded
