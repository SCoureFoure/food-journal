// Tests for BlameSheet — manual blame modal (specs/food_blame.spec.md).
//
// The 24h window query is exercised at the storage layer (getBlameCandidates);
// here the fake returns a seeded candidate list so we test the modal's own
// behavior: rendering candidates, multi-select, pre-checking, and returning the
// chosen set. AC6 (window contents) and AC7 (selection → result) at the UI layer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_suspicion.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/blame_sheet.dart';

class _FakeStorage extends StorageService {
  List<BlameCandidate> candidates = [];
  Duration? requestedWindow;

  @override
  Future<List<BlameCandidate>> getBlameCandidates(
      {required DateTime anchor, required Duration window}) async {
    requestedWindow = window;
    return candidates;
  }
}

BlameCandidate _food(int id, String name, {DateTime? ts}) => BlameCandidate(
      type: SuspicionTargetType.food,
      targetId: id,
      name: name,
      timestamp: ts ?? DateTime(2026, 6, 2, 13),
      subtitle: '1 cup',
    );

BlameCandidate _med(int id, String name) => BlameCandidate(
      type: SuspicionTargetType.medication,
      targetId: id,
      name: name,
      timestamp: DateTime(2026, 6, 2, 9),
    );

/// Pumps the sheet. The returned record holds the still-pending modal future
/// (wrapped in a record so `await` does not flatten/block on it before the
/// modal is dismissed in the test body).
Future<({Future<List<BlameCandidate>?> popped})> _open(
  WidgetTester tester,
  _FakeStorage storage, {
  Set<String> initial = const {},
}) async {
  // Tall viewport so the sheet's bottom button stays on-screen — off-screen
  // widgets are pruned from the semantics tree and can't be found/tapped.
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late Future<List<BlameCandidate>?> popped;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () {
            popped = showModalBottomSheet<List<BlameCandidate>>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BlameSheet(
                anchor: DateTime(2026, 6, 2, 20),
                initiallySelectedKeys: initial,
                storageOverride: storage,
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (popped: popped);
}

void main() {
  testWidgets('AC6 lists seeded food + med candidates', (t) async {
    final storage = _FakeStorage()
      ..candidates = [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')];
    await _open(t, storage);

    expect(find.bySemanticsIdentifier('blame-sheet'), findsOneWidget);
    expect(find.bySemanticsIdentifier('blame-item-food-1'), findsOneWidget);
    expect(find.bySemanticsIdentifier('blame-item-med-2'), findsOneWidget);
    expect(find.text('Hamburger'), findsOneWidget);
    expect(find.text('Ibuprofen'), findsOneWidget);
  });

  testWidgets('AC6 requests the 24h manual window', (t) async {
    final storage = _FakeStorage()..candidates = [];
    await _open(t, storage);
    expect(storage.requestedWindow, kManualBlameWindow);
  });

  testWidgets('empty candidate list shows the empty message', (t) async {
    final storage = _FakeStorage()..candidates = [];
    await _open(t, storage);
    expect(find.text('Nothing logged in the past 24 hours.'), findsOneWidget);
  });

  testWidgets('AC7 selecting items returns them via pop', (t) async {
    final storage = _FakeStorage()
      ..candidates = [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')];
    final h = await _open(t, storage);

    await t.tap(find.text('Hamburger'));
    await t.pump();
    expect(find.text('Blame 1 item'), findsOneWidget);

    // FilledButton absorbs its Semantics identifier (✱) — tap by label.
    await t.tap(find.widgetWithText(FilledButton, 'Blame 1 item'));
    await t.pumpAndSettle();

    final chosen = await h.popped;
    expect(chosen, isNotNull);
    expect(chosen!.map((c) => c.targetId), [1]);
  });

  testWidgets('multi-select returns every chosen candidate', (t) async {
    final storage = _FakeStorage()
      ..candidates = [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')];
    final h = await _open(t, storage);

    await t.tap(find.text('Hamburger'));
    await t.tap(find.text('Ibuprofen'));
    await t.pump();
    expect(find.text('Blame 2 items'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'Blame 2 items'));
    await t.pumpAndSettle();

    final chosen = await h.popped;
    expect(chosen!.map((c) => c.targetId).toSet(), {1, 2});
  });

  testWidgets('pre-selected keys render checked and survive into result', (t) async {
    final storage = _FakeStorage()
      ..candidates = [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')];
    final h = await _open(t, storage, initial: {'food:1'});

    // already counted as blamed
    expect(find.text('Blame 1 item'), findsOneWidget);

    await t.tap(find.widgetWithText(FilledButton, 'Blame 1 item'));
    await t.pumpAndSettle();
    final chosen = await h.popped;
    expect(chosen!.map((c) => c.targetId), [1]);
  });

  testWidgets('search filters the visible list by name', (t) async {
    final storage = _FakeStorage()
      ..candidates = [_food(1, 'Hamburger'), _med(2, 'Ibuprofen')];
    await _open(t, storage);

    // TextField absorbs its Semantics identifier (✱) — reach it by type.
    await t.enterText(find.byType(TextField), 'ibu');
    await t.pump();
    expect(find.text('Ibuprofen'), findsOneWidget);
    expect(find.text('Hamburger'), findsNothing);
  });
}
