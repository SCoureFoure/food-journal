// Tests for CheckinScreen (standalone "feeling" log) — spec: specs/log_feeling.spec.md
//
// Fake StorageService records inserted/updated/deleted reaction logs so tests
// never touch SQLite. Covers AC1–AC4, AC6–AC9. AC5 (severity derivation) is a
// pure model test in test/models/reaction_log_test.dart; AC10 (feed subtitle) is
// test/widgets/feeling_tile_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/screens/checkin/checkin_screen.dart';
import 'package:food_journal/services/storage_service.dart';

// ── Fake storage ───────────────────────────────────────────────────────────────

class _FakeStorage extends StorageService {
  final List<ReactionLog> saved = [];
  final List<ReactionLog> updated = [];
  final List<int> deleted = [];
  final List<(int, String?)> mealSymptoms = [];

  @override
  Future<void> saveReactionLog(ReactionLog log) async => saved.add(log);

  @override
  Future<void> updateReactionLog(ReactionLog log) async => updated.add(log);

  @override
  Future<void> deleteReactionLog(int logId) async => deleted.add(logId);

  @override
  Future<void> updateMealSymptoms(int mealId, String? symptoms) async =>
      mealSymptoms.add((mealId, symptoms));
}

// Push CheckinScreen above a placeholder route so its Navigator.pop on save has
// somewhere to land (popping the only route poisons the test binding).
Future<void> _pump(WidgetTester tester, _FakeStorage storage,
    {ReactionLog? existingLog}) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const Scaffold()));
  key.currentState!.push(MaterialPageRoute(
    builder: (_) => CheckinScreen(existingLog: existingLog, storageOverride: storage),
  ));
  await tester.pumpAndSettle();
}

FilterChip _chip(WidgetTester tester, String label) =>
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

void main() {
  // ── AC1 — new feeling happy path ──────────────────────────────────────────────
  testWidgets('AC1 new feeling: mood + symptoms (mild) + notes → one insert', (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    await t.tap(find.text('Good'));
    await t.tap(find.widgetWithText(FilterChip, 'Bloating'));
    await t.tap(find.widgetWithText(FilterChip, 'Nausea'));
    await t.pump();
    await t.enterText(find.byType(TextField), 'felt off');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(storage.saved, hasLength(1));
    final log = storage.saved.single;
    expect(log.mealId, isNull);
    expect(log.mood, Mood.good);
    expect(log.symptoms, ['Bloating', 'Nausea']);
    expect(log.symptomLevels,
        {'Bloating': ReactionLevel.mild, 'Nausea': ReactionLevel.mild});
    expect(log.severity, ReactionLevel.mild);
    expect(log.notes, 'felt off');
    expect(storage.mealSymptoms, isEmpty); // standalone: no meal touched
  });

  // ── AC2 — chip default + slider visibility ────────────────────────────────────
  testWidgets('AC2 "How bad?" panel hidden until a symptom is selected, removed on untap',
      (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    expect(find.text('How bad?'), findsNothing);

    await t.tap(find.widgetWithText(FilterChip, 'Bloating'));
    await t.pump();
    expect(find.text('How bad?'), findsOneWidget);
    expect(_chip(t, 'Bloating').selected, isTrue);

    await t.tap(find.widgetWithText(FilterChip, 'Bloating'));
    await t.pump();
    expect(find.text('How bad?'), findsNothing);

    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(storage.saved.single.symptoms, isEmpty);
  });

  // ── AC3 — mood optional + toggle ──────────────────────────────────────────────
  testWidgets('AC3 mood left null saves null; re-tapping a mood clears it', (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    await t.tap(find.widgetWithText(FilterChip, 'Bloating'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(storage.saved.single.mood, isNull);
  });

  testWidgets('AC3b re-tapping a selected mood clears it back to null', (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    await t.tap(find.text('Okay'));
    await t.pump();
    await t.tap(find.text('Okay')); // toggle off
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(storage.saved.single.mood, isNull);
  });

  // ── AC4 — empty feeling valid ─────────────────────────────────────────────────
  testWidgets('AC4 no symptoms + no mood saves a row, severity none', (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(storage.saved, hasLength(1));
    expect(storage.saved.single.symptoms, isEmpty);
    expect(storage.saved.single.severity, ReactionLevel.none);
  });

  // ── AC6 — notes trim → null ───────────────────────────────────────────────────
  testWidgets('AC6 whitespace-only notes saved as null', (t) async {
    final storage = _FakeStorage();
    await _pump(t, storage);

    await t.enterText(find.byType(TextField), '   ');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(storage.saved.single.notes, isNull);
  });

  // ── AC7 — accumulation / independence ─────────────────────────────────────────
  testWidgets('AC7 a second feeling is a new insert, not an update', (t) async {
    final storage = _FakeStorage();

    await _pump(t, storage);
    await t.tap(find.widgetWithText(FilterChip, 'Nausea'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    await _pump(t, storage); // fresh screen, same storage
    await t.tap(find.widgetWithText(FilterChip, 'Fatigue'));
    await t.pump();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(storage.saved, hasLength(2));
    expect(storage.updated, isEmpty);
    expect(storage.saved[0].symptoms, ['Nausea']);
    expect(storage.saved[1].symptoms, ['Fatigue']);
  });

  // ── AC8 — edit preload + update ───────────────────────────────────────────────
  testWidgets('AC8 edit preloads fields and saves via update on the same id', (t) async {
    final storage = _FakeStorage();
    final existing = ReactionLog(
      id: 42,
      mealId: null,
      checkinTime: DateTime(2026, 6, 1, 14, 30),
      symptoms: const ['Bloating'],
      symptomLevels: const {'Bloating': ReactionLevel.moderate},
      severity: ReactionLevel.moderate,
      mood: Mood.low,
      notes: 'old note',
    );
    await _pump(t, storage, existingLog: existing);

    // preload: title, chip selected, notes text present
    expect(find.text('Edit feeling'), findsOneWidget);
    expect(_chip(t, 'Bloating').selected, isTrue);
    expect(find.widgetWithText(TextField, 'old note'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'new note');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    expect(storage.saved, isEmpty);
    expect(storage.updated, hasLength(1));
    final upd = storage.updated.single;
    expect(upd.id, 42);
    expect(upd.notes, 'new note');
    expect(upd.symptomLevels, {'Bloating': ReactionLevel.moderate});
    // unchanged date/time pickers → checkinTime preserved
    expect(upd.checkinTime, DateTime(2026, 6, 1, 14, 30));
  });

  // ── AC9 — delete ──────────────────────────────────────────────────────────────
  testWidgets('AC9 delete (confirmed) removes the row; cancel keeps it', (t) async {
    final storage = _FakeStorage();
    final existing = ReactionLog(
      id: 7,
      checkinTime: DateTime(2026, 6, 1, 9, 0),
      symptoms: const [],
      severity: ReactionLevel.none,
    );

    // cancel path
    await _pump(t, storage, existingLog: existing);
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(storage.deleted, isEmpty);

    // confirm path
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Delete'));
    await t.pumpAndSettle();
    expect(storage.deleted, [7]);
  });
}
