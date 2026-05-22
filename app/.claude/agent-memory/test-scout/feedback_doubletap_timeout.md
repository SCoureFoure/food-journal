---
name: feedback_doubletap_timeout
description: Tapping a GestureDetector(onTap:) nested inside GestureDetector(onDoubleTap:) requires pumping past kDoubleTapTimeout (300ms) before the callback fires in tests
metadata:
  type: feedback
---

`FoodItemCard` wraps the entire card in `GestureDetector(onDoubleTap: onToggleFavorite)` when `onToggleFavorite != null`. The heart icon has its own inner `GestureDetector(onTap: onToggleFavorite)`. Flutter's gesture arena cannot resolve which recogniser wins until the double-tap timeout (300 ms) elapses without a second tap — `pumpAndSettle` exits as soon as there are no pending frames, which happens before that timer fires.

**Pattern:** After `tester.tap(heartSem)`, pump 310 ms then one more frame:
```dart
await tester.tap(heartSem);
await tester.pump(const Duration(milliseconds: 310)); // > kDoubleTapTimeout
await tester.pump();                                  // let setState rebuild
await tester.pumpAndSettle();                         // clear any remaining frames
```

**Why:** `kDoubleTapTimeout` is defined in `package:flutter/gestures.dart` as 300 ms. The extra 10 ms guards against floating-point boundary effects.

**How to apply:** Any widget test that taps a single-tap target inside a double-tap wrapper must use this pattern. Look for `GestureDetector(onDoubleTap:)` in the widget tree — if present, `pumpAndSettle` alone after a tap will silently leave the callback un-fired and the assertion will see stale state.

See: [[feedback_fake_storage_pattern]]
