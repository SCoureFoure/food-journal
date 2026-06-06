# Spec — Food/medication entity resolution (local canonical identity)

> Status: active · Feature: food_entity_resolution · Added: 2026-06-05
> Source of truth for collapsing re-entered foods and medications onto one
> canonical identity so symptom-blame and future dashboards accumulate across
> logs. Pure local logic — **no AI layer**.

## Requirement

Today every logged food item / medication is a free-text name. The blame ledger
([food_blame](food_blame.spec.md)) already lowercases `target_name`, so
**case** variants of the same item already accumulate. What still fragments the
record:

1. **Whitespace / punctuation** — "turkey  sandwich", "turkey-sandwich",
   "Turkey sandwich." land in different buckets (lowercase doesn't collapse them).
2. **Wording / tokens** — "turkey sandwich" vs "turkey sandwich w/ mayo" vs
   "turkey sand". The AI re-parses each meal fresh and varies wording, so the same
   real food scatters across names and no single bucket reflects the true picture.
3. **No durable key on the source tables** — only `food_suspicions.target_name`
   is normalized; `food_items` / `medications` themselves carry only the raw name,
   so any future dashboard reading the item tables has nothing stable to join on.

This feature resolves a logged item to a canonical identity in two layers:

- **Layer A — canonical key at save (deterministic).** A pure `canonicalize(name)`
  (lowercase, trim, collapse internal whitespace, strip punctuation) is computed at
  save and persisted as `canonical_name` on `food_items` and `medications`. Blame
  (`getBlameCandidates` → `food_suspicions.target_name`) and the aggregation
  (`getSuspicionScores`) key on `canonical_name`. Fixes #1 and #3; gives every
  downstream query one stable entity key.
- **Layer B — passive reuse nudge at add (low-click).** When an item name is
  entered (typed or AI-parsed) on the add-meal / add-med screen, the screen
  background-searches existing history for a close lexical match (token overlap,
  **not** vectors / AI). If found, one inline chip appears
  ("Match: Turkey sandwich ×N — use"); one tap adopts the existing name (+macros),
  landing the entry in the same canonical bucket. No match → no chip → zero added
  clicks. This is the only layer that addresses wording variants (#2); it steers,
  never forces.

Resolution happens at **save / entry time only** — the add screens never blame.
Whatever exists for food works symmetrically for medications.

## Constraints (inherited)

- **Not AI** (CLAUDE.md AI-optional untouched): `canonicalize` and the match
  scorer are pure deterministic Dart. No worker call, works fully offline. The
  add-time nudge runs a local SQL search, never the parse service.
- **Schema = contract**: new nullable `canonical_name` column on `food_items` and
  `medications` (v12). Needs a drift migration + `migration_*` integration test;
  `currentSchemaVersion` 11 → 12, `migrationStepVersions` appends `12`.
- **Side-effects**: writing `canonical_name` is part of the existing save
  transaction; it schedules no notification and must not change save success/failure
  semantics. The nudge has no side-effect until the user taps it.
- **Reuse**: food nudge reuses `searchFoodHistory` + the `FoodHistorySearchSheet`
  selection→`FoodItemDraft` pattern; blame reuses the pure fns in
  `food_suspicion.dart`. A parallel `searchMedicationHistory` is added for meds.

## Decisions (pinned 2026-06-05)

- **Case already accumulates — do not re-derive it.** The load-bearing change is
  (a) collapsing whitespace/punctuation beyond today's `toLowerCase()` and
  (b) persisting the key on the source tables. Confirmed with user after discovery
  that `_row` already lowercases (`food_suspicion.dart`).
- **`canonicalize` rules.** lowercase → strip every char that is not a Unicode
  letter, digit, or whitespace (replace with a space) → collapse whitespace runs to
  one space → trim. Empty/whitespace-only input → `''`. Deterministic, no locale
  dependence beyond Dart `toLowerCase`.
- **Layer A scope = source tables + ledger** (user-ruled). `canonical_name` on both
  `food_items` and `medications`; blame + dashboard group on it.
- **Backfill on migrate = yes** (user-ruled). v12 backfills `canonical_name` for all
  existing `food_items` / `medications` rows by applying the same normalization in
  SQL (`lower` + char-class scrub + whitespace collapse), so historical rows join too.
- **Ledger key = canonical, not raw-lowercase.** `getBlameCandidates` emits the
  candidate's `canonical_name` as the blame `target_name`; `_row` no longer does its
  own `toLowerCase()` (the canonical form is already normalized). `getSuspicionScores`
  groups on the stored (now-canonical) `target_name`. Amends
  [food_blame](food_blame.spec.md) decision "target_name lowercased for aggregation".
- **Nudge match = fuzzy-token Jaccard, threshold 0.5** (user-ruled — pure Dart,
  deterministic, not embeddings/AI). Token-set Jaccard where two tokens match by
  **equality OR length-gated character-trigram overlap** (both tokens ≥4 chars,
  trigram Jaccard ≥0.4). One coherent metric across two problems:
  - *multiword phrasing* resolves at the token level (`turkey sandwich` ≈
    `turkey sandwich w/ mayo`);
  - *compound words* resolve via the fuzzy step (`burger` ≈ `hamburger`,
    `cheeseburger` ≈ `burger`) — whole-token equality alone scores those 0.

  Chosen over a token-vs-trigram *hybrid* (two thresholds + scale-mixing): a single
  token-level metric avoids the hybrid's failure modes — whole-string trigram
  **false-merges distinct dishes** (`turkey sandwich`/`tuna sandwich` → 0.41) and
  *under*-scores real partials (`fried rice`/`rice`). The length gate stops the fuzzy
  step from inventing short-word merges (`ice`/`rice`, `men`/`menu`). A candidate
  whose canonical form **equals** the typed item's is skipped. Best at/above threshold
  wins; ties break to higher score, then most-recently-logged.
- **Nudge is advisory + dismissable.** Adopting is one tap; ignoring it costs
  nothing and the raw name is saved as-is (still gets its own `canonical_name`).
  The chip never blocks save and never auto-applies.
- **AI-parsed names get a canonical key too.** Canonicalization is at the storage
  seam, independent of whether the name came from AI autofill, history, or manual
  typing — so the source of the name never changes the entity math.

## Known limits (pinned 2026-06-05, lexical not semantic)

Probed against the live fn and locked as contracts in `food_entity_test.dart`:
- **Canonical wins (auto-merge):** case, accents (`Café`/`CAFÉ`), separators
  (`Coca-Cola`≡`coca cola`), symbols (`PB&J`≡`PB & J`→`pb j`), emoji/punctuation
  stripped, CJK/non-latin letters preserved, tab/newline/multi-space collapsed.
- **Nudge wins (one-tap merge):** filler-word drift (`Mac & Cheese` vs
  `mac and cheese`, 0.667) and **compound words** (`burger`≈`hamburger`,
  `cheeseburger`≈`burger`) via the length-gated fuzzy-token step.
- **Precision guards (must NOT merge):** short-word trigram collisions blocked by
  the length gate (`ice`/`rice`, `men`/`menu`, `egg`/`eggplant`); distinct dishes
  sharing a head noun (`turkey`/`tuna sandwich` → 0.33); look-alikes
  (`chicken`/`chickpea`). A bare generic word does **not** spray to a specific
  multiword dish (`chicken` ↛ `grilled chicken breast`, 0.33) — symmetric Jaccard's
  length penalty is the deliberate guard against generic-token spray.
- **Lexical, not semantic** — stay separate until/unless we add stemming or
  synonyms: digit-vs-word (`2 eggs` ≠ `two eggs`) and zero-shared-letter synonyms
  (`soda` ≠ `Coke`). User rejected the AI path that would close these.
- **Apostrophes orphan a token** (`Trader Joe's`→`trader joe s`) — deterministic
  and stable (both entries collapse identically), just slightly noisy.

## Acceptance criteria (Given / When / Then)

### Layer A — canonicalize (pure)

1. **AC1 — case + whitespace + punctuation collapse.** `canonicalize` maps
   "Turkey Sandwich", "turkey  sandwich", "turkey-sandwich", "  Turkey sandwich. "
   all to `"turkey sandwich"`.
2. **AC2 — distinct foods stay distinct.** "turkey sandwich" and "tuna sandwich"
   canonicalize to different non-empty keys.
3. **AC3 — empty/punct-only guard.** `canonicalize("")`, `canonicalize("   ")`,
   `canonicalize("!!!")` all return `""`.
4. **AC4 — digits + unicode preserved.** `canonicalize("Café 50g")` →
   `"café 50g"` (letters incl. accents and digits survive; the space is single).

### Layer A — persistence + blame/dashboard

5. **AC5 — migration.** Given a v11 DB, when opened at v12 → `food_items` and
   `medications` each have a `canonical_name` column, `currentSchemaVersion == 12`,
   `migrationStepVersions` ends with `12`, and existing rows are **backfilled**
   (a pre-existing "Turkey Sandwich" food row has `canonical_name == "turkey sandwich"`).
6. **AC6 — save writes canonical (food).** Given `saveMeal` / `updateMeal` with a
   food item named "Turkey-Sandwich", when saved → its `food_items.canonical_name`
   is `"turkey sandwich"`.
7. **AC7 — save writes canonical (med).** Given `saveMedication` / `updateMedication`
   with name "Vitamin D3", when saved → its `medications.canonical_name` is
   `"vitamin d3"`.
8. **AC8 — blame keys on canonical.** Given two meals logged days apart with food
   names "Turkey Sandwich" and "turkey-sandwich", each blamed for Bloating, when
   `getSuspicionScores()` runs → both contribute to **one** `(canonical_name,
   symptom)` bucket `("turkey sandwich", "Bloating")`, score summed (not two rows of
   half the weight).
9. **AC9 — distinct foods stay separate buckets.** "turkey sandwich" and
   "tuna sandwich" blamed for the same symptom → two distinct score rows.

### Layer B — reuse nudge (pure matcher)

10. **AC10 — fuzzy match found.** `bestNameMatch("turkey sandwich w/ mayo",
    ["Turkey Sandwich", "Tuna Salad"])` returns the "Turkey Sandwich" candidate
    (token overlap ≥ 0.5).
11. **AC11 — no match below threshold.** `bestNameMatch("oatmeal", ["Turkey
    Sandwich", "Tuna Salad"])` returns `null`.
12. **AC12 — canonical-identical skipped.** `bestNameMatch("turkey sandwich",
    ["Turkey  Sandwich"])` returns `null` (already the same entity — nothing to
    nudge).
13. **AC13 — best of several wins, deterministic tie-break.** Given multiple
    candidates above threshold, the highest score is returned; equal scores resolve
    to the most-recently-logged candidate.
14. **AC14 — empty/garbage input.** `bestNameMatch("", [...])` and
    `bestNameMatch("!!!", [...])` return `null`.

### Layer B — UI wiring  (active)

> Shared `ReuseSuggestionChip` widget. Debounced (400ms) name-change listener →
> `searchFoodHistory('')` / `searchMedicationHistory('')` (full recent history, **not**
> LIKE-filtered) → `bestNameMatch` → chip. Full-history fetch is load-bearing: a
> LIKE filter on the typed string defeats the fuzzy matcher for compound words
> (`hamburger` typed, `burger` in history — LIKE returns nothing; full history lets
> fuzzy find it). Guard: chip hidden and lookup skipped when `enabled=false` (meal,
> set by `_isSaving`) or when editing an existing entry (med). Adopt: name + all
> macro fields + portion/prep/ingredients/servings (food); name + dose + valid-list
> unit/route (med — off-list values silently skipped to avoid DropdownButton assert).
15. **AC15 — chip appears on close match (meal).** Given the user types a food
    item name on Log Meal that closely matches a history item, then an inline
    `food-reuse-suggestion-<i>` chip renders under that item card naming the match;
    given no close match, no chip renders.
16. **AC16 — tap adopts the match (meal).** When the user taps the reuse chip, then
    the card's name, portion, prep, macros, ingredients, and servings are replaced
    with the matched history item's values (fields only overwritten when the history
    item has a non-null value), and the chip disappears. Save is not triggered.
17. **AC17 — med parity.** The Log Medication name field shows a `med-reuse-suggestion`
    chip on a close history match; one tap adopts name, dose, and valid-list
    unit/route. Chip absent in edit mode and while saving.
18. **AC18 — nudge never blocks.** With the nudge chip showing, saving the entry as
    typed (ignoring the chip) still succeeds and the raw name is persisted with its
    own `canonical_name`.
19. **AC19 — compound word via full-history fetch.** Typing a compound form (`hamburger`)
    with only the base word (`burger`) in history surfaces the chip — proves the
    full-history fetch (not LIKE-filtered) is in effect. Pinned as regression guard.

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->
- `food-reuse-suggestion-<i>` — inline reuse chip under food item card `i` on
  Log Meal (+ `…-dismiss` × child) — **registered**
- `med-reuse-suggestion` — inline reuse chip under the name field on
  Log Medication (+ `…-dismiss` × child) — **registered**
- `log-meal-screen` / `log-medication-screen` — host roots (existing)

## Verifies-with

- Pure logic (AC1–AC4, AC10–AC14): `app/test/models/food_entity_test.dart` —
  `canonicalize` (EQUIV/BVA) + `bestNameMatch` (threshold, tie-break, guards). No
  native sqlite needed.
- Blame keying on canonical (AC8, AC9): `[entity_resolution]` group in
  `app/test/models/food_suspicion_test.dart` — `buildSuspicionRows` +
  `aggregateSuspicions` over candidates carrying canonical names.
- Migration (AC5): `app/test/services/migration_order_test.dart` (version constant +
  step). Actual v11→v12 SQL + backfill deferred to on-device integration, matching
  the repo's "defer SQL to on-device integration" split (see food_blame AC1).
- Save writes canonical (AC6, AC7): on-device integration (native sqlite) — the
  pure normalization it delegates to is covered by AC1–AC4.
- Nudge UI (AC15–AC18): `[food_entity_resolution] reuse nudge` groups in
  `app/test/widgets/log_meal_screen_test.dart` (AC15 chip-on-match/none, AC16 adopt
  name+macros) and `app/test/widgets/log_medication_screen_test.dart` (AC17 adopt
  name+dose, AC18 ignore-chip-saves-raw-name) via `storageOverride` fakes returning a
  canned history.
- e2e: type a near-duplicate item on Log Meal, assert the chip via the explore rig —
  deferred where it needs seeded history + on-device DB.
