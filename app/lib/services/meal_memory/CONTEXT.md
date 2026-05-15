# meal_memory — Module Context

> Read this before probing or modifying this module.
> Maintained by ai-scout. Update when architecture changes.

## What this module does

Enables natural-language references to past meals in the food journal. When a user types
"leftovers from last friday" or "the usual breakfast", the app:
1. Detects the reference (pattern engine — no AI, no DB)
2. Fetches matching meal fingerprints from SQLite
3. Injects compact context into the Gemini prompt
4. Gemini resolves the reference and pre-fills the meal form

Zero extra API round-trips. All DB work happens client-side before the network call.

## Files

| File | Role |
|------|------|
| `reference_engine.dart` | Generic pattern detection engine. Port of `docs/meal_memory_starter/pattern_engine.py`. Domain-agnostic. |
| `meal_reference_rules.dart` | Domain rules: temporal + meal-type regex patterns. `buildQuerySpec()` translates profile → DB query. |
| `meal_memory_service.dart` | Public API: `isReferential()`, `buildContextSnippet()`, `recordFingerprint()`. Uses AppDatabase singleton. |

## Key design decisions

- **No agentic loops.** Gemini is called once. Context pre-fetched locally.
- **`meal_fingerprints` table** (schema v4): rolling 40-row window. Fast, no joins, stays tiny.
- **Pattern engine is deterministic.** No AI in the detection step. Pure regex.
- **`named_day` overrides `leftovers→yesterday`** in `buildQuerySpec()`. "Leftovers from last friday" = friday, not yesterday. See priority order in `buildQuerySpec`.
- **`days_ago` priority > `this_morning`** — "earlier this week" fires both; days_ago wins.
- **`now` parameter on `buildQuerySpec()`** makes it testable with fixed dates.

## Known edge cases

- `isReferential()` AI-off path: the quick-copy ("Did you mean?") UI IS built. `_onDescChanged` in `log_meal_screen.dart` runs when `_aiEnabled=false`, calls `findReferentialMeals()` which calls `isReferential()` internally. The CONTEXT.md "open item" is closed as of commit 60754d4.
- `recordFingerprint()` is called `unawaited` after `saveMeal()`. Fingerprints may lag behind by one meal if app closes immediately after save.
- `\bearlier\b` in `this_morning` rules also fires on "earlier this week" — handled by priority.
- `named_day` walks back up to 14 days max. Input referencing 3+ weeks ago will fall back to `matchRecent`.
- "day before yesterday" fires both `two_days_ago` and `yesterday` — `two_days_ago` wins (offset=2) because it is checked first in buildQuerySpec.
- `last week` in `days_ago` maps to offset=3 (approximation). Named day override still applies if a weekday is also present.
- Worker `parse_meal` prompt: "Recent meals:" context instruction added in v1.2.0 (audit 2026-05-14 session 1).
- `AnthropicAiService` and `GeminiAiService` system prompts: same instruction added (audit 2026-05-14 session 2). All three AI paths are now consistent.

## What to watch when testing

- Named day + leftovers combo (the original failing case from May 14, 2026)
- `days_ago` vs `this_morning` priority at boundaries
- Rolling window pruning (insert 41 rows, verify only 40 remain)
- `buildContextSnippet` returns null when no fingerprints exist (should not crash callers)
- Date string format consistency: `_toDateString` output must match SQLite query format

## Integration points

- `StorageService.saveMeal()` → calls `_memory.recordFingerprint()` (unawaited)
- `LogMealScreen._autofill()` → calls `isReferential()` then `buildContextSnippet()`
- `WorkerAiService.parseMeal()` → receives `mealContext`, prepends to text field
- `AiService` interface → `mealContext` param on `parseMeal()` (all three implementations)
