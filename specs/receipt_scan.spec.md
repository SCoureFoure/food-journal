# Spec — Receipt scan into pantry

> Status: active · Feature: receipt_scan · Added: 2026-10-19
> Source of truth for on-device receipt reading, the review step, the optional AI
> name clean-up, and the pantry list the items land in.

## Requirement

The user photographs a grocery receipt and the items they bought land in a pantry list on
the Meal Planning tab. The pantry is the "what do I have" half of planning: it feeds the
planner and the grocery list later. What matters is **which foods and how many** — not
prices. This is not a budgeting app.

Reading happens **on the phone**. A photo of a receipt carries a card number fragment and
a store location, so the photo itself never leaves the device and is never stored. Only
the item lines the user confirms are saved.

## Constraints (inherited)

- **AI-optional.** OCR and parsing are on-device and need no network. The AI step only
  tidies names. With AI off its button is *absent*, not disabled, and the review list
  still saves.
- **Portable, low-dependency.** No Play Services, no vendor OCR cloud, no OpenCV. One
  native runtime (ONNX Runtime via `flutter_onnxruntime`); every image and geometry step is
  plain Dart so it ports to any platform ONNX Runtime runs on.
- **Schema = contract.** Additive migration to v16 with the existing numbered-block pattern
  and a migration test.
- **Pure logic lives in `models/`** so it is unit-testable without native sqlite3 or ONNX.
- **Anchors** declared in Dart and registered in `specs/anchors.md` in the same commit.
- **Tests carry metadata** (theory tag + contract + implication).

## Decisions (pinned 2026-10-19)

The user delegated these ("do what you think makes sense — we can see how it pans out").
Each is a reversible default, recorded so it can be revisited with evidence.

### Engine

1. **PaddleOCR PP-OCRv6 small detector + small recogniser, as ONNX, bundled as assets**
   (~30 MB). Chosen by a bake-off on five real receipts (strict line match, threshold 0.95):
   96.6% item names / 84.6% quantity lines, against 56.8% / 23.1% for the best Tesseract
   setup. Smaller models lost quantity lines (tiny detector: 76.9%). Bundled, not
   downloaded, so scanning works offline from first launch.
2. **No angle classifier, no grayscale step.** Grayscale lost quantity lines in the
   bake-off. The classifier only fixes upside-down text.
3. **Pre/post-processing is a line-for-line Dart port of a Python reference**
   (`ref_ocr.py`, kept with the bake-off). Primitives: half-pixel bilinear resize,
   normalisation, 2×2 dilation, 8-connected components, convex hull, minimum-area
   rectangle, rectangle unclip, rotated crop, CTC decode, row grouping. The reference's
   unit cases become the Dart unit tests, so the two cannot drift silently.
4. **The receipt photo is decoded, read, and discarded.** It is never written to the
   database or to disk by this feature.

### Parsing

5. **A local rules parser turns OCR lines into items.** Section headers (fuzzy match ≥ 0.80)
   start the item region and set food/non-food (`GENERAL MDSE`, `HEALTH & BEAUTY`,
   `HOUSEHOLD`, `PET`, `PHARMACY` are non-food). Quantity lines (`2 @ 1.39`,
   `2.26 lb @ 1.49/lb`) set the previous item's quantity. `BALANCE DUE`, `TAX PAID`,
   `TAX …`, `SUBTOTAL <price>`, `TOTAL <price>` end the region.
6. **Stores without section headers still parse.** If no header is ever seen, the region
   starts at the first line ending in a price, and food is unknown (`null`).
7. **Identical lines merge in review.** Six `PROG TRD CHK ORZ LMN` lines become one row with
   quantity 6. Merge key: raw text + unit. Weighted (`lb`) rows sum their weights.

### Review

8. **Nothing is saved without review.** After reading, a review screen lists every row with
   an include checkbox, an editable name, quantity, and unit. Rows default to included
   unless they are known non-food.
9. **The AI clean-up is a button, not automatic.** The free Gemini tier allows 20 requests
   a day, shared with meal logging, so the user spends one only when they want it. The
   button sends the OCR text (item region only, never payment lines) plus up to 200 of the
   user's known food names, so the AI reuses names the journal already has.
10. **AI never overwrites the user.** A row the user has edited keeps their name and
    checkbox. Unedited rows take the AI name and the AI food flag.
11. **No items found is not an error screen.** The review opens empty with a message and an
    "Add item" control, so the user can still type their shopping in.

### Pantry

12. **New table `PantryItems`, schema v16.** One row per saved review row:
    `{ id, name, canonicalName, quantity REAL, unit TEXT ('ea'|'lb'), source TEXT
    ('receipt'|'manual'), rawText TEXT?, addedAt, createdAt }`. `canonicalName` via
    `canonicalize()` so pantry joins the food ledger later.
13. **Pantry card on the Meal Planning tab**, between the planner stub and the grocery card.
    It shows each item with its quantity, a delete control per item, "Scan receipt", and
    "Add item". Using items up (decrementing stock), expiry dates, and planner integration
    are later slices.
