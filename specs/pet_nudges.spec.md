# Spec — Virtual pet, nudges: gentle reminders to log

> Status: draft · Feature: pet_nudges · Added: 2026-11-23
> Source of truth for the pet's reminder notifications and the two notification
> fixes they depend on.

## Requirement

When the user drifts from logging, the pet gently asks to be looked after: a local
notification such as "Your pet is getting hungry — log a meal to feed it." The point is
consistency of logging, not calorie control. Nudges key on the **absence of a log**, are
capped and quiet-houred so they help rather than nag, and can be paused. This is the
sad-path counterpart to `specs/virtual_pet.spec.md` (layer 1 was happy-path only).

## Constraints (inherited)

- **No judgement / honesty-first:** nudges trigger on *not having logged*, never on a
  calorie deficit or amount (doc 03 §3.1). Copy is pet-voiced and gentle — no "failed",
  "over", "under", no numbers framed as failure, no calorie-restriction framing (ED
  safety, doc 03 §3.4). A full day or a light-eating day is never scolded.
- **Reuse `NotificationService`:** extend the existing `flutter_local_notifications`
  service (`app/lib/services/notification_service.dart`), its channel pattern, timezone
  scheduling and permission flow. Do not add a second notification stack.
- **Respect the pet switch:** when `pet_enabled` (virtual_pet) is false, no nudges at all.
- **Derive, don't store sensor state:** "due" is computed from existing journal data
  (last meal `created_at`, today's water vs `effectiveWaterMl`) plus small nudge
  bookkeeping (last-fired times, pause flag). No new domain tables.
- **AI-optional:** no AI in this feature.
- **Anchors:** every new interactive widget gets `Semantics(identifier:)`, registered in
  `specs/anchors.md`.

## Decisions (pinned 2026-11-23)

- **Triggers v1 (two):** *(user)*
  - **Hungry:** no meal logged for ≥ 5 waking hours (waking = after quiet-hours end),
    and the day is not already fully fed. Keys on the act of logging a meal, not calories.
  - **Thirsty:** today's water < 50% of the effective water target (`effectiveWaterMl`,
    64 oz when unset) after 15:00 local.
- **Cadence:** max **2** nudges/day; **quiet hours 22:00–08:00** (never fire; defer to
  quiet-end); minimum **3 h** spacing between nudges. *(user defaults)*
- **Reschedule on log:** a successful meal log cancels/defers the pending hungry nudge; a
  water log that brings water ≥ target cancels the day's thirsty nudge. Logging reschedules
  the next evaluation. *(intent)*
- **Pause:** a manual "Pause pet reminders" switch in Settings. While paused, no nudges are
  scheduled or fired (and later, no decay/death). SharedPreferences `pet_nudges_paused`,
  default `false`. *(user: manual pause)*
- **Tone / copy:** pet-voiced, gentle, no numbers-as-failure. Hungry → title "Your pet is
  getting hungry", body "Log a meal to feed it." Thirsty → title "Your pet is thirsty",
  body "Log some water to fill its bowl." *(fiat — tune wording)*
- **Fix A — notification id namespacing (blocker, doc 03 §2e):** reserve non-overlapping
  id ranges so nothing collides. Check-ins: meals keep `entryId`; medications offset by a
  constant `medCheckinIdOffset = 1_000_000`. Nudges use fixed reserved ids
  `nudgeHungryId = 2_000_001`, `nudgeThirstyId = 2_000_002`. Entry ids never reach these
  ranges in practice; documented as the contract. *(intent)*
- **Fix B — tap handler (blocker, doc 03 §2e):** `NotificationService.initialize` registers
  `onDidReceiveNotificationResponse`, routing by payload: `checkin:<id>` → open the
  check-in screen for that entry; `nudge:meal` → open Log Meal; `nudge:water` → open the
  Log Water sheet. A top-level/static callback as the plugin requires. *(intent)*
