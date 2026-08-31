import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/screens/meal_planning/meal_planning_screen.dart';
import 'package:food_journal/widgets/grocery_list_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// [MFT] MealPlanningScreen composition — holds the contract that the Meal Planning tab
  /// renders exactly two things in order: an inert "this week's meals" placeholder and the
  /// relocated grocery card, with no AppBar of its own (the shell owns the bar and the
  /// folder tabs). If this regresses: the tab shows a second title bar stacked under the
  /// shell's, or the grocery list vanishes from the only place it now lives — the user's
  /// shopping list becomes unreachable and no other test in the suite would notice.
  group('[MFT] MealPlanningScreen composition', () {
    testWidgets('screen has meal-planning-screen semantics identifier',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final finder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'meal-planning-screen',
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('planner stub card has planner-stub-card identifier',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final finder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('stub text renders correctly', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      expect(find.text("This week's meals"), findsOneWidget);
      expect(find.text('Nothing planned yet.'), findsOneWidget);
    });

    testWidgets('grocery card is mounted and displays title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.ensureVisible(find.byType(GroceryListCard));
      await tester.pumpAndSettle();

      expect(find.byType(GroceryListCard), findsOneWidget);
      expect(find.text('Grocery list'), findsOneWidget);
    });

    testWidgets('screen has no AppBar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('stub renders above grocery card', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.ensureVisible(find.byType(GroceryListCard));
      await tester.pumpAndSettle();

      final stubFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      final groceryFinder = find.byType(GroceryListCard);

      final stubTop = tester.getTopLeft(stubFinder).dy;
      final groceryTop = tester.getTopLeft(groceryFinder).dy;

      expect(stubTop < groceryTop, isTrue);
    });
  });

  /// [INV] MealPlanningScreen stub inertness — holds the invariant that the
  /// "this week's meals" placeholder offers no interactive controls and cannot be
  /// tapped or acted upon. The text is static, announcing that planning lands later.
  /// If this regresses: an early implementer added a "Plan a meal" button or
  /// similar action to the empty state, violating the spec that the stub is
  /// copy-only and the planning feature is not yet implemented.
  group('[INV] MealPlanningScreen stub inertness', () {
    testWidgets('stub contains no ElevatedButton', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final stubFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      final buttonFinder = find.descendant(
        of: stubFinder,
        matching: find.byType(ElevatedButton),
      );
      expect(buttonFinder, findsNothing);
    });

    testWidgets('stub contains no FilledButton', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final stubFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      final buttonFinder = find.descendant(
        of: stubFinder,
        matching: find.byType(FilledButton),
      );
      expect(buttonFinder, findsNothing);
    });

    testWidgets('stub contains no OutlinedButton', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final stubFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      final buttonFinder = find.descendant(
        of: stubFinder,
        matching: find.byType(OutlinedButton),
      );
      expect(buttonFinder, findsNothing);
    });

    testWidgets('stub contains no TextButton', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MealPlanningScreen()));
      await tester.pumpAndSettle();

      final stubFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.identifier == 'planner-stub-card',
      );
      final buttonFinder = find.descendant(
        of: stubFinder,
        matching: find.byType(TextButton),
      );
      expect(buttonFinder, findsNothing);
    });
  });
}
