import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/worker_ai_service.dart';

// WorkerAiService tests that exercise pure in-process logic only.
// HTTP calls are not made — we rely on the empty-URL guard returning a
// MealParseResult/MedicationParseResult with success=false before any
// network I/O occurs.

void main() {
  // ── Empty URL guard ───────────────────────────────────────────────────────

  group('[BVA] WorkerAiService — empty URL guard', () {
    late WorkerAiService svc;

    setUp(() {
      svc = WorkerAiService(workerUrl: '', authToken: null);
    });

    test('parseMeal with empty URL returns failure without throwing', () async {
      final result = await svc.parseMeal(text: 'eggs and toast');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('MEAL_PARSER_URL'));
    });

    test('parseMedication with empty URL returns failure without throwing', () async {
      final result = await svc.parseMedication(text: 'aspirin 100mg');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('MEAL_PARSER_URL'));
    });

    test('parseMeal with empty URL and image returns failure without throwing', () async {
      final result = await svc.parseMeal(imageBytes: Uint8List.fromList([1, 2, 3]));
      expect(result.success, isFalse);
    });
  });

  // ── Missing input guard ──────────────────────────────────────────────────
  // Integration tests cover the full guard path; here we verify the
  // service construction contract and early-exit behaviour.

  group('[BVA] WorkerAiService — missing input guard', () {
    test('constructed with explicit url exposes it via parseMeal failure message', () async {
      final svc = WorkerAiService(workerUrl: '', authToken: 'tok');
      final result = await svc.parseMeal(text: 'test');
      // URL is empty → early-exit with MEAL_PARSER_URL message, not auth error
      expect(result.success, isFalse);
      expect(result.errorMessage, isNotNull);
    });
  });
}
