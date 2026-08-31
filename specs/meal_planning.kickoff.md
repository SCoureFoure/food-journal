# Kickoff — Meal Planning, Grocery Planning & Diet Analysis

> Status: kickoff (not a spec) · Created 2026-08-30
> Hand this to a fresh session to start the feature set. The first job is to turn
> the relevant part of it into `specs/meal_planning.spec.md` via the `/spec` skill.

---

## The ask

Grow the app past "log what I ate and how I felt" into planning what I'm *going to*
eat. The driver is real: my nutritionist told me to plan my weeks of meals so the
right foods are in front of me. Three connected capabilities:

1. **Meal planning** — lay out a week of meals in advance.
2. **Grocery planning** — derive what to buy from that plan (and from what I
   actually eat).
3. **Diet analysis** — tell me whether the plan and the reality are any good.

### Navigation change (explicitly requested)

Meal Planning gets **its own tab**, not a screen buried in the journal.

- **Index-folder tabs at the top left of the page** — the overlapping manila-folder
  look, like tabs on a physical file folder. Two to start: **Food Journal** and
  **Meal Planning**. Click between them to switch.
- This is a deliberate visual, not a Material `TabBar`. The app already renders on
  `LinedPaperBackground` (a notebook metaphor), so paper folder tabs fit the
  existing aesthetic. Build it to match that, not to match Material defaults.
- **The grocery list moves into the Meal Planning tab.** Today it lives on the
  Export/Import screen behind the top-right icon; that was always a placement of
  convenience and it is now wrong. Export/Import keeps JSON export and import only.

---

## Why the split is right

The journal is **retrospective** — what did I eat, how did I feel, what caused it.
Meal planning is **prospective** — what will I eat, what must I buy, am I on track.
Different mental modes, different time direction, different data. That is a real
justification for two tabs rather than one crowded feed, and it should shape the
information architecture rather than being cosmetic.

The full loop the nutritionist is describing:

```
plan the week → derive groceries → shop → prep/cook → log meals → reactions
      ▲                                                                │
      └──────────────── analysis feeds the next plan ──────────────────┘
```

The app currently owns the **back half** (log → reactions → blame). The grocery list
built in the previous session is the first bridge from the back half to the front.
This feature set builds the front half and closes the loop.

---

## What already exists (built and verified — do not rebuild)

### Grocery list export — shipped, working, deployed

