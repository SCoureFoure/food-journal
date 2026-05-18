import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/loading_button.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  // ── Rendering ─────────────────────────────────────────────────────────────

  group('[MFT] LoadingButton — rendering', () {
    testWidgets('shows label when not loading', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingButton(isLoading: false, label: 'Save', onPressed: () {}),
      ));
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows spinner and hides label when loading', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingButton(isLoading: true, label: 'Save', onPressed: () {}),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('wraps in Semantics when semanticsId is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingButton(
          isLoading: false,
          label: 'Submit',
          onPressed: () {},
          semanticsId: 'btn-submit',
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(Semantics),
          matching: find.text('Submit'),
        ),
        findsOneWidget,
      );
    });
  });

  // ── Disabled invariant ────────────────────────────────────────────────────

  group('[INV] LoadingButton — disabled invariant', () {
    testWidgets('button is disabled when isLoading is true', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingButton(isLoading: true, label: 'Save', onPressed: () => taps++),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
    });

    testWidgets('button is disabled when disabled flag is true', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingButton(
          isLoading: false,
          disabled: true,
          label: 'Save',
          onPressed: () => taps++,
        ),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
    });
  });

  // ── Interaction ───────────────────────────────────────────────────────────

  group('[Scenario] LoadingButton — interaction', () {
    testWidgets('button fires callback when enabled and tapped', (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingButton(isLoading: false, label: 'Save', onPressed: () => taps++),
      ));
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);
    });

    testWidgets('no Semantics wrapper when semanticsId is null', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingButton(isLoading: false, label: 'Go', onPressed: () {}),
      ));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
