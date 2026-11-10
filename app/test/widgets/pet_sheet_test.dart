import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pet_feed.dart';
import 'package:food_journal/widgets/goal_fill_bar.dart';
import 'package:food_journal/widgets/pet/pet_sheet.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

// bySemanticsIdentifier does not work in widget tests (semantics tree not built),
// so anchors are found on the declared Semantics widget.
Finder _id(String id) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.identifier == id);

void main() {
  group('[MFT] PetSheet — anchors and labels', () {
    testWidgets('renders sheet, both meter anchors, and value texts', (tester) async {
      // testTheory: minimum functionality — the sheet shows both meters with their values.
      // contract: anchors pet-sheet, pet-meter-food, pet-meter-water present; texts
      //   "2 / 3 meals", "32 / 64 oz", "Your pet" present.
      // implication: AC6 — the pet sheet reports food and water progress.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_id('pet-sheet'), findsOneWidget);
      expect(_id('pet-meter-food'), findsOneWidget);
      expect(_id('pet-meter-water'), findsOneWidget);
      expect(find.text('2 / 3 meals'), findsOneWidget);
      expect(find.text('32 / 64 oz'), findsOneWidget);
      expect(find.text('Your pet'), findsOneWidget);
    });
  });

  group('[BVA] PetSheet — food over target', () {
    testWidgets('4 meals shows "4 / 3 meals" and fill widthFactor 1.0', (tester) async {
      // testTheory: boundary value — food count above the meals-per-day target.
      // contract: text "4 / 3 meals"; food FractionallySizedBox widthFactor == 1.0.
      // implication: AC6 — over-eating shows the real count and the bar stays within its track.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('4 / 3 meals'), findsOneWidget);
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(
          of: _id('pet-meter-food'),
          matching: find.byType(FractionallySizedBox),
        ),
      );
      expect(fill.widthFactor, 1.0);
    });
  });

  group('[INV] PetSheet — food colour neutral over target', () {
    testWidgets('food fill colour is greenFill at 1 and at 4 meals', (tester) async {
      // testTheory: invariance — food fill colour does not change with the count.
      // contract: food fill ColoredBox colour == GoalFillBar.greenFill for mealsToday 1 and 4.
      // implication: AC6 — the food meter has no warning colour over 3 meals.
      Finder foodFill() => find.descendant(
            of: _id('pet-meter-food'),
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == GoalFillBar.greenFill,
            ),
          );

      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 1, waterMl: 0, waterGoalMl: 1893),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(foodFill(), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(foodFill(), findsOneWidget);
    });
  });

  group('[MFT] showPetSheet — modal entry point', () {
    testWidgets('tapping open shows the pet sheet with food count', (tester) async {
      // testTheory: minimum functionality — the helper opens a modal sheet with the feed.
      // contract: showPetSheet(ctx, PetFeed(mealsToday: 1, ...)) → pet-sheet found,
      //   text "1 / 3 meals" found.
      // implication: AC6 — the pet sheet is reachable from the app and shows current feed.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showPetSheet(
                ctx,
                const PetFeed(mealsToday: 1, waterMl: 0, waterGoalMl: 1893),
                animateBars: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(_id('pet-sheet'), findsOneWidget);
      expect(find.text('1 / 3 meals'), findsOneWidget);
    });
  });

  group('[MFT] PetSheet — water target conversion', () {
    testWidgets('2366 ml goal shows "0 / 80 oz"', (tester) async {
      // testTheory: minimum functionality — water goal converts ml to oz for display.
      // contract: waterGoalMl 2366 → target 80 oz; waterMl 0 → current 0; text "0 / 80 oz".
      // implication: AC6 — the water meter uses the same oz unit as the goal panel.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 2366),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('0 / 80 oz'), findsOneWidget);
    });
  });
}
