import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
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
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoalsPanel(goals: goals, intake: intake, onEdit: onEdit ?? () {}),
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
}
