---
name: project_ai_integration_flake
description: parse_meal_integration_test shows -1 when the full suite runs concurrently; passes cleanly in isolation
metadata:
  type: project
---

`test/integration/ai/parse_meal_integration_test.dart` reports one failure (`+369 -1`) when the full suite runs with `flutter test --reporter=compact` but passes 12/12 when run alone.

**Why:** The AI integration tests make live network calls to the Cloudflare Worker. When run concurrently with all other test files, one test appears to time out or collide. This is a pre-existing concurrency/network flake — not a code defect.

**How to apply:** When auditing full-suite results, a `-1` confined to `parse_meal_integration_test.dart` that disappears when the file runs in isolation can be ignored. Do not attempt to fix it as a code bug. If it starts failing in isolation, that is a real regression worth investigating.
