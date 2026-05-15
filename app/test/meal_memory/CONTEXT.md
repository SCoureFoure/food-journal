# meal_memory tests — Context

> Read this before adding tests or running the scout here.
> Maintained by ai-scout. Update as the suite grows.

## What this test suite covers

Deterministic unit tests for the meal memory pattern engine. No Flutter widgets,
no DB, no API calls — pure logic tests runnable in milliseconds.

## Files

| File                          | What it tests                                                                               |
|-------------------------------|---------------------------------------------------------------------------------------------|
| `reference_engine_test.dart`  | Low-level: rule firing, confidence scoring, named-day resolution                            |
| `scenarios_test.dart`         | High-level: input string -> expected dateOffset + mealType + matchRecent                    |
| `invariance_test.dart`        | INV: case/punctuation/whitespace/synonym perturbations produce identical output             |
| `directional_test.dart`       | DIR: monotonic behavioral contracts (vague→specific, additive meal type, priority ordering) |

## How to add a scenario

Open `scenarios_test.dart`. Add a row to `_scenarios`:

```dart
_Scenario(
  'your input string here',
  expectReferential: true,      // or false
  expectDateOffset: 1,          // optional: days ago
  expectMealType: 'dinner',     // optional: meal slot
  expectMatchRecent: false,     // optional: true if no specific date
),
```

Run: `flutter test test/meal_memory/ --reporter expanded`

The fixed "today" is `DateTime(2026, 5, 14)` = Thursday.
Named-day offsets are relative to that date:

- Monday May 11 → 3 days ago
- Tuesday May 12 → 2 days ago
- Wednesday May 13 → 1 day ago
- Thursday May 7 → 7 days ago (same weekday = last week)
- Friday May 8 → 6 days ago
- Saturday May 9 → 5 days ago
- Sunday May 10 → 4 days ago

## Known gaps (open items for ai-scout)

- No test for rolling window pruning in `recordFingerprint()` — requires real DB; needs integration test setup
- No test for Worker prompt behavior when "Recent meals:" block is injected — requires network mock
- AI-off path widget test: `_aiEnabled=false` with referential input should show `_buildDidYouMeanBanner`. Requires widget test / mock AiService. Low priority since logic is covered by unit path through `findReferentialMeals`.

## Closed gaps (2026-05-14 session 2)

- Quick-copy fallback UI: BUILT. `log_meal_screen._onDescChanged` fires when AI is off, calls `findReferentialMeals`, shows "Did you mean?" banner. The open item from session 1 is resolved.
- `AnthropicAiService` and `GeminiAiService` missing "Recent meals:" instruction: FIXED. All three AI implementations now tell the model not to list historical meals as new food items.
- New patterns: `night before last` (two_days_ago), `couple days back` (days_ago), `earlier in the week` (days_ago), `what I (had|ate)` (same_as_before).
- New scenarios: 8 rows added (night before last, couple days back, earlier in the week, what I ate, what I had, false-positive guards for "just" and plain "had").
- Total tests: 98 (was 90).

## Closed gaps (2026-05-14 session 1)

- `buildContextSnippet()` output format: smoke test added to `reference_engine_test.dart`
- Slang coverage: "same old", "repeat", "the thing I had", "like what I had" — rules added, scenarios added
- Multi-temporal: "day before yesterday" → `two_days_ago` rule, offset=2
- "the other night", "last week", "a while back", "couple nights ago" — rules added, scenarios added
- All priority boundary cases now have explicit tests in `reference_engine_test.dart`
- Wrong comment in `reference_engine_test.dart` ("offset 4" → "offset 3") fixed

## Patterns found by ai-scout

- `\bearlier\b` fires on both `this_morning` and `days_ago` — priority matters
- Named-day + leftovers combo requires `named_day` to override `leftovers→1`
- `the other day` → `named_day` rule fires but no weekday found → `matchRecent`
- "day before yesterday" fires both `two_days_ago` and `yesterday` — `two_days_ago` checked first in buildQuerySpec
- `usually` does NOT match `\busual\b` due to word boundary — verified with negative scenario test

## How to run

```bash
cd app
flutter test test/meal_memory/                    # all tests
flutter test test/meal_memory/ --reporter expanded  # verbose
flutter test test/meal_memory/scenarios_test.dart  # scenarios only
```
