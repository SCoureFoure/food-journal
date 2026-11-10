import 'daily_goals.dart';

/// Meals that fill the pet's Food meter for one day. Arbitrary; expected to
/// become adjustable.
const int kPetMealsPerDay = 3;

/// Today's feeding, worked out from the journal on every reload.
class PetFeed {
  final int mealsToday;
  final int waterMl;
  final int waterGoalMl;

  const PetFeed({required this.mealsToday, required this.waterMl, required this.waterGoalMl});

  static const empty = PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: kDefaultWaterGoalMl);

  double get foodLevel => (mealsToday / kPetMealsPerDay).clamp(0.0, 1.0).toDouble();

  double get waterLevel {
    if (waterGoalMl <= 0) return 0.0;
    return (waterMl / waterGoalMl).clamp(0.0, 1.0).toDouble();
  }

  /// False when [previous] is null. True when meals or water went up since
  /// [previous]; false otherwise (equal, or fewer meals with no more water).
  bool fedSince(PetFeed? previous) {
    if (previous == null) return false;
    return mealsToday > previous.mealsToday || waterMl > previous.waterMl;
  }

  @override
  bool operator ==(Object other) =>
      other is PetFeed &&
      other.mealsToday == mealsToday &&
      other.waterMl == waterMl &&
      other.waterGoalMl == waterGoalMl;

  @override
  int get hashCode => Object.hash(mealsToday, waterMl, waterGoalMl);

  @override
  String toString() => 'PetFeed(meals: $mealsToday, waterMl: $waterMl, goalMl: $waterGoalMl)';
}
