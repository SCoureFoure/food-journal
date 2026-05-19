import 'package:drift/drift.dart';

import '../../models/food_item.dart';
import '../../models/meal_entry.dart';
import '../database/app_database.dart' as db;
import 'meal_reference_rules.dart';
import 'reference_engine.dart';

class MealSuggestion {
  final int mealId;
  final String dateLabel;
  final String? mealType;
  final String foodsSummary;
  final int? totalCals;
  final int? totalProtein;

  const MealSuggestion({
    required this.mealId,
    required this.dateLabel,
    this.mealType,
    required this.foodsSummary,
    this.totalCals,
    this.totalProtein,
  });

  String get displayLine {
    final type = mealType != null ? ' ${_capitalize(mealType!)}' : '';
    final macros = <String>[
      if (totalCals != null) '$totalCals cal',
      if (totalProtein != null) '${totalProtein}g protein',
    ];
    final macroStr = macros.isEmpty ? '' : ' (${macros.join(', ')})';
    return '$dateLabel$type — $foodsSummary$macroStr';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class MealMemoryService {
  final _db = db.AppDatabase();

  static const _windowSize = 40;

  // Returns true if [input] appears to reference a past meal.
  // Fast: runs compiled regex, no DB access.
  bool isReferential(String input) {
    if (input.trim().isEmpty) return false;
    final profile = detectReferencesCached(
      input,
      mealRules,
      temporalKeys: temporalKeys,
      mealTypeKeys: mealTypeKeys,
    );
    return profile.hasTemporalRef;
  }

  // Builds a compact context string (<200 tokens) for injection into the
  // AI prompt. Queries meals+food_items directly so pre-fingerprint meals
  // (schema v4 not backfilled) are included.
  Future<String?> buildContextSnippet(String input) async {
    final profile = detectReferencesCached(
      input,
      mealRules,
      temporalKeys: temporalKeys,
      mealTypeKeys: mealTypeKeys,
    );
    if (!profile.hasTemporalRef) return null;

    final spec = buildQuerySpec(profile);
    final now = DateTime.now();

    final query = _db.select(_db.meals);
    if (spec.dateOffset != null) {
      final target = now.subtract(Duration(days: spec.dateOffset!));
      final dayStart = DateTime(target.year, target.month, target.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      query.where(
        (t) => t.date.isBiggerOrEqualValue(dayStart) & t.date.isSmallerThanValue(dayEnd),
      );
    }
    if (spec.mealType != null) {
      // meals table stores title-case ("Dinner"); spec produces lowercase ("dinner")
      final titleType = spec.mealType![0].toUpperCase() + spec.mealType!.substring(1);
      query.where((t) => t.mealType.equals(titleType));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(5);

    var mealRows = await query.get();

    // Fallback: specific date/type returned nothing → most recent 5 meals
    if (mealRows.isEmpty) {
      mealRows = await (_db.select(_db.meals)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(5))
          .get();
    }
    if (mealRows.isEmpty) return null;

    final buf = StringBuffer('Recent meals:\n');
    for (final meal in mealRows) {
      final items = await (_db.select(_db.foodItems)
            ..where((t) => t.mealId.equals(meal.id)))
          .get();
      final label = _dateLabel(_toDateString(meal.date), now);
      final type = ' ${meal.mealType}';
      if (items.isEmpty) {
        buf.writeln('- $label$type: unknown');
      } else {
        final itemStrs = items.map((f) {
          final parts = <String>[];
          if (f.calories != null) parts.add('${f.calories} cal');
          if (f.protein != null) parts.add('${f.protein}g prot');
          if (f.carbs != null) parts.add('${f.carbs}g carbs');
          if (f.fat != null) parts.add('${f.fat}g fat');
          final macroStr = parts.isEmpty ? '' : ' (${parts.join(', ')})';
          return '${f.name}$macroStr';
        }).join('; ');
        buf.writeln('- $label$type: $itemStrs');
      }
    }
    return buf.toString().trim();
  }

  // Returns candidate past meals for the "did you mean?" quick-copy UI.
  // Pure local path — no AI call. Returns [] if input is not referential.
  Future<List<MealSuggestion>> findReferentialMeals(String input) async {
    if (!isReferential(input)) return [];
    final profile = detectReferencesCached(
      input,
      mealRules,
      temporalKeys: temporalKeys,
      mealTypeKeys: mealTypeKeys,
    );
    final spec = buildQuerySpec(profile);
    final now = DateTime.now();

    final query = _db.select(_db.meals);
    if (spec.dateOffset != null) {
      final target = now.subtract(Duration(days: spec.dateOffset!));
      final dayStart = DateTime(target.year, target.month, target.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      query.where(
        (t) => t.date.isBiggerOrEqualValue(dayStart) & t.date.isSmallerThanValue(dayEnd),
      );
    }
    if (spec.mealType != null) {
      final titleType = spec.mealType![0].toUpperCase() + spec.mealType!.substring(1);
      query.where((t) => t.mealType.equals(titleType));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.date)])
      ..limit(5);

    var mealRows = await query.get();
    if (mealRows.isEmpty) {
      mealRows = await (_db.select(_db.meals)
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(5))
          .get();
    }

    final suggestions = <MealSuggestion>[];
    for (final meal in mealRows) {
      final items = await (_db.select(_db.foodItems)
            ..where((t) => t.mealId.equals(meal.id)))
          .get();
      final foodsSummary =
          items.isNotEmpty ? items.map((f) => f.name).join(', ') : 'unknown';
      final totalCals = items.fold<int>(0, (s, f) => s + (f.calories ?? 0));
      final totalProtein =
          items.fold<double>(0.0, (s, f) => s + (f.protein?.toDouble() ?? 0.0));
      suggestions.add(MealSuggestion(
        mealId: meal.id,
        dateLabel: _dateLabel(_toDateString(meal.date), now),
        mealType: meal.mealType,
        foodsSummary: foodsSummary,
        totalCals: totalCals > 0 ? totalCals : null,
        totalProtein: totalProtein > 0 ? totalProtein.round() : null,
      ));
    }
    return suggestions;
  }

  // Called after every meal save. Inserts a fingerprint row and prunes the
  // rolling window to [_windowSize] rows.
  Future<void> recordFingerprint(MealEntry meal, List<FoodItem> items) async {
    if (meal.id == null) return;

    final foodsSummary = items.map((f) => f.name).join(', ');
    final totalCals = items.fold<int>(0, (sum, f) => sum + (f.calories ?? 0));
    final totalProtein = items.fold<double>(0.0, (sum, f) => sum + (f.protein ?? 0));

    await _db.into(_db.mealFingerprints).insert(
      db.MealFingerprintsCompanion.insert(
        mealId: meal.id!,
        date: _toDateString(meal.date),
        mealType: Value(meal.mealType.toLowerCase()),
        foodsSummary: foodsSummary.isEmpty ? 'unknown' : foodsSummary,
        totalCals: Value(totalCals > 0 ? totalCals : null),
        totalProtein: Value(totalProtein > 0 ? totalProtein : null),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    // Prune oldest rows beyond the rolling window
    final all = await (_db.select(_db.mealFingerprints)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (all.length > _windowSize) {
      final toDelete = all.skip(_windowSize).map((r) => r.id).toList();
      await (_db.delete(_db.mealFingerprints)..where((t) => t.id.isIn(toDelete))).go();
    }
  }

  // ─── Private ────────────────────────────────────────────────────────────────

  String _toDateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  String _dateLabel(String dateStr, DateTime now) {
    final today = _toDateString(now);
    final yesterday = _toDateString(now.subtract(const Duration(days: 1)));
    if (dateStr == today) return 'Today';
    if (dateStr == yesterday) return 'Yesterday';
    try {
      final parts = dateStr.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      const dayNames = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
      ];
      return dayNames[dt.weekday - 1];
    } catch (_) {
      return dateStr;
    }
  }

}
