# Import fixtures — data-state library

JSON files matching the `ImportService.parseJson` contract (payload `version: 3`).
Each fixture is a **named data state** for setting up a specific scenario. Two consumers,
one registry (this file):

- **Dart tests** — `ImportService.parseFile('test/fixtures/import/<name>.json')`, or
  `parseJson(File(...).readAsStringSync())`, then `importSelected(...)` to seed a store.
- **Explore rig** — push to device, open via Import wizard to drive the real app into
  the state, then screenshot / assert. (`adb push <file> /sdcard/`, then file-pick in app.)

Schema v3 arrays: `meals`, `medications`, `food_memories`, `water_logs`, `weight_logs`,
`saved_items`. All optional — omitted arrays default to `[]`. Field names are snake_case
(see `export_service.dart` `*ToJson` for the exact keys). Enum names: `ReactionLevel` =
`pending·none·mild·moderate·bad`; `Mood` = `great·good·okay·low·awful`.

## Valid fixtures

| Fixture | State it produces | Drives spec / scenario |
|---|---|---|
| `empty.json` | nothing | home empty-state (`home-empty-state`) |
| `single_meal.json` | 1 meal, 2 food items, no reactions | minimal feed render |
| `full_week.json` | 5 meals across 2 ISO weeks (May 25 – Jun 2) | `home_feed_grouping` — week split + weekly macro bar |
| `flagged_memory.json` | 1 meal + 3 food_memories (2 flagged) | `food_memory_flagging` — warning badges |
| `reactions_severe.json` | meals w/ reaction_logs incl. `mood` + `symptom_levels`, severities none→bad | `feeling_checkin` display, severity rendering |
| `meds_only.json` | 3 medications, varied unit/route/delay | `log_medication` list/edit |
| `water_weight_saved.json` | 3 water + 2 weight + 2 saved_items (no meals) | `log_water`, `log_weight`, saved-items insert |
| `dupes_vs_sample.json` | 1 meal + 1 med that duplicate `../sample_import.json`, plus new rows | `import_wizard` — import sample first, then this; dupe-detect flags the collisions |
| `legacy_v1.json` | `version: 1`, no v3 arrays | back-compat: old export still parses |
| `lenient_enum.json` | invalid `reaction`/`severity`/`mood` names | graceful degradation — parses, unknown enums → `pending`; does NOT throw |

## Malformed fixtures — `malformed/`

These **must throw** in `parseJson` / `parseFile` (negative tests):

| Fixture | Why it throws |
|---|---|
| `missing_required_field.json` | meal has no `time` → null cast to `String` |
| `bad_date.json` | `date: "not-a-real-date"` → `DateTime.parse` `FormatException` |
| `wrong_type_dose.json` | medication `dose: "twenty"` → cast to `num?` fails |
| `water_missing_amount.json` | water_log has no `amount_ml` → null cast to `num` |
| `not_json.json` | not valid JSON → `jsonDecode` throws |

## Adding a fixture

1. Match the v3 field names exactly (round-trip against `export_service` `*ToJson`).
2. Add a row here with the state it produces and the spec it serves.
3. If it seeds a screen for explore, note the anchor it should land on.
