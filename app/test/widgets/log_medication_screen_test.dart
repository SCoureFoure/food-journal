// Tests for LogMedicationScreen — spec: specs/log_medication.spec.md
//
// Fakes for storage / ai / notifications / settings so tests never touch SQLite,
// the worker, the notification plugin, or shared prefs.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/screens/log_medication/log_medication_screen.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/notification_service.dart';
import 'package:food_journal/services/settings_service.dart';
import 'package:food_journal/services/storage_service.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeStorage extends StorageService {
  final List<Medication> saved = [];
  final List<Medication> updated = [];
  final List<int> deleted = [];
  int _nextId = 1;

  @override
  Future<int> saveMedication(Medication med) async {
    saved.add(med);
    return _nextId++;
  }

  @override
  Future<void> updateMedication(Medication med) async => updated.add(med);

  @override
  Future<void> deleteMedication(int medId) async => deleted.add(medId);
}

class _FakeAi implements AiService {
  final MedicationParseResult Function() medImpl;
  int calls = 0;
  _FakeAi(this.medImpl);

  @override
  Future<MedicationParseResult> parseMedication({String? text, Uint8List? imageBytes}) async {
    calls++;
    return medImpl();
  }

  @override
  Future<MealParseResult> parseMeal({
    String? text,
    Uint8List? imageBytes,
    String? mealType,
    String? mealContext,
  }) async =>
      throw UnimplementedError();
}

class _Scheduled {
  final int id;
  final int? delay;
  _Scheduled(this.id, this.delay);
}

class _FakeNotifications extends NotificationService {
  final List<_Scheduled> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleCheckin(int entryId, String label, DateTime entryTime,
          {int? delayMinutes}) async =>
      scheduled.add(_Scheduled(entryId, delayMinutes));

  @override
  Future<void> cancelCheckin(int entryId) async => cancelled.add(entryId);
}

class _FakeSettings extends SettingsService {
  final bool aiEnabled;
  _FakeSettings({this.aiEnabled = true});

  @override
  Future<bool> get isAiEnabled async => aiEnabled;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

MedicationParseResult okMed() => MedicationParseResult(
      success: true,
      name: 'Ibuprofen',
      dose: 200,
      unit: 'mg',
      route: 'oral',
      notes: 'with food',
    );

Widget _screen({
  Medication? existing,
  required _FakeStorage storage,
  _FakeAi? ai,
  _FakeNotifications? notifications,
  _FakeSettings? settings,
}) =>
    MaterialApp(
      home: LogMedicationScreen(
        existingMed: existing,
        storageOverride: storage,
        aiOverride: ai ?? _FakeAi(okMed),
        notificationsOverride: notifications ?? _FakeNotifications(),
        settingsOverride: settings ?? _FakeSettings(),
      ),
    );

Finder _bySemanticsId(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

Finder _field(String id) =>
    find.descendant(of: _bySemanticsId(id), matching: find.byType(TextField));

// Save sits at the bottom of a scroll view. Grow the viewport so the full form
// (and the button) is on-screen and hit-testable, then tap.
Future<void> _tapSave(WidgetTester t) async {
  t.view.physicalSize = const Size(1000, 2400);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpAndSettle();
  await t.ensureVisible(_bySemanticsId('btn-save-medication'));
  await t.pumpAndSettle();
  await t.tap(_bySemanticsId('btn-save-medication'));
}

Medication _existing() => Medication(
      id: 7,
      date: DateTime(2026, 6, 1),
      time: '8:00 AM',
      name: 'Aspirin',
      dose: 81,
      unit: 'mg',
      createdAt: DateTime(2026, 6, 1),
    );

void main() {
  // AC2 — name required.
  testWidgets('AC2 empty name shows error and does not save', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(storage: storage));
    await tester.pumpAndSettle();

    await _tapSave(tester);
    await tester.pump();

    expect(find.text('Medication name is required.'), findsOneWidget);
    expect(storage.saved, isEmpty);
  });

  // AC1 + AC8 — manual create persists and schedules a check-in (default 90).
  testWidgets('AC1/AC8 create saves and schedules check-in with default delay',
      (tester) async {
    final storage = _FakeStorage();
    final notifs = _FakeNotifications();
    await tester.pumpWidget(_screen(storage: storage, notifications: notifs));
    await tester.pumpAndSettle();

    await tester.enterText(_field('log-med-name'), 'Vitamin D3');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(storage.saved, hasLength(1));
    expect(storage.saved.first.name, 'Vitamin D3');
    expect(notifs.scheduled, hasLength(1));
    expect(notifs.scheduled.first.delay, 90, reason: 'AC8: default check-in delay');
  });

