# Spec — Log Medication

> Status: active · Feature: log-medication · Added: 2026-06-02
> Source of truth for creating, AI-autofilling, editing, and deleting a
> medication/supplement entry and its follow-up check-in.

## Requirement

The user can log a medication or supplement — manually or with AI autofill from a
text description / label photo — recording name, dose, unit, route, notes, time,
and a check-in delay. Saving schedules a follow-up "how did you feel?" check-in.
Existing entries can be edited or deleted.

## Constraints (inherited)

- **AI-optional** (CLAUDE.md): autofill prefills, never blocks; manual entry always
  works. AI off / call failure / empty input never prevents saving.
- **Side-effect / notification contract**: a saved medication schedules a check-in at
  `entryTime + delay` (default 90 min) via `NotificationService`, keyed by the
  medication id.
- **Reuse**: autofill uses `AiService.parseMedication`; the description+autofill UI is
  the shared `LogDescriptionSection`.

## Decisions (pinned 2026-06-02)

- name **required**; check-in delay default **90**.
- Autofill fills name/dose/unit/route/notes **only when that field is empty** — never
  overwrites a value the user typed.
- **Create** schedules a check-in.
- **Edit reschedules** (FIXED 2026-06-02): on save of an existing med, the check-in is
  **cancelled and re-armed** to the new time/delay. Previously edit left the original
  notification untouched — surfaced as a bug during reverse-engineering and fixed.
- dose is parsed with `double.tryParse`: non-numeric → null (no crash).

## Acceptance criteria (Given / When / Then)

1. **AC1 — manual create persists.** Given a name (+ optional fields), when Save,
   then `saveMedication` is called and the screen pops.
2. **AC2 — name required.** Given an empty name, when Save, then
   "Medication name is required." shows and nothing is saved.
3. **AC3 — autofill fills only-empty fields.** Given a description and empty fields,
   when Autofill succeeds, then name/dose/unit/route/notes populate from the result;
   fields the user already filled are left unchanged.
4. **AC4 — autofill empty-input guard.** Given no description and no photo, when
   Autofill, then "Add a description or photo before autofilling." shows and no AI
   call is made.
5. **AC5 — autofill failure is non-blocking.** Given the AI call fails, when Autofill,
   then an error shows and the form remains editable/savable.
6. **AC6 — AI disabled hides autofill.** Given AI is disabled in settings, when the
   screen renders, then the Autofill affordance is absent.
7. **AC7 — dose parsing.** "200" → 200.0; "0.5" → 0.5; "abc" → null (no crash).
8. **AC8 — create schedules check-in.** Given a new med, when Save, then
   `scheduleCheckin` is called with the entry time and delay (default 90).
9. **AC9 — edit reschedules.** Given an existing med, when Save Changes, then
   `updateMedication` is called AND the check-in is `cancelCheckin` then
   `scheduleCheckin` at the new time/delay (no duplicate, no stale time).
10. **AC10 — delete confirms then removes.** Given an existing med, when the delete
    icon is tapped and confirmed, then `deleteMedication` is called and the screen pops.

## Anchors (explore rig)

- `log-medication-screen` — screen root
- `log-med-name` — name field
- `btn-autofill-medication` — autofill button (shared `LogDescriptionSection`)
- `log-med-dose` · `log-med-unit` · `log-med-route` — dose + dropdowns
- `log-med-notes` · `log-med-checkin-delay`
- `btn-delete-medication` — delete (edit mode)
- `btn-save-medication` — save
- `btn-fab-medication` — home speed-dial entry (✱ absorbed; tap via bounds)

## Verifies-with

- Widget tests: `app/test/widgets/log_medication_screen_test.dart`
  (fakes for storage / ai / notifications / settings).
- e2e: Home → FAB → Medication → fill → Save. Autofill journey deferred
  (worker-dependent).
