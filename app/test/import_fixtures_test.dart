import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/saved_item.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/services/export_service.dart';
import 'package:food_journal/services/import_service.dart';

const _dir = 'test/fixtures/import';

String _read(String name) => File('$_dir/$name').readAsStringSync();

void main() {
  // ─── Valid fixtures parse without error ───────────────────────────────────

  group('[MFT] valid fixtures parse', () {
    const valid = [
      'empty.json',
      'single_meal.json',
      'full_week.json',
      'flagged_memory.json',
      'reactions_severe.json',
      'meds_only.json',
      'water_weight_saved.json',
      'dupes_vs_sample.json',
      'legacy_v1.json',
      'lenient_enum.json',
    ];

    for (final name in valid) {
      test('$name parses', () {
        expect(() => ImportService.parseJson(_read(name)), returnsNormally);
      });
    }

    test('empty.json yields all-empty payload', () {
      final p = ImportService.parseJson(_read('empty.json'));
      expect(p.meals, isEmpty);
      expect(p.medications, isEmpty);
      expect(p.foodMemories, isEmpty);
      expect(p.waterLogs, isEmpty);
      expect(p.weightLogs, isEmpty);
      expect(p.savedItems, isEmpty);
    });

    test('full_week.json spans 5 meals across the range', () {
      final p = ImportService.parseJson(_read('full_week.json'));
      expect(p.meals.length, 5);
    });

    test('flagged_memory.json has 2 flagged memories', () {
      final p = ImportService.parseJson(_read('flagged_memory.json'));
      final flagged = p.foodMemories.where((m) => m.flagged).length;
      expect(flagged, 2);
    });

    test('legacy_v1.json reports version 1 and still parses meals', () {
      final p = ImportService.parseJson(_read('legacy_v1.json'));
      expect(p.version, 1);
      expect(p.meals.length, 1);
      expect(p.waterLogs, isEmpty);
    });
  });

  // ─── New v3 types ─────────────────────────────────────────────────────────

  group('[MFT] water / weight / saved_items parsing', () {
    late ImportPayload p;
    setUp(() => p = ImportService.parseJson(_read('water_weight_saved.json')));

    test('water logs parsed', () {
      expect(p.waterLogs.length, 3);
      expect(p.waterLogs.first.amountMl, 250);
      expect(p.waterLogs.first.time, '9:00 AM');
      expect(p.waterLogs[1].notes, 'with lunch');
    });

    test('weight logs parsed', () {
      expect(p.weightLogs.length, 2);
      expect(p.weightLogs.first.weightValue, 168.4);
      expect(p.weightLogs.first.unit, 'lbs');
    });

    test('saved items parsed with components', () {
      expect(p.savedItems.length, 2);
      final shake = p.savedItems.first;
      expect(shake.name, 'Protein shake');
      expect(shake.calories, 300);
      expect(shake.components, containsAll(['whey protein', 'almond milk', 'banana']));
    });
  });

  // ─── Lenient degradation ──────────────────────────────────────────────────

  group('[BVA] lenient_enum.json degrades, does not throw', () {
    test('unknown reaction → pending', () {
      final p = ImportService.parseJson(_read('lenient_enum.json'));
      expect(p.meals.first.foodItems.first.reaction, ReactionLevel.pending);
    });

    test('unknown severity → pending', () {
      final p = ImportService.parseJson(_read('lenient_enum.json'));
      expect(p.meals.first.reactionLogs.first.severity, ReactionLevel.pending);
    });

    test('unknown mood → null', () {
      final p = ImportService.parseJson(_read('lenient_enum.json'));
      expect(p.meals.first.reactionLogs.first.mood, isNull);
    });
  });

  // ─── Malformed fixtures throw ─────────────────────────────────────────────

  group('[BVA] malformed fixtures throw', () {
    const malformed = [
      'missing_required_field.json',
      'bad_date.json',
      'wrong_type_dose.json',
      'water_missing_amount.json',
      'not_json.json',
    ];

    for (final name in malformed) {
      test('malformed/$name throws', () {
        expect(() => ImportService.parseJson(_read('malformed/$name')), throwsA(anything));
      });
    }
  });

  // ─── Round-trip for new types via Export statics ──────────────────────────

  group('[INV] export → parse round-trip (v3 types)', () {
    test('water log survives round-trip', () {
      final log = WaterLog(
        date: DateTime(2026, 6, 1),
        time: '9:00 AM',
        amountMl: 500,
        notes: 'big glass',
        createdAt: DateTime(2026, 6, 1, 9),
      );
      final json = ExportService.waterLogToJson(log);
      final payload = ImportService.parseJson(
        '{"version":3,"meals":[],"medications":[],"food_memories":[],"water_logs":[${_encode(json)}]}',
      );
      final out = payload.waterLogs.single;
      expect(out.amountMl, 500);
      expect(out.notes, 'big glass');
      expect(out.date, DateTime(2026, 6, 1));
    });

    test('weight log survives round-trip', () {
      final log = WeightLog(
        date: DateTime(2026, 6, 2),
        time: '7:00 AM',
        weightValue: 167.2,
        unit: 'lbs',
        createdAt: DateTime(2026, 6, 2, 7),
      );
      final json = ExportService.weightLogToJson(log);
      final payload = ImportService.parseJson(
        '{"version":3,"meals":[],"medications":[],"food_memories":[],"weight_logs":[${_encode(json)}]}',
      );
      final out = payload.weightLogs.single;
      expect(out.weightValue, 167.2);
      expect(out.unit, 'lbs');
    });

    test('saved item survives round-trip', () {
      final item = SavedItem(
        name: 'Protein shake',
        calories: 300,
        protein: 40,
        components: const ['whey', 'milk'],
        createdAt: DateTime(2026, 5, 20),
      );
      final json = ExportService.savedItemToJson(item);
      final payload = ImportService.parseJson(
        '{"version":3,"meals":[],"medications":[],"food_memories":[],"saved_items":[${_encode(json)}]}',
      );
      final out = payload.savedItems.single;
      expect(out.name, 'Protein shake');
      expect(out.calories, 300);
      expect(out.components, ['whey', 'milk']);
    });
  });
}

String _encode(Map<String, dynamic> m) => jsonEncode(m);
