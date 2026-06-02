# Food Journal — Agent Entry Point

---

## Project context

Mobile-first food journal app for tracking meals, macros, ingredients, and GI/health reactions. AI layer (Anthropic Claude API) handles unstructured input (text + photos) → structured data. Local storage only — no cloud DB. Flutter for cross-platform (Android primary, iOS stretch).

---

## Mode announcements

When switching modes, state the new mode in one short line before proceeding (e.g. "**DEVELOP**"). Modes switch automatically: writing code → DEVELOP, running tests → TEST, answering questions → EXPLAIN, proposing multi-step work → PLAN.

---

## Mode definitions

### EXPLAIN (default)

```contract
inputs:
  question: user's question or request for understanding

produces:
  answer: direct response to the question

constraints:
  - Minimize tokens to understanding
  - No filler, no meta-offers
  - Only suggest next steps when asked
```

### PLAN

```contract
inputs:
  task: non-trivial request (multi-file, architectural, or unclear)

produces:
  approach: ordered steps with rationale
  options: alternative approaches if multiple valid paths exist
  approval_request: explicit ask for user confirmation

constraints:
  - Required for multi-file or architectural work only
  - Skip for simple/obvious changes
  - Do not implement until user approves
```

### SPEC

```contract
inputs:
  feature: a requirement (spec-in) OR an existing workflow / exploration finding (explore-out)

produces:
  spec_file: specs/<feature>.spec.md — requirement, inherited constraints,
             pinned decisions, acceptance criteria (Given/When/Then), anchors
  open_decisions: forks the spec forces ("is it supposed to do that?") — ruled before encoding

constraints:
  - Run via the /spec skill (the full loop) — see .claude/skills/spec/SKILL.md
  - Every non-trivial feature deposits {spec, test}; the spec pile is an output, not a precondition
  - New behavior on an existing screen still gets its own AC / spec amendment — never bundle silently
  - Acceptance criteria map 1:1 to tests at the cheapest layer (widget+fake > integration > e2e)
```

### DEVELOP

```contract
inputs:
  approved_plan: from PLAN (or implicit for trivial tasks)
  source_files: read contents of every file to modify

produces:
  code_changes: production-ready modifications
  summary: what changed and why (1-2 sentences)

constraints:
  - Write complete, production-ready code
  - Match existing Flutter/Dart conventions
  - Comments only for: non-obvious algorithms, "why" decisions
  - Do not narrate tool calls or explain obvious actions
```

### TEST

```contract
inputs:
  code_changes: from DEVELOP

produces:
  test_results: pass/fail with failure details
  next_action: "done" | "return to DEVELOP"

constraints:
  - Run flutter test if tests exist
  - Manual verification documented for UI flows
  - If fails, return to DEVELOP
```

---

## Development workflow

| Step | Mode | Gate |
| ---- | ---- | ---- |
| Intake | EXPLAIN | Scope identified |
| Plan | PLAN | User approves |
| Spec | SPEC | Acceptance criteria written to `specs/<feature>.spec.md` |
| Develop | DEVELOP | Code matches plan + spec |
| Test | TEST | Tests pass (one per acceptance criterion) |
| Iterate | DEVELOP/TEST | All gates green |
| Deposit | — | `{spec, test}` committed; anchors trail-blazed + registered in explore SKILL.md |

Two entry paths, one output: **spec-in** (requirement handed in) and **explore-out**
(behavior discovered while probing/fixing) both converge on `{spec, test}`. The `/spec`
skill runs this loop.

---

## Key architectural decisions

