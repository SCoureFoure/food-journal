import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/widgets/reaction_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('[MFT] ReactionBadge', () {
    for (final level in ReactionLevel.values) {
      testWidgets('renders label for $level', (tester) async {
        await tester.pumpWidget(_wrap(ReactionBadge(level: level)));
        expect(find.text(level.label), findsOneWidget);
      });
    }

    testWidgets('pending uses neutral colour (no green/red tint)', (tester) async {
      await tester.pumpWidget(_wrap(const ReactionBadge(level: ReactionLevel.pending)));
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('bad level renders Bad label', (tester) async {
      await tester.pumpWidget(_wrap(const ReactionBadge(level: ReactionLevel.bad)));
      expect(find.text('Bad'), findsOneWidget);
    });

    testWidgets('none level renders No reaction label', (tester) async {
      await tester.pumpWidget(_wrap(const ReactionBadge(level: ReactionLevel.none)));
      expect(find.text('No reaction'), findsOneWidget);
    });
  });
}
