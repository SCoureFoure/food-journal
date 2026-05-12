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
| Develop | DEVELOP | Code matches plan |
| Test | TEST | Tests pass |
| Iterate | DEVELOP/TEST | All gates green |

---

## Key architectural decisions

- **AI input parsing**: Claude API (`claude-sonnet-4-6`) — text + image → structured JSON meal entry
- **Local storage**: SQLite via `drift` — meals, food_items, ingredients, reactions, food_memory
- **Notifications**: `flutter_local_notifications` — post-meal check-in (configurable delay, default 90 min)
- **Export**: CSV for meals, separate grocery list from ingredient aggregation
- **No backend**: all data local on device

## Data model (core)

```text
MealEntry { id, date, time, mealType, overallSymptoms, rawInput }
FoodItem { id, mealId, name, portion, prep, calories, protein, carbs, fat, reaction, notes }
Ingredient { id, foodItemId, name, quantity, unit }
ReactionLog { id, mealId, checkinTime, symptoms[], severity, notes }
FoodMemory { id, foodName, reactionPattern, occurrences, lastSeen }
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

## Known package constraints

- `flutter_local_notifications: ^18.0.1` — pinned; v21+ requires Dart ≥3.10, we're on 3.9.2
- `flutter_timezone: ^5.0.2` — v5 returns `TimezoneInfo`, use `.identifier` not `.name`
- `android/app/build.gradle.kts` has `isCoreLibraryDesugaringEnabled = true` + desugar dep — required by flutter_local_notifications
