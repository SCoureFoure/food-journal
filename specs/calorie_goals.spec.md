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

## Verifies-with

- Service: `app/test/services/goals_storage_test.dart` (AC2–AC4), `migration_order_test.dart` + `app/test/services/migration_v17_goals_test.dart` (AC1)
- Widget: `app/test/widgets/goal_fill_bar_test.dart` (AC5), `app/test/widgets/goals_panel_test.dart` (AC6–AC9, AC12), home layout test (AC10–AC11)
- e2e: explore rig screenshot of the journal tab with goals set, collapsed and expanded
