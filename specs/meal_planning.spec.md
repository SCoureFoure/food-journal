# Spec — Meal planning tab (shell)

> Status: active · Feature: meal_planning · Added: 2026-08-30
> Source of truth for the two-tab app shell, the folder-tab navigation, and the
> relocation of the grocery list out of Export/Import.
> Supersedes `specs/groceries.spec.md` decision 1 / fork F1 (see *Overturned decisions*).

## Requirement

The app grows a second top-level surface. Today everything hangs off the journal, which is
**retrospective** — what did I eat, how did I feel, what caused it. Planning is
**prospective** — what will I eat, what must I buy, am I on track. Different mental mode,
different time direction, different data; that is a real justification for two tabs rather
than one crowded feed, and it shapes the information architecture rather than being
cosmetic.

The user (on their nutritionist's instruction) wants to plan weeks of meals so the right
foods are in front of them. The full loop:

```
plan the week → derive groceries → shop → prep/cook → log meals → reactions
      ▲                                                                │
      └──────────────── analysis feeds the next plan ──────────────────┘
```

The app owns the back half. This spec covers **the shell only** — the navigation
restructure and the relocation the user asked for, built before any new schema exists so
the shell is de-risked first. The planner itself is a later slice, pre-decided below.

## Constraints (inherited)

- **AI-optional.** Every AI flow keeps a complete manual path. With AI off the control is
  *absent*, not disabled, and the manual flow carries the feature.
- **Schema = contract.** This slice adds no tables and no columns. Schema stays at **v14**.
- **Services as tool interface.** `ExportService`'s grocery methods do not move; only
  widgets move.
- **Pure logic lives in `models/`** so it is unit-testable without native sqlite3.
- **Anchors** are declared in Dart and registered in `specs/anchors.md` in the same commit.
- **Tests carry metadata** (theory tag + contract + implication) or the dashboard
  classifiers cannot see them.

## Decisions (pinned 2026-08-30)

### Navigation

1. **Two top-level tabs, drawn as index-folder tabs.** `Food Journal` and `Meal Planning`,
   overlapping-manila-folder styling on the existing `LinedPaperBackground` notebook
   metaphor. Deliberately **not** a Material `TabBar`: no underline indicator, no ripple,
   no uppercase, no `TabController`.
2. **Tabs replace the AppBar title.** They sit left-aligned inside the AppBar's title slot
   (`titleSpacing: 8`); there is no separate app-title text and no second bar. *(User
   ruled; the alternatives — a strip above or below the AppBar — were declined.)*
3. **`IndexedStack`, not route swapping.** Both tab bodies mount on the first frame and the
   journal's `State`, loaded feed, and scroll offset survive a tab switch. Rebuilding the
   journal on every switch is a regression, and AC8 fails on it.
4. **`AppShell` owns route `/`.** `HomeScreen` is no longer a route target; it is tab 0's
   body. Every other route in `main.dart` is unchanged.
5. **`AppShell` owns the paper background.** `LinedPaperBackground` moves up to the shell so
   the paper spans behind the tabs and the AppBar. Both tab bodies are transparent
   `Scaffold`s.
6. **Settings is shell-level; Export and Blame history are journal-only.** The settings
   icon renders on both tabs and is listed first so it holds a stable position; the export
   and blame-history icons render only while tab 0 is active. *(User ruled; a single shared
   action row on both tabs was declined — retrospective tools do not belong on the
   prospective surface.)*
7. **The shell refreshes the journal through a `GlobalKey<HomeScreenState>`.** Two public
   methods, `reloadSettings()` and `navigateAndReload(String route)`, replace what
   `HomeScreen` used to do for itself. Not decoration: left-handed mode moves the journal
   FAB, and returning from Export/Import must reload the feed — the latter was a real bug
   fixed in `5f2ff79` and must not regress.
8. **Zero journal regressions is the bar.** `HomeScreen` loses exactly two things (its
   `AppBar` and its `LinedPaperBackground` wrapper) and gains exactly two public methods.
   Its feed, FAB, speed-dial, settings-driven FAB side, and every existing anchor are
   untouched.
8a. **`HomeScreen` gains a `storageOverride` test seam, and `AppShell` passes one
    through as `journalStorageOverride`.** Same pattern `BlameHistoryScreen` already
    uses. Not optional gold-plating: `flutter test` has no sqlite3, so the real journal
    load never completes, the feed sits on its spinner forever, and the shell's own
    widget tests die at teardown on a pending timer. With the seam the tests measure
    shell chrome instead of a database. Production passes null and behaves exactly as
    before, including disposing its own storage only when it owns it.

### Grocery relocation

9. **The grocery list moves to the Meal Planning tab.** Its placement on Export/Import was
   always a placement of convenience and is now wrong. Export/Import keeps JSON export and
   import only.
10. **The UI extracts to a self-contained `GroceryListCard` widget.** No constructor
    arguments; it owns its own `StorageService` / `ExportService` / `SettingsService`
    exactly as the export screen did. Behaviour, chip labels, defaults, anchor ids, and
    SnackBar error text are carried over unchanged.
11. **Screen-wide spinner becomes per-button busy state.** A card cannot blank the screen.
    While a generate or tidy call is in flight both buttons are disabled and their icons
    swap for an 18px spinner.
12. **Errors stay SnackBars.** An inline error on a long scrolling screen renders below the
    fold and reads to the user as a no-op. Real bug, found on device; do not re-discover it.

### Tab 2 content, this slice

13. **Planner stub + grocery card, in that order.** An inert `This week's meals` placeholder
    card sits above the relocated grocery card so the tab reads as a planning surface from
    day one and the next slice fills it in rather than restructuring. The stub carries no
    button, no navigation, and no disabled control — copy only. *(User ruled.)*

### Pre-decided for the next slice — the planner itself (not built here)

Recorded now so the planning slices are dispatchable without re-opening these forks.

14. **Fork B — plan granularity: a loose weekly pool.** "Meals I intend to eat this week",
    with no day or `mealType` assignment. *(User ruled; a rigid week × mealType grid was
    declined — rigid grids get abandoned when life moves, and groceries derive just as well
    from a pool.)* Consequence for the schema sketch below: `PlannedMeals` carries **no
    `date` and no `mealType` column**. Adherence becomes "did I eat this at all this week",
    not "on the right day".
15. **Fork A — what a planned meal is: four sources, `SavedItem` primary.** Reference a
    `SavedItem`, copy a past `Meal`, free text, or an AI suggestion. Free text is always
    available and AI never gates (AI-optional).
16. **Fork C — plan/actual link: yes, a nullable `plannedMealId` on `meals`.** Cheap, and
    it is the entire analytic payoff — without it "did I follow the plan?" is unanswerable.
17. **Fork D — grocery source: a third window mode, `From my plan`,** alongside
    `By meals` / `By days`. The existing pipeline (canonicalise → aggregate → rank → tidy →
    share) is reused unchanged; only the candidate source swaps.
18. **Fork E/F — diet analysis v1 covers all four dimensions:** macro totals against a
    target, reaction-risk flags from `food_suspicions`, variety/repetition, and adherence
    (plan vs actual). *(User ruled — all four selected.)* Reaction-aware planning is the
    app's unique angle: nothing else on the market knows which foods make *this* user ill,
    and catching it before you buy beats discovering it after you ate. Anything needing new
    nutrition data beyond what `FoodItems` and `SavedItems` already carry is out of scope.
19. **Fork G — meal prep is explicitly deferred.** Batch cooking (one cook event → N
    servings consumed across M days) is a separate modelling problem. It does not leak into
    the planning model.

### Schema sketch (v15 — for the next slice, not this one)

Additive only. Follow the existing migration pattern in
`app/lib/services/database/app_database.dart`: a numbered `if (from < 15)` block, register
the version in `migrationStepVersions`, keep `migration_order_test.dart` green, and write
`canonicalName` via `canonicalize()` on any new food-name column so it joins the blame
ledger for free.

```text
MealPlans    { id, weekStart, notes, createdAt }
PlannedMeals { id, planId, savedItemId?, title, canonicalName, servings,
               notes, sortOrder, createdAt }        ← no date, no mealType (decision 14)
Meals        + plannedMealId (nullable)             ← adherence link (decision 16)
```

## Overturned decisions

`specs/groceries.spec.md` **decision 1 / fork F1** pinned the grocery UI to the Export
screen. The user has ruled the other way. That spec is amended, not silently contradicted:
its decision 1 is marked superseded and points here, and its anchor view moves with the
widgets.

## Acceptance criteria (Given / When / Then)

**Shell composition**

1. **AC1** — Given the app launches at route `/`, Then the `app-shell` root renders a
   `FolderTabBar` with exactly two tabs labelled `Food Journal` and `Meal Planning`.
2. **AC2** — Given the shell is mounted, Then both `HomeScreen` and `MealPlanningScreen`
   are in the tree on the first frame (the `IndexedStack` builds all children).
3. **AC3** — Given the shell is mounted, Then the `IndexedStack` index is 0 — the journal
   is the default tab.
4. **AC4** — Given tab 0 is active, When `Meal Planning` is tapped, Then the index becomes
   1; When `Food Journal` is tapped, Then it returns to 0.
5. **AC5** — Given either tab is active, Then exactly one `AppBar` exists in the tree
   (`HomeScreen` no longer supplies one).
6. **AC6** — Given tab 0 is active, Then `btn-settings`, `btn-export`, and
   `btn-blame-history` all render.
7. **AC7** — Given tab 1 is active, Then `btn-settings` still renders while `btn-export`
   and `btn-blame-history` are absent.
8. **AC8** — Given the journal has mounted, When the user switches to tab 1 and back, Then
   the same `HomeScreenState` instance is still in the tree (state preserved).
9. **AC9** — Given the shell renders, Then no Material `TabBar` or `Tab` widget exists in
   the tree.

**Folder tab widget**

10. **AC10** — Given a two-tab bar with `selectedIndex: 0`, Then the `Food Journal` tab
    renders in the selected treatment (fill `kFolderTabSelected`, 44px tall, w600) and
    `Meal Planning` renders recessed (fill `kFolderTabUnselected`, 36px tall, w500).
11. **AC11** — Given `selectedIndex: 1`, Then AC10's treatments are mirrored.
12. **AC12** — Given any tab is tapped, Then `onSelected` fires with that tab's index —
    including a tap on the already-selected tab.
13. **AC13** — Given a single-tab bar, Then it renders without throwing and draws no
    separator.
14. **AC14** — Given any tab, Then its `Semantics(identifier:)` is declared and matches the
    registry (`tab-food-journal`, `tab-meal-planning`).

**Meal Planning tab body**

15. **AC15** — Given tab 1 renders, Then `meal-planning-screen` and `planner-stub-card`
    both exist, and the stub shows `This week's meals` / `Nothing planned yet.`.
16. **AC16** — Given tab 1 renders, Then a `GroceryListCard` is mounted and `Grocery list`
    is on screen.
17. **AC17** — Given the planner stub, Then it contains no button of any kind (it is copy
    only, this slice ships no planner).
18. **AC18** — Given tab 1 renders, Then the stub sits above the grocery card.
19. **AC19** — Given `MealPlanningScreen` alone, Then it supplies no `AppBar` of its own.

**Grocery card, relocated**

20. **AC20** — Given default settings, Then `By meals` is the selected mode, `By days` is
    not, and the meal window defaults to `30 meals`.
21. **AC21** — Given meals mode, Then `10 meals` / `30 meals` / `60 meals` render and no
    day chip is in the tree; given days mode, Then `7 days` / `14 days` / `30 days` render
    with `30 days` selected and no meal chip is in the tree.
22. **AC22** — Given a window chip is tapped, Then selection moves to it within that mode.
23. **AC23** — Given AI is disabled, Then `btn-tidy-grocery-list` is **absent** — not
    disabled — while `btn-generate-grocery-list` still renders and works (AI-optional).
24. **AC24** — Given AI is disabled, Then the mode and window chips are unaffected.
25. **AC25** — Given a generate or tidy call is in flight, Then both share controls are
    disabled so a second share sheet cannot be fired on top of the first.
26. **AC26** — Given a grocery call fails, Then the message surfaces as a floating SnackBar
    (6s), never as inline text below the fold.
27. **AC27** — Given the Export/Import screen renders, Then none of `Grocery list`,
    `Generate & share`, `Tidy with AI & share`, or `By meals` appear anywhere on it.
28. **AC28** — Given the Export/Import screen renders, Then its date range, include
    toggles, `btn-export-json`, and `btn-import-json` behave exactly as before.

**Panel chrome parity across tabs**

29. **AC29** — Given tab 1 renders, Then every top-level section (planner stub, grocery
    card) is a `PanelContainer` carrying `PanelContainer.sectionMargin` and a non-null
    `accentColor` — the same chrome the journal's week panels use.
30. **AC30** — Given either tab renders, Then each top-level panel's painted surface starts
    at `PanelContainer.horizontalMargin` from the left and spans
    `screenWidth - 2 * horizontalMargin` — the hosting scroll view adds no horizontal
    padding of its own, so panel widths cannot drift between the two tabs.

31. **AC31** — Given tab 1 renders, Then every panel's `accentColor` is
    `kTabMealPlanning`; given the journal's week panel renders, Then its `accentColor` is
    `kTabFoodJournal`. Panels read their spine from the folder palette, never from
    `ColorScheme`, so tab / folder body / spine cannot drift apart.
32. **AC32** — Given any tab colour in the palette, Then `folderTabInk` returns ink of the
    opposite brightness to the fill it is drawn on, selected or recessed —
    `kTabFoodJournal` is dark enough to need light ink, `kTabMealPlanning` is not.

**Folder alignment and tab motion**

33. **AC33** — Given the shell renders, Then the folder body's top edge equals the tab
    bar's bottom edge exactly — the edge meets the tabs' bases, so no strip of bare paper
    shows under them and no coloured band cuts across them.
34. **AC34** — Given the shell renders, Then that edge sits `(kToolbarHeight -
    kTabRaisedHeight) / 2` ABOVE the app bar's bottom, because the AppBar centres its
    title slot. Anything measuring from the app bar's bottom edge is wrong by that gap.
35. **AC35** — Given the shell renders, Then the `Scaffold` is the LAST child of the
    shell's `Stack` — nothing paints over the tabs.
36. **AC36** — Given the active tab changes, Then both tabs pass through heights strictly
    between `kTabRecessedHeight` and `kTabRaisedHeight` over `kTabPopDuration` before
    settling on their final values — the tab rises out of / drops back into the folder
    rather than snapping.
37. **AC37** — Given a tab bar's first build, Then each tab renders at its final height
    immediately (no entry animation), and after any pop the fills are exactly
    `kTab*` / `folderTabFill(..., selected: false)` — endpoints are snapped, not lerped.

## Anchors (explore rig)

<!-- A view: ids this feature touches. Canonical row (screen · meaning · ✱/fallback)
     lives in specs/anchors.md. -->

- `app-shell` — shell root; the whole two-tab surface
- `tab-food-journal` — folder tab 0; selects the journal
- `tab-meal-planning` — folder tab 1; selects the planning surface
- `btn-settings` — settings icon, shell-level, present on both tabs (moved from Home)
- `btn-export` — export icon, journal tab only (moved from Home)
- `btn-blame-history` — blame-history icon, journal tab only (moved from Home)
- `meal-planning-screen` — tab 1 body root
- `planner-stub-card` — inert "this week's meals" placeholder
- `chip-grocery-mode-meals`, `chip-grocery-mode-days` — window mode (moved from Export)
- `chip-grocery-meals-<n>`, `chip-grocery-days-<n>` — window size (moved from Export)
- `btn-generate-grocery-list` — plain generate & share (moved from Export)
- `btn-tidy-grocery-list` — AI tidy & share; absent when AI is off (moved from Export)

Note the ✱ doctrine: `Semantics(identifier:)` merges onto the enclosing *card* on device,
so a UIAutomator resource-id tap on a chip or button inside a card lands mid-card. The
controls surface with an empty `resource-id` and a correct `content-desc`. The ids are
declared regardless — Dart `integration_test` reads them in-process and is unaffected.

## Verifies-with

- Widget tests: `app/test/widgets/app_shell_test.dart`,
  `app/test/widgets/folder_tab_bar_test.dart`,
  `app/test/widgets/meal_planning_screen_test.dart`,
  `app/test/widgets/grocery_list_card_test.dart`,
  `app/test/widgets/export_screen_test.dart` (AC27/AC28),
  `app/test/widgets/panel_container_test.dart` (AC29–AC32),
  `app/test/widgets/app_shell_test.dart` (AC33–AC35),
  `app/test/widgets/folder_tab_bar_test.dart` (AC36/AC37)
- Grocery pipeline (unchanged, still green): `app/test/models/grocery_test.dart`,
  `app/test/services/export_grocery_test.dart`,
  `app/test/integration/ai/tidy_grocery_list_integration_test.dart`
- e2e: emulator confirmation of the folder tabs, the relocated card, and a state-preserving
  tab switch via the `/explore` rig
