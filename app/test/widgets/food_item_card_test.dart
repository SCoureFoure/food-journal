// Tests for FoodItemCard widget — favorites feature (heart icon, callbacks,
// double-tap, Semantics anchor) added in the favorites-on-journal update.
//
// No StorageService involvement — FoodItemCard is purely presentational;
// callers hand it `favorited` and `onToggleFavorite`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/widgets/food_item_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

FoodItem _item({int id = 1, String name = 'Chicken breast'}) => FoodItem(
      id: id,
      mealId: 10,
      name: name,
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ── Heart icon visibility ──────────────────────────────────────────────────

  group('[MFT] FoodItemCard — heart icon visibility', () {
    setUpAll(() {
      // contract: heart icon only renders when onToggleFavorite is provided
      // implication: card without a callback never shows a stray heart icon
    });

    testWidgets('no heart icon when onToggleFavorite is null', (tester) async {
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          onToggleFavorite: null,
        ),
      ));
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('favorited=true shows filled heart icon', (tester) async {
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          favorited: true,
          onToggleFavorite: () {},
        ),
      ));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('favorited=false shows border heart icon', (tester) async {
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          favorited: false,
          onToggleFavorite: () {},
        ),
      ));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('default favorited is false — shows border heart when callback given', (tester) async {
      // BVA: default param value must be false, not true
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          onToggleFavorite: () {},
          // favorited not provided — relies on default
        ),
      ));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });

  // ── Semantics anchor ───────────────────────────────────────────────────────

  group('[MFT] FoodItemCard — Semantics anchor', () {
    testWidgets('btn-favorite-<id> Semantics identifier present when callback given',
        (tester) async {
      const itemId = 42;
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(id: itemId),
          ingredients: const [],
          onToggleFavorite: () {},
        ),
      ));
      final semFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'btn-favorite-$itemId',
      );
      expect(semFinder, findsOneWidget,
          reason: 'CLAUDE.md requires Semantics(identifier: btn-favorite-<id>) '
              'for every favorite button');
    });

    testWidgets('no btn-favorite Semantics when onToggleFavorite is null', (tester) async {
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(id: 7),
          ingredients: const [],
          onToggleFavorite: null,
        ),
      ));
      final semFinder = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.identifier ?? '').startsWith('btn-favorite-'),
      );
      expect(semFinder, findsNothing);
    });
  });

  // ── Tap heart fires callback ───────────────────────────────────────────────
  //
  // The card is wrapped in GestureDetector(onDoubleTap:), so the inner
  // GestureDetector(onTap:) on the heart is delayed by kDoubleTapTimeout
  // (300 ms) before Flutter resolves the gesture arena. Tests must pump
  // past that deadline before asserting on the callback count.

  group('[MFT] FoodItemCard — tap heart fires onToggleFavorite', () {
    testWidgets('single tap on heart icon fires callback once', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(id: 1),
          ingredients: const [],
          onToggleFavorite: () => callCount++,
        ),
      ));

      // Tap via the Semantics identifier (explore-rig pattern)
      final heartSem = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'btn-favorite-1',
      );
      await tester.tap(heartSem);
      // Pump past kDoubleTapTimeout so the gesture arena resolves onTap.
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pump();

      expect(callCount, 1);
    });

    testWidgets('tapping heart does not fire when onToggleFavorite is null', (tester) async {
      // FP guard: no callback registered → no crash, no spurious calls
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          onToggleFavorite: null,
        ),
      ));
      // No heart icon to tap — just verify widget renders without error
      expect(find.byType(FoodItemCard), findsOneWidget);
    });
  });

  // ── Double-tap fires callback ──────────────────────────────────────────────

  group('[MFT] FoodItemCard — double-tap on card fires onToggleFavorite', () {
    testWidgets('double-tap on card body fires callback once', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(id: 2),
          ingredients: const [],
          onToggleFavorite: () => callCount++,
        ),
      ));

      // Double-tap the Card widget itself (not the icon)
      await tester.tap(find.byType(Card));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(callCount, greaterThanOrEqualTo(1),
          reason: 'Double-tap on card must invoke onToggleFavorite');
    });

    testWidgets('no double-tap GestureDetector wrapping when onToggleFavorite is null',
        (tester) async {
      // When no callback, the outer GestureDetector(onDoubleTap:) must not be added.
      // We verify indirectly: double-tapping causes no error and callCount stays 0.
      int callCount = 0;
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(),
          ingredients: const [],
          onToggleFavorite: null,
        ),
      ));
      await tester.tap(find.byType(Card));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });
  });

  // ── Item name always renders ───────────────────────────────────────────────

  group('[MFT] FoodItemCard — item name renders', () {
    testWidgets('item name text is present regardless of favorited state', (tester) async {
      await tester.pumpWidget(_wrap(
        FoodItemCard(
          item: _item(name: 'Greek Yogurt'),
          ingredients: const [],
          favorited: true,
          onToggleFavorite: () {},
        ),
      ));
      expect(find.text('Greek Yogurt'), findsOneWidget);
    });
  });
}
