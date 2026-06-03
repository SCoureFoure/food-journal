// AC10 (specs/log_feeling.spec.md) — feed surfacing: FeelingTile subtitle reads
// "time · mood · sym (level), …", or "No reaction" when empty.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/widgets/home/feeling_tile.dart';

Future<void> _pump(WidgetTester t, ReactionLog log) => t.pumpWidget(MaterialApp(
      home: Scaffold(body: FeelingTile(log: log, onReload: () {})),
    ));

void main() {
  testWidgets('AC10 subtitle: time · mood · symptom (level), …', (t) async {
    await _pump(
      t,
      ReactionLog(
        id: 1,
        checkinTime: DateTime(2026, 6, 2, 22, 27),
        symptoms: const ['Bloating', 'Nausea'],
        symptomLevels: const {
          'Bloating': ReactionLevel.mild,
          'Nausea': ReactionLevel.bad,
        },
        severity: ReactionLevel.bad,
        mood: Mood.good,
      ),
    );

    expect(find.text('How I felt'), findsOneWidget);
    expect(
      find.textContaining('Good · Bloating (Mild), Nausea (Bad)'),
      findsOneWidget,
    );
  });

  testWidgets('AC10 empty feeling subtitle reads "No reaction"', (t) async {
    await _pump(
      t,
      ReactionLog(
        id: 2,
        checkinTime: DateTime(2026, 6, 2, 8, 0),
        symptoms: const [],
        severity: ReactionLevel.none,
      ),
    );

    expect(find.textContaining('No reaction'), findsOneWidget);
  });

  // Edit affordance lives in the expanded body (not the header trailing) so it
  // wins its own tap instead of toggling the ExpansionTile. Expand → Edit → route.
  testWidgets('Edit button in body navigates to /edit_checkin with the log', (t) async {
    final log = ReactionLog(
      id: 9,
      checkinTime: DateTime(2026, 6, 2, 12, 0),
      symptoms: const ['Nausea'],
      symptomLevels: const {'Nausea': ReactionLevel.mild},
      severity: ReactionLevel.mild,
    );
    Object? routedArg;

    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: FeelingTile(log: log, onReload: () {})),
      onGenerateRoute: (s) {
        if (s.name == '/edit_checkin') {
          routedArg = s.arguments;
          return MaterialPageRoute(builder: (_) => const Scaffold());
        }
        return null;
      },
    ));

    // collapsed: Edit not built yet
    expect(find.text('Edit'), findsNothing);

    await t.tap(find.text('How I felt')); // expand
    await t.pumpAndSettle();

    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();

    expect(routedArg, same(log));
  });
}
