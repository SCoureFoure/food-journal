import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/meal_entry.dart';

void main() {
  final base = MealEntry(
    id: 1,
    date: DateTime(2026, 6, 1),
    time: '12:00',
    mealType: 'Lunch',
    overallSymptoms: 'Bloating',
    rawInput: 'salad',
    createdAt: DateTime(2026, 6, 1, 12, 0),
    imageData: Uint8List.fromList([1, 2, 3]),
  );

  group('[DIR] MealEntry.copyWith — field replacement', () {
    test('copyWith id replaces id', () {
      final copy = base.copyWith(id: 99);
      expect(copy.id, 99);
      expect(copy.date, base.date);
      expect(copy.time, base.time);
    });

    test('copyWith date replaces date', () {
      final newDate = DateTime(2026, 12, 31);
      final copy = base.copyWith(date: newDate);
      expect(copy.date, newDate);
      expect(copy.id, base.id);
    });

    test('copyWith time replaces time', () {
      final copy = base.copyWith(time: '18:30');
      expect(copy.time, '18:30');
      expect(copy.mealType, base.mealType);
    });

    test('copyWith mealType replaces mealType', () {
      final copy = base.copyWith(mealType: 'Dinner');
      expect(copy.mealType, 'Dinner');
    });

    test('copyWith overallSymptoms replaces overallSymptoms', () {
      final copy = base.copyWith(overallSymptoms: 'None');
      expect(copy.overallSymptoms, 'None');
    });

    test('copyWith rawInput replaces rawInput', () {
      final copy = base.copyWith(rawInput: 'burger');
      expect(copy.rawInput, 'burger');
    });

    test('copyWith createdAt replaces createdAt', () {
      final now = DateTime(2026, 6, 6, 9, 0);
      final copy = base.copyWith(createdAt: now);
      expect(copy.createdAt, now);
    });

    test('copyWith imageData replaces imageData', () {
      final newImg = Uint8List.fromList([9, 8, 7]);
      final copy = base.copyWith(imageData: newImg);
      expect(copy.imageData, newImg);
    });
  });

  group('[INV] MealEntry.copyWith — unchanged fields preserved', () {
    test('no-arg copyWith preserves all fields', () {
      final copy = base.copyWith();
      expect(copy.id, base.id);
      expect(copy.date, base.date);
      expect(copy.time, base.time);
      expect(copy.mealType, base.mealType);
      expect(copy.overallSymptoms, base.overallSymptoms);
      expect(copy.rawInput, base.rawInput);
      expect(copy.createdAt, base.createdAt);
      expect(copy.imageData, base.imageData);
    });

    test('replacing one field does not alter others', () {
      final copy = base.copyWith(time: '07:00');
      expect(copy.id, base.id);
      expect(copy.date, base.date);
      expect(copy.mealType, base.mealType);
      expect(copy.overallSymptoms, base.overallSymptoms);
      expect(copy.rawInput, base.rawInput);
      expect(copy.createdAt, base.createdAt);
    });
  });

  group('[BVA] MealEntry.copyWith — null optional fields', () {
    test('entry with null optionals copies without error', () {
      final minimal = MealEntry(
        date: DateTime(2026, 1, 1),
        time: '08:00',
        mealType: 'Breakfast',
        createdAt: DateTime(2026, 1, 1, 8),
      );
      final copy = minimal.copyWith(time: '09:00');
      expect(copy.id, isNull);
      expect(copy.overallSymptoms, isNull);
      expect(copy.rawInput, isNull);
      expect(copy.imageData, isNull);
      expect(copy.time, '09:00');
    });
  });
}
