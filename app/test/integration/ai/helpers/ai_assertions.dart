import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/ai_service.dart';

/// Reusable invariant assertions for AI integration tests.
///
/// All methods call expect() directly — AI output is non-deterministic so we
/// test structural/relational invariants, never exact values.
class AiAssertions {
  // ─── MealParseResult ────────────────────────────────────────────────────────

  /// Core schema: success=true, title populated, ≥1 food item, all names non-empty,
  /// all numeric macro fields are null or non-negative.
  static void mealSchema(MealParseResult r) {
    expect(r.success, isTrue, reason: 'parseMeal returned success=false: ${r.errorMessage}');
    expect(r.title, isNotNull, reason: 'title should not be null on success');
    expect(r.title, isNotEmpty, reason: 'title should not be empty on success');
    expect(r.items, isNotNull, reason: 'items should not be null on success');
    expect(r.items!, isNotEmpty, reason: 'items list should not be empty on success');
    for (final item in r.items!) {
      expect(item.name, isNotEmpty, reason: 'every food item must have a name');
      _assertNonNegativeOrNull(item.calories?.toDouble(), 'calories', item.name);
      _assertNonNegativeOrNull(item.protein?.toDouble(), 'protein', item.name);
      _assertNonNegativeOrNull(item.carbs?.toDouble(), 'carbs', item.name);
      _assertNonNegativeOrNull(item.fat?.toDouble(), 'fat', item.name);
    }
    _emit({
      'title': r.title,
      'itemCount': r.items!.length,
      'items': r.items!.map((i) => {
        'name': i.name,
        'calories': i.calories,
        'protein': i.protein,
        'carbs': i.carbs,
        'fat': i.fat,
      }).toList(),
    });
  }

  /// Asserts result has at least [min] food items.
  static void mealMinItems(MealParseResult r, int min) {
    expect(
      r.items?.length ?? 0,
      greaterThanOrEqualTo(min),
      reason: 'expected at least $min food items, got ${r.items?.length}',
    );
  }

  /// Asserts that at least one food item has protein > fat (protein-dominant food).
  static void mealProteinDominant(MealParseResult r) {
    final dominant = r.items?.any((i) {
      final p = i.protein;
      final f = i.fat;
      return p != null && f != null && p > f;
    });
    expect(
      dominant,
      isTrue,
      reason: 'expected at least one item with protein > fat for protein-dominant input',
    );
  }

  /// Asserts that total calories across all items exceed [minTotal].
  static void mealCaloriesExceed(MealParseResult r, int minTotal) {
    final total = r.items?.fold<int>(0, (sum, i) => sum + (i.calories ?? 0)) ?? 0;
    expect(
      total,
      greaterThan(minTotal),
      reason: 'expected total calories > $minTotal, got $total',
    );
  }

  /// Asserts failure: success=false with an errorMessage.
  static void mealFailure(MealParseResult r) {
    expect(r.success, isFalse, reason: 'expected success=false for invalid input');
    expect(r.errorMessage, isNotEmpty, reason: 'expected non-empty errorMessage on failure');
    _emit({'success': false, 'errorMessage': r.errorMessage});
  }

  // ─── MedicationParseResult ──────────────────────────────────────────────────

  /// Core schema: success=true, name populated, dose null or positive.
  static void medicationSchema(MedicationParseResult r) {
    expect(r.success, isTrue, reason: 'parseMedication returned success=false: ${r.errorMessage}');
    expect(r.name, isNotNull, reason: 'name should not be null on success');
    expect(r.name, isNotEmpty, reason: 'name should not be empty on success');
    if (r.dose != null) {
      expect(r.dose!, greaterThan(0), reason: 'dose must be > 0 when present');
    }
    _emit({'name': r.name, 'dose': r.dose, 'unit': r.unit, 'route': r.route, 'notes': r.notes});
  }

  /// Asserts name contains [fragment] (case-insensitive).
  static void medicationNameContains(MedicationParseResult r, String fragment) {
    expect(
      r.name?.toLowerCase(),
      contains(fragment.toLowerCase()),
      reason: 'expected name to contain "$fragment", got "${r.name}"',
    );
  }

  /// Asserts dose matches [expected] within tolerance.
  static void medicationDose(MedicationParseResult r, double expected, {double tolerance = 0.1}) {
    expect(r.dose, isNotNull, reason: 'expected dose=$expected but dose is null');
    expect(
      r.dose!,
      closeTo(expected, tolerance),
      reason: 'expected dose≈$expected, got ${r.dose}',
    );
  }

  /// Asserts unit matches [expected] (case-insensitive).
  static void medicationUnit(MedicationParseResult r, String expected) {
    expect(
      r.unit?.toLowerCase(),
      equals(expected.toLowerCase()),
      reason: 'expected unit="$expected", got "${r.unit}"',
    );
  }

  /// Asserts route matches [expected] (case-insensitive).
  static void medicationRoute(MedicationParseResult r, String expected) {
    expect(
      r.route?.toLowerCase(),
      equals(expected.toLowerCase()),
      reason: 'expected route="$expected", got "${r.route}"',
    );
  }

  /// Asserts no-inference rule: dose must be null when not explicitly stated.
  static void medicationNoDoseInferred(MedicationParseResult r) {
    expect(r.dose, isNull, reason: 'dose must be null when not explicitly stated in input');
  }

  /// Asserts no-inference rule: route must be null when not explicitly stated.
  static void medicationNoRouteInferred(MedicationParseResult r) {
    expect(r.route, isNull, reason: 'route must be null when not explicitly stated — prompt forbids assuming "oral"');
  }

  /// Asserts failure: success=false with an errorMessage.
  static void medicationFailure(MedicationParseResult r) {
    expect(r.success, isFalse, reason: 'expected success=false for invalid input');
    expect(r.errorMessage, isNotEmpty, reason: 'expected non-empty errorMessage on failure');
    _emit({'success': false, 'errorMessage': r.errorMessage});
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  static void _emit(Map<String, dynamic> data) =>
      // ignore: avoid_print
      print(jsonEncode({'type': 'test_output', ...data}));

  static void _assertNonNegativeOrNull(double? value, String field, String itemName) {
    if (value != null) {
      expect(
        value,
        greaterThanOrEqualTo(0),
        reason: '$field for "$itemName" must be null or ≥ 0, got $value',
      );
    }
  }
}
