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
│   └── food_memory.dart
├── services/
│   ├── ai_service.dart          # Claude API calls (image + text → JSON)
│   ├── storage_service.dart     # drift DB abstraction
│   ├── notification_service.dart
│   └── export_service.dart      # CSV + grocery list
├── screens/
│   ├── home/                    # journal list, day/week nav
│   ├── log_meal/                # text + photo input
│   ├── meal_detail/             # view/edit single meal
│   ├── checkin/                 # reaction check-in flow
│   └── export/                  # export options
└── widgets/
    ├── macro_totals_bar.dart
    ├── reaction_badge.dart
    └── food_memory_card.dart
```

---

## Database Schema

```
┌─────────────────┐       ┌──────────────────┐
│   meals         │       │   food_items      │
├─────────────────┤       ├──────────────────┤
│ id (PK)         │──┐    │ id (PK)           │
│ date            │  └───▶│ meal_id (FK)      │
│ time            │       │ name              │
│ meal_type       │       │ portion           │
│ raw_input       │       │ prep              │
│ overall_symptoms│       │ calories          │
│ created_at      │       │ protein           │
└─────────────────┘       │ carbs             │
                          │ fat               │
                          │ reaction          │
                          │ notes             │
                          └──────┬───────────┘
                                 │
                    ┌────────────┘
                    ▼
          ┌──────────────────┐
          │   ingredients    │
          ├──────────────────┤
          │ id (PK)          │
          │ food_item_id (FK)│
          │ name             │
          │ quantity         │
          │ unit             │
          └──────────────────┘

┌─────────────────┐       ┌──────────────────┐
│ reaction_logs   │       │  food_memory     │
├─────────────────┤       ├──────────────────┤
│ id (PK)         │       │ id (PK)          │
│ meal_id (FK)    │       │ food_name        │
│ checkin_time    │       │ reaction_pattern │
│ symptoms (JSON) │       │ occurrences      │
│ severity        │       │ last_seen        │
│ notes           │       │ flagged          │
└─────────────────┘       └──────────────────┘

┌─────────────────┐       ┌──────────────────┐
│  medications    │       │  body_outputs    │
├─────────────────┤       ├──────────────────┤
│ id (PK)         │       │ id (PK)          │
│ date            │       │ date             │
│ time            │       │ time             │
│ name            │       │ output_type      │
│ dose            │       │ urgency          │
│ unit            │       │ consistency      │
│ route           │       │ notes            │
│ notes           │       │ created_at       │
│ created_at      │       └──────────────────┘
└─────────────────┘
```

---

## AI Service Flow

```
logMeal(text?, imageBytes?) async
  │
  ├─ Build prompt with system context + user input
  │
  ├─ POST to Claude API (claude-sonnet-4-6)
  │    content: [image block?, text block]
  │    system: meal parsing instructions + JSON schema
  │
  ├─ Parse JSON response
  │
  └─ return List<FoodItemDraft>
```

### System prompt strategy

- Instruct Claude to return strict JSON only (no markdown wrapper)
- Include portion estimation guidelines
- Include common ingredient extraction rules
- Gracefully handle partial info (estimate where unclear, flag as estimated)

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
