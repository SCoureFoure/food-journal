import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/weight_goal.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/widgets/home/goals_panel.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Anchors are found on the declared `Semantics` widget — the semantics tree
  // is not built in widget tests.
  Finder anchor(String id) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      );

  // GoalFillBar animates forever, so never pumpAndSettle while bars are shown.
  Future<void> pumpPanel(
    WidgetTester tester, {
    required DailyGoals goals,
    GoalIntake intake = const GoalIntake(),
    VoidCallback? onEdit,
    WeightGoalMet? weightGoalMet,
    VoidCallback? onNewWeightGoal,
    VoidCallback? onDismissWeightGoal,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoalsPanel(
            goals: goals,
            intake: intake,
            onEdit: onEdit ?? () {},
            weightGoalMet: weightGoalMet,
            onNewWeightGoal: onNewWeightGoal,
            onDismissWeightGoal: onDismissWeightGoal,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// [MFT] GoalsPanel renders one bar per set target — holds the contract that
  /// null targets are hidden and set targets show `current / target unit`
  /// (water in oz).
  /// If this regresses: unset metrics show empty bars, or water shows raw ml.
  group('[MFT] GoalsPanel rows', () {
    testWidgets('AC6/AC12: only set targets render, with intake text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(
        tester,
        goals: const DailyGoals(calories: 2000, waterMl: 2366),
        intake: const GoalIntake(calories: 1450, waterMl: 1000),
      );

      expect(anchor('goal-row-calories'), findsOneWidget);
      expect(anchor('goal-row-water'), findsOneWidget);
      expect(anchor('goal-row-protein'), findsNothing);
      expect(anchor('goal-row-carbs'), findsNothing);
      expect(anchor('goal-row-fat'), findsNothing);
      expect(find.text('1450 / 2000 kcal'), findsOneWidget);
      expect(find.text('34 / 80 oz'), findsOneWidget);
    });

    testWidgets('rows appear in order calories, protein, carbs, fat, water',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(
        tester,
        goals: const DailyGoals(
          calories: 2000,
          proteinG: 140,
          carbsG: 200,
          fatG: 70,
          waterMl: 2366,
        ),
      );

      final ys = ['calories', 'protein', 'carbs', 'fat', 'water']
          .map((m) => tester.getTopLeft(anchor('goal-row-$m')).dy)
          .toList();
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
    });

    testWidgets('subtitle shows calories progress when calories set', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(
        tester,
        goals: const DailyGoals(calories: 2000),
        intake: const GoalIntake(calories: 1450),
      );

      expect(find.text('1450 / 2000 kcal today'), findsOneWidget);
    });
  });

  /// [BVA] GoalsPanel empty vs set state — holds the contract that
  /// `goals.isEmpty` alone picks between the Set-goals prompt and the bars.
  /// If this regresses: an empty panel shows an Edit button with no bars, or
  /// the user has no way to set a first goal.
  group('[BVA] GoalsPanel empty state', () {
    testWidgets('AC7: DailyGoals.none shows Set goals only', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(tester, goals: DailyGoals.none);

      expect(anchor('btn-set-goals'), findsOneWidget);
      for (final m in ['calories', 'protein', 'carbs', 'fat', 'water']) {
        expect(anchor('goal-row-$m'), findsNothing);
      }
      expect(anchor('btn-edit-goals'), findsNothing);
      expect(find.text('No goals set'), findsOneWidget);
    });
  });

  /// [MFT] GoalsPanel edit entry points — both buttons delegate to onEdit.
  /// If this regresses: the host never opens the dialog.
  group('[MFT] GoalsPanel onEdit', () {
    testWidgets('btn-edit-goals calls onEdit once', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var edits = 0;
      await pumpPanel(
        tester,
        goals: const DailyGoals(calories: 2000),
        onEdit: () => edits++,
      );

      await tester.tap(find.descendant(of: anchor('btn-edit-goals'), matching: find.text('Edit')));
      await tester.pump();
      expect(edits, 1);
    });

    testWidgets('btn-set-goals calls onEdit once', (tester) async {
      SharedPreferences.setMockInitialValues({});
      var edits = 0;
      await pumpPanel(tester, goals: DailyGoals.none, onEdit: () => edits++);

      await tester.tap(
          find.descendant(of: anchor('btn-set-goals'), matching: find.text('Set goals')));
      await tester.pump();
      expect(edits, 1);
    });
  });

  /// [INV] / [DIR] GoalsPanel collapse persistence — the saved
  /// `card_collapsed_goals` flag decides the initial state, and toggling the
  /// header writes it back.
  /// If this regresses: the panel ignores or forgets the user's collapse choice.
  group('[INV] GoalsPanel collapse persistence', () {
    testWidgets('AC9: saved collapsed flag builds the panel collapsed', (tester) async {
      SharedPreferences.setMockInitialValues({'card_collapsed_goals': true});
      await pumpPanel(tester, goals: const DailyGoals(calories: 2000));

      expect(anchor('goal-row-calories'), findsNothing);
      expect(anchor('item-header-goals'), findsOneWidget);
    });

    testWidgets('AC9: collapsing the header persists the flag', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(tester, goals: const DailyGoals(calories: 2000));

      await tester.tap(anchor('item-header-goals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('card_collapsed_goals'), isTrue);
    });
  });

  /// [MFT] GoalsPanel animateBars — the flag selects still vs wavy bars for
  /// every set target.
  /// If this regresses: the moving-bars setting has no effect on the panel.
  group('[MFT] GoalsPanel — animateBars', () {
    testWidgets('animateBars: false draws still fills, no liquid wave', (tester) async {
      // testTheory: minimum functionality — still flag reaches each GoalFillBar.
      // contract: animateBars false with calories + protein → no LiquidLinearProgressIndicator;
      //   two FractionallySizedBox fills.
      // implication: S8 — turning off moving bars stills every goal bar in the panel.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoalsPanel(
              goals: const DailyGoals(calories: 2000, proteinG: 140),
              intake: const GoalIntake(calories: 1450),
              onEdit: () {},
              animateBars: false,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LiquidLinearProgressIndicator), findsNothing);
      expect(find.byType(FractionallySizedBox), findsNWidgets(2));
    });

    testWidgets('default animateBars keeps a liquid wave per set target', (tester) async {
      // testTheory: invariance — omitting the flag leaves the panel wavy.
      // contract: default → LiquidLinearProgressIndicator findsNWidgets(2) for two targets.
      // implication: S8 — default ON, existing look preserved.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GoalsPanel(
              goals: const DailyGoals(calories: 2000, proteinG: 140),
              intake: const GoalIntake(calories: 1450),
              onEdit: () {},
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(LiquidLinearProgressIndicator), findsNWidgets(2));
    });
  });

  /// [MFT] GoalsPanel weight-goal prompt — a non-null weightGoalMet shows the
  /// "You reached" prompt with both buttons wired to their callbacks (AC25).
  /// If this regresses: a met weight goal is silent, or its buttons do nothing.
  group('[MFT] GoalsPanel weight-goal prompt', () {
    testWidgets('AC25: prompt shows target text and both buttons call their callback once',
        (tester) async {
      // testTheory: minimum functionality — prompt text and both buttons are wired.
      // contract: weightGoalMet 170 lb → anchor goal-weight-met with text
      //   "You reached 170 lb! Set a new goal?"; each button calls its callback once.
      // implication: AC25 — a reached weight goal offers "Set new goal" and "Not now".
      SharedPreferences.setMockInitialValues({});
      var newGoal = 0;
      var later = 0;
      await pumpPanel(
        tester,
        goals: const DailyGoals(calories: 2000),
        weightGoalMet: const WeightGoalMet(
          targetWeightLb: 170,
          direction: WeightDirection.lose,
        ),
        onNewWeightGoal: () => newGoal++,
        onDismissWeightGoal: () => later++,
      );

      expect(anchor('goal-weight-met'), findsOneWidget);
      expect(find.text('You reached 170 lb! Set a new goal?'), findsOneWidget);

      await tester.tap(find.descendant(
          of: anchor('btn-weight-goal-new'), matching: find.text('Set new goal')));
      await tester.pump();
      expect(newGoal, 1);
      expect(later, 0);

      await tester.tap(find.descendant(
          of: anchor('btn-weight-goal-later'), matching: find.text('Not now')));
      await tester.pump();
      expect(later, 1);
      expect(newGoal, 1);
    });
  });

  /// [BVA] GoalsPanel weight-goal prompt absence — null weightGoalMet shows no
  /// prompt (AC25).
  /// If this regresses: the prompt nags users who have no reached goal.
  group('[BVA] GoalsPanel weight-goal prompt absence', () {
    testWidgets('AC25: null weightGoalMet shows no goal-weight-met anchor', (tester) async {
      // testTheory: boundary — the null edge hides the prompt entirely.
      // contract: weightGoalMet null → anchor goal-weight-met findsNothing.
      // implication: AC25 — the prompt appears only when a weigh-in reaches the target.
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(tester, goals: const DailyGoals(calories: 2000));

      expect(anchor('goal-weight-met'), findsNothing);
      expect(anchor('btn-weight-goal-new'), findsNothing);
      expect(anchor('btn-weight-goal-later'), findsNothing);
    });
  });

  /// [DIR] GoalsPanel weight-goal prompt when collapsed — the prompt sits above
  /// the header, so collapsing the Goals card does not hide it (AC25).
  /// If this regresses: the prompt disappears with the panel body.
  group('[DIR] GoalsPanel weight-goal prompt collapsed', () {
    testWidgets('AC25: prompt still shown after collapsing the header', (tester) async {
      // testTheory: directional — collapsing changes only the body, not the prompt.
      // contract: tap item-header-goals → goal-weight-met still findsOneWidget.
      // implication: AC25 — the reached-goal prompt is visible whether collapsed or expanded.
      SharedPreferences.setMockInitialValues({});
      await pumpPanel(
        tester,
        goals: const DailyGoals(calories: 2000),
        weightGoalMet: const WeightGoalMet(
          targetWeightLb: 170,
          direction: WeightDirection.lose,
        ),
        onNewWeightGoal: () {},
        onDismissWeightGoal: () {},
      );

      await tester.tap(anchor('item-header-goals'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(anchor('goal-row-calories'), findsNothing);
      expect(anchor('goal-weight-met'), findsOneWidget);
    });
  });

  /// [INV] SettingsService weight-goal dismissed log id — a stored id round-trips
  /// and defaults to null (AC25).
  /// If this regresses: a dismissed prompt cannot be remembered, or reappears
  /// with no stored id.
  group('[INV] SettingsService weight-goal dismissed log id', () {
    test('AC25: set 7 then read 7; default is null', () async {
      // testTheory: invariance — round-trip through SharedPreferences preserves the id.
      // contract: fresh prefs → null; setWeightGoalDismissedLogId(7) → 7.
      // implication: AC25 — "Not now" persists the dismissed weigh-in so the prompt stays hidden.
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();

      expect(await settings.weightGoalDismissedLogId, isNull);
      await settings.setWeightGoalDismissedLogId(7);
      expect(await settings.weightGoalDismissedLogId, 7);
    });
  });
}
