import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/widgets/home/edit_goals_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Finder anchor(String id) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == id,
      );

  Finder fieldOf(String metric) => find.descendant(
        of: anchor('field-goal-$metric'),
        matching: find.byType(TextField),
      );

  String fieldText(WidgetTester tester, String metric) =>
      tester.widget<TextField>(fieldOf(metric)).controller!.text;

  DailyGoals? result;
  var closed = false;

  Future<void> openDialog(WidgetTester tester, DailyGoals initial) async {
    SharedPreferences.setMockInitialValues({});
    result = null;
    closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showEditGoalsDialog(context, initial);
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

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.descendant(of: anchor('btn-save-goals'), matching: find.text('Save')));
    await tester.pumpAndSettle();
  }

  /// [MFT] EditGoalsDialog pre-fill — holds the contract that existing
  /// targets show in the fields, with water converted ml -> oz.
  /// If this regresses: opening the editor wipes or mis-scales saved goals.
  group('[MFT] EditGoalsDialog pre-fill', () {
    testWidgets('fields show current targets, water in oz', (tester) async {
      await openDialog(
          tester, const DailyGoals(calories: 2000, proteinG: 140, waterMl: 1893));

      expect(fieldText(tester, 'calories'), '2000');
      expect(fieldText(tester, 'protein'), '140');
      expect(fieldText(tester, 'carbs'), '');
      expect(fieldText(tester, 'fat'), '');
      expect(fieldText(tester, 'water'), '64');
    });
  });

  /// [MFT] EditGoalsDialog save — holds the contract that Save pops the
  /// edited targets, empty = cleared, water oz -> ml.
  /// If this regresses: edits are lost or stored in the wrong unit.
  group('[MFT] EditGoalsDialog save', () {
    testWidgets('AC8: clearing calories and adding fat pops the new goals',
        (tester) async {
      await openDialog(
          tester, const DailyGoals(calories: 2000, proteinG: 140, waterMl: 1893));

      await tester.enterText(fieldOf('calories'), '');
      await tester.enterText(fieldOf('fat'), '70');
      await save(tester);

      expect(closed, isTrue);
      expect(result, const DailyGoals(proteinG: 140, fatG: 70, waterMl: 1893));
    });

    testWidgets('Cancel closes with null', (tester) async {
      await openDialog(tester, const DailyGoals(calories: 2000));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });
  });

  /// [BVA] EditGoalsDialog boundaries — water conversion, zero rejection, and
  /// the all-empty clear.
  /// If this regresses: oz are stored as ml, zero targets are saved, or users
  /// cannot clear every goal.
  group('[BVA] EditGoalsDialog boundaries', () {
    testWidgets('80 oz saves as 2366 ml', (tester) async {
      await openDialog(tester, DailyGoals.none);

      await tester.enterText(fieldOf('water'), '80');
      await save(tester);

      expect(result!.waterMl, 2366);
    });

    testWidgets('0 calories is rejected and the dialog stays open', (tester) async {
      await openDialog(tester, DailyGoals.none);

      await tester.enterText(fieldOf('calories'), '0');
      await save(tester);

      expect(find.text('Enter a number above 0'), findsOneWidget);
      expect(anchor('edit-goals-dialog'), findsOneWidget);
      expect(closed, isFalse);
    });

    testWidgets('all fields empty saves DailyGoals.none', (tester) async {
      await openDialog(tester, const DailyGoals(calories: 2000, waterMl: 1893));

      await tester.enterText(fieldOf('calories'), '');
      await tester.enterText(fieldOf('water'), '');
      await save(tester);

      expect(closed, isTrue);
      expect(result, DailyGoals.none);
    });
  });

  /// [INV] AC15 calculator pre-fills only — the calculator fills calorie and
  /// macro fields, leaves water alone, and never saves.
  /// If this regresses: the calculator overwrites water or closes/saves the dialog.
  group('[INV] AC15 calculator pre-fills only', () {
    testWidgets('Use these fills macros, keeps water, edit dialog stays open',
        (tester) async {
      // testTheory: INV
      // contract: calculator result lands in fields; water and pending state unchanged
      // implication: goals are saved without the user pressing Save, or water is clobbered
      Finder calc(String input) => find.descendant(
            of: anchor('field-calc-$input'),
            matching: find.byType(TextField),
          );
      Future<void> pick(String input, String label) async {
        await tester.tap(anchor('field-calc-$input'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await openDialog(tester, const DailyGoals(waterMl: 2366));
      expect(fieldText(tester, 'water'), '80');

      await tester.tap(anchor('btn-calc-goals'));
      await tester.pumpAndSettle();

      await tester.enterText(calc('weight'), '180');
      await tester.enterText(calc('height-ft'), '5');
      await tester.enterText(calc('height-in'), '10');
      await tester.enterText(calc('age'), '30');
      await tester.pumpAndSettle();
      await pick('formula', 'Male formula');
      await pick('activity', 'Moderate (3–5 days a week)');
      await pick('goal', 'Lose 1 lb a week');

      await tester.tap(find.descendant(of: anchor('btn-calc-apply'), matching: find.text('Use these')));
      await tester.pumpAndSettle();

      expect(fieldText(tester, 'calories'), '2263');
      expect(fieldText(tester, 'protein'), '144');
      expect(fieldText(tester, 'carbs'), '253');
      expect(fieldText(tester, 'fat'), '75');
      expect(fieldText(tester, 'water'), '80');
      expect(anchor('edit-goals-dialog'), findsOneWidget);
      expect(closed, isFalse);
    });
  });
}
