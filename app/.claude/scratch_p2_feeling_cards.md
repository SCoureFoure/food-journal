# P2 — Meal card check-in picker

## What was deferred

The "Log Check-in" `TextButton` on `_MealTile` in `home_screen.dart` still uses the old flow
(push `/checkin` with `mealId`). The user wants to:

1. **Remove** the `TextButton.icon` "Log Check-in" button from `_MealTile`.
2. **Replace** it with an inline picker that lets the user associate a `ReactionLog` to a specific
   meal card without leaving the list view — OR navigate to a redesigned check-in that is
   pre-associated with the card.

## Design intent (user's words)

> "we are going to remove that button from the meal and associate feelings to cards with a picker"

## Options to consider

### Option A — Quick-reaction chips inline
Replace the button with a row of reaction chips on the expanded tile:
`😊 Good` · `😐 Mild` · `😖 Bad`
Tapping one saves a `ReactionLog` directly without navigating away.
Pros: frictionless. Cons: no notes or symptom detail.

### Option B — Bottom sheet check-in
Tapping "How did I feel?" (small icon button) opens a `showModalBottomSheet`
with the full check-in form (symptoms + severity + notes), pre-filled with `mealId`.
Pros: full detail, no full-screen navigation. Cons: slightly more taps.

### Option C — Dedicated button → full screen (current behavior, kept but restyled)
Keep navigation but make the button less prominent.

**Recommended: Option B** — bottom sheet gives full detail without losing journal context.

## Files to change

- `app/lib/screens/home/home_screen.dart` — `_MealTile._buildChildren`:
  - Remove `TextButton.icon('Log Check-in')`.
  - Add small icon button (e.g. `Icons.sentiment_satisfied_alt`) that opens bottom sheet.
- Extract the check-in form from `checkin_screen.dart` into a reusable
  `CheckinForm` widget so it can be used in both the bottom sheet and the full screen.
- `app/lib/screens/checkin/checkin_screen.dart` — wrap `CheckinForm` in `Scaffold`.

## Acceptance criteria

- Meal tile has no "Log Check-in" text button.
- Tapping the reaction icon on an expanded meal tile opens check-in (bottom sheet or full screen).
- Standalone "Feeling…" FAB option still works (no mealId).
- `ReactionLog` saved correctly in both flows.
- `overallSymptoms` on `MealEntry` updated when check-in is linked to a meal.
