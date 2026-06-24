// Tests for the fractional-servings control on EditableFoodItemCard:
// the 0.5-step stepper and the tap-to-type dialog. The dialog test is a
// regression guard for the disposed-controller crash (controller must be
// owned by the dialog's own State, not disposed synchronously after pop).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/editable_food_item_card.dart';

Finder _byId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Widget _wrap(FoodItemFormData data) => MaterialApp(
      home: Scaffold(
        body: EditableFoodItemCard(data: data, onDelete: () {}),
      ),
    );

void main() {
  group('[MFT] EditableFoodItemCard — servings stepper', () {
    testWidgets('starts at 1', (tester) async {
      await tester.pumpWidget(_wrap(FoodItemFormData.blank()));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('+ steps up by half to 1½', (tester) async {
      final data = FoodItemFormData.blank();
      await tester.pumpWidget(_wrap(data));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(data.servings, 1.5);
      expect(find.text('1½'), findsOneWidget);
    });

    testWidgets('- steps down by half but floors at 0.5', (tester) async {
      final data = FoodItemFormData.blank();
      await tester.pumpWidget(_wrap(data));
      await tester.tap(find.byIcon(Icons.remove)); // 1 → 0.5
      await tester.pump();
      expect(data.servings, 0.5);
      expect(find.text('½'), findsOneWidget);

      // Further taps are disabled at the floor.
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(data.servings, 0.5);
    });
  });

  group('[MFT] EditableFoodItemCard — servings type-in dialog', () {
    testWidgets('typing an exact value applies it without crashing', (tester) async {
      final data = FoodItemFormData.blank();
      await tester.pumpWidget(_wrap(data));

      await tester.tap(_byId('btn-servings-edit'));
      await tester.pumpAndSettle();

      expect(_byId('servings-input-field'), findsOneWidget);
      await tester.enterText(find.descendant(
        of: _byId('servings-input-field'),
        matching: find.byType(TextField),
      ), '0.25');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle(); // dialog animates out — would crash if controller disposed early

      expect(data.servings, 0.25);
      expect(find.text('¼'), findsOneWidget);
    });

    testWidgets('cancel leaves servings unchanged', (tester) async {
      final data = FoodItemFormData.blank();
      await tester.pumpWidget(_wrap(data));

      await tester.tap(_byId('btn-servings-edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(data.servings, 1.0);
    });
  });
}
