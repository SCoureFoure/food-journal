// Tests for BlameHistoryScreen — review/dismiss accrued suspicion
// (specs/blame_history.spec.md).
//
// The aggregation math (grouping, dedupe, sort, dismissed flag) is exercised
// purely in food_suspicion_test.dart (buildBlameHistory/excludeDismissedSuspicions);
// here the fake returns a pre-built entry list so we test the screen's own
// behavior: rendering, the dismiss/restore round-trip, empty state, and the
// screen-root anchor (AC2, AC4, AC8, AC9).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart' show ReactionLevel;
import 'package:food_journal/models/food_suspicion.dart';
import 'package:food_journal/screens/blame_history/blame_history_screen.dart';
import 'package:food_journal/services/storage_service.dart';

class _FakeStorage extends StorageService {
  List<BlameHistoryEntry> entries = [];
  Object? loadError;
  final List<({int reactionLogId, String symptom})> toggled = [];
  List<SuspectEntry> suspects = [];
  int suspectLoads = 0;

  @override
  Future<List<BlameHistoryEntry>> getBlameHistory() async {
    if (loadError != null) throw loadError!;
    return entries;
  }

  @override
  Future<List<SuspectEntry>> getSuspects() async {
    suspectLoads++;
    if (loadError != null) throw loadError!;
    return suspects;
  }

  @override
  Future<void> toggleSuspicionExclusion({
    required int reactionLogId,
    required String symptom,
  }) async {
    toggled.add((reactionLogId: reactionLogId, symptom: symptom));
    final i = entries.indexWhere(
        (e) => e.reactionLogId == reactionLogId && e.symptom == symptom);
    final e = entries[i];
    entries[i] = BlameHistoryEntry(
      reactionLogId: e.reactionLogId,
      symptom: e.symptom,
      checkinTime: e.checkinTime,
      severity: e.severity,
      blamedNames: e.blamedNames,
      dismissed: !e.dismissed,
    );
  }
}

BlameHistoryEntry _entry(
  int logId,
  String symptom, {
  required ReactionLevel severity,
  required List<String> names,
  bool dismissed = false,
  DateTime? checkinTime,
}) =>
    BlameHistoryEntry(
      reactionLogId: logId,
      symptom: symptom,
      checkinTime: checkinTime ?? DateTime(2026, 6, 2, 20),
      severity: severity,
      blamedNames: names,
      dismissed: dismissed,
    );

SuspectEntry _suspect(String symptom, String name,
        {int episodes = 3, int eaten = 4, double score = 3}) =>
    SuspectEntry(
      targetName: name,
      symptom: symptom,
      score: score,
      episodeCount: episodes,
      timesEaten: eaten,
      rate: score / (eaten < 1 ? 1 : eaten),
    );

