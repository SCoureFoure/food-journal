// Run with:
//   MEAL_PARSER_URL=https://... flutter test test/integration/ai/parse_medication_integration_test.dart
//
// Skipped automatically when MEAL_PARSER_URL is not set.

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/ai_service.dart';
import 'package:food_journal/services/worker_ai_service.dart';

import 'helpers/ai_assertions.dart';
import 'helpers/test_env.dart';

// ─── Skip guard ──────────────────────────────────────────────────────────────

final _workerUrl = readRootEnv('MEAL_PARSER_URL') ?? '';
final _skip = _workerUrl.isEmpty ? 'Set MEAL_PARSER_URL env var to run AI integration tests' : null;

// ─── Helpers ─────────────────────────────────────────────────────────────────

AiService _makeService() => WorkerAiService(
      workerUrl: _workerUrl,
      authToken: readRootEnv('TEST_AUTH_TOKEN'),
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late AiService ai;

  setUpAll(() {
    if (_workerUrl.isNotEmpty) ai = _makeService();
  });

  // ── Schema invariants ──────────────────────────────────────────────────────

  group('parseMedication — schema invariants', () {
    test(
      'well-formed input: success=true, name populated, dose > 0',
      () async {
        final r = await ai.parseMedication(text: 'Metformin 500mg');
        AiAssertions.medicationSchema(r);
      },
      skip: _skip,
    );

    test(
      'supplement input: success=true, name populated',
      () async {
        final r = await ai.parseMedication(text: 'Vitamin D3 2000 IU');
        AiAssertions.medicationSchema(r);
      },
      skip: _skip,
    );
  });

  // ── Semantic assertions ────────────────────────────────────────────────────
  // Verify that explicitly stated values are parsed correctly.

  group('parseMedication — semantic assertions', () {
    test(
      'Metformin 500mg: name contains "metformin", dose=500, unit="mg"',
      () async {
        final r = await ai.parseMedication(text: 'Metformin 500mg');
        AiAssertions.medicationSchema(r);
        AiAssertions.medicationNameContains(r, 'metformin');
        AiAssertions.medicationDose(r, 500);
        AiAssertions.medicationUnit(r, 'mg');
      },
      skip: _skip,
    );

    test(
      'Insulin 10 units subcutaneous: route is non-null (maps to "other" — not in prompt enum)',
      () async {
        final r = await ai.parseMedication(text: 'Insulin 10 units subcutaneous');
        AiAssertions.medicationSchema(r);
        // "subcutaneous" is not in the route enum (oral|topical|inhaled|sublingual|IV|other),
        // so the model correctly returns "other". Assert non-null only.
        expect(r.route, isNotNull, reason: 'route should be populated when explicitly stated');
      },
      skip: _skip,
    );

    test(
      'brand name Tylenol 1000mg: name populated, dose=1000, unit="mg"',
      () async {
        final r = await ai.parseMedication(text: 'Tylenol 1000mg');
        AiAssertions.medicationSchema(r);
        // Accept "Tylenol" or generic "Acetaminophen" — either is correct
        expect(r.name, isNotEmpty);
        AiAssertions.medicationDose(r, 1000);
        AiAssertions.medicationUnit(r, 'mg');
      },
      skip: _skip,
    );
  });

  // ── No-inference rule ──────────────────────────────────────────────────────
  // The parse_medication prompt explicitly states:
  //   "Do NOT estimate, assume, or infer any field. If not explicitly provided, return null."
  //   "route: ONLY if explicitly stated; null if not mentioned — do NOT assume 'oral'"
  //
  // These tests enforce that constraint is not violated by the model.

  group('parseMedication — no-inference rule', () {
    test(
      'name only (no dose): dose=null, route=null',
      () async {
        final r = await ai.parseMedication(text: 'Metformin');
        AiAssertions.medicationSchema(r);
        AiAssertions.medicationNoDoseInferred(r);
        AiAssertions.medicationNoRouteInferred(r);
      },
      skip: _skip,
    );

    test(
      'name + dose, no route: route=null (must not assume oral)',
      () async {
        final r = await ai.parseMedication(text: 'Lisinopril 10mg');
        AiAssertions.medicationSchema(r);
        AiAssertions.medicationNoRouteInferred(r);
      },
      skip: _skip,
    );

    test(
      'vague input "my blood pressure pill": name non-null, dose=null, route=null',
      () async {
        final r = await ai.parseMedication(text: 'my blood pressure pill');
        // Model should attempt a name extraction; dose/route must stay null
        if (r.success) {
          AiAssertions.medicationSchema(r);
          AiAssertions.medicationNoDoseInferred(r);
          AiAssertions.medicationNoRouteInferred(r);
        } else {
          // Acceptable: model returns failure for vague input
          expect(r.errorMessage, isNotNull);
        }
      },
      skip: _skip,
    );
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('parseMedication — edge cases', () {
    test(
      'empty text returns success=false with errorMessage',
      () async {
        final r = await ai.parseMedication(text: '');
        AiAssertions.medicationFailure(r);
      },
      skip: _skip,
    );

    test(
      'null text returns success=false with errorMessage',
      () async {
        final r = await ai.parseMedication();
        AiAssertions.medicationFailure(r);
      },
      skip: _skip,
    );
  });
}
