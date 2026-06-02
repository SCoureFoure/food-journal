# Spec — AI parsing in Create Saved Item

> Status: active · Feature: create-saved-item · Added: 2026-06-01
> Format: provisional (markdown-contract). Source of truth for the AI-parse
> behavior of `CreateSavedItemSheet`.

## Requirement

When building a reusable saved item, the user can describe it in free text and
have the AI parse that text into component food items (with macros), instead of
adding every component by hand.

## Constraints (inherited)

- **AI-optional** (CLAUDE.md): AI *prefills*, never blocks. If the worker is
  unavailable, the key is missing, the call fails, or the user ignores the
  field — the full manual create flow stays usable. No AI output is required to
  save an item.
- **Reuse**: parsing uses the existing `AiService.parseMeal` pipeline and the
  sheet's existing `FoodItemDraft → component card` path. No new AI plumbing.

## Decisions (pinned 2026-06-01)

- **Input modality:** text only (no photo/voice).
- **Name fill:** parsed `title` fills the item name *only when the name field is
  empty*; never overwrites a name the user typed.
- **Merge:** parsed components **append** to any existing component cards
  (non-destructive; user may parse multiple times).

## Acceptance criteria (Given / When / Then)

1. **AC1 — manual path unaffected (fallback).**
   Given no AI interaction, when the user builds and saves an item manually,
   then it saves exactly as before. (AI presence changes nothing.)

2. **AC2 — text parse populates components.**
   Given the AI field has a description, when the user taps Parse and the call
   succeeds with N items, then N component cards are appended.

3. **AC3 — name fill when empty.**
   Given the name field is empty and parse returns a title, when parse succeeds,
   then the name field is set to that title. Given the name is already filled,
   the name is left unchanged.

4. **AC4 — append, not replace.**
   Given M component cards already exist, when a successful parse returns N
   items, then the list has M+N cards (existing cards preserved).

5. **AC5 — parse failure is non-blocking (fallback).**
   Given the AI call returns failure, when the user taps Parse, then an error
   message is shown and the form remains fully editable/savable. No crash, no
   lost input.

6. **AC6 — empty input guard.**
   Given the AI field is empty/whitespace, when the user taps Parse, then no
   call is made and a prompt to enter text is shown.

7. **AC7 — historical-meal context injection.**
   Given the description references a past meal ("leftovers", "same as last
   friday"), when the user taps Parse, then the `MealMemoryService` context
   snippet is built and passed to `parseMeal(mealContext:)` so the model can
   resolve the reference against stored history. Given a non-referential
   description, no snippet is built (no needless DB hit) and `mealContext` is
   null. Reuses the existing log-meal memory path verbatim.

## Anchors (explore rig)

- `saved-item-ai-field` — the AI description text field
- `btn-parse-saved-item-ai` — the Parse button

## Verifies-with

- Widget tests: `test/widgets/create_saved_item_sheet_test.dart` (fake `AiService`).
- e2e: navigate Food → Create saved item; field present; manual fallback works.
  (Live parse depends on worker availability.)
