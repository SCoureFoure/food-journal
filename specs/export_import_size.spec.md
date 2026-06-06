# Spec — Export/Import size control

> Status: active · Feature: export_import_size · Added: 2026-06-05
> Source of truth for keeping export files small and import parsing responsive.
> Photos (base64-embedded) are the dominant size driver; large files froze the
> import wizard because parsing ran on the main isolate.

## Requirement
A user on a phone with many photo-attached meals must be able to export and
re-import their journal without producing an unusably large file or freezing the
app. Four levers:

1. **Capture smaller photos.** `image_picker` downscales at pick time so each
   stored photo is bounded, shrinking every future export.
2. **Photo-export is opt-in.** Export embeds photos only when the user asks; the
   default export is data-only (KB, not MB).
3. **Compact JSON.** Export serialises without pretty-print indentation.
4. **Off-main-isolate import parse.** The import wizard parses + base64-decodes in
   a background isolate so a large file never ANRs the UI.

## Constraints (inherited)
- **Schema = contract.** No schema change. JSON payload shape is unchanged except
  that `image_data` may now be `null` when photos are excluded — already a valid,
  parseable value (existing fixtures carry `image_data: null`). `version` stays 3.
- **AI-optional / local-only.** Export/import is pure local logic; no worker, no AI.
- **Round-trip invariant.** Export → import must preserve all non-image fields
  byte-for-byte regardless of indentation or the photo toggle.
- **Reuse.** Keep `ImportService.parseJson` a pure static (pure-Dart testable, no
  Flutter import); the isolate hop wraps it from the service, tests call the static
  directly.

## Decisions (pinned 2026-06-05)
- **Photo-export default = OFF.** New `ExportTypes.images` flag; the Export screen's
  "Include photos" switch defaults **off**, so the common export is small. User opts
  in for a full backup. `ExportTypes.images` model default stays `true` so
  `exportMealJson` (single-meal share) and any caller that omits the flag keep
  embedding the photo.
- **Downscale bounds = 1280×1280, quality 80.** `pickImage(maxWidth: 1280,
  maxHeight: 1280, imageQuality: 80)`. ~10× smaller per photo; fixes future data
  only — photos already in the DB are untouched.
- **No pretty-print.** `jsonEncode(payload)` replaces
  `JsonEncoder.withIndent('  ')` in `_shareJson`. ~20% smaller, fewer in-memory
  copies. No test asserts indentation.
- **Isolate via `compute`.** `ImportService.parseFile` runs read+parse in
  `compute`. `parseJson` stays a synchronous static so it can be the isolate entry
  and remain unit-testable without an isolate. `ImportPayload` + its models are
  plain objects → sendable across the isolate by copy.
- **Toggle scope.** The photo switch governs both meal and medication images in a
  full export (`buildPayload`). Single-meal share (`exportMealJson`) always embeds.

## Acceptance criteria (Given / When / Then)
1. **AC1 — photo toggle excludes images.** Given a meal with `imageData`, when
   `mealToJson(..., includeImages: false)` → `image_data` is `null`; with
   `includeImages: true` (or omitted) → `image_data` is the base64 string. Same for
   `medicationToJson`.
2. **AC2 — export default is data-only.** Given the Export screen at defaults, when
   the user exports → the photo switch is off and the built payload carries no
   embedded image bytes (`image_data` null for every meal/medication).
3. **AC3 — compact JSON.** Given any export, when serialised → the output contains
   no two-space indentation newlines (`jsonEncode`, not `withIndent`), and still
   round-trips through `parseJson` to equal field values.
4. **AC4 — round-trip survives toggle + compact.** Given a meal exported with
   photos OFF and compact JSON, when re-parsed → meal type, food names, calories,
   reactions, ingredients all match; `imageData` is null.
5. **AC5 — isolate parse returns correct payload.** Given a JSON file on disk, when
   `ImportService(storage).parseFile(path)` runs (through `compute`) → it returns a
   payload equal to `parseJson` of the same content (behavioural parity; the isolate
   hop is transparent).
6. **AC6 — downscale config.** Photos are picked with `maxWidth: 1280,
   maxHeight: 1280, imageQuality: 80`. (Config/manual-verify — image_picker has no
   widget-test fake here.)

## Anchors (explore rig)
<!-- A view: ids this feature touches. Canonical rows live in specs/anchors.md. -->
- `toggle-include-photos` — Export screen "Include photos" switch (default off) —
  **new, trail-blazed with this spec**
- `btn-import-json` — Import-from-JSON button (existing in code, now registered)
- `import-wizard-screen` — import wizard root (existing in code, now registered)
- `btn-import-confirm` — import confirm button (existing in code, now registered)
- `export-screen`, `btn-export-json` — existing export anchors

## Verifies-with
- Toggle + compact + round-trip (AC1, AC3, AC4): `app/test/export_import_test.dart`
  via `ExportService` static helpers + `jsonEncode`/`parseJson`.
- Default data-only (AC2): `app/test/widgets/export_screen_test.dart` — switch
  state + payload via `ExportService.buildPayload` over a `storageOverride` fake.
- Isolate parity (AC5): `app/test/export_import_test.dart` — temp file →
  `parseFile` equals `parseJson`.
- Downscale (AC6): config assertion / manual verify; image_picker not fakeable in
  widget test.
- e2e: export→share→import journey via the explore rig (deferred — share sheet +
  file picker are OS surfaces outside the rig).
