/// The journal's original fixed water goal (64 oz). Used when the user has
/// never saved a water target.
const int kDefaultWaterGoalMl = 1893;

const double kMlPerOz = 29.5735;

/// Daily targets. Every target is optional; null means "not set" and the
/// Goals panel hides that metric.
class DailyGoals {
  final int? calories;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final int? waterMl;

  const DailyGoals({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.waterMl,
  });

  static const none = DailyGoals();

  bool get isEmpty =>
      calories == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      waterMl == null;

  /// The water target the day's water bar fills toward, set or not.
  int get effectiveWaterMl => waterMl ?? kDefaultWaterGoalMl;

  @override
  bool operator ==(Object other) =>
      other is DailyGoals &&
      other.calories == calories &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.waterMl == waterMl;

  @override
  int get hashCode => Object.hash(calories, proteinG, carbsG, fatG, waterMl);

  @override
  String toString() =>
      'DailyGoals(cal: $calories, p: $proteinG, c: $carbsG, f: $fatG, waterMl: $waterMl)';
}

/// One saved change of targets. A save stores all five targets, so a snapshot
/// alone says what applied from [effectiveDate] on.
class GoalSnapshot {
  final int? id;

  /// Local midnight of the day the targets were saved.
  final DateTime effectiveDate;
  final DailyGoals goals;
  final DateTime createdAt;

  const GoalSnapshot({
    this.id,
    required this.effectiveDate,
    required this.goals,
    required this.createdAt,
  });
}

/// Today's intake, the amounts the Goals panel bars fill with.
class GoalIntake {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;

  const GoalIntake({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.waterMl = 0,
  });
}

/// The targets that applied on [day]: the snapshot with the greatest
/// (effectiveDate, id) whose effectiveDate is on or before [day]'s date.
/// [DailyGoals.none] when no snapshot qualifies. [history] may be in any order.
DailyGoals goalsForDate(List<GoalSnapshot> history, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  GoalSnapshot? best;
  for (final s in history) {
    if (s.effectiveDate.isAfter(dayStart)) continue;
    if (best == null) {
      best = s;
      continue;
    }
    final cmp = s.effectiveDate.compareTo(best.effectiveDate);
    if (cmp > 0 || (cmp == 0 && (s.id ?? 0) > (best.id ?? 0))) best = s;
  }
  return best?.goals ?? DailyGoals.none;
}
