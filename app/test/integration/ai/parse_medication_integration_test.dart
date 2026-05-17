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
  // MFT: binary oracle — if these fail the feature ships nothing.

  group('[MFT] parseMedication — schema invariants', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'MFT',
        contract: 'success=true, name populated, dose null or > 0 for any well-formed input',
        implication: 'medication parsing returns unusable data for any valid input',
      );
    });
    tearDownAll(AiAssertions.clearContext);
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
  // MFT: explicitly stated name/dose/unit must be extracted exactly.
  // Zero tolerance oracle: medication dose is safety-critical — no approximation.

  group('[MFT] parseMedication — semantic assertions', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'MFT',
        contract: 'explicitly stated name, dose, and unit must be extracted exactly — zero tolerance for dose values',
        implication: 'medication dose errors are safety-critical: wrong dose stored in DB',
      );
    });
    tearDownAll(AiAssertions.clearContext);
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
  // INV (behavioral): the no-inference contract is an invariant across all inputs.
  // Prompt states: "Do NOT estimate, assume, or infer any field. If not explicitly
  // provided, return null." and "route: ONLY if explicitly stated — do NOT assume oral."
  // These tests verify the model does not drift from that contract.

  group('[INV] parseMedication — no-inference rule', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'INV',
        contract: 'fields not explicitly stated in input must be null — model must never infer dose or route',
        implication: 'model infers a default route or dose, corrupting records with fabricated values',
      );
    });
    tearDownAll(AiAssertions.clearContext);
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

  // ── Word-order invariance ──────────────────────────────────────────────────
  // INV: input phrasing variation (word order, case) must not change dose/unit.
  // Medication dose is safety-critical — "500mg ibuprofen" and "ibuprofen 500mg"
  // must produce identical structured output.

  group('[INV] parseMedication — word-order and case invariance', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'INV',
        contract: 'word order and case must not change name, dose, or unit — "500mg drug" == "drug 500mg"',
        implication: 'users who phrase medication differently get wrong dose stored — safety-critical failure',
      );
    });
    tearDownAll(AiAssertions.clearContext);

    test(
      '"ibuprofen 500mg" vs "500mg ibuprofen": same dose and unit',
      () async {
        final forward = await ai.parseMedication(text: 'ibuprofen 500mg');
        final reversed = await ai.parseMedication(text: '500mg ibuprofen');
        AiAssertions.medicationSchema(forward);
        AiAssertions.medicationSchema(reversed);
        AiAssertions.medicationDose(forward, 500);
        AiAssertions.medicationDose(reversed, 500);
        AiAssertions.medicationUnit(forward, 'mg');
        AiAssertions.medicationUnit(reversed, 'mg');
      },
      skip: _skip,
    );

    test(
      '"Metformin 500mg" vs "500mg Metformin": same dose regardless of name-first vs dose-first',
      () async {
        final forward = await ai.parseMedication(text: 'Metformin 500mg');
        final reversed = await ai.parseMedication(text: '500mg Metformin');
        AiAssertions.medicationSchema(forward);
        AiAssertions.medicationSchema(reversed);
        AiAssertions.medicationDose(forward, 500);
        AiAssertions.medicationDose(reversed, 500);
      },
      skip: _skip,
    );

    test(
      '"IBUPROFEN 500MG" vs "ibuprofen 500mg": case must not affect dose or unit',
      () async {
        final upper = await ai.parseMedication(text: 'IBUPROFEN 500MG');
        final lower = await ai.parseMedication(text: 'ibuprofen 500mg');
        AiAssertions.medicationSchema(upper);
        AiAssertions.medicationSchema(lower);
        AiAssertions.medicationDose(upper, 500);
        AiAssertions.medicationDose(lower, 500);
        AiAssertions.medicationUnit(upper, 'mg');
        AiAssertions.medicationUnit(lower, 'mg');
      },
      skip: _skip,
    );
  });

  // ── Boundary value analysis ────────────────────────────────────────────────
  // BVA: extreme or ambiguous inputs must not crash the parser.
  // Dose=0, extreme doses, and food/drug ambiguity are the known boundary cases.

  group('[BVA] parseMedication — boundary values', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'BVA',
        contract: 'extreme or edge-case inputs must return a structured result (success or failure) — never crash',
        implication: 'malformed input causes an unhandled exception instead of a graceful error message',
      );
    });
    tearDownAll(AiAssertions.clearContext);

    test(
      '"Metformin 0mg": dose=0 is medically invalid — success=false or dose not positive',
      () async {
        final r = await ai.parseMedication(text: 'Metformin 0mg');
        expect(r, isNotNull);
        if (r.success) {
          // If model accepts it, dose must not be recorded as a positive value
          expect(
            r.dose == null || r.dose! <= 0,
            isTrue,
            reason: 'dose=0 is not a valid medication dose; model must not return a positive dose for "0mg" input',
          );
        } else {
          expect(r.errorMessage, isNotNull);
        }
      },
      skip: _skip,
    );

    test(
      '"Aspirin 50000mg": extreme dose — parses without crash, dose extracted if successful',
      () async {
        final r = await ai.parseMedication(text: 'Aspirin 50000mg');
        expect(r, isNotNull,
            reason: 'extreme dose must return a structured result, not throw');
        if (r.success) {
          AiAssertions.medicationDose(r, 50000);
          AiAssertions.medicationUnit(r, 'mg');
        } else {
          expect(r.errorMessage, isNotNull);
        }
      },
      skip: _skip,
    );

    test(
      '"Ginger root 500mg capsule": food/drug ambiguity — graceful result either way',
      () async {
        // Ginger root is both a food and a supplement. The model may succeed or
        // return failure. Either is acceptable — what is not acceptable is a crash.
        final r = await ai.parseMedication(text: 'Ginger root 500mg capsule');
        expect(r, isNotNull,
            reason: 'ambiguous food/drug input must return structured result, not throw');
        if (r.success) {
          expect(r.name, isNotEmpty,
              reason: 'on success, name must be populated');
        } else {
          expect(r.errorMessage, isNotNull);
        }
      },
      skip: _skip,
    );
  });

  // ── Edge cases ─────────────────────────────────────────────────────────────
  // BVA: null and empty are the hard boundary — must return failure, not crash.

  group('[BVA] parseMedication — null and empty input', () {
    setUpAll(() {
      AiAssertions.setContext(
        testTheory: 'BVA',
        contract: 'null or empty input returns success=false with errorMessage — never crashes',
        implication: 'empty submit from the UI causes an unhandled exception',
      );
    });
    tearDownAll(AiAssertions.clearContext);
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
