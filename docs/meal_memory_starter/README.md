# Meal Memory Starter — Pattern Engine Port

Extracted from `magic-deck-builder` (Python/FastAPI). That project has a deterministic
intent engine that classifies card text using regex rules, scores features, and drives
AI-assisted recommendations — all without calling an LLM for the classification step.

This folder ports the **pattern detection layer** of that engine to the meal memory use
case. The goal: detect when a user's natural-language meal entry references a past meal
("leftovers from last night", "the usual breakfast") so the app can pre-fill from history
without asking the user to confirm.

---

## What to steal

| File | What it gives you |
|------|-------------------|
| `pattern_engine.py` | Generic, reusable primitives: `ReferenceRule`, `_compile()`, `detect_references()`, `ReferenceProfile`. No domain logic. Drop in as-is. |
| `meal_reference_rules.py` | Ready-to-use rules for temporal/referential meal language. Edit freely. |

## What NOT to steal

The source repo also has:
- **Cosine + coverage similarity scoring** — designed for fuzzy card-to-card matching.
  Meals are date/type indexed. Use direct SQL (`WHERE date = ? AND meal_type = ?`),
  not vector math.
- **Synergy map expansion** — no equivalent for meal memory.
- **ILIKE DB text scanning** — meals are structured records, not full-text documents.
  Query by foreign key, not ILIKE.

---

## How it fits

```
User types: "I had the leftovers from dinner last night"
                            ↓
          detect_references(input)   ← pattern_engine.py
                            ↓
          ReferenceProfile {
            has_temporal_ref: True,
            temporal_keys: ["yesterday_dinner"],
            meal_type_hints: ["dinner"],
            confidence: 1.5          ← first match = 1.0, extras +0.5
          }
                            ↓
          If has_temporal_ref → build SQL query from profile
          Inject compact result as context into Gemini prompt
          Single API call → pre-filled meal entry
          User taps save (or edits)
```

No agentic loops. No tool calling. No extra API round-trips.
All heavy lifting happens client-side before the network call.

---

## AI-off fallback

`detect_references()` runs the same way with AI off. When `has_temporal_ref` is true
and AI is disabled, surface the last 3–5 matching meals as quick-copy buttons.
Same UX concept, zero AI cost.

---

## Next steps for the agent

See `agent_brief.md` for a full implementation spec.
