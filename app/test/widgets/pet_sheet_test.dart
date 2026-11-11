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
    testWidgets('renders sheet, meter anchors, kcal and oz value texts', (tester) async {
      // testTheory: minimum functionality — the sheet shows the food and water meters with their values.
      // contract: anchors pet-sheet, pet-meter-food, pet-meter-water present once each; texts
      //   "1450 / 2000 kcal", "32 / 64 oz", "Your pet" present; btn-pet-set-goal absent.
      // implication: AC6 — the pet sheet reports food (kcal) and water progress; no goal prompt when a goal is set.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 1450, calorieGoal: 2000),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_id('pet-sheet'), findsOneWidget);
      expect(_id('pet-meter-food'), findsOneWidget);
      expect(_id('pet-meter-water'), findsOneWidget);
      expect(_id('btn-pet-set-goal'), findsNothing);
      expect(find.text('1450 / 2000 kcal'), findsOneWidget);
      expect(find.text('32 / 64 oz'), findsOneWidget);
      expect(find.text('Your pet'), findsOneWidget);
    });
  });

  group('[BVA] PetSheet — food over target', () {
    testWidgets('2150 kcal over 2000 goal shows "2150 / 2000 kcal" and fill widthFactor 1.0', (tester) async {
      // testTheory: boundary value — calories above the calorie goal.
      // contract: text "2150 / 2000 kcal"; food FractionallySizedBox widthFactor == 1.0.
      // implication: AC6 — over-eating shows the real kcal and the bar stays within its track.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893, caloriesToday: 2150, calorieGoal: 2000),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('2150 / 2000 kcal'), findsOneWidget);
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
    testWidgets('food fill colour is greenFill at 1450 and at 2150 kcal', (tester) async {
      // testTheory: invariance — food fill colour does not change with the calorie count.
      // contract: food fill ColoredBox colour == GoalFillBar.greenFill at 1450/2000 and 2150/2000.
      // implication: AC6 — the food meter has no warning colour when over the calorie goal.
      Finder foodFill() => find.descendant(
            of: _id('pet-meter-food'),
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == GoalFillBar.greenFill,
            ),
          );

      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 2, waterMl: 0, waterGoalMl: 1893, caloriesToday: 1450, calorieGoal: 2000),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(foodFill(), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893, caloriesToday: 2150, calorieGoal: 2000),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(foodFill(), findsOneWidget);
    });
  });

  group('[MFT] PetSheet — no calorie goal', () {
    testWidgets('shows "650 kcal today" and the set-goal button, over an empty food bar', (tester) async {
      // testTheory: minimum functionality — without a calorie goal the food row shows the day's total and a goal prompt.
      // contract: text "650 kcal today" inside pet-meter-food; btn-pet-set-goal found; food fill
      //   FractionallySizedBox under pet-meter-food has widthFactor 0.0 (empty GoalFillBar track).
      // implication: AC10 — with no goal the food meter is an empty bar reading the day's total, and the user is offered a way to set one.
      await tester.pumpWidget(_wrap(
        PetSheet(
          feed: const PetFeed(mealsToday: 1, waterMl: 0, waterGoalMl: 1893, caloriesToday: 650),
          animateBars: false,
          onSetGoal: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: _id('pet-meter-food'), matching: find.text('650 kcal today')),
        findsOneWidget,
      );
      expect(_id('btn-pet-set-goal'), findsOneWidget);
      final fill = tester.widget<FractionallySizedBox>(
        find.descendant(of: _id('pet-meter-food'), matching: find.byType(FractionallySizedBox)),
      );
      expect(fill.widthFactor, 0.0);
    });
  });

  group('[INV] PetSheet — no calorie goal, no callback', () {
    testWidgets('btn-pet-set-goal is absent when onSetGoal is null', (tester) async {
      // testTheory: invariance — the goal prompt appears only when a handler is supplied.
      // contract: no calorieGoal and onSetGoal null → btn-pet-set-goal findsNothing.
      // implication: AC10 — the sheet never renders a dead "Set a calorie goal" button.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893, caloriesToday: 650),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_id('btn-pet-set-goal'), findsNothing);
    });
  });

  group('[DIR] showPetSheet — set-goal callback', () {
    testWidgets('tapping "Set a calorie goal" closes the sheet and calls onSetGoal once', (tester) async {
      // testTheory: directional — the button's effect is to close the sheet and invoke the handler.
      // contract: showPetSheet(ctx, <no-goal feed>, onSetGoal: () => calls++); tap open, tap "Set a calorie goal"
      //   → calls == 1 and pet-sheet findsNothing.
      // implication: AC10 — the prompt hands off to the edit-goals dialog from a closed sheet.
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => showPetSheet(
                ctx,
                const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893, caloriesToday: 650),
                animateBars: false,
                onSetGoal: () => calls++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set a calorie goal'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(_id('pet-sheet'), findsNothing);
    });
  });

  group('[MFT] PetSheet — water target conversion', () {
    testWidgets('2366 ml goal shows "0 / 80 oz"', (tester) async {
      // testTheory: minimum functionality — water goal converts ml to oz for display.
      // contract: waterGoalMl 2366 → target 80 oz; waterMl 0 → current 0; text "0 / 80 oz".
      // implication: AC6 — the water meter uses the same oz unit as the goal panel.
      await tester.pumpWidget(_wrap(
        const PetSheet(
          feed: PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 2366, caloriesToday: 0, calorieGoal: 2000),
          animateBars: false,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('0 / 80 oz'), findsOneWidget);
    });
  });
}
