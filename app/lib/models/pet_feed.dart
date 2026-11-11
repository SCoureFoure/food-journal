import 'daily_goals.dart';

/// Today's feeding, worked out from the journal on every reload.
class PetFeed {
  final int mealsToday;
  final int waterMl;
  final int waterGoalMl;
  final int caloriesToday;
  final int? calorieGoal;

  const PetFeed({
    required this.mealsToday,
    required this.waterMl,
    required this.waterGoalMl,
    this.caloriesToday = 0,
    this.calorieGoal,
  });

  static const empty = PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: kDefaultWaterGoalMl);

  double get foodLevel {
    final goal = calorieGoal;
    if (goal == null || goal <= 0) return 0.0;
    return (caloriesToday / goal).clamp(0.0, 1.0).toDouble();
  }

  double get waterLevel {
    if (waterGoalMl <= 0) return 0.0;
    return (waterMl / waterGoalMl).clamp(0.0, 1.0).toDouble();
  }

  /// False when [previous] is null. True when meals, calories or water went up
  /// since [previous]; false otherwise (nothing went up).
  bool fedSince(PetFeed? previous) {
    if (previous == null) return false;
    return mealsToday > previous.mealsToday ||
        caloriesToday > previous.caloriesToday ||
        waterMl > previous.waterMl;
  }

  @override
  bool operator ==(Object other) =>
      other is PetFeed &&
      other.mealsToday == mealsToday &&
      other.waterMl == waterMl &&
      other.waterGoalMl == waterGoalMl &&
      other.caloriesToday == caloriesToday &&
      other.calorieGoal == calorieGoal;

  @override
  int get hashCode => Object.hash(mealsToday, waterMl, waterGoalMl, caloriesToday, calorieGoal);

  @override
  String toString() =>
      'PetFeed(meals: $mealsToday, kcal: $caloriesToday/$calorieGoal, waterMl: $waterMl, goalMl: $waterGoalMl)';
}
