# Spec — Log a feeling (standalone check-in)

> Status: active · Feature: log_feeling · Added: 2026-06-02
> Source of truth for the standalone "How are you feeling?" check-in — creating,
> editing, deleting a feeling log and how it surfaces on the journal feed.

## Requirement
The user logs how they feel as a standalone entry, independent of any meal. From the
home FAB → **Feeling…** they open a check-in: pick an overall **mood** (optional),
select any number of **symptoms**, set each symptom's **intensity**, and add free-text
**notes**. Saving writes one `reaction_logs` row and the feeling appears on the home
feed as its own tile. Feeling poorly again later is a **separate** feeling log — logs
accumulate independently and never overwrite each other. Existing feelings can be
edited (including their date/time) or deleted.

## Out of scope (future work)
- **Meal ↔ feeling association.** `CheckinScreen` carries a dormant `mealId` path
  (`updateMealSymptoms`, meal-summary overwrite) that the current product does not
  exercise — feelings are not linked to meals yet. That linkage is a separate future
  spec; do not encode the meal path as intended behavior here.

## Constraints (inherited)
- **Schema = contract.** A feeling is one `reaction_logs` row: `mealId` NULL,
  `checkinTime`, `symptoms` (JSON string array, insertion-ordered), `symptomLevels`
  (JSON map name→int), `severity` (int, derived), `mood` (int, nullable), `notes`
  (nullable). Shape is stable; changes need a drift migration + integration test.
- **Not AI.** No AI parsing in this flow — pure manual entry. No AI-optional fallback
  applies.
- **Side-effects.** Saving a feeling schedules **no** notification (unlike meal/med
  saves). Standalone feelings are terminal records.

## Decisions (pinned 2026-06-02)
- **New vs edit modes** keyed by constructor:
  - new standalone — `mealId == null && existingLog == null`, title **"How are you
    feeling?"**, **no** date/time row, `checkinTime = DateTime.now()` at save.
  - edit — `existingLog != null`, title **"Edit feeling"**, **shows** date/time row +
    delete; `checkinTime` taken from the editable date/time.
- **Mood is optional.** May be left null and still save. Re-tapping the selected mood
  clears it back to null (toggle).
- **Symptom chip default.** Tapping a symptom chip adds it at `ReactionLevel.mild`;
  untapping removes the symptom and its level. The "How bad?" slider panel renders
  only when ≥1 symptom is selected.
- **Intensity slider** has 4 stops: none / mild / moderate / bad (position 0..3).
- **Severity is derived, never user-set:** `deriveSeverity` = the worst (max-index)
  per-symptom level, or `ReactionLevel.none` when no symptoms.
- **Notes** are trimmed; whitespace-only → stored as `null`.
- **Empty feeling is valid:** zero symptoms + no mood saves a row (severity `none`);
  feed renders it as "No reaction".
- **Accumulation:** every new save is `into(reactionLogs).insert` — a fresh row. New
  feelings never mutate prior ones. Edit (`updateReactionLog`) mutates only the row
  it opened.

## Acceptance criteria (Given / When / Then)
1. **AC1 — new feeling happy path.** Given the new check-in (mealId null, no
   existingLog), when the user picks mood=Good, selects Bloating+Nausea (both Mild),
   types notes, and saves → then exactly one `reaction_logs` row is inserted with
   `mealId == null`, `mood == Good`, `symptoms == ['Bloating','Nausea']`,
   `symptomLevels == {Bloating: mild, Nausea: mild}`, `severity == mild`, notes set,
   and the screen pops.
2. **AC2 — chip default + slider visibility.** Given no symptoms selected, then the
   "How bad?" panel is absent; when a chip is tapped it is added at `mild` and the
   panel appears; when the chip is untapped the symptom and its level are removed.
3. **AC3 — mood optional + toggle.** Given a feeling with symptoms but mood untouched,
   when saved → the row has `mood == null`. Given a selected mood, re-tapping it sets
   `_mood` back to null.
4. **AC4 — empty feeling valid.** Given no symptoms and no mood, when saved → a row is
   inserted with empty `symptoms`, `severity == none`; no exception.
5. **AC5 — severity = worst level.** Given symptoms at {mild, bad, moderate}, then the
   saved `severity == bad`; given zero symptoms, `severity == none`.
6. **AC6 — notes trim → null.** Given the notes field contains only whitespace, when
   saved → `notes == null`.
7. **AC7 — accumulation / independence.** Given one feeling already saved, when a
   second feeling is saved → a second distinct row exists and the first row is
   unchanged (no update/overwrite of the earlier log).
8. **AC8 — edit preload + update.** Given `existingLog`, then mood/symptoms/levels/
   notes preload and the date/time row is shown; when fields (incl. date/time) change
   and the user saves → `updateReactionLog` runs on the same `id` (no new row) and
   `checkinTime` reflects the chosen date/time.
9. **AC9 — delete.** Given edit mode, when the user taps delete and confirms → the row
   is removed via `deleteReactionLog` and the screen pops. Cancelling the dialog keeps
   the row.
10. **AC10 — feed surfacing.** Given a saved feeling, then the home feed shows a
    `feeling-tile-<id>` whose subtitle is `time · mood · sym (level), …` (or "No
    reaction" when empty), and the day/week grouping counts it as a "check-in",
    distinct from the meal count.

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->
- `checkin-screen` — check-in screen root (shared new + edit)
- `mood-selector` / `mood-<name>` — mood face row + each face
- `symptom-intensity-sheet` — "How bad?" notebook panel (renders only when ≥1 symptom)
- `symptom-slider-<name>` — per-symptom intensity slider ✱ (absorbed; SeekBar +
  content-desc)
- `feeling-tile-<id>` / `feeling-tile-header-<id>` — feed tile + its header (toggle)
- `btn-edit-feeling-<id>` — Edit button in the tile's expanded body (TextButton).
  Reachable: expand via `feeling-tile-header-<id>`, then tap. Lives in the body
  (not header `trailing`) so it wins its own tap instead of toggling the tile.
- `btn-delete-feeling-<id>` — inline delete (edit mode) — **new anchor, trail-blazed
  with this spec**
- Symptom chips have no anchor — tap by `content-desc="<SymptomName>"`

## Verifies-with
- Widget tests: `app/test/widgets/checkin_screen_test.dart` (AC1–AC9 via
  `storageOverride` fake — record inserted/updated/deleted logs).
- Feed surfacing (AC10): `app/test/widgets/feeling_tile_test.dart` (subtitle string)
  + existing home grouping coverage.
- e2e: new-feeling journey verified live via the explore rig (FAB→Feeling→fill→Save→
  feed tile). Edit journey: expand `feeling-tile-header-<id>` → tap `btn-edit-feeling`
  (body button) → `/edit_checkin`; delete via the edit screen's `btn-delete-feeling`.
