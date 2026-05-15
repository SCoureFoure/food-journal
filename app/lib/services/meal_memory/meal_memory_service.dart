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
  // Gemini prompt. Returns null if no matching fingerprints exist.
  Future<String?> buildContextSnippet(String input) async {
    final profile = detectReferencesCached(
      input,
      mealRules,
      temporalKeys: temporalKeys,
      mealTypeKeys: mealTypeKeys,
    );
    if (!profile.hasTemporalRef) return null;

    final spec = buildQuerySpec(profile);
    final rows = await _queryFingerprints(spec);
    if (rows.isEmpty) return null;

    final now = DateTime.now();
    final buf = StringBuffer('Recent meals:\n');
    for (final row in rows) {
      final label = _dateLabel(row.date, now);
      final type = row.mealType != null ? ' ${row.mealType}' : '';
      final macros = _formatMacros(row.totalCals, row.totalProtein);
      buf.writeln('- $label$type: ${row.foodsSummary}$macros');
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
    final rows = await _queryFingerprints(spec);
    final now = DateTime.now();
    return rows
        .map((r) => MealSuggestion(
              mealId: r.mealId,
              dateLabel: _dateLabel(r.date, now),
              mealType: r.mealType,
              foodsSummary: r.foodsSummary,
              totalCals: r.totalCals,
              totalProtein: r.totalProtein?.round(),
            ))
        .toList();
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

  Future<List<db.MealFingerprint>> _queryFingerprints(MealQuerySpec spec) async {
    final now = DateTime.now();
    final query = _db.select(_db.mealFingerprints);

    if (spec.dateOffset != null) {
      final target = now.subtract(Duration(days: spec.dateOffset!));
      query.where((t) => t.date.equals(_toDateString(target)));
    }

    if (spec.mealType != null) {
      query.where((t) => t.mealType.equals(spec.mealType!));
    }

    query
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(5);

    final rows = await query.get();

    // Fallback: if specific date returned nothing, return most recent entries
    if (rows.isEmpty) {
      return (_db.select(_db.mealFingerprints)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(5))
          .get();
    }
    return rows;
  }

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

  String _formatMacros(int? cals, double? protein) {
    if (cals == null && protein == null) return '';
    final parts = <String>[];
    if (cals != null) parts.add('$cals cal');
    if (protein != null) parts.add('${protein.round()}g protein');
    return ' (${parts.join(', ')})';
  }
}
