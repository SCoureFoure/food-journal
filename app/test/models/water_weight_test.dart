import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';

WaterLog _water({required int amountMl}) => WaterLog(
      date: DateTime(2026, 5, 18),
      time: '8:00 AM',
      amountMl: amountMl,
      createdAt: DateTime(2026, 5, 18, 8),
    );

WeightLog _weight({required double value, required String unit}) => WeightLog(
      date: DateTime(2026, 5, 18),
      time: '9:00 AM',
      weightValue: value,
      unit: unit,
      createdAt: DateTime(2026, 5, 18, 9),
    );

void main() {
  // ── WaterLog.amountOz ──────────────────────────────────────────────────────

  group('[INV] WaterLog.amountOz — ml → oz conversion', () {
    test('237 ml rounds to 8 oz', () {
      expect(_water(amountMl: 237).amountOz.round(), 8);
    });

    test('473 ml rounds to 16 oz', () {
      expect(_water(amountMl: 473).amountOz.round(), 16);
    });

    test('946 ml rounds to 32 oz', () {
      expect(_water(amountMl: 946).amountOz.round(), 32);
    });

    test('1893 ml rounds to 64 oz (daily goal)', () {
      expect(_water(amountMl: 1893).amountOz.round(), 64);
    });
  });

  // ── WaterLog.displayOz ────────────────────────────────────────────────────

  group('[INV] WaterLog.displayOz — display string', () {
    test('237 ml displays as "8 oz"', () {
      expect(_water(amountMl: 237).displayOz, '8 oz');
    });

    test('710 ml displays as "24 oz"', () {
      expect(_water(amountMl: 710).displayOz, '24 oz');
    });
  });

  // ── WaterLog totals — aggregate helper ────────────────────────────────────

  group('[MFT] WaterLog — daily total calculation', () {
    test('sum of amountMl across logs equals total', () {
      final logs = [
        _water(amountMl: 237),
        _water(amountMl: 473),
        _water(amountMl: 473),
      ];
      final total = logs.fold(0, (sum, l) => sum + l.amountMl);
      expect(total, 1183);
    });

    test('empty list sums to zero', () {
      final logs = <WaterLog>[];
      expect(logs.fold(0, (sum, l) => sum + l.amountMl), 0);
    });
  });

  // ── WeightLog.displayWeight — integer value ────────────────────────────────

  group('[INV] WeightLog.displayWeight — integer weight', () {
    test('whole lbs shows no decimal', () {
      expect(_weight(value: 182.0, unit: 'lbs').displayWeight, '182 lbs');
    });

    test('whole kg shows no decimal', () {
      expect(_weight(value: 80.0, unit: 'kg').displayWeight, '80 kg');
    });
  });

  // ── WeightLog.displayWeight — decimal value ───────────────────────────────

  group('[INV] WeightLog.displayWeight — decimal weight', () {
    test('fractional lbs shows one decimal place', () {
      expect(_weight(value: 182.5, unit: 'lbs').displayWeight, '182.5 lbs');
    });

    test('fractional kg shows one decimal place', () {
      expect(_weight(value: 75.3, unit: 'kg').displayWeight, '75.3 kg');
    });
  });

  // ── WeightLog unit field ───────────────────────────────────────────────────

  group('[INV] WeightLog — unit field preserved', () {
    test('lbs unit stored and displayed', () {
      final log = _weight(value: 175.0, unit: 'lbs');
      expect(log.unit, 'lbs');
      expect(log.displayWeight.endsWith('lbs'), isTrue);
    });

    test('kg unit stored and displayed', () {
      final log = _weight(value: 79.5, unit: 'kg');
      expect(log.unit, 'kg');
      expect(log.displayWeight.endsWith('kg'), isTrue);
    });
  });
}
