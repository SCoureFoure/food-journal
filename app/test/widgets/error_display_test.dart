import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/widgets/error_display.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  // ── ErrorBanner rendering ─────────────────────────────────────────────────

  group('[MFT] ErrorBanner', () {
    testWidgets('renders message text in red', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorBanner(message: 'Something went wrong')));
      expect(find.text('Something went wrong'), findsOneWidget);
      final text = tester.widget<Text>(find.text('Something went wrong'));
      expect(text.style?.color, Colors.red);
    });
  });

  // ── ErrorBanner boundary ─────────────────────────────────────────────────

  group('[BVA] ErrorBanner — boundary', () {
    testWidgets('renders empty string without error', (tester) async {
      await tester.pumpWidget(_wrap(const ErrorBanner(message: '')));
      expect(find.byType(ErrorBanner), findsOneWidget);
    });
  });

  // ── ErrorRetry rendering ──────────────────────────────────────────────────

  group('[MFT] ErrorRetry', () {
    testWidgets('renders message and Retry button', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorRetry(message: 'Load failed', onRetry: () {}),
      ));
      expect(find.text('Load failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping Retry fires onRetry callback', (tester) async {
      int calls = 0;
      await tester.pumpWidget(_wrap(
        ErrorRetry(message: 'Oops', onRetry: () => calls++),
      ));
      await tester.tap(find.text('Retry'));
      expect(calls, 1);
    });

    testWidgets('wraps in Semantics when semanticsId is provided', (tester) async {
      await tester.pumpWidget(_wrap(
        ErrorRetry(
          message: 'Error',
          onRetry: () {},
          semanticsId: 'error-retry',
        ),
      ));
      expect(
        find.descendant(
          of: find.byType(Semantics),
          matching: find.text('Retry'),
        ),
        findsOneWidget,
      );
    });
  });

  // ── ErrorRetry callback invariant ────────────────────────────────────────

  group('[INV] ErrorRetry — callback invariant', () {
    testWidgets('n taps → callback fires n times', (tester) async {
      int calls = 0;
      await tester.pumpWidget(_wrap(
        ErrorRetry(message: 'Oops', onRetry: () => calls++),
      ));
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Retry'));
      expect(calls, 2);
    });
  });
}
