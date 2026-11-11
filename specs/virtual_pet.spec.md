# Spec — Virtual pet, layer 1: happy path (feeding)

> Status: draft · Feature: virtual_pet · Added: 2026-11-10
> Source of truth for the pet avatar, the pet sheet, and how logging feeds the pet.

## Requirement

A small companion creature floats in a bottom corner of the app, on every tab, and
can be opened from anywhere. Logging a meal or water feeds it: its Food and Water
meters fill and it reacts with a short bounce. The point is to encourage the user to
take care of themselves by taking care of it. This is layer 1 of the pet build order
(`docs/virtual-pet/03-concept-and-feasibility.md` §5), happy path only. What happens
when the user does not log (decay, sad states, notifications, death) is a later design
pass.

## Constraints (inherited)

- **No judgement:** the pet never punishes. A full meter stays full; going past the
  target is shown neutrally (same colour, `current / target` text), as the Goals panel
  does (calorie_goals AC5). No "hungry", "starving" or "over" wording in this slice.
- **Own art only:** the creature is a code-drawn placeholder block until the user's
  own pixel art exists. No third-party asset packs, no generated images.
  `docs/virtual-pet/03` §4d (Craftpix sprites) is superseded.
- **No schema change:** all pet state in this slice is derived from existing journal
  data on each reload. Nothing new is stored except one setting.
- **Reuse:** today's meals and water come from the totals the journal already builds in
  `HomeScreenState._load`; the water target is `goalsForDate(history, today).effectiveWaterMl`;
  meters reuse `GoalFillBar`; the setting follows the `SettingsService` getter/setter +
  `SwitchListTile` + shell re-read pattern.
- **AI-optional:** no AI in this feature.
- **Anchors:** every new interactive widget gets `Semantics(identifier:)`, registered in
  `specs/anchors.md`.

## Decisions (pinned 2026-11-10)

- **Layer:** feeding from logging only. No calorie-proportional hunger (that is layer 2). *(user)*
- **What feeds:** meal entries and water logs. Medications, check-ins, weight: not in
  this slice. *(user)*
- **Placement:** a floating avatar in the app shell's `Stack`, shown on both tabs, in the
  bottom corner opposite the add (+) button: bottom-left normally, bottom-right in
  left-handed mode. *(user)*
- **Open:** tapping the avatar opens a modal bottom sheet with a large block and two
  meters, Food and Water. Swipe down or tap outside to close. *(user)*
- **Food meter (amended 2026-11-10):** today's calories ÷ today's calorie goal
  (`goalsForDate(history, today).calories`), capped at full. Reads `<kcal> / <goal> kcal`,
  the same numbers as the Goals panel calorie row. Meal *count* was dropped because
  every entry (snacks, drinks) is logged as a meal, so a count means nothing. *(user)*
  This pulls layer 2 (proportional feeding) forward; risks 1–4 in doc 03 §3 apply and
  the no-judgement rule covers over-target days.
- **No calorie goal:** the Food meter is replaced by `<kcal> kcal today` and a
  "Set a calorie goal" button that closes the sheet and opens the existing goals editor.
  No default calorie number is invented. *(user)*
- **Set goal from Meal Planning (amended 2026-11-11):** the button first switches the shell
  to the journal tab, then opens the goals editor, so the saved goal shows in the Goals
  panel. *(user)*
- **Meals with no calories** (AI parse skipped or failed) add 0 kcal, as in the Goals
  panel. They still count as feeding for the bounce. *(intent: one source with Goals panel)*
- **Water meter:** today's water ÷ today's water target (`effectiveWaterMl`, 64 oz
  when unset), capped at full. Reads `<oz> / <target oz> oz`, the same numbers as the
  Goals panel water row. *(user)*
- **Default:** pet shown by default; a "Show pet" switch in Settings hides it. *(user)*
- **"Today":** meals counted by `meals.date` and water by `water_logs.date` falling on
  today, exactly as the Goals panel counts. A meal backdated to yesterday does not feed
  today. The `created_at` question is part of the sad-path design. *(intent: one source
  with the Goals panel)*
- **Data flow (seam):** `app/lib/models/pet_feed.dart` defines `PetFeed { mealsToday,
  waterMl, waterGoalMl, caloriesToday, calorieGoal? }` with
  `bool fedSince(PetFeed? previous)`. The shell owns a `ValueNotifier<PetFeed?>` and
  passes it to `HomeScreen` (new optional param `petFeed`); `HomeScreenState._load`
  sets it at the end of every successful load. No second database read. *(intent)*
- **Refresh:** the pet updates whenever the journal reloads (after any log screen or the
  water sheet closes). Meal Planning has no log actions, so nothing is missed. Like the
  Goals panel, counts roll over at midnight on the next reload, not live. *(intent)*
- **Feed reaction:** when a new `PetFeed` arrives and `fedSince(previous)` is true (more
  meals, more calories or more water than the last value), the avatar bounces once (~400 ms up-and-down).
  No bounce on the first load, on unchanged counts, or when counts go down (a delete,
  midnight). Skipped when `MediaQuery.disableAnimations` is true. *(intent)*