Generates a frequency-ranked shopping list from logged meals and shares it as plain
text. Two window modes: **By meals** (10/30/60, default 30 — the N most recently
logged meals, time-independent so a logging gap can't empty it) and **By days**
(7/14/30, default 30, counting today).

An **AI tidy pass** (`Tidy with AI & share`, present only when AI is enabled) sends
that list to the Worker's `tidy_grocery_list` task, which merges variants, drops the
occurrence counts, and groups into a fixed supermarket vocabulary. Verified live:

```
salt (x6)                          →  Pantry:       Salt
Peanut butter and fluff sandwich   →  Pantry:       Peanut butter, Marshmallow fluff
                                      Bakery:       Bread
butter (x2) + unsalted butter (x2) →  Dairy & Eggs: Butter        ← merged
water (x9)                         →  (dropped)
potatoes (x3)                      →  Produce:      Potato
```

| Thing | Where |
|---|---|
| Pure aggregation, renderers, `GrocerySection`, `kGrocerySections` | `app/lib/models/grocery.dart` |
| Candidate building, tidy call, share | `app/lib/services/export_service.dart` |
| AI contract + client | `app/lib/services/ai_service.dart`, `worker_ai_service.dart` |
| UI (to be moved) | `app/lib/screens/export/export_screen.dart` |
| Worker prompt | `worker/src/prompts.json` → `tidy_grocery_list` |
| Spec — 24 decisions, AC1–AC43, open forks F1–F11 | `specs/groceries.spec.md` |

Tests: 21 model · 29 service · 14 widget · 76 worker (vitest) · **11 live-worker
integration**. Worker deployed, version `2800df53`. Schema untouched at **v14**.

### Decision this feature set overturns

`specs/groceries.spec.md` **decision 1 / fork F1** pinned the grocery UI to the
Export screen. The user has now ruled the other way. Amend that spec — do not
silently contradict it — and move the anchors with the widgets.

---

## Open design forks — rule on these before building

These are the decisions that shape everything. Do not guess them; several are
genuine product calls. Recommendations are given, but the user rules.

**A. What *is* a planned meal?**
`SavedItem` already exists and already carries name, macros, and a component list —
it is the natural building block. Options: reference a `SavedItem`, copy a past
`Meal`, free text, or an AI suggestion. *Recommendation:* all four as sources, with
`SavedItem` as the primary and free text always available (AI-optional applies).

**B. Plan granularity.** A rigid week × mealType grid (breakfast/lunch/dinner/snack),
or a looser "meals I intend to eat this week" pool without day assignment? A grid
matches "plan my weeks" but rigid grids get abandoned when life moves. *Worth asking
the user directly.*

**C. Plan → actual link (adherence).** When you eat a planned meal, does logging it
link back to the plan row? *Recommendation:* yes — a nullable `plannedMealId` on
`meals`, set when logging from a plan. This is cheap and it is the entire analytic
payoff: without it, "did I follow the plan?" is unanswerable.

**D. Grocery list source.** Today's list looks **backward** (from logged meals).
Planning wants it to look **forward** (from the plan). *Recommendation:* add a third
window mode — "From my plan" — alongside "By meals" / "By days". The whole existing
pipeline (canonicalise → aggregate → rank → tidy → share) is reused unchanged; only
the candidate source swaps. Strong reuse, small diff.

**E. Diet analysis scope.** Macro targets? Variety? Reaction avoidance? Nutritionist
constraints? *Recommendation:* start with what the data already supports — macro
totals against a target, plus reaction-risk flags from `food_suspicions`. Anything
needing new nutrition data is a separate slice.

**F. Reaction-aware planning — the app's unique angle.** Nothing else on the market
knows which foods make *this* user ill. When the plan schedules a food carrying
suspicion weight, warn at plan time. This is the "reaction badges" work already
deferred in `specs/groceries.spec.md`, and planning is where it pays off most:
catching it before you buy beats discovering it after you ate.

**G. Meal prep is not meal planning.** The user said "meal prep" — batch cooking,
portioning, leftovers spanning days. That is a real and separate modelling problem
(one cook event → N servings consumed across M days). *Recommendation:* defer
explicitly, note it in the spec, do not let it leak into the planning model.

---

## Schema sketch (v15 — a starting point, not a decision)

```text
MealPlans    { id, weekStart, notes, createdAt }
PlannedMeals { id, planId, date, mealType, savedItemId?, title, notes,
               servings, createdAt }
Meals        + plannedMealId (nullable)        ← adherence link, fork C
```

Additive only. Follow the existing migration pattern in
`app/lib/services/database/app_database.dart`: a numbered `if (from < 15)` block,
register the version in `migrationStepVersions`, and keep
`migration_order_test.dart` green. Write `canonicalName` via `canonicalize()` on any
new food-name column so it joins with the blame ledger for free.

---

## Constraints carried forward (project rules — non-negotiable)

- **AI-optional.** Every AI-powered flow needs a complete manual path. AI pre-fills;
  it never gates. With AI off, the control is *absent* and the manual flow carries
  the feature.
- **Schema = contract.** Additive migrations, drift codegen, integration test.
- **Services as tool interface.** Typed, single-responsibility, injectable seams.
- **Pure logic lives in `models/`** so it is unit-testable without native sqlite3.
  `StorageService` needs a `_FakeStorage extends StorageService` subclass in tests.
- **Every feature deposits `{spec, test}`** and registers its anchors in
  `specs/anchors.md` in the same commit.
- **Tests carry metadata** (theory tag + contract + implication) or the dashboard
  classifiers cannot see them.

---

## Gotchas learned the hard way — do not re-discover these

1. **Semantics identifiers merge onto the card container.** Verified on the emulator:
   Flutter attaches `Semantics(identifier:)` to the enclosing *card*, not the
   control, so a UIAutomator resource-id tap lands mid-card. Controls surface with
   an empty `resource-id` and a correct `content-desc`. Declare the id anyway, mark
   it ✱ in the registry, and document `content-desc` as the ADB fallback. Dart
   `integration_test` reads ids in-process and is unaffected.
2. **`find.bySemanticsIdentifier` does not work in widget tests** — the semantics
   tree isn't built. Use
   `find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == '…')`.
3. **Below-the-fold taps fail silently** on the 800×600 test surface. Call
   `await tester.ensureVisible(finder)` then `pumpAndSettle()` before tapping. Never
   `warnIfMissed: false`; never resize the view.
4. **`SharedPreferences.setMockInitialValues({})`** at the top of `main()` in any
   widget test whose screen reads settings.
5. **A new AI task is one key in `worker/src/prompts.json`** — `isKnownTask` is
   `Boolean(prompts[task])` and `handleParse` is generic, so no Worker JS changes.
   **But you must `wrangler deploy`**, and you must add a live integration test at
   the app↔worker seam. A whole suite stayed green while the button was broken
   because that seam had no test; the pattern to copy is
   `app/test/integration/ai/tidy_grocery_list_integration_test.dart`.
6. **Errors on long scrolling screens must be SnackBars.** An inline error rendered
   below the fold looks exactly like a no-op to the user. Real bug, found on device.
7. **`getAllMeals` returns `createdAt` ascending within a date** — re-sort
   descending before taking "the most recent N", or you get the earliest meals of
   the newest day.
8. **Analyzer runs at zero issues.** A `const` declaration's initializer needs no
   inner `const` keyword, and `DateTime(...)` is never `const`.
9. **The explore rig** (`/explore`, `test_explore.ps1`) boots the emulator, builds,
   installs, navigates, and screenshots. Use it — this session's two most valuable
   findings (invisible error, anchor merging) were invisible to the test suite and
   obvious on device within minutes.

---

## Suggested first slice — the shell, not the planner

Resist building the planner first. The highest-value, lowest-risk opening move is
the navigation restructure plus the relocation the user already asked for, because
it de-risks the shell before any new schema exists:

1. **`AppShell` at route `/`** holding an `IndexedStack` and the folder-tab widget.
   `IndexedStack`, not route swapping — the journal's scroll and load state must
   survive a tab switch.
2. **Tab 1 = existing `HomeScreen`, unchanged.** Zero regressions in the journal is
   the bar.
3. **Tab 2 = `MealPlanningScreen`** — initially just the relocated grocery card.
4. **Move the grocery UI** out of `export_screen.dart`. Export/Import keeps JSON
   only. `ExportService`'s grocery methods stay where they are — only the widgets
   move — unless a cleaner home suggests itself.
5. **Anchors:** `app-shell`, `tab-food-journal`, `tab-meal-planning`, plus the
   relocated grocery ids. Register all of them.
6. **Amend `specs/groceries.spec.md`** — decision 1 / fork F1 reversed, anchors
   section updated.

Done when: both tabs render, the journal is untouched and state-preserving, the
grocery list works from its new home, `flutter analyze` is at 0 issues, the whole
suite is green, and the emulator confirms the tabs and the relocated card.

Then, and only then, start on fork A/B and the planning model itself.

---

## Housekeeping the next session inherits

- The working tree is dirty on `main` across five rounds of grocery work
  (list, meal-count window, AI tidy, error visibility, integration test). It has
  never been committed. Branch and commit it as a coherent set before starting.
- `app/test/integration/ai/image_smoke_test.dart` fails — Gemini rejecting a
  synthetic minimal JPEG. Pre-existing, unrelated to groceries, still red.
