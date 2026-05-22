---
name: feedback_fake_storage_pattern
description: How to correctly subclass StorageService for widget tests; named-param signature staleness is a recurring hazard
metadata:
  type: feedback
---

The project uses `_FakeStorage extends StorageService` in widget tests (never Mockito). When `StorageService` adds or changes a named parameter on an overridden method, every lambda passed to the fake's constructor breaks with a type error — the compiler error message points to the call sites, not the override, which is confusing.

**Pattern for `searchFoodHistory`:** The fake field type must be `List<FoodItemDraft> Function(String, bool)` (query + favoritesOnly). All call-site lambdas must be `(_, __) => [...]` or `(q, favOnly) { ... }` — single-param `(_) => [...]` is a compile error.

**Tap chip by Semantics identifier, not by text:** `tester.tap(find.text('All'))` hits the Text child inside a FilterChip and produces a "offset would not hit test" warning. Use `find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == 'btn-history-filter-all')` instead — this hits the chip's gesture area directly.

**Why:** FilterChip wraps its label Text in internal layout nodes; the Text's render offset resolves to inside the chip's material ink layer, not at a tappable coordinate. Tapping the Semantics wrapper avoids this indirection.

**How to apply:** Whenever a new named parameter is added to a StorageService method, immediately grep `test/` for all fake overrides of that method and update their type signatures and call sites in the same commit.