- **Unique anchors:** the sheet's meters must not reuse `goal-row-water` because the
  Goals panel is on screen under the sheet. `GoalFillBar` gains an optional
  `semanticsId` (default `goal-row-<metric>`, so existing ids don't change). *(intent)*
- **Placeholder look:** a rounded square block, `colorScheme.primaryContainer` fill with
  a 2 px `colorScheme.primary` border. Avatar 48×48, sheet block 128×128. Avatar sits
  16 px from the side and bottom edges, plus the bottom safe-area inset. *(fiat: tune on
  screen)*
- **Sheet title:** "Your pet" until the creature has a name. *(fiat: confirm or name it)*
- **Setting key:** SharedPreferences `pet_enabled`, default `true`. *(intent)*

## Acceptance criteria (Given / When / Then)

1. **AC1: food level.** *(removed 2026-11-11: the sheet's `GoalFillBar` computes the fill,
   calorie_goals AC5. `PetFeed.foodLevel` is gone until the mood layer needs it.)*
2. **AC2: water level.** *(removed 2026-11-11, as AC1: `PetFeed.waterLevel` is gone.)*
3. **AC3: fed since.** Given previous `PetFeed(2 meals, 946 ml, 1893, 650 kcal)`: a meal
   more gives true; 250 ml more water gives true; more calories with the same meal count
   (an edit) gives true; the same values give false; fewer meals and calories (delete,
   midnight) give false; a previous of `null` (first load) gives false.
4. **AC4: journal publishes the feed.** Given 2 meals dated today (400 + 250 kcal), 1 meal
   dated yesterday, and 946 ml of water today, when the journal loads, then the notifier
   holds `PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650,
   calorieGoal: null)`. Given a snapshot with calories 2000 and water 2366 ml saved,
   `calorieGoal` is 2000 and `waterGoalMl` is 2366.
5. **AC5: avatar on both tabs, opposite the FAB.** Given the pet enabled and right-handed
   mode, the `pet-avatar` sits in the bottom-left quadrant on the journal tab and is
   still shown after switching to Meal Planning. Given left-handed mode, it sits in the
   bottom-right quadrant.
6. **AC6: sheet shows the meters.** Given 1450 kcal of a 2000 kcal goal and 946 ml of
   1893, when the avatar is tapped, then `pet-sheet` opens with `pet-meter-food` reading
   `1450 / 2000 kcal` and `pet-meter-water` reading `32 / 64 oz`. Given 2150 kcal, the
   food meter reads `2150 / 2000 kcal`, is full, and uses the same colour as below target.
7. **AC7: unique ids.** Given the sheet open over the journal with a water goal set,
   `goal-row-water` and `pet-meter-water` are both found, once each.
8. **AC8: bounce on feed.** Given the avatar showing `PetFeed(2, 946, 1893)`, when the
   notifier changes to `PetFeed(3, 946, 1893)`, the bounce animation runs once and ends
   at rest. When it changes to an equal value or to `PetFeed(1, 946, 1893)`, no animation
   runs.
9. **AC9: off switch.** Given no saved setting, the pet is shown. When the user turns off
   "Show pet" in Settings and closes the dialog, then no `pet-avatar` is shown on either
   tab, and it stays hidden after the shell is rebuilt (setting persists).
10. **AC10: no calorie goal.** Given no calorie goal and 650 kcal today, the sheet shows
    `650 kcal today` in `pet-meter-food` and a `btn-pet-set-goal` button, with no food
    bar. Tapping it closes the sheet and opens the edit-goals dialog (`edit-goals-dialog`).
11. **AC11: set goal from Meal Planning.** Given the shell on Meal Planning and no calorie
    goal, when "Set a calorie goal" is tapped in the pet sheet, then the shell shows the
    journal tab and `edit-goals-dialog` is open.

## Anchors (explore rig)

- `pet-avatar`: floating avatar, tap to open the sheet
- `pet-sheet`: bottom sheet root
- `pet-meter-food`: Food meter (`GoalFillBar`, `container: true`); with no calorie goal,
  the `<kcal> kcal today` row
- `btn-pet-set-goal`: "Set a calorie goal" button, shown only with no calorie goal
- `pet-meter-water`: Water meter (`GoalFillBar`, `container: true`)
- `switch-pet-enabled`: Settings "Show pet" switch. SwitchListTile may absorb the id ✱;
  fallback: tap by text `Show pet`

## Out of scope (later passes)

Decay and sad states for days with no logging · hungry/thirsty push notifications
(needs the meal/medication notification-id collision fixed first) · death and egg ·
medication reminders · calorie-proportional hunger (layer 2) · reactions to suspect
foods (layer 3) · stats · the user's own pixel art and sprite-strip player · naming.

## Verifies-with

- Unit: `app/test/models/pet_feed_test.dart` (AC3)
- Widget: `app/test/screens/home_pet_feed_test.dart` (AC4),
  `app/test/widgets/pet_avatar_test.dart` (AC8), `app/test/widgets/pet_sheet_test.dart`
  (AC6), `app/test/screens/app_shell_pet_test.dart` (AC5, AC7, AC9, AC10, AC11)
- e2e: explore rig screenshot of the avatar on both tabs, plus the open sheet, in both
  handedness modes
