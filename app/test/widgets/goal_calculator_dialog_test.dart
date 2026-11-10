import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/goal_estimate.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/widgets/home/goal_calculator_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder id(String identifier) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == identifier,
      );

  Finder fieldOf(String input) => find.descendant(
        of: id('field-calc-$input'),
        matching: find.byType(TextField),
      );

  String fieldText(WidgetTester tester, String input) =>
      tester.widget<TextField>(fieldOf(input)).controller!.text;

  const ac13Result = DailyGoals(calories: 2263, proteinG: 144, carbsG: 253, fatG: 75);
  const ac13Line = '2263 kcal · protein 144 g · carbs 253 g · fat 75 g';

  DailyGoals? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    double? latestWeightLb,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    result = null;
    closed = false;
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => ElevatedButton(
            onPressed: () async {
              result = await showGoalCalculator(c, latestWeightLb: latestWeightLb);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String input, String label) async {
    await tester.tap(id('field-calc-$input'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    String? weight,
    String? ft,
    String? inch,
    String? age,
    String? formula,
    String? activity,
    String? goal,
  }) async {
    if (weight != null) await tester.enterText(fieldOf('weight'), weight);
    if (ft != null) await tester.enterText(fieldOf('height-ft'), ft);
    if (inch != null) await tester.enterText(fieldOf('height-in'), inch);
    if (age != null) await tester.enterText(fieldOf('age'), age);
    await tester.pumpAndSettle();
    if (formula != null) await pick(tester, 'formula', formula);
    if (activity != null) await pick(tester, 'activity', activity);
    if (goal != null) await pick(tester, 'goal', goal);
  }

  Future<void> fillAc13(WidgetTester tester, {String age = '30'}) => fill(
        tester,
        weight: '180',
        ft: '5',
        inch: '10',
        age: age,
        formula: 'Male formula',
        activity: 'Moderate (3–5 days a week)',
        goal: 'Lose 1 lb a week',
      );

  Future<void> apply(WidgetTester tester) async {
    await tester.tap(find.descendant(of: id('btn-calc-apply'), matching: find.text('Use these')));
    await tester.pumpAndSettle();
  }

  /// [MFT] Goal calculator estimate — holds the contract that the live result
  /// matches the Mifflin-St Jeor estimate and Use these pops it.
  /// If this regresses: users get wrong targets or an empty/missing prompt.
  group('[MFT] GoalCalculatorDialog estimate', () {
    testWidgets('AC13: 180 lb, 5\'10", 30, male, moderate, lose 1 lb', (tester) async {
      // testTheory: MFT
      // contract: known inputs produce exactly the spec'd estimate and pop it
      // implication: calculator math or wiring is broken
      await open(tester);
      await fillAc13(tester);

      expect(find.text(ac13Line), findsOneWidget);

      await apply(tester);

      expect(result, ac13Result);
      expect(closed, isTrue);
      expect(id('goal-calculator-dialog'), findsNothing);
    });

    testWidgets('incomplete form shows the fill-in prompt', (tester) async {
      // testTheory: MFT
      // contract: with no inputs the result line prompts instead of estimating
      // implication: a bogus estimate is shown from blank fields
      await open(tester);

      expect(find.text('Fill in all fields to see an estimate.'), findsOneWidget);
    });
  });

  /// [BVA] Goal calculator validation — age, height and formula bounds.
  /// If this regresses: invalid bodies are estimated or saved.
  group('[BVA] GoalCalculatorDialog validation', () {
    testWidgets('AC17: age 15 is rejected, dialog stays, profile not saved',
        (tester) async {
      // testTheory: BVA
      // contract: age below 18 shows the error and does not close or persist
      // implication: invalid ages pass through or a profile is stored
      await open(tester);
      await fillAc13(tester, age: '15');
      await apply(tester);

      expect(find.text('Enter an age from 18 to 100'), findsOneWidget);
      expect(id('goal-calculator-dialog'), findsOneWidget);
      expect(closed, isFalse);
      expect(await SettingsService().goalProfile, isNull);
    });

    testWidgets('empty height ft is rejected', (tester) async {
      // testTheory: BVA
      // contract: missing feet shows Enter 4–8 ft
      // implication: zero-height bodies are estimated
      await open(tester);
      await fill(
        tester,
        weight: '180',
        age: '30',
        formula: 'Male formula',
      );
      await apply(tester);

      expect(find.text('Enter 4–8 ft'), findsOneWidget);
    });

    testWidgets('no formula picked is rejected', (tester) async {
      // testTheory: BVA
      // contract: formula has no default; applying without one shows Pick a formula
      // implication: the app presumes a formula for the user
      await open(tester);
      await fill(tester, weight: '180', ft: '5', inch: '10', age: '30');
      await apply(tester);

      expect(find.text('Pick a formula'), findsOneWidget);
    });
  });

  /// [INV] Goal calculator cancel — leaves no trace.
  /// If this regresses: cancelling still returns goals or stores a profile.
  group('[INV] GoalCalculatorDialog cancel', () {
    testWidgets('cancel returns null and saves no profile', (tester) async {
      // testTheory: INV
      // contract: Cancel pops null and does not touch the stored profile
      // implication: cancel leaks inputs into goals or settings
      await open(tester);
      await fillAc13(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
      expect(await SettingsService().goalProfile, isNull);
    });
  });

  /// [MFT] Goal calculator memory — body stats are remembered between opens.
  /// If this regresses: users retype height, age and formula every time.
  group('[MFT] GoalCalculatorDialog remembered profile', () {
    testWidgets('AC16: reopening pre-fills the saved profile', (tester) async {
      // testTheory: MFT
      // contract: after one apply, a second open restores height, age, weight, formula
      // implication: profile is not persisted or not read back
      await open(tester);
      await fillAc13(tester);
      await apply(tester);

      // Prefs persist within the mock store; reopen without resetting them.
      result = null;
      closed = false;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'height-ft'), '5');
      expect(fieldText(tester, 'height-in'), '10');
      expect(fieldText(tester, 'age'), '30');
      expect(fieldText(tester, 'weight'), '180');
      expect(
        find.descendant(of: id('goal-calculator-dialog'), matching: find.text('Male formula')),
        findsWidgets,
      );
    });
  });

  /// [DIR] Goal calculator weight source — a fresh logged weight beats the
  /// saved profile weight.
  /// If this regresses: stale weights drive new estimates.
  group('[DIR] GoalCalculatorDialog latest weight', () {
    testWidgets('latestWeightLb overrides the saved profile weight', (tester) async {
      // testTheory: DIR
      // contract: with a logged weight supplied, the weight field shows it, not the saved one
      // implication: estimates use outdated weight
      const saved = GoalProfile(
        weightLb: 200,
        heightIn: 70,
        age: 30,
        formula: BodyFormula.male,
        activity: ActivityLevel.light,
        goal: WeightGoal.maintain,
      );
      await open(
        tester,
        latestWeightLb: 172.5,
        prefs: {'goal_profile': saved.encode()},
      );

      expect(fieldText(tester, 'weight'), '172.5');
    });
  });

  /// [BVA] Goal calculator target weight — optional target validated against
  /// the pace direction and the current weight.
  /// If this regresses: impossible weight goals are saved or targets are dropped.
  group('[BVA] GoalCalculatorDialog target weight', () {
    Future<void> fillWith(WidgetTester tester, String goal, {String? target}) async {
      await fill(
        tester,
        weight: '180',
        ft: '5',
        inch: '10',
        age: '30',
        formula: 'Male formula',
        activity: 'Moderate (3–5 days a week)',
        goal: goal,
      );
      if (target != null) {
        await tester.enterText(fieldOf('target'), target);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('AC21: lose pace with target 170 pops target and direction', (tester) async {
      // testTheory: MFT
      // contract: a valid lose target is returned with lose direction, calories unchanged
      // implication: AC21 weight goal is lost or alters the calorie estimate
      await open(tester);
      await fillWith(tester, 'Lose 1 lb a week', target: '170');
      await apply(tester);

      expect(result?.targetWeightLb, 170.0);
      expect(result?.weightDirection, WeightDirection.lose);
      expect(result?.calories, ac13Result.calories);
    });

    testWidgets('AC21: lose pace with target above weight is rejected', (tester) async {
      // testTheory: BVA
      // contract: lose target 185 at weight 180 shows an error and keeps the dialog open
      // implication: AC21 a lose goal above current weight is accepted
      await open(tester);
      await fillWith(tester, 'Lose 1 lb a week', target: '185');
      await apply(tester);

      expect(find.text('Target must be below your current weight'), findsOneWidget);
      expect(id('goal-calculator-dialog'), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('AC21: gain pace with target below weight is rejected', (tester) async {
      // testTheory: BVA
      // contract: gain target 175 at weight 180 shows an error and keeps the dialog open
      // implication: AC21 a gain goal below current weight is accepted
      await open(tester);
      await fillWith(tester, 'Gain 0.5 lb a week', target: '175');
      await apply(tester);

      expect(find.text('Target must be above your current weight'), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('AC21: maintain pace has no target field and no target result', (tester) async {
      // testTheory: DIR
      // contract: maintain hides the target field and pops a null target
      // implication: AC21 a weight goal is set without a direction
      await open(tester);
      await fillWith(tester, 'Maintain weight');

      expect(id('field-calc-target'), findsNothing);

      await apply(tester);

      expect(result?.targetWeightLb, isNull);
      expect(result?.weightDirection, isNull);
    });

    testWidgets('AC21: empty target pops null target and direction', (tester) async {
      // testTheory: MFT
      // contract: a blank optional target yields no weight goal
      // implication: AC21 blank target is treated as an error or a zero goal
      await open(tester);
      await fillWith(tester, 'Lose 1 lb a week');
      await apply(tester);

      expect(closed, isTrue);
      expect(result?.targetWeightLb, isNull);
      expect(result?.weightDirection, isNull);
    });
  });
}