14. **Pantry is not in the JSON export yet.** Export covers journal entry types. Adding the
    pantry is a follow-up with its own export/import ACs.

## Acceptance criteria (Given / When / Then)

**Rules parser (`models/receipt_parser.dart`)**

1. **AC1** — Given the Hannaford fixture text, When parsed, Then items, quantities, units and
   food flags equal the fixture's expected list (same cases as the bake-off's
   `test_parse_rules.py`).
2. **AC2** — Given a `TAX PAID` / `BALANCE DUE` line, Then nothing after it is an item.
3. **AC3** — Given a misread header (`GENERA MDSE`, `GROCER`), Then it is still a header.
4. **AC4** — Given text with no section header, Then items start at the first line ending in
   a price and every item's food flag is `null`.
5. **AC5** — Given `TOTAL 12.34` or `SUBTOTAL 12.34`, Then the region ends there, but an
   item named `TOTAL CEREAL 4.99` is still an item.
6. **AC6** — Given two identical raw lines with unit `ea`, When merged for review, Then one
   row with quantity 2 remains; lines differing in unit stay separate.

**OCR primitives (`models/receipt_ocr/`)**

7. **AC7** — Each primitive returns the reference's values on the reference's unit cases
   (resize shape, normalise, bilinear, dilate, components, hull, min-area rectangle,
   unclip, crop, recogniser input, CTC decode).
8. **AC8** — Given detector probabilities and recogniser outputs dumped from the reference
   for one receipt, When fed through the Dart pipeline with a fake inference runner,
   Then the Dart text lines equal the reference lines.

**OCR on device (`services/receipt_ocr_service.dart`)**

9. **AC9** — Given a receipt photo on the emulator, When read with the bundled models, Then
   the rules parser finds at least 90% of the items the reference finds (integration test;
   skipped when the private photo is absent).

**AI clean-up**

10. **AC10** — `AiService.parseReceipt` posts `task: parse_receipt` with the OCR text,
    prefixed by a `Known foods:` block when names are given, and maps
    `{items:[{raw,qty,unit,food,name}]}`. Non-200, malformed JSON, or empty text returns
    `success: false` with a message, never throws.
11. **AC11** — Given AI is off, Then `btn-receipt-ai-names` is absent and the review still
    saves.
12. **AC12** — Given the user edited row 1's name, When the AI result arrives, Then row 1
    keeps the user's name and checkbox while unedited rows take the AI name and food flag.

**Review screen**

13. **AC13** — Given parsed rows, Then each shows an include checkbox, name, quantity and
    unit; known non-food rows start unchecked; food and unknown rows start checked.
14. **AC14** — Given the user taps Save, Then only checked rows with a non-empty name are
    stored, as `source: 'receipt'` with their raw text, and the screen pops `true`.
15. **AC15** — Given zero rows, Then `receipt-review-empty` shows and `btn-receipt-add-row`
    adds a blank row.

**Pantry**

16. **AC16** — Given a fresh install, Then schema version is 16 and `pantry_items` exists;
    given a v15 database, When migrated, Then `pantry_items` exists and journal data is
    unchanged.
17. **AC17** — Given pantry rows, Then the pantry card lists them newest first with
    quantity and unit (`2 ea` shows as `×2`, `2.26 lb` as `2.26 lb`), and
    `btn-pantry-delete-<id>` removes one.
18. **AC18** — Given the empty pantry, Then the card shows `Nothing in the pantry yet.`
    plus `btn-scan-receipt` and `btn-pantry-add`.
19. **AC19** — Given the Meal Planning tab, Then the order is planner stub, pantry card,
    grocery card.

## Anchors (explore rig)

- `pantry-card` — pantry panel on the Meal Planning tab
- `btn-scan-receipt` — opens camera / gallery choice, then reads the receipt
- `btn-pantry-add` — adds one item by hand
- `item-pantry-<id>` — one pantry row
- `btn-pantry-delete-<id>` — deletes one pantry row
- `receipt-review-screen` — review screen root
- `item-receipt-row-<index>` — one review row
- `btn-receipt-ai-names` — AI name clean-up; absent when AI is off
- `btn-receipt-add-row` — adds a blank review row
- `btn-receipt-save` — saves checked rows to the pantry
- `receipt-review-empty` — "no items found" message

## Verifies-with

- Unit: `app/test/models/receipt_parser_test.dart`, `app/test/models/receipt_ocr_test.dart`
- Services: `app/test/services/worker_ai_receipt_test.dart`,
  `app/test/services/pantry_storage_test.dart`, migration test
- Widgets: `app/test/widgets/receipt_review_screen_test.dart`,
  `app/test/widgets/pantry_card_test.dart`, `app/test/widgets/meal_planning_screen_test.dart`
- Device: `app/integration_test/receipt_ocr_test.dart` via `flutter drive --profile`, with
  inputs served from the host (see the file header). 2026-10-19 on the x86_64 emulator:
  synthetic receipt exact; a real 21-item receipt 21/21 found in 23 s.
- Bake-off: `.warboss-horde/bakeoff/` (gitignored — holds private receipt photos)
