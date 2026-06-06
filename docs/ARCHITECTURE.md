# Food Journal — System Architecture

---

## Design Principles

### 1. AI-Optional
Every AI-powered flow **must have a complete manual fallback**. AI is enhancement, not a dependency. If the API is unavailable, the key is missing, the user declines AI, or parsing fails — the user can still complete the action by hand. Manual entry is the baseline; AI pre-fills it.

### 2. Schema as Contract
The SQLite schema is a stable API. Screens and services depend on it the same way a client depends on a REST contract.
- No column rename or removal without a drift migration.
- Every new table or migration must have a corresponding integration test in `storage_service_test.dart`.
- AI-parsed JSON output must also be validated against a schema before being written to DB.

### 3. Services as Tool Interface
Service methods are designed to be exposable as Claude tool-use functions (function calling). Each method must have: clear typed inputs, clear typed output, single responsibility. This forward-compatibility allows the AI layer to call services as tools rather than only accepting pre-parsed structured output.

### 4. Entry Types
The app tracks anything that goes *into* or *out of* the body. Three entry types share the journal feed:
- `meal` — food/drink, with food items + macros + ingredient breakdown
- `medication` — drug, supplement, or substance with dose/route
- `body_output` — bathroom/WC visits and other body outputs

All three share: `id`, `date`, `time`, `created_at`, `notes`. Each has its own table with type-specific fields.

---

## High-Level Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        USER INPUT                           │
│  [Camera / Photo]  or  [Text Description]                   │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    AI LAYER (Claude API)                     │
│                                                             │
│  Input: image + text prompt                                 │
│  Output: structured JSON                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  {                                                    │  │
│  │    "foods": [                                         │  │
│  │      {                                                │  │
│  │        "name": "Sweet potato",                        │  │
│  │        "portion": "1 medium ~5oz",                    │  │
│  │        "prep": "Baked with honey",                    │  │
│  │        "calories": 160,                               │  │
│  │        "protein": 2, "carbs": 38, "fat": 0,          │  │
│  │        "ingredients": ["sweet potato", "honey"]       │  │
│  │      }                                                │  │
│  │    ]                                                  │  │
│  │  }                                                    │  │
│  └───────────────────────────────────────────────────────┘  │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│                  LOCAL STORAGE (SQLite/drift)                │
│                                                             │
│  meals ────────── food_items ────────── ingredients         │
│     └──────────── reaction_logs                             │
│     └──────────── food_memory                               │
└────────────────┬────────────────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌───────────────┐  ┌────────────────┐
│  JOURNAL VIEW │  │  NOTIFICATION  │
│               │  │  SERVICE       │
│  Day filter   │  │                │
│  Week filter  │  │  Post-meal     │
│  Daily totals │  │  check-in      │
│  Weekly totals│  │  (~90 min)     │
└───────────────┘  └────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│                       EXPORTS                               │
│  CSV (meals + macros)   |   Grocery list (ingredients)      │
└─────────────────────────────────────────────────────────────┘
```

---

## Flutter App Structure

```
lib/
├── main.dart
├── models/
│   ├── meal_entry.dart
│   ├── food_item.dart
│   ├── ingredient.dart
│   ├── reaction_log.dart
│   ├── food_memory.dart
│   └── medication.dart
├── services/
│   ├── ai_service.dart              # AiService interface + Claude direct impl
│   ├── worker_ai_service.dart       # Cloudflare Worker / Gemini impl (primary)
│   ├── storage_service.dart         # drift DB abstraction
│   ├── notification_service.dart
│   ├── export_service.dart
│   ├── import_service.dart          # JSON import with dupe detection
│   ├── settings_service.dart        # AI toggle (shared_preferences)
│   ├── seed_service.dart            # debug seed data
│   ├── database/
│   │   ├── app_database.dart        # drift schema (v12) + migration strategy
│   │   └── app_database.g.dart      # generated
│   └── meal_memory/
│       ├── meal_memory_service.dart # isReferential / buildContextSnippet / recordFingerprint
│       ├── meal_reference_rules.dart # temporal + meal-type regex rules
│       └── reference_engine.dart    # rule runner + confidence scoring + cache
├── screens/
│   ├── home/                        # week-grouped journal feed
│   ├── log_meal/                    # text + photo input
│   ├── log_medication/              # medication entry
│   ├── meal_detail/                 # view/edit single meal
│   ├── checkin/                     # reaction check-in (linked to meal or standalone)
│   ├── export/                      # export options
│   └── import/                      # import wizard
├── utils/
│   └── date_time_utils.dart
└── widgets/
    ├── home/                        # meal_tile, medication_tile, feeling_tile, week_summary_section
    ├── macro_totals_bar.dart
    ├── reaction_badge.dart
    ├── food_memory_card.dart
    └── ...
```

---

## Database Schema

Schema version: **12**. Managed by drift with an explicit `MigrationStrategy`. Migration history in `app_database.dart`; each step is verified in `migration_order_test.dart`.

```
┌─────────────────────┐       ┌──────────────────────────┐
│   meals             │       │   food_items              │
├─────────────────────┤       ├──────────────────────────┤
│ id (PK)             │──┐    │ id (PK)                   │
│ date                │  └───▶│ meal_id (FK → meals)      │
│ time                │       │ name                      │
│ meal_type           │       │ canonical_name  ← v12     │
│ raw_input           │       │ portion / prep            │
│ overall_symptoms    │       │ calories / protein        │
│ image_data (BLOB)   │       │ carbs / fat               │
│ created_at          │       │ reaction (int index)      │
└─────────────────────┘       │ notes / servings          │
                              └──────────┬────────────────┘
                                         │
                             ┌───────────┘
                             ▼
                   ┌──────────────────────┐
                   │   ingredients        │
                   ├──────────────────────┤
                   │ id (PK)              │
                   │ food_item_id (FK)    │
                   │ name / quantity / unit│
                   └──────────────────────┘

