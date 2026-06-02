---
name: spec
description: >
  Capture or build a feature against a durable spec, then leave it covered by tests
  and reachable by the explore rig. Runs the full loop: SPEC → REUSE-SCAN →
  CRITERIA→TESTS → BUILD → VERIFY → DEPOSIT (+ trail-blaze anchors). Works two ways —
  reverse-engineer an existing workflow into a spec, or build a new feature spec-first.
  Trigger when the user says "/spec <feature>", "write a spec for X", "capture X as a
  spec", "spec-driven", or asks to turn a requirement/exploration into a regression test.
---

You are running the spec-driven loop for the food-journal app. A "spec" is the
durable source of truth for one feature: requirement + constraints + pinned
decisions + acceptance criteria. Every feature leaves behind two artifacts —
**a spec** (`specs/<feature>.spec.md`) and **tests** (the regression guardrail).
The spec pile is an *output*, not a precondition; it fills as features are touched.

## Two entry paths, one output

- **Spec-in** — the user hands an explicit requirement. Consume it → spec → tests.
- **Explore-out** — vague request, coverage probing, or a bug found while clicking
  around. Discover intended behavior (read code + run the explore rig), write it
  down, fix to it. Exploration is just spec-discovery.

Both converge on `{spec in repo, regression test in suite}`.

## The loop

```
1. SPEC
   - Spec-in:    consume the given requirement.
   - Explore-out: read the screen → model → storage → every service it touches →
                  schema. Then run the explore rig journeys to confirm code matches
                  reality and catch drift. Pin vague decisions with AskUserQuestion.
   - WRITE specs/<feature>.spec.md  (see template + specs/README.md)
   - Surface decisions the spec forces ("is it supposed to do that?") — these are
     the spec's real value. Get a ruling before encoding behavior as correct.

2. REUSE-SCAN
   - Find existing pipeline/widgets/services to wire — do NOT rebuild.
   - Honor inherited constraints (AI-optional, schema=contract, notification
     side-effects). State them in the spec's Constraints section.

3. CRITERIA → TESTS
   - Each acceptance criterion → a test at the CHEAPEST layer that proves it:
     widget+fake > integration > e2e. Inject fakes (storageOverride/aiOverride/etc).
   - Prefer writing the failing test before the code (red→green) when building new.

4. BUILD to spec.

5. VERIFY
   - flutter test (touched files) + flutter analyze — green.
   - e2e via the explore rig when it adds signal and isn't blocked by an external
     dep (e.g. live worker). If blocked, say so; fakes carry the behavior.

5b. TRAIL-BLAZE  (side objective of every exploration — not optional)
   Exploration's deliverable is {findings + anchors + registry}, not just findings.
   - Every interactive widget on a touched screen gets `Semantics(identifier: '...')`.
   - Screen roots get `Semantics(identifier: 'screen-name')`.
   - Prefer anchors on SHARED widgets — one change blazes trail for every screen
     that uses them.
   - Register each anchor in the explore skill's "Known anchors" table (the map).
   - ✱ doctrine: some ids are absorbed by their Material widget (FAB, Slider) and
     do NOT surface through UIAutomator. The rule is NOT "every id is tappable by
     ADB" — it is "every id is declared + its reach is documented." Mark absorbed
     ids ✱ in the table and note the fallback (bounds / content-desc / SeekBar).
     Dart integration_test reads ids in-process and is unaffected — two consumers,
     one registry. Anchors are also accessibility-positive, not test-only debt.

6. DEPOSIT
   - spec + tests committed; anchors live in code + registered in SKILL.md.
   - Same change set ("same commit") per CLAUDE.md.
```

## Spec template

Write `specs/<feature>.spec.md`:

```markdown
# Spec — <feature title>

> Status: active · Feature: <slug> · Added: <YYYY-MM-DD>
> Source of truth for <what behavior>.

## Requirement
<one paragraph: what the user can do and why>

## Constraints (inherited)
- <AI-optional / schema=contract / side-effects — the rules this rides on>

## Decisions (pinned <date>)
- <each fork resolved: defaults, only-if-empty, create-vs-edit, etc.>

## Acceptance criteria (Given / When / Then)
1. AC1 — <happy path>
2. AC2 — <validation>
3. ... (one per distinct behavior; new behavior = new AC, even on the same screen)

## Anchors (explore rig)
- `anchor-id` — meaning   (✱ if absorbed; note fallback)

## Verifies-with
- Widget/integration tests: <path>
- e2e: <journey>, or "deferred (worker-dependent)"
```

## Roles as gates (not headcount)
- **Implementer** — DEVELOP, builds to spec.
- **Validator** — the adversarial pass (`test-scout` / `flutter-scout` subagents)
  hunts coverage gaps and hardens the regression tests; doesn't trust the
  implementer's assumptions.
- **Spec** — the contract both answer to.

## Worked example
`specs/create_saved_item_ai_parse.spec.md` (AC1–AC7) + its tests in
`app/test/widgets/create_saved_item_sheet_test.dart` — AI parse + leftovers
context injection, built through this loop.

## Notes
- New behavior riding an existing screen still gets its own AC / spec amendment —
  don't bundle silently. The spec is where "same feature or new one?" gets answered.
- Where discovery is mine (Claude Code), no LLM-function framework (BAML) is
  needed; it would only slot into the discovery `[AI]` hops if discovery were ever
  made a standalone autonomous harness. Replay stays pure Dart integration_test.
