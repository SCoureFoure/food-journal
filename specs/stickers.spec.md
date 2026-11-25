# Spec — Goal stickers: positive reinforcement on the Goals panel

> Status: draft · Feature: stickers · Added: 2026-11-23
> Source of truth for the reward stickers shown on the Goals panel.

## Requirement

When the user hits a daily goal or keeps a logging streak, a small pixel sticker
appears on the collapsible Goals panel. Stickers are the carrot to the nudges' stick:
they reward the act of logging and meeting goals, and they only ever add — a missed
goal shows nothing. This is the positive half of the consistency loop.

## Constraints (inherited)

- **No judgement / positive-only:** stickers are awarded, never taken away or shown as a
  failure. An unmet goal or a broken streak simply shows no sticker. No red, no "missed".
- **Honesty-first:** reward the *act of logging* and meeting balanced goals, not eating
  a particular amount (doc 03 §3.1). Every goal metric that can be met earns the same
  kind of sticker, so no food is implicitly "good" or "bad".
- **Derive, don't store (v1):** earned stickers are computed from existing data
  (`goal_history` + today's intake + the logged-day set) on each load. No new table, no
  migration. A persisted sticker book / "new!" state is a later slice.
- **Own art only:** stickers are original code-drawn pixel icons (same discipline as
  `PetBlock`). No third-party packs, no generated images.
- **Reuse:** "met" mirrors the Goals panel bar (`intake.X >= goals.X`). The row lives in
  `GoalsPanel`. Streak is derived from the date maps `HomeScreen._load` already builds.
- **Anchors:** every new widget gets `Semantics(identifier:)`, registered in
  `specs/anchors.md`.

## Decisions (pinned 2026-11-23 — defaults; confirm the 3 forks)

- **Triggers v1:** *(fork 1 — granularity)* one sticker per **met goal metric** (calories,
  protein, carbs, fat, water) where a target is set and `intake >= target`; plus one
  **streak** sticker at the highest milestone reached. *(default: per-metric)*
- **Streak:** *(fork 2)* a logging streak = consecutive days up to today that each have
  any journal entry. Milestones 3 / 7 / 14 / 30 days; show the highest reached as a single
  sticker. This directly rewards consistency (the core scoreboard). *(default: include)*
- **Scope v1:** *(fork 3)* today's earned stickers only, derived, no schema change. A
  collectible history / "new sticker" animation is a later slice. *(default: today-only)*
- **Placement:** a horizontal sticker row inside the expanded Goals panel, above the Edit
  button; hidden entirely when nothing is earned. *(fiat — tune on screen)*
- **Art:** small code-drawn pixel icons — e.g. a medal for a met metric (tinted per
  metric), a flame for the streak. Original. *(fiat — tune)*
- **Logic seam (pure):** `app/lib/models/stickers.dart` —
  `List<StickerKind> earnedStickers(DailyGoals goals, GoalIntake intake, int streakDays)`
  and `int loggingStreak(Set<DateTime> loggedDays, DateTime today)`. The panel renders the
  list; the host computes streak and passes intake/goals. *(intent)*

## Acceptance criteria (Given / When / Then)

1. **AC1 — met metric earns its sticker.** Given calories target 2000 and intake 2000,
   `earnedStickers` contains the calories sticker; given intake 1800, it does not.
2. **AC2 — over target still counts, no penalty.** Given calories target 2000 and intake
   2200, the calories sticker is present (>= is met) and no negative sticker exists.
3. **AC3 — untargeted metric earns nothing.** Given no protein target, no protein sticker
   regardless of protein intake.
4. **AC4 — streak milestone.** Given `streakDays` 3, the result contains exactly the
   3-day streak sticker (not 7/14); given 7, the 7-day one; given 2, no streak sticker.
5. **AC5 — streak counting.** `loggingStreak` counts back from today over consecutive
   logged days: today + the 2 prior days logged, the 3rd prior missing → 3. A gap at
   yesterday → 1 (today only). No logged days → 0.
6. **AC6 — nothing earned, nothing shown.** Given no met goals and a streak below 3, the
   Goals panel shows no `goal-stickers` row.
7. **AC7 — stickers render.** Given the calories sticker and the 7-day streak sticker
   earned, the expanded Goals panel shows `goal-stickers` containing two sticker widgets.

## Anchors (explore rig)

- `goal-stickers` — the sticker row (shown only when ≥1 earned)
- `sticker-<kind>` — an individual sticker (e.g. `sticker-calories`, `sticker-streak-7`)

## Out of scope (later passes)

Persisted sticker book / history across days · "new sticker!" animation or celebration ·
per-meal "you logged" sticker · sharing/exporting stickers (art-redistribution risk) ·
stickers on the watch · stats/quests (doc 03 layers 4–5).

## Verifies-with

- Unit: `app/test/models/stickers_test.dart` (AC1–AC5)
- Widget: `app/test/widgets/goals_panel_stickers_test.dart` (AC6, AC7)
- e2e: explore rig screenshot of the Goals panel with stickers (deferred if it adds no
  signal over the widget test)
