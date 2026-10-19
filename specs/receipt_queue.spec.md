# Spec — Receipt queue and scan speed

> Status: active · Feature: receipt_queue · Added: 2026-10-19
> Source of truth for phase 1 of `specs/kitchen.kickoff.md`: faster on-device receipt
> reading, and a queue that reads several receipt photos in the background while the
> user keeps using the app. Amends `specs/receipt_scan.spec.md` decision 4.

## Requirement

The user snaps several receipts in a row, or picks several from the gallery, without
waiting for each one. The photos read one after another in the background while the app
stays usable. The pantry card shows how many are still reading and how many are ready to
review. The user reviews each ready receipt with the existing review screen (approve,
edit, or discard). A photo waits only in the app's private cache and is deleted as soon
as it has been read.

Reading itself gets faster first: on the x86_64 emulator a real 46-line receipt took
22.9 s warm, of which 15.5 s was the recogniser — 100 calls shipping 317 MB of class
scores over the platform channel to pick one class per step.

## Constraints (inherited)

- **AI-optional.** Queue and reading are on-device; the AI name button in review is
  unchanged.
- **Portable, low-dependency.** Same runtime (`flutter_onnxruntime`), no new packages.
  Model changes are made offline by a checked-in script, not at runtime.
- **Schema = contract.** No schema change in phase 1. The `pantry_items` reshape belongs
  to phase 2 (ruled 2026-10-19). Saving from review uses the existing pantry path.
- **Privacy.** A receipt photo carries a card fragment and a store location. It never
  leaves the device, lives only in the app cache, and is deleted once read. What is kept
  for review is the item region of the text only — never the payment lines.
- **Pure logic in `models/`**, anchors registered in `specs/anchors.md`, tests carry
  metadata.

## Decisions (pinned 2026-10-19)

### Speed

1. **Argmax inside the model.** `scripts/ocr_rec_argmax.py` rewrites the recogniser so its
   outputs are `idx` (int64 `[N,T]`, ArgMax over classes) and `maxp` (float `[N,T]`,
   ReduceMax over classes) instead of the `[N,T,18710]` softmax. The bundled asset becomes
   `assets/ocr/PP-OCRv6_rec_small_argmax.onnx`. The original file stays in the repo as
   the script's input but is no longer listed in `pubspec.yaml`, so it is not bundled.
   The script checks the new outputs against the original on seeded inputs and fails on
   any difference.
