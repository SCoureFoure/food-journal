# Food Journal — Feature Spec

## Core Features

### F1 — Meal Logging (text + photo)

- User describes meal in free text and/or attaches a photo
- AI parses input → pre-fills structured form
- User can review/edit before saving
- Fields: food name, portion, prep method, calories, P/C/F macros, ingredients list
- Multiple food items per meal entry

### F2 — Journal View

- Chronological list of meals, grouped by day
- Day filter: tap a date to see only that day
- Week filter: see current or past week
- Daily totals bar: calories, protein, carbs, fat (sum of all meals)
- Weekly totals summary card
- Reaction badges on foods flagged in food memory

### F3 — Reaction Tracking (check-in)

- Push notification fires ~90 min after each saved meal (configurable)
- Check-in screen:
  - Multi-select symptoms: bloating, stomach pain, nausea, fatigue, brain fog, heartburn, none, other
  - Severity: none / mild / moderate / bad
  - Free text notes
- Reaction saved to `reaction_logs` table
- Per-food-item reaction can also be logged directly in meal detail

### F4 — Food Memory / Pattern Detection

- Automatic: builds from reaction logs
- Flags a food when it has caused a non-none reaction 2+ times
- Memory view: list of flagged foods with reaction summary and last-seen date
- Configurable lookback window (default: all time, options: 30 / 90 / 180 days)
- Flagged foods show warning badge wherever they appear in journal

### F5 — Ingredients Tracking

- Each food item has an ingredients list (populated by AI, editable)
- Standard: "sweet potato", "honey", "olive oil", "feta cheese"
- Used for grocery list export (F7)
- Cross-reference with food memory for ingredient-level reaction patterns (stretch)

### F6 — CSV Export

- Exports full journal to CSV
- Columns: date, time, meal type, food, portion, prep, calories, P, C, F, reaction, notes
- Filename: `food_journal_YYYY-MM-DD.csv`
- Shareable via OS share sheet (doctor, nutritionist, etc.)

### F7 — Grocery List Export

- Aggregates ingredients from selected date range (this week / custom)
- Deduplicates and sorts alphabetically
- Exports as plain text or shares via OS share sheet
- Format: one ingredient per line, optionally grouped by category (stretch)

### F8 — Notes

- Freeform notes field per meal (AI-populated from description, editable)
- Notes visible in journal view and CSV export

---

## Stretch Features

### S1 — Ingredient-level reaction memory

- Cross-reference reaction logs with ingredient list
- Flag specific ingredients (e.g., "feta cheese" rather than just "salad")
- Requires enough data to infer (3+ occurrences)

### S2 — Weekly summary / insights

- "This week you ate X meals, felt good after Y%"
- Most common flagged foods this week
- Trend: is severity improving over time?

### S3 — Grocery list categories

- AI groups ingredients: produce, dairy, proteins, pantry
- Displayed grouped in grocery list export

### S4 — Offline-first AI fallback

- If no network: show manual entry form (no AI parsing)
- Queue AI parse for when network returns

---

## Non-goals (explicit)

- No cloud sync / backend
- No social features
- No calorie goals or diet plans
- No barcode scanning (possible future)
- No web version
