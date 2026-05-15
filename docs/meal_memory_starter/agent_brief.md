# Agent Brief — Meal Memory Implementation

You are implementing a meal memory system for a food journaling app. This document
tells you exactly what to build, what already exists (in this folder), and the
architectural decisions already made so you don't re-litigate them.

Read this in full before writing any code.

---

## Context

The app is a **Flutter mobile app** with:
- Local SQLite via Drift ORM
- A Cloudflare Worker backend running a lightweight Gemini model
- An "AI mode" toggle — all AI features must gracefully disable when it is off
- A core UX problem: food logging apps die because entry is too many clicks

The meal memory feature solves this: when a user types something like
"I had the leftovers from dinner last night," the app should pre-fill the
meal entry from history without asking for confirmation. The user saves or edits.

---

## What is in this folder

### `pattern_engine.py`
Generic, framework-free Python that ports the deterministic pattern detection
layer from `magic-deck-builder`. It is the model for what to build in Dart.

Key concepts to carry over verbatim:
- `ReferenceRule` → a key, a label, a list of compiled regex patterns
- `compile_patterns()` → compile once at startup, reuse every call
- `detect_references()` → run all rules, score, return a profile
- Confidence scoring: **first match = 1.0, each additional match on same rule = +0.5**
- In-process cache keyed by normalized input string

### `meal_reference_rules.py`
The domain rules themselves (temporal references, meal type hints) plus
`build_query_spec()` which translates a profile into a structured DB query.

This is your reference for which regex patterns to implement. Translate to Dart
`RegExp` objects. The patterns themselves transfer directly.

---

## Architecture — do NOT deviate from this

```
User input
    ↓
MealMemoryService.isReferential(input)          ← runs pattern engine, O(microseconds)
    ↓ (if false → skip everything below, call Gemini normally)
MealMemoryService.buildContextSnippet(input)    ← queries meal_fingerprints, formats text
    ↓
Inject snippet into Gemini prompt
Single Gemini API call
    ↓
Pre-filled MealEntry returned
User sees form, taps Save (or edits)
```

No agentic loops. No tool calling from the Gemini side. No extra round-trips.
All DB interaction happens **before** the API call, on the client.

---

## Database schema to build

### `meal_fingerprints` table

```sql
CREATE TABLE meal_fingerprints (
  id TEXT PRIMARY KEY,
  meal_id TEXT NOT NULL REFERENCES meal_entries(id) ON DELETE CASCADE,
  date TEXT NOT NULL,          -- ISO 8601: "2026-05-14"
  meal_type TEXT,              -- "breakfast" | "lunch" | "dinner" | "snack" | null
  foods_summary TEXT NOT NULL, -- "chicken thighs, roasted potatoes, salad"
  total_cals INTEGER,
  total_protein REAL,
  created_at INTEGER NOT NULL  -- Unix ms timestamp
);

-- Rolling window index: fast lookup by date + type
CREATE INDEX idx_fingerprints_date ON meal_fingerprints(date DESC);
CREATE INDEX idx_fingerprints_type ON meal_fingerprints(meal_type, date DESC);
```

Maintain a rolling window of **30–50 rows max**. On every meal save:
1. Insert new fingerprint row
2. Delete oldest rows beyond the window limit
3. Never store full nutritional breakdowns — just the summary fields above

### Why separate table (not just querying meal_entries)?
- No joins needed to build context snippets
- Stays tiny and fast regardless of total meal history size
- Can be serialized as compact prompt context in under 200 tokens

---

## Dart implementation spec

### `MealMemoryService`

```dart
class MealMemoryService {
  final Database _db;

  // Step 1: is this input referential?
  // Run before any API call. Returns false for "I had eggs" → skip everything.
  bool isReferential(String input);

  // Step 2: build compact context for the Gemini prompt.
  // Only called when isReferential() == true.
  // Returns null if no matching fingerprints found.
  Future<String?> buildContextSnippet(String input);

  // Called after every meal save — maintains rolling window.
  Future<void> recordFingerprint(MealEntry meal);
}
```

### `isReferential()` implementation

Port the rule set from `meal_reference_rules.py` as Dart `RegExp` constants.
Compile them at class construction time (not inside isReferential — Dart RegExp
compilation is not free).

```dart
static final _temporalPatterns = [
  RegExp(r'\byesterday\b', caseSensitive: false),
  RegExp(r'\blast night\b', caseSensitive: false),
  RegExp(r'\bleftovers?\b', caseSensitive: false),
  RegExp(r'\bsame (?:as|thing)\b', caseSensitive: false),
  RegExp(r'\bagain\b', caseSensitive: false),
  RegExp(r'\bthe usual\b', caseSensitive: false),
  // ... full list from meal_reference_rules.py _TEMPORAL_RULES
];

bool isReferential(String input) {
  final normalized = input.trim().toLowerCase();
  return _temporalPatterns.any((p) => p.hasMatch(normalized));
}
```

### `buildContextSnippet()` implementation

1. Parse `ReferenceProfile` from input (run full pattern engine)
2. Build SQL query from profile (using the logic in `build_query_spec()`)
3. Query `meal_fingerprints` — at most 5 rows
4. Format as compact text:

```
Recent meals:
- Yesterday dinner: chicken thighs, roasted potatoes, salad (620 cal, 48g protein)
- Yesterday lunch: turkey sandwich, chips (540 cal, 32g protein)
- This morning: oatmeal with berries (380 cal, 12g protein)
```

Total target: **under 200 tokens** injected into every referential prompt.

### Gemini prompt update

Add a section to your existing parse prompt:

```
{{#if mealContext}}
The user may be referencing a past meal. Here is their recent meal history:

{{mealContext}}

If the user's input clearly refers to one of these past meals, use that meal's
foods, calories, and protein as the basis for this entry. Do not ask for
confirmation — pre-fill it and let the user edit if needed.
{{/if}}
```

---

## AI-off fallback

When AI mode is off and `isReferential()` returns true:
- Query `meal_fingerprints` using the same `buildQuerySpec()` logic
- Surface the top 3–5 results as quick-copy buttons in the UI
- User taps one → copies as a template entry (no AI call)

Same UX concept, zero AI cost.

---

## Build order

1. `meal_fingerprints` Drift schema + migration
2. `MealMemoryService.recordFingerprint()` — wire into existing meal save path
3. `isReferential()` — port patterns from `meal_reference_rules.py`
4. `buildContextSnippet()` — build and format the context string
5. Inject context into existing Gemini parse call (only when `isReferential()`)
6. AI-off fallback: quick-copy button list

Do steps 1–3 first. They are pure local logic with no API dependency and can be
tested without any Gemini interaction.

---

## What NOT to build

- Vector embeddings or semantic similarity — meals are structured records, query by
  date + meal_type, not cosine similarity
- Tool calling from the Gemini side — pre-fetch context client-side instead
- Confirmation dialogs ("Did you mean X?") — pre-fill and let the user edit
- Named meal templates as a separate feature — fingerprints already serve this role
- Any backend changes to the Cloudflare Worker for this feature