2. **Batched recogniser calls.** Crops are sorted by width and recognised in batches of
   up to 8, each batch right-padded with 0.0 to its widest crop (PaddleOCR's own scheme).
   Results go back to the original box order before rows are grouped. Kept only if the
   device checks below hold.
3. **Dart work off the UI isolate.** Decoding, the detector resize/normalise, box
   extraction, crops and recogniser inputs run in `compute` isolates. Only the model
   calls stay on the main isolate (the plugin needs it).
4. **Platform thread opt-out.** Flutter 3.35 runs the Android platform thread and the Dart
   UI thread as one, and the plugin runs inference on the platform thread, so every
   model call froze the UI. `AndroidManifest.xml` sets
   `io.flutter.embedding.android.DisableMergedPlatformUIThread` to `true` (ruled
   2026-10-19). Revisit when Flutter removes the flag.
5. **Threads.** The session sets `intraOpNumThreads: 4`. ONNX Runtime's default may
   already use all cores; the profile decides whether the explicit value stays.
6. **Measured, not assumed.** `app/integration_test/receipt_ocr_profile_test.dart` prints
   per-stage timings. Target on the emulator: warm total ≤ 11.4 s (half the 22.9 s
   baseline). The phone measurement is pending a connected device.

### Queue

7. **One app-wide `ReceiptQueue`** (`services/receipt_queue.dart`, a `ChangeNotifier`),
   so reading continues when the user changes tabs. "Background" means while the app
   process runs; there is no OS background job. Reads are sequential, oldest first.
8. **Files are the queue.** Directory `<app cache>/receipt_queue/`. A photo waiting to be
   read is `<id>.jpg`; a read receipt waiting for review is `<id>.json`. On read success
   the JSON is written, then the photo is deleted. On app start, leftover photos resume
   reading and leftover JSON files are ready to review (ruled 2026-10-19: cache-dir JSON).
   The OS may purge the cache; that loses only unreviewed receipts.
9. **What a ready receipt keeps:** `{id, createdAt, ocrText, items}` where `ocrText` is
   `receiptItemRegion(fullText)` and `items` is `mergeReceiptItems(parseReceiptText(fullText))`.
10. **A failed read** deletes the photo, writes nothing, and counts toward a
    "couldn't be read" notice with a Dismiss control (ruled 2026-10-19). The count is not
    persisted.
11. **Scanning never blocks.** "Scan receipt" stays enabled while reading. Camera adds one
    photo; Gallery allows picking several. Each picked file is copied into the queue and
    the picker's own copy is deleted.
12. **Review from the card.** "Review" opens the oldest ready receipt in the existing
    `ReceiptReviewScreen`. Save removes it from the queue and reloads the pantry. Back
    keeps it ready. A new **Discard** control on the review screen (shown only when
    opened from the queue) removes it without saving.
13. **The Kitchen tab is phase 2.** Phase 1 shows the queue on the existing pantry card.

## Acceptance criteria (Given / When / Then)

**Model and decoding**

1. **AC1** — Given the original and converted recognisers and seeded inputs of shapes
   `[1,3,48,320]`, `[3,3,48,320]` and `[2,3,48,640]`, When both run, Then `idx` equals argmax of the original output and `maxp` equals its max for
   every step (script exits non-zero otherwise).
2. **AC2** — Given the AC8 reference fixture (`receipt_scan` spec), When
   `ctcDecodeArgmax(idx, maxp, chars)` runs per box, Then text and score equal
   `ctcDecode` on the full scores for every box.
3. **AC3** — Given crops of widths `[100, 700, 320, 500]` (after resize to 48 high), When
   batched with size 2, Then batches are `{100→320, 320→320}` padded to 320 and
   `{500, 700}` padded to 700, padding is 0.0, and results map back to the input order.
4. **AC4** — Given the reference fixture and a fake runner, When the pipeline runs with
   batching, Then the text lines equal the reference lines (AC8 kept green).

**On device** (`flutter drive --profile`, inputs over `adb reverse`)

5. **AC5** — Synthetic receipt still reads exactly the five reference lines.
6. **AC6** — Private receipt: parser finds ≥ 90% of expected items, and no fewer than
   before the change.
7. **AC7** — Profile warm total ≤ 11.4 s on the emulator.

**Queue (`services/receipt_queue.dart`)**

8. **AC8** — Given an empty queue, When a photo is added, Then `<id>.jpg` exists and
   `readingCount` is 1; When the read completes, Then `<id>.json` exists, the photo is
   gone, `readingCount` is 0, and `ready` holds one receipt with merged items.
9. **AC9** — Given the Hannaford lines, When read, Then the ready `ocrText` ends at
   `BALANCE DUE 16.08` and contains no `VISA` line.
10. **AC10** — Given three photos added at once, Then the reader runs one at a time, in the
    order added.
11. **AC11** — Given the reader throws, Then the photo is deleted, no JSON is written,
    `failedCount` is 1, and `dismissFailed()` sets it to 0.
12. **AC12** — Given a queue directory holding `a.jpg`, `b.json`, and a malformed `c.json`,
    When the queue starts, Then `b` is ready, `a` is read, and `c.json` is deleted.
13. **AC13** — Given a ready receipt, When `remove(id)` runs, Then its JSON is deleted and
    it leaves `ready`.

**Pantry card and review**

14. **AC14** — Given 2 reading and 1 ready, Then `receipt-queue-status` reads
    `2 reading… · 1 ready to review` and `btn-receipt-review-next` is shown; with 0 ready
    the review button is absent; with nothing queued the status is absent.
15. **AC15** — While a receipt is reading, `btn-scan-receipt` stays enabled; picking two
    gallery photos queues two.
16. **AC16** — Tapping `btn-receipt-review-next` opens the oldest ready receipt; Save
    removes it from the queue and reloads the pantry; Back keeps it ready.
17. **AC17** — `btn-receipt-discard` appears only when review is opened from the queue;
    tapping it pops `false`, saves nothing, and removes the receipt from the queue.
18. **AC18** — Given a failed read, Then `receipt-queue-failed` shows
    `1 receipt couldn't be read` and `btn-receipt-failed-dismiss` hides it.

## Anchors (explore rig)

- `receipt-queue-status` — reading / ready counts on the pantry card
- `btn-receipt-review-next` — opens the oldest ready receipt
- `receipt-queue-failed` — "couldn't be read" notice
- `btn-receipt-failed-dismiss` — hides the notice
- `btn-receipt-discard` — discards a queued receipt from the review screen
- unchanged: `btn-scan-receipt`, `pantry-card`, `receipt-review-screen`

## Verifies-with

- Script: `scripts/ocr_rec_argmax.py` (self-check, AC1)
- Unit: `app/test/models/receipt_ocr_test.dart` (AC2–AC4),
  `app/test/services/receipt_queue_test.dart` (AC8–AC13)
- Widgets: `app/test/widgets/pantry_card_test.dart` (AC14–AC16, AC18),
  `app/test/widgets/receipt_review_screen_test.dart` (AC17)
- Device: `app/integration_test/receipt_ocr_test.dart` (AC5, AC6),
  `app/integration_test/receipt_ocr_profile_test.dart` (AC7)

## Measurements (x86_64 emulator, same 46-line receipt, warm)

| Stage | Before | After |
| --- | --- | --- |
| Total | 22.9 s | 9.6 s |
| Detector | 3.1 s | 1.7 s |
| Recogniser | 15.5 s (100 calls, 317 MB out) | 2.4 s (13 calls, < 0.1 MB out) |
| Dart pre/post-processing | 4.3 s | 5.5 s (now off the UI isolate) |

Synthetic receipt exact; real receipt 21/21 items, as before. Dart work is now the
largest stage — the image is copied into two `compute` isolates. Next lever if needed:
one long-lived isolate that holds the decoded image. Phone numbers pending a device.