┌──────────────────────┐       ┌──────────────────────┐
│ reaction_logs        │       │  food_memories       │
├──────────────────────┤       ├──────────────────────┤
│ id (PK)              │       │ id (PK)              │
│ meal_id (nullable FK)│       │ food_name (UNIQUE)   │
│ checkin_time         │       │ reaction_pattern     │
│ symptoms (JSON)      │       │ occurrences          │
│ severity (int)       │       │ last_seen            │
│ mood (int, nullable) │       │ flagged / favorited  │
│ symptom_levels (JSON)│       └──────────────────────┘
│ notes                │
└──────────┬───────────┘
           │ ON DELETE CASCADE
           ▼
┌──────────────────────────────────────────────────────┐
│  food_suspicions  (blame ledger — v11)               │
├──────────────────────────────────────────────────────┤
│ id (PK)                                              │
│ reaction_log_id (FK → reaction_logs CASCADE)         │
│ symptom (text)                                       │
│ target_type ('food' | 'medication')                  │
│ target_id (food_items.id | medications.id)           │
│ target_name (canonical — groups across re-entries)   │
│ base_weight (REAL — ReactionLevel severity index)    │
│ source ('auto' | 'manual')                           │
│ created_at (INTEGER — decay input)                   │
│ INDEX (target_name, symptom) — aggregation           │
│ INDEX (reaction_log_id)      — edit / cascade        │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  medications                                         │
├──────────────────────────────────────────────────────┤
│ id (PK)  date  time  name                           │
│ canonical_name  ← v12                                │
│ dose  unit  route                                    │
│ checkin_delay_minutes  raw_input  notes              │
│ image_data (BLOB)  created_at                        │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│  meal_fingerprints  (rolling 40-row window)          │
├──────────────────────────────────────────────────────┤
│ id (PK)  meal_id (FK CASCADE)  date (ISO text)      │
│ meal_type  foods_summary  total_cals  total_protein  │
│ created_at (Unix ms)                                 │
│ INDEX (date DESC)  INDEX (meal_type, date DESC)      │
└──────────────────────────────────────────────────────┘
  Used by MealMemoryService for temporal-ref context snippets.

┌────────────────────┐  ┌────────────────────┐  ┌─────────────────────┐
│  water_logs        │  │  weight_logs       │  │  saved_items        │
├────────────────────┤  ├────────────────────┤  ├─────────────────────┤
│ id  date  time     │  │ id  date  time     │  │ id  name            │
│ amount_ml  notes   │  │ weight_value  unit │  │ calories/protein    │
│ created_at         │  │ notes  created_at  │  │ carbs/fat           │
└────────────────────┘  └────────────────────┘  │ components_json     │
                                                 │ created_at          │
                                                 └─────────────────────┘
```

**canonical_name** (v12) — every `food_items` and `medications` row stores a normalized entity key (`canonicalize()`: lowercase → strip punct → collapse whitespace). Blame ledger groups on this key so the same food re-entered with different spelling/casing accumulates in one suspicion bucket. Backfilled for all existing rows on migration.

> **body_outputs** is NOT implemented. It is listed as a stretch feature in FEATURES.md.

---

## AI Service Flow

Two implementations behind a common `AiService` interface:

**WorkerAiService** (primary — `MEAL_PARSER_URL` in `.env`):

```
parseMeal(text?, imageBytes?, mealType?, mealContext?) async
  │
  ├─ MealMemoryService.isReferential(text)?
  │    yes → buildContextSnippet() → prepend to text as mealContext
  │
  ├─ POST { task: "parse_meal", text?, image?, mealType? }
  │    to Cloudflare Worker (Gemini backend)
  │    auto-retry once on 503
  │
  ├─ Parse JSON response { foods: [...], title: "..." }
  │
  └─ return MealParseResult
```

**AiService** (fallback — `ANTHROPIC_API_KEY` in `.env`):

```
parseMeal(text?, imageBytes?) async
  │
  ├─ POST to Claude API (claude-sonnet-4-6)
  │    content: [image block?, text block]
  │    system: meal parsing instructions + strict JSON schema
  │
  └─ return MealParseResult
```

Both return `MealParseResult(success, items, title)`. Screens call whichever is configured; if AI is toggled off in Settings, neither is called.

---

## Notification Flow

```
Meal saved
    │
    ├─ Schedule local notification at +90 min (configurable)
    │   title: "How did you feel after [meal]?"
    │   body:  "Tap to log any reactions."
    │
User taps notification
    │
    └─ Open check-in screen
         ├─ Symptom selector (bloating, pain, nausea, fatigue, none, other)
         ├─ Severity slider (none / mild / moderate / bad)
         ├─ Free text notes
         └─ Save → ReactionLog + update food_memory
```

---

## Food Memory (Pattern Detection)

```
On each ReactionLog save:
  for each food_item in meal:
    upsert food_memory (food_name)
      increment occurrences
      update reaction_pattern if severity >= mild
      set flagged = true if occurrences >= 2 AND reaction != none
```

Display in journal as warning badge on flagged foods.