  // AC7 — dose parsing.
  testWidgets('AC7 dose "0.5" parses to 0.5', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(_field('log-med-name'), 'X');
    await tester.enterText(_field('log-med-dose'), '0.5');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(storage.saved.first.dose, 0.5);
  });

  testWidgets('AC7 non-numeric dose "abc" parses to null (no crash)', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(storage: storage));
    await tester.pumpAndSettle();

    await tester.enterText(_field('log-med-name'), 'X');
    await tester.enterText(_field('log-med-dose'), 'abc');
    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(storage.saved.first.dose, isNull);
  });

  // AC3 — autofill fills only-empty fields.
  testWidgets('AC3 autofill populates empty name/dose/notes', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(storage: storage, ai: _FakeAi(okMed)));
    await tester.pumpAndSettle();

    await tester.enterText(_field('log-med-name').first, ''); // ensure empty
    await tester.enterText(
      find.descendant(of: _bySemanticsId('log-medication-screen'), matching: find.byType(TextField)).at(1),
      'ibuprofen 200mg',
    );
    await tester.tap(_bySemanticsId('btn-autofill-medication'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_field('log-med-name')).controller?.text, 'Ibuprofen');
    expect(tester.widget<TextField>(_field('log-med-dose')).controller?.text, '200');
    expect(tester.widget<TextField>(_field('log-med-notes')).controller?.text, 'with food');
  });

  testWidgets('AC3 autofill does not overwrite a typed name', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(storage: storage, ai: _FakeAi(okMed)));
    await tester.pumpAndSettle();

    await tester.enterText(_field('log-med-name'), 'MyMed');
    await tester.enterText(
      find.descendant(of: _bySemanticsId('log-medication-screen'), matching: find.byType(TextField)).at(1),
      'ibuprofen',
    );
    await tester.tap(_bySemanticsId('btn-autofill-medication'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_field('log-med-name')).controller?.text, 'MyMed');
  });

  // AC4 — autofill empty-input guard.
  testWidgets('AC4 autofill with no description/photo prompts, no AI call',
      (tester) async {
    final storage = _FakeStorage();
    final ai = _FakeAi(okMed);
    await tester.pumpWidget(_screen(storage: storage, ai: ai));
    await tester.pumpAndSettle();

    await tester.tap(_bySemanticsId('btn-autofill-medication'));
    await tester.pumpAndSettle();

    expect(ai.calls, 0);
    expect(find.text('Add a description or photo before autofilling.'), findsOneWidget);
  });

  // AC5 — autofill failure is non-blocking.
  testWidgets('AC5 autofill failure shows error and form still saves', (tester) async {
    final storage = _FakeStorage();
    final ai = _FakeAi(() => MedicationParseResult(success: false, errorMessage: 'down'));
    await tester.pumpWidget(_screen(storage: storage, ai: ai));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: _bySemanticsId('log-medication-screen'), matching: find.byType(TextField)).at(1),
      'something',
    );
    await tester.tap(_bySemanticsId('btn-autofill-medication'));
    await tester.pumpAndSettle();
    expect(find.text('down'), findsOneWidget);

    await tester.enterText(_field('log-med-name'), 'Manual');
    await _tapSave(tester);
    await tester.pumpAndSettle();
    expect(storage.saved, hasLength(1));
  });

  // AC6 — AI disabled hides autofill.
  testWidgets('AC6 autofill button absent when AI disabled', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(
      _screen(storage: storage, settings: _FakeSettings(aiEnabled: false)),
    );
    await tester.pumpAndSettle();

    expect(_bySemanticsId('btn-autofill-medication'), findsNothing);
  });

  // AC9 — edit reschedules (the FIX).
  testWidgets('AC9 edit updates record and cancels+reschedules check-in',
      (tester) async {
    final storage = _FakeStorage();
    final notifs = _FakeNotifications();
    await tester.pumpWidget(
      _screen(existing: _existing(), storage: storage, notifications: notifs),
    );
    await tester.pumpAndSettle();

    await _tapSave(tester);
    await tester.pumpAndSettle();

    expect(storage.updated, hasLength(1));
    expect(storage.saved, isEmpty, reason: 'edit must not create a new record');
    expect(notifs.cancelled, contains(7), reason: 'AC9: old check-in cancelled');
    expect(notifs.scheduled.map((s) => s.id), contains(7),
        reason: 'AC9: check-in re-armed for the edited med');
  });

  // AC10 — delete confirms then removes.
  testWidgets('AC10 delete confirm calls deleteMedication', (tester) async {
    final storage = _FakeStorage();
    await tester.pumpWidget(_screen(existing: _existing(), storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(_bySemanticsId('btn-delete-medication'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(storage.deleted, contains(7));
  });
}
