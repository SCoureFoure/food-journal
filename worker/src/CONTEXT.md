# Worker — Context

> Read this before modifying the Cloudflare Worker or its prompts.
> Maintained by ai-scout.

## What the Worker does

Thin Cloudflare Worker that receives a JSON body from the Flutter app,
builds a Gemini prompt from `prompts.json`, calls the Gemini Flash API,
strips markdown fences from the response, and returns raw JSON to the client.

## Files

| File | Role |
|------|------|
| `index.js` | Request routing, Gemini call, response cleanup |
| `prompts.json` | System prompts keyed by task name |

## Supported tasks

| Task | Input fields | Output JSON |
|------|-------------|-------------|
| `parse_meal` | `text`, `image`, `mealType` | `{ title, foods[] }` |
| `parse_medication` | `text`, `image` | `{ name, dose, unit, route, notes }` |

## Output schema — parse_meal

```json
{
  "title": "string",
  "foods": [
    {
      "name": "string",
      "portion": "string | null",
      "prep": "string | null",
      "calories": "number | null",
      "protein": "number | null",
      "carbs": "number | null",
      "fat": "number | null",
      "ingredients": ["string"],
      "notes": "string | null"
    }
  ]
}
```

## How context injection works (meal memory)

The Flutter `WorkerAiService` prepends a "Recent meals:" block to the `text`
field before sending it to the Worker. The Worker sees a combined string like:

```
Recent meals:
- Yesterday dinner: grilled chicken, rice (450 cal, 35g protein)
- Friday dinner: salmon with asparagus (520 cal, 42g protein)

User input: leftovers from last night
```

The Worker passes this directly to Gemini with no modification.

## Known prompt gap — context instruction missing

**Risk:** The `parse_meal` system prompt does not tell Gemini what to do with the
"Recent meals:" block. Gemini correctly resolves temporal references in most cases
because the block is self-explanatory, but there is no explicit instruction like:
"If the input contains a 'Recent meals:' section, use it to resolve any references
to past meals. Do not list the historical meals as new food items."

**Failure mode:** If a user input is very short (e.g. just "again") and the
history block is large, Gemini could include historical food items in the output
as if they were a new entry, or could hallucinate a new meal instead of copying
the referenced one. Observed in adversarial testing: not yet triggered in prod.

**Recommended fix:** Add to the `parse_meal` systemPrompt:

```
If the input begins with a "Recent meals:" section, use it only as context
to resolve temporal references (e.g. "leftovers from last night",
"same as yesterday"). Extract food items from the current meal description
that follows — not from the history block. Do not repeat historical entries.
```

This fix goes in `prompts.json` — no Worker code change needed.

## Schema drift risks

- `foods` key must be an array — single-item meals could come back as an object
  if the model drifts. The Flutter client does `(json['foods'] as List)` which
  throws if this happens. No guard exists today.
- `title` is optional in schema but relied on by the client for the meal name
  field pre-fill. If null, client silently skips pre-fill (correct behavior).
- Macro fields (`calories`, `protein`, `carbs`, `fat`) are typed as `number`
  in the prompt but could come back as strings (e.g. `"450"`). Flutter uses
  `FoodItemDraft.fromJson` — verify it uses `num?.toDouble()` not direct cast.

## Environment

- `GEMINI_API_KEY` secret in Cloudflare Worker environment
- `MEAL_PARSER_URL` set in Flutter `.env` (dev and prod values differ)
- No auth on the Worker endpoint — rate limiting via Cloudflare only

## What to watch

- Gemini model name in `GEMINI_URL` uses `gemini-flash-latest` — this is a
  floating alias. Pin to a specific version (e.g. `gemini-1.5-flash`) if
  response format instability is observed.
- The `cleaned` regex strips `` ```json `` and `` ``` `` fences but not other
  markdown. If Gemini wraps output in other code fences it will break parsing.
