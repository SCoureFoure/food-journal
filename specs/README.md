# Specs

Durable source of truth for the app's behavior. One file per feature:
`specs/<feature>.spec.md`. Each spec pairs with regression tests (the guardrail).

The spec pile is an **output**, not a precondition — it fills as features are
touched. Two entry paths converge here:

- **spec-in** — an explicit requirement is consumed → spec → tests.
- **explore-out** — behavior discovered while probing or fixing a bug → written
  down → fixed to → captured as spec + test.

Run the loop with the **`/spec`** skill (`.claude/skills/spec/SKILL.md`):
`SPEC → REUSE-SCAN → CRITERIA→TESTS → BUILD → VERIFY → DEPOSIT (+ trail-blaze)`.

## Rules

- Every non-trivial feature deposits `{spec, test}`.
- Acceptance criteria map 1:1 to tests at the cheapest layer
  (widget+fake > integration > e2e).
- New behavior on an existing screen gets its own AC / spec amendment — never
  bundle silently. The spec is where "same feature or new one?" is answered.
- Anchors: the registry [`anchors.md`](anchors.md) is **canonical** — one flat
  lookup for the explore rig + Dart tests, and the only home for shared-widget
  (cross-screen) anchors. Each spec's `## Anchors` section is a **view**: the ids
  that feature touches, linking back. Trail-blaze in Dart + add the canonical row
  to the registry, same commit.

## Template

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
3. ...

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical row (screen·meaning·✱/fallback)
     lives in specs/anchors.md. -->
- `anchor-id` — what it's for in this feature

## Verifies-with
- Widget/integration tests: <path>
- e2e: <journey> | "deferred (worker-dependent)"
```

## Index

| Spec | Feature | Status |
|------|---------|--------|
| [create_saved_item_ai_parse](create_saved_item_ai_parse.spec.md) | AI parse + leftovers context in Create Saved Item | active |
| [log_medication](log_medication.spec.md) | Log/autofill/edit/delete medication + check-in scheduling | active |
| [log_meal_ai_parse](log_meal_ai_parse.spec.md) | AI autofill on Log Meal — parse, replace, title-fill, context injection, AI-off fallback | active |
| [log_feeling](log_feeling.spec.md) | Standalone feeling check-in — create/edit/delete, mood, symptom intensity, accumulation, feed surfacing | active |
