# Spec — Log Meal AI parse (autofill)

> Status: active · Feature: log_meal_ai_parse · Added: 2026-06-02
> Source of truth for the AI autofill flow on the Log Meal screen
> ([log_meal_screen.dart](../app/lib/screens/log_meal/log_meal_screen.dart)).

## Requirement

On the Log Meal screen the user describes a meal in free text and/or attaches a
photo, taps **Autofill with AI**, and the screen calls the parse service
(`AiService.parseMeal`) and fills the food-item cards (name, portion, macros) from
the structured result. Autofill is the meal's starting point: it **replaces** the
current item list. Parsing never blocks — any failure surfaces an error and leaves
the manual form fully usable. When the description references a past meal
("leftovers from last night"), the meal-memory engine injects a context snippet so
the AI can pre-fill without the user re-typing.

## Constraints (inherited)

- **AI-optional**: when AI is toggled off in Settings the autofill button is absent;
  the manual food-item form and the meal-memory "Did you mean?" quick-copy carry the
  flow. AI pre-fills, never gates.
- **Schema = contract**: parsed drafts become `FoodItem`s written via
  `StorageService.saveMeal`; macro fields are ints, nullable.
- **Side-effects**: saving a *new* meal schedules a check-in notification
  (`NotificationService.scheduleCheckin`). Autofill itself has no side-effect.
- **Service seams**: screen takes `aiOverride / storageOverride / memoryOverride /
  notificationsOverride / settingsOverride`; production passes none.

## Decisions (pinned 2026-06-02)

- **Replace, not append** — Log Meal autofill clears existing food items and
  repopulates from the result. (Diverges deliberately from
  [create_saved_item_ai_parse](create_saved_item_ai_parse.spec.md), which appends.
  Confirmed intended: autofill defines the meal's starting list.)
- **Title prefill only when empty** — `result.title` fills the title field only if
  the user hasn't typed one; a user-entered title is never overwritten.
- **Empty-input guard** — with no text *and* no photo, autofill shows
  "Add a description or photo before autofilling." and does **not** call the service.
- **Image-only autofill allowed** — a photo with empty text is a valid input; text
  is sent as `null`, `imageBytes` carries the request.
- **Context injection gated** — a snippet is built and passed as `mealContext` only
  when AI is enabled **and** text is non-empty **and** `isReferential(text)` is true;
  otherwise `mealContext` is null (no DB hit).

## Acceptance criteria (Given / When / Then)

1. **AC1 — happy-path text parse.** Given AI enabled and a description, when Autofill
   is tapped and the service returns N items, then N food-item cards render.
2. **AC2 — title prefill when empty.** Given an empty title and a result with a title,
   when parse succeeds, then the title field is set to `result.title`.
3. **AC3 — title not overwritten.** Given the user typed a title, when parse returns a
   different title, then the user's title stands.
4. **AC4 — replace existing items.** Given the user has manual item cards, when a parse
   returns M items, then the list shows exactly M cards (old cleared, not appended).
5. **AC5 — failure non-blocking.** Given the service returns `success:false`, when
   Autofill is tapped, then the error message shows, no cards are added, and adding a
   manual item afterward still works.
6. **AC6 — empty-input guard.** Given empty text and no photo, when Autofill is tapped,
   then the service is not called and "Add a description or photo before autofilling."
   shows.
7. **AC7 — image-only autofill.** Given a photo and empty text, when Autofill is tapped,
   then `parseMeal` is called with `imageBytes` set and `text` null.
8. **AC8 — referential context injected.** Given referential text and AI enabled, when
   Autofill is tapped, then `buildContextSnippet` runs and its result reaches
   `parseMeal.mealContext`.
9. **AC9 — non-referential ⇒ null context.** Given non-referential text, when Autofill
   is tapped, then `parseMeal.mealContext` is null.
10. **AC10 — AI-off hides autofill.** Given AI disabled in Settings, then the
    "Autofill with AI" button is absent and the manual food-item controls remain.

## Anchors (explore rig)

- `log-meal-screen` — screen root
- `log-meal-title` — title field
- `log-meal-input` — description field (newly blazed; shared `LogDescriptionSection`)
- `btn-autofill-meal` — Autofill-with-AI button (shared section, meal variant)
- `btn-add-item` / `btn-create-item` / `btn-add-from-history` / `btn-add-from-favorites`
  / `btn-my-items` — food-item discovery + add controls
- `btn-save-meal` — save (✱ absorbed by Material button under UIAutomator; tap via
  bounds / Dart integration_test reads it in-process)

## Verifies-with

- Widget tests: [app/test/widgets/log_meal_screen_test.dart](../app/test/widgets/log_meal_screen_test.dart)
  — fakes for AI/storage/memory/notifications/settings; the happy-path fake returns
  drafts parsed from `test/fixtures/import/single_meal.json` so the flow runs against
  real structured data ("against the fixtures").
- e2e: deferred (worker-dependent). Explore-rig journey: seed via
  `full_week.json` / `single_meal.json` import, open Log Meal, type, tap
  `btn-autofill-meal`, assert cards. Blocked on live worker; fakes carry the behavior.
