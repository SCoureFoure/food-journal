# A virtual pet in food-journal: fit notes and open questions

Research only, with no design decisions made. This maps what Fitness Friends offers (doc 01) onto how food-journal is built today, and lists the questions that need your call before anything gets specced.

Detail and `path:line` citations: `research/fj-surface.md`.

---

## Why the fit is better than it first looks

| Concern | Fitness Friends | food-journal | Consequence |
|---|---|---|---|
| Platform | Flutter, Dart `^3.9.2` | Flutter, Dart `^3.9.2` | The rendering widget can drop in. `flame` would be a new dependency |
| Backend | Express + Postgres + JWT accounts (Render/Neon) | None for user data. Local-first drift/SQLite; the Worker is AI-only | **None of FF's backend transfers.** The pet would be fully on-device, which suits food-journal's "all local" promise |
| Anti-cheat | Allele rolls run on the server so clients can't forge them | Single-player, no accounts | Genetics and randomness can just run on the device |
| State management | `provider` | Plain `StatefulWidget` + `setState`, services built per screen | The FF widget needs no provider, so this isn't a conflict |

**What really carries over:** the procedural creature renderer (~1,220 lines) and, optionally, the genetics *ideas*, which would need a TS→Dart port. FF's "activity → points → pet" loop is a useful shape. Its adventure system, breeding cycle, auth and server do not carry over.

## Where journaling events happen

There is **no single choke point** today. Each screen builds its own `StorageService`; only `AppDatabase` is shared. A "user journaled" hook would attach to these methods in `app/lib/services/storage_service.dart`:

| Event | Method | Table |
|---|---|---|
| Meal | `saveMeal` (:33) | `meals` (+ `food_items`, `ingredients`) |
| Medication | `saveMedication` (:285) | `medications` |
| Feeling check-in | `saveReactionLog` (:696) | `reaction_logs` |
| Water | `saveWaterLog` (:846) | `water_logs` |
| Weight | `saveWeightLog` (:885) | `weight_logs` |
| (optional) Receipt scan | `addPantryItems` (:987) | `pantry_items` |
| (optional) Saved item | `saveSavedItem` (:949) | `saved_items` |

Gotchas:
- **Import and the debug seed call the same methods.** A naive hook would reward a 500-row JSON import. Nothing currently tells the callers apart.
- Because each screen has its own service instance, an event hook would need a global notifier. The alternative is to watch the shared drift tables (drift has table watch streams). The second option might mean no change to `StorageService` at all.
- Grocery list is a SharedPreferences string, not a table. Meal planning has no storage yet.

## Streak and consistency data already exists

No new tables are needed to *compute* journaling consistency:
- **Days journaled:** distinct days across `meals.date`, `medications.date`, `water_logs.date`, `weight_logs.date` and `reaction_logs.checkin_time`. The home screen already unions these five.
- **Meals today:** `getMealsInRange(from, to)`.
- **Gap since last log:** max of the date columns, or `created_at` for the actual moment of logging.
- **Caveats:**
  - `date` is user-picked and can be backdated; `created_at` is when the entry was saved.
  - Deletes remove rows outright, so a derived streak can go *down* after the fact.
  - The `time` columns are locale-formatted strings, so they can't be sorted.

## Where a pet could be shown (description, not design)

- **Shell `Stack`** (`app_shell.dart:45`): sits above the Scaffold, so a widget there persists across both folder tabs.
- **AppBar actions:** room for something small, but the settings gear is deliberately pinned last.
- **Home `Stack`:** a bottom corner is possible, but the FAB moves sides in left-handed mode, so the pet would have to follow `_leftHanded`.
- **Refresh hook:** the home screen already reloads after every log screen returns, so a pet can react there without new plumbing.

## Rules a pet feature would have to follow

- **Spec process:** a `specs/virtual_pet.spec.md` is required (SPEC → REUSE-SCAN → CRITERIA→TESTS → BUILD → VERIFY → DEPOSIT). Acceptance criteria map 1:1 to tests. A PLAN gate applies to multi-file work.
- **Anchors:** every new interactive widget gets `Semantics(identifier:)` and a row in `specs/anchors.md`.
- **If pet state goes in a new drift table:**
  - Schema v16 → v17, with an `onUpgrade` block and a matching `CREATE TABLE`.
  - Update `migrationStepVersions` and the two literal `16`s in `migration_order_test.dart`.
  - Add `StorageService` methods.
  - Decide whether it goes into export/import (new `ExportTypes` flag, JSON key, dedupe key).
- **If pet state goes in SharedPreferences instead:** no migration is needed, but the pet won't survive export/import or a reinstall.
- **Feature flag pattern:** add a getter/setter on `SettingsService`, then a `SwitchListTile` in `SettingsDialog`, then have the host re-read it after the dialog closes.
- **Notifications:** only one-shot "how did you feel?" check-in reminders exist today. Any "your pet misses you" nudge is new. Note the existing id-collision risk: meal *N* and medication *N* share a notification id.

## The question that matters most: what does the pet reward?

food-journal is a symptom and trigger tracker. Its stated non-goals include **"No calorie goals or diet plans"** (`docs/FEATURES.md:190-193`). A pet that gets happier when you eat more, eat less or eat "well" would cut against the app's purpose. It could also make logging feel judged, which is the opposite of what you want. FF rewarded *effort* (minutes of exercise). The clean analogue here is rewarding **the act of logging**, never what was logged. That's my reading of the docs, not a decision. It's the first item below.

## Open questions for you (nothing is decided)

1. **Reward unit.** Is it per entry, per day journaled, or per meal with a check-in attached? Which entry types count? (Water could be spammed. A feeling check-in arguably carries the most value.)
2. **Absence.** FF gives no precedent: nothing happens when you stop. Options include no penalty (carrot only), a gentle mood dip, or Tamagotchi-style decay. Guilt could backfire for a health journal.
3. **Content-awareness.** Should the pet react to *what* you log? An example would be looking sympathetic when you log bad symptoms. Or should it react only to *that* you logged?
4. **Single pet or collection?** FF's genetics and breeding only make sense with many creatures and a retire/breed cycle. One companion would make most of the genetics layer unnecessary. Maybe keep just the random gen-0 genome so each user's pet looks unique.
5. **"When did I log?"** Should streaks use the event `date` (backdatable, so you can fill yesterday's gap) or `created_at` (the honest save moment)? Do imports count? Do deletes undo progress?
6. **Persistence.** A drift table (exported, migration cost) or SharedPreferences (cheap, lost on reinstall)?
7. **Rendering dependency.** Add `flame`, or port the five Canvas components to a `CustomPainter` with no new dependency? Either way, expressions and mood visuals (blink, happy, sad, sleepy) are new work, because FF never built them.
8. **Placement.** Should the pet be persistent across tabs (shell `Stack`), live on the journal tab only, or be a tap-to-open companion screen?

## Suggested next step (when you're ready)

One de-risking spike would answer questions 7 and 8 together. Render FF's `CreatureFlameWidget` inside food-journal's shell `Stack`, behind a settings flag, with a hard-coded genome, and screenshot it via the explore rig. That proves the renderer drops in and shows how a pet looks on the lined-paper UI before any reward or state design. It doesn't touch the schema.