- **Logic seam (pure, testable):** `app/lib/models/pet_nudge.dart` —
  `PetNudgeState { DateTime? lastMealLog; int waterToday; int waterGoal; List<DateTime>
  firedToday; bool paused; bool petEnabled; }` and a pure
  `List<PetNudgeKind> dueNudges(PetNudgeState s, DateTime now)` applying all rules above.
  The service schedules from its result; the rules are unit-tested without the plugin. *(intent)*
- **Evaluation points:** on app resume/journal load and after any log screen closes
  (same hooks the Goals panel and pet avatar already use). Counts roll at midnight on the
  next evaluation, like the Goals panel — not a live background tick. *(intent)*
- **Scoreboard (not code):** before shipping, record the baseline of distinct days with
  any entry per week from current data; compare after. Noted here, measured out-of-band. *(doc 03 §5)*

## Acceptance criteria (Given / When / Then)

1. **AC1 — hungry due.** Given `lastMealLog` 6 h before `now`, `now` 14:00, 0 fired today,
   not paused, pet enabled, then `dueNudges` contains `hungry`. Given `lastMealLog` 2 h
   before `now`, it does not.
2. **AC2 — thirsty due.** Given water 20 of 64 oz target and `now` 16:00, then `dueNudges`
   contains `thirsty`. Given water 40 of 64 (≥50%), it does not. Given `now` 13:00, it does
   not (before 15:00).
3. **AC3 — quiet hours.** Given hungry conditions met but `now` 23:30, `dueNudges` is empty;
   the scheduled fire time is the next 08:00.
4. **AC4 — daily cap.** Given 2 entries in `firedToday`, `dueNudges` is empty regardless of
   conditions.
5. **AC5 — min spacing.** Given one fire 1 h before `now`, no new nudge is due; given the
   last fire ≥ 3 h before `now`, an otherwise-due nudge is due.
6. **AC6 — pause and pet-off.** Given `paused` true, `dueNudges` is empty. Given
   `petEnabled` false, `dueNudges` is empty.
7. **AC7 — reschedule on log.** Given a pending hungry nudge, when a meal is logged, then
   the hungry nudge id is cancelled. When water is logged bringing it ≥ target, the thirsty
   nudge id is cancelled.
8. **AC8 — id namespacing (Fix A).** A meal with entry id 5 and a medication with entry id
   5 schedule two distinct notification ids (5 and 1_000_005). The nudge ids (2_000_001,
   2_000_002) differ from both.
9. **AC9 — tap routing (Fix B).** A response with payload `checkin:42` opens the check-in
   screen for entry 42; `nudge:meal` opens Log Meal; `nudge:water` opens the Log Water sheet.
10. **AC10 — gentle copy.** The hungry and thirsty notification bodies contain none of
    "failed", "over", "under", "goal missed", or a bare deficit number; they match the
    pinned pet-voiced strings.
11. **AC11 — pause switch.** Given the Settings dialog, toggling "Pause pet reminders" sets
    `pet_nudges_paused` and it survives a shell rebuild; `switch-pet-nudges-paused` is the
    anchor (✱ if SwitchListTile absorbs it; fallback tap by text "Pause pet reminders").

## Anchors (explore rig)

- `switch-pet-nudges-paused` — Settings "Pause pet reminders" switch (✱ possible)

## Out of scope (later passes)

Decay/death and the egg · in-app visual mood (hungry/thirsty sprite) · calorie-proportional
hunger · reactions to suspect foods · stickers/rewards (next slice) · watch delivery of the
nudge over the C60 `0xFF00` channel · streak logic.

## Verifies-with

- Unit: `app/test/models/pet_nudge_test.dart` (AC1–AC8 via `dueNudges` + id constants)
- Widget: `app/test/services/notification_tap_test.dart` (AC9 routing),
  `app/test/widgets/settings_dialog_pet_nudges_test.dart` (AC11)
- e2e: deferred (local notifications fire out of the explore rig; pure logic carries it)