Future<void> _openSuspectsTab(WidgetTester t) async {
  await t.tap(find.text('Suspects'));
  await t.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, _FakeStorage storage) async {
  await tester.pumpWidget(MaterialApp(
    home: BlameHistoryScreen(storageOverride: storage),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AC9 screen root renders', (t) async {
    await _pump(t, _FakeStorage());
    expect(find.bySemanticsIdentifier('blame-history-screen'), findsOneWidget);
  });

  testWidgets('AC2 lists entries newest-first with date, symptom, severity, blamed names',
      (t) async {
    final storage = _FakeStorage()
      ..entries = [
        _entry(1, 'Nausea',
            severity: ReactionLevel.bad,
            names: ['salad', 'yogurt'],
            checkinTime: DateTime(2026, 6, 2, 20, 30)),
        _entry(2, 'Bloating',
            severity: ReactionLevel.mild,
            names: ['soup'],
            checkinTime: DateTime(2026, 6, 1, 8, 0)),
      ];
    await _pump(t, storage);

    expect(find.bySemanticsIdentifier('blame-history-item-1-nausea'), findsOneWidget);
    expect(find.bySemanticsIdentifier('blame-history-item-2-bloating'), findsOneWidget);
    expect(find.text('Nausea'), findsOneWidget);
    expect(find.text('Bad'), findsOneWidget);
    expect(find.text('Mild'), findsOneWidget);
    expect(find.textContaining('Salad'), findsOneWidget);
    expect(find.textContaining('Yogurt'), findsOneWidget);
    expect(find.textContaining('Jun 2, 2026'), findsOneWidget);

    // newest checkin (Jun 2) renders above the older one (Jun 1).
    final nauseaTop = topOf(t, 'blame-history-item-1-nausea');
    final bloatingTop = topOf(t, 'blame-history-item-2-bloating');
    expect(nauseaTop, lessThan(bloatingTop));
  });

  testWidgets('symptom names with spaces slug to dashes for the anchor id', (t) async {
    final storage = _FakeStorage()
      ..entries = [
        _entry(5, 'Stomach pain', severity: ReactionLevel.moderate, names: ['chili']),
      ];
    await _pump(t, storage);
    expect(find.bySemanticsIdentifier('blame-history-item-5-stomach-pain'), findsOneWidget);
    expect(find.bySemanticsIdentifier('btn-blame-history-toggle-5-stomach-pain'), findsOneWidget);
  });

  group('[MFT] AC4 dismiss/restore toggle', () {
    testWidgets('tapping Dismiss calls toggleSuspicionExclusion and flips to Restore', (t) async {
      final storage = _FakeStorage()
        ..entries = [
          _entry(1, 'Nausea', severity: ReactionLevel.bad, names: ['salad']),
        ];
      await _pump(t, storage);

      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);

      // TextButton/OutlinedButton absorb their Semantics identifier (✱) —
      // tap by label, matching the established pattern (e.g. blame_sheet_test).
      await t.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await t.pumpAndSettle();

      expect(storage.toggled, [(reactionLogId: 1, symptom: 'Nausea')]);
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Dismiss'), findsNothing);
    });

    testWidgets('tapping Restore on a dismissed entry flips it back', (t) async {
      final storage = _FakeStorage()
        ..entries = [
          _entry(1, 'Nausea', severity: ReactionLevel.bad, names: ['salad'], dismissed: true),
        ];
      await _pump(t, storage);

      expect(find.text('Restore'), findsOneWidget);
      // TextButton/OutlinedButton absorb their Semantics identifier (✱) —
      // tap by label, matching the established pattern (e.g. blame_sheet_test).
      await t.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await t.pumpAndSettle();

      expect(storage.toggled, [(reactionLogId: 1, symptom: 'Nausea')]);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('toggle failure surfaces a snackbar and leaves state unchanged', (t) async {
      final storage = _ToggleFailsStorage()
        ..entries = [
          _entry(1, 'Nausea', severity: ReactionLevel.bad, names: ['salad']),
        ];
      await _pump(t, storage);

      // TextButton/OutlinedButton absorb their Semantics identifier (✱) —
      // tap by label, matching the established pattern (e.g. blame_sheet_test).
      await t.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await t.pumpAndSettle();

      expect(find.textContaining("Couldn't update"), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget, reason: 'row stays in its prior state');
    });
  });

  testWidgets('AC8 empty state renders when nothing has accrued suspicion yet', (t) async {
    await _pump(t, _FakeStorage()..entries = []);
    // The Semantics(identifier:) on a bare-Text empty state merges into its
    // container node (same shape as `home-empty-state`) — assert on the
    // rendered message instead, matching how that sibling anchor is verified.
    expect(find.textContaining('No blamed episodes yet'), findsOneWidget);
    expect(find.bySemanticsIdentifier('blame-history-item-1-nausea'), findsNothing);
  });

  testWidgets('load failure renders an error message, not a crash', (t) async {
    final storage = _FakeStorage()..loadError = Exception('boom');
    await _pump(t, storage);
    expect(find.textContaining("Couldn't load blame history"), findsOneWidget);
    expect(find.bySemanticsIdentifier('blame-history-empty-state'), findsNothing);
  });

  group('[MFT] blame_suspects tabs', () {
    // testTheory: MFT
    // contract: The screen exposes Episodes and Suspects tabs; Suspects lists
    //   each symptom section with its targets, eaten counts, and an empty state.
    // implication: Without the Suspects tab users cannot see which foods or
    //   medications are repeatedly blamed for a symptom.

    testWidgets('AC10 both tab anchors render and the Episodes list is the default tab', (t) async {
      final storage = _FakeStorage()
        ..entries = [
          _entry(1, 'Nausea', severity: ReactionLevel.bad, names: ['salad']),
        ];
      await _pump(t, storage);

      expect(find.bySemanticsIdentifier('tab-blame-episodes'), findsOneWidget);
      expect(find.bySemanticsIdentifier('tab-blame-suspects'), findsOneWidget);
      expect(find.bySemanticsIdentifier('blame-history-item-1-nausea'), findsOneWidget);
    });

    testWidgets('AC11 suspects are grouped by symptom, ordered by rank, with eaten-count subtitles',
        (t) async {
      final storage = _FakeStorage()
        ..suspects = [
          _suspect('Bloating', 'milk', episodes: 4, eaten: 1),
          _suspect('Bloating', 'oat bran', eaten: 0),
          _suspect('Stomach pain', 'coffee'),
        ];
      await _pump(t, storage);
      await _openSuspectsTab(t);

      expect(find.bySemanticsIdentifier('blame-suspects-section-bloating'), findsOneWidget);
      expect(find.bySemanticsIdentifier('blame-suspects-section-stomach-pain'), findsOneWidget);
      expect(find.bySemanticsIdentifier('blame-suspect-item-bloating-milk'), findsOneWidget);
      expect(find.bySemanticsIdentifier('blame-suspect-item-bloating-oat-bran'), findsOneWidget);
      expect(find.bySemanticsIdentifier('blame-suspect-item-stomach-pain-coffee'), findsOneWidget);

      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Oat Bran'), findsOneWidget);
      expect(find.text('Blamed in 4 check-ins · eaten 1 time'), findsOneWidget);
      expect(find.text('Blamed in 3 check-ins · eaten 0 times'), findsOneWidget);
      expect(find.text('Blamed in 3 check-ins · eaten 4 times'), findsOneWidget);

      // fake returns the list as given; screen must not re-sort.
      expect(topOf(t, 'blame-suspect-item-bloating-milk'),
          lessThan(topOf(t, 'blame-suspect-item-bloating-oat-bran')));
    });

    testWidgets('AC12 empty suspects shows the empty state with the threshold message', (t) async {
      await _pump(t, _FakeStorage()..suspects = []);
      await _openSuspectsTab(t);

      expect(find.bySemanticsIdentifier('blame-suspects-empty-state'), findsOneWidget);
      expect(find.textContaining('at least 3 check-ins'), findsOneWidget);
    });

    testWidgets('AC13 dismissing an episode reloads suspects', (t) async {
      final storage = _FakeStorage()
        ..entries = [
          _entry(1, 'Nausea', severity: ReactionLevel.bad, names: ['salad']),
        ];
      await _pump(t, storage);
      final before = storage.suspectLoads;

      // TextButton/OutlinedButton absorb their Semantics identifier (✱) —
      // tap by label, matching the existing AC4 toggle test.
      await t.tap(find.widgetWithText(TextButton, 'Dismiss'));
      await t.pumpAndSettle();

      expect(storage.suspectLoads, before + 1);
    });
  });
}

class _ToggleFailsStorage extends _FakeStorage {
  @override
  Future<void> toggleSuspicionExclusion({
    required int reactionLogId,
    required String symptom,
  }) async =>
      throw Exception('db error');
}

double topOf(WidgetTester t, String anchorId) =>
    t.getTopLeft(find.bySemanticsIdentifier(anchorId)).dy;