- **AI-optional (top-level)**: every AI-powered flow has a complete manual fallback. AI pre-fills; it never blocks. If API unavailable, key missing, or user skips — manual entry form shows directly. Applies to meal logging, medication logging, and all future AI features.
- **Schema = contract**: SQLite schema is a stable API. No breaking changes without a drift migration + integration test. AI-parsed JSON validated before DB write.
- **Services as tool interface**: service methods designed to be exposable as Claude tool-use (function calling). Clear typed inputs/outputs, single responsibility. Forward-compatible for AI calling services as tools.
- **Entry types**: journal tracks `meal` | `medication` | `body_output`. All appear in same chronological feed. Each has its own table; all share date/time/notes/created_at.
- **AI input parsing**: Claude API (`claude-sonnet-4-6`) — text + image → structured JSON (meals + medications)
- **Local storage**: SQLite via `drift` — meals, food_items, ingredients, reactions, food_memory, medications, body_outputs
- **Notifications**: `flutter_local_notifications` — check-in scheduled on save of any entry that warrants follow-up (configurable delay, default 90 min); permission prompt on first save if not yet granted
- **Camera**: `image_picker` with `ImageSource.camera` as primary; gallery as secondary option on photo attach
- **Export**: CSV for all entry types (entry_type column), separate grocery list from ingredient aggregation
- **No backend**: all data local on device

## Data model (core)

```text
MealEntry     { id, date, time, mealType, overallSymptoms, rawInput, imageData }
FoodItem      { id, mealId, name, portion, prep, calories, protein, carbs, fat, reaction, notes }
Ingredient    { id, foodItemId, name, quantity, unit }
ReactionLog   { id, mealId, checkinTime, symptoms[], severity, notes }
FoodMemory    { id, foodName, reactionPattern, occurrences, lastSeen }
Medication    { id, date, time, name, dose, unit, route, notes }
BodyOutput    { id, date, time, outputType, urgency, consistency, notes }
```

## Dev commands

See `docs/STACK.md` for Flutter setup and package list.
See `docs/ARCHITECTURE.md` for system diagram.
See `docs/FEATURES.md` for full feature spec.

## Dev workflow

- `start.bat` (repo root) — pub get → drift codegen → `flutter run`
- `stop.bat` (repo root) — kills dart/flutter processes
- Test on Android phone via USB: enable Developer Options → USB Debugging → plug in → `start.bat` auto-detects
- Hot reload: `r` | Hot restart: `R` | Quit: `q` (in running flutter session)

## Semantics anchors — trail-blazing (explore rig requirement)

Anchors are **footholds for the next explorer** (agent, human, or regression test).
Laying them is a standing **side objective of every exploration** — when you reach a
screen, you leave it more reachable than you found it. Anchors are also
accessibility-positive (screen readers use the same semantics), not test-only debt.

Every new interactive widget MUST get a `Semantics(identifier: '...')` when built:

- Screen roots: `Semantics(identifier: 'screen-name')`
- Buttons / FABs: wrap with `Semantics(identifier: 'btn-action')`
- List tiles / cards: wrap with `Semantics(identifier: 'item-<id>')`
- ExpansionTile headers: wrap the `title:` param specifically with `Semantics(identifier: 'item-header-<id>')` so `Tap-Element` hits the header even when expanded
- Prefer anchors on SHARED widgets — one change blazes trail for every screen using them

Register every anchor in the Known anchors table in `.claude/skills/explore/SKILL.md`
in the same commit. That table is the map.

**✱ doctrine.** Some ids are absorbed by their Material widget (FAB, Slider) and do
NOT surface through UIAutomator. The rule is not "every id is tappable by ADB" — it is
**"every id is declared + its reach is documented."** Prefer tapping by resource-id;
where a widget absorbs its id, mark it ✱ in the table and note the fallback (bounds /
`content-desc` / SeekBar). Dart `integration_test` reads ids in-process and is
unaffected — two consumers, one registry. See `/spec` skill for the full loop.

## Known package constraints

- `flutter_local_notifications: ^18.0.1` — pinned; v21+ requires Dart ≥3.10, we're on 3.9.2
- `flutter_timezone: ^5.0.2` — v5 returns `TimezoneInfo`, use `.identifier` not `.name`
- `android/app/build.gradle.kts` has `isCoreLibraryDesugaringEnabled = true` + desugar dep — required by flutter_local_notifications
