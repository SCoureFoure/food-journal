# Food Journal — Feature Spec

---

## Design Constraints (apply to all features)

- **AI-optional**: every feature with AI parsing must work end-to-end without AI. Manual entry is the baseline; AI pre-fills it. Never block the save path on an AI call.
- **Schema = contract**: the SQLite schema is stable. Any change requires a drift migration + integration test. AI output is validated before write.
- **Entry types**: the journal feed contains three entry types — `meal`, `medication`, `body_output`. All three share the same feed and date-grouping UI.

---

## Core Features

### F1 — Meal Logging (text + photo + camera)

- User describes meal in free text and/or attaches a photo
- "Add photo" opens camera directly (ImageSource.camera); gallery fallback also available
- AI parses input → pre-fills structured form. If AI unavailable or user skips: manual entry form shown directly
- User can review/edit all fields before saving
- Fields: food name, portion, prep method, calories, P/C/F macros, ingredients list
- Multiple food items per meal entry
- On save: push notification scheduled for check-in (configurable delay, default 90 min). If notification permission not yet granted, prompt user at this point.

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

### F4 — Reaction Tracking & Pattern Detection

- **Blame ledger** — on any check-in with ≥1 symptom, every food/med logged in the
  prior 16h is auto-suspected (`auto` rows). User can manually blame specific items
  from a 24h window (`manual` rows, 3× weight). Ledger stored in `food_suspicions`:
  one row per `(symptom × item)`, severity-weighted, keyed by `canonical_name` so
  the same food re-entered with different phrasing accumulates in one bucket.
- **`getSuspicionScores()`** — aggregates `food_suspicions` by `(canonical_name,
  symptom)`, summing effective weight (base × source multiplier × decay stub).
  Answers "what foods correlate most with bloating?" without any manual tagging.
- **Food memory** — flags foods with 2+ non-none reactions; configurable lookback
  window (30 / 90 / 180 days / all time). Flagged foods show a warning badge.
- **Blame modal** — from the check-in screen, opens a searchable item list (food +
  meds in 24h window); tapping blames an item with manual-weight rows for all active
  symptoms. "Blamed" items surface on the home-feed feeling tile (manual only —
  auto suspicions are a discreet background signal).

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

### F9 — Medication Tracking

- Same entry flow as meal logging: text/photo input → AI parses → manual review/edit form
- AI-optional: manual entry form always available
- Fields: name (drug/supplement), dose, unit (mg/g/ml/etc.), route (oral/topical/inhaled/other), time
- Notes field
- Appears in journal feed alongside meals with distinct icon/label
- Reaction check-in notification scheduled same as meals (configurable, same delay setting)
- Exported in CSV alongside meals with entry_type column

### F10 — Body Output Tracking (WC Log)

- Quick-log entry, minimal fields
- Fields: output_type (bowel movement / urine / other), time, urgency (low/medium/high), consistency (for BM: Bristol scale 1–7), notes
- No AI parsing needed (structured form only)
- Appears in journal feed with distinct icon
- Correlates with food_memory over time (stretch: flag foods that precede urgent BM within N hours)

### F11 — Entity Resolution & Reuse Nudge

- **Canonical identity** — every saved food item and medication gets a
  `canonical_name` (lowercase, punctuation stripped, whitespace collapsed). Blame
  and dashboard queries group on this key so "Turkey Sandwich" and "turkey-sandwich"
  share one suspicion bucket automatically. All existing rows backfilled on v12 migration.
- **Reuse nudge** — while typing a food name on Log Meal, or a medication name on
  Log Medication, a debounced (400ms) fuzzy search runs against recent history.
  On a close match a chip appears (`Reuse "Turkey Sandwich"`); one tap adopts the
  matched name + macros (or med name + dose/unit/route). No match → no chip → no
  extra clicks. Chip hidden during save and (med) when editing an existing entry.
- **Fuzzy-token Jaccard matcher** — token-set Jaccard where two tokens may match by
  equality *or* length-gated character-trigram overlap (both tokens ≥4 chars,
  trigram score ≥0.4). Catches compound variants (`hamburger` ≈ `burger`) that
  pure string equality misses, without false-merging distinct foods
  (`turkey sandwich` / `tuna sandwich` stays 0.33) or short-word collisions
  (`ice` / `rice` blocked by the length gate).

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

### S5 — Body-output / food correlation

- Flag foods in food_memory that frequently precede urgent BM within configurable window
- Requires enough logged entries to infer (5+ occurrences)

### S6 — Biometrics / smart device sync

- Capture or sync biometric data from wearables (heart rate, HRV, glucose, sleep)
- Correlate with meal and reaction entries
- Integration targets: Apple Health / Google Fit / Garmin Connect (platform-specific)
- Long-term goal — no implementation planned until F1–F10 are stable

---

## Non-goals (explicit)

- No cloud sync / backend
- No social features
- No calorie goals or diet plans
- No barcode scanning (possible future)
- No web version
