import 'dart:convert';
import 'dart:math' as math;

import 'daily_goals.dart';

const double kLbPerKg = 2.20462;
const double kCmPerIn = 2.54;

/// Lowest calorie target the calculator will suggest.
const int kMinCalories = 1200;

/// Activity multipliers applied to resting burn (BMR) to get daily burn (TDEE).
enum ActivityLevel {
  sedentary(1.2, 'Sedentary (little exercise)'),
  light(1.375, 'Light (1–3 days a week)'),
  moderate(1.55, 'Moderate (3–5 days a week)'),
  veryActive(1.725, 'Very active (6–7 days a week)');

  final double factor;
  final String label;
  const ActivityLevel(this.factor, this.label);
}

/// Mifflin-St Jeor constant. The formula has two variants; the user picks one.
enum BodyFormula {
  male(5, 'Male formula'),
  female(-161, 'Female formula');

  final int offset;
  final String label;
  const BodyFormula(this.offset, this.label);
}

/// Daily calorie change for a weekly weight goal (about 3500 kcal per lb).
enum WeightGoal {
  lose1(-500, 'Lose 1 lb a week'),
  lose05(-250, 'Lose 0.5 lb a week'),
  maintain(0, 'Maintain weight'),
  gain05(250, 'Gain 0.5 lb a week');

  final int delta;
  final String label;
  const WeightGoal(this.delta, this.label);
}

/// Calculator inputs. Imperial units, matching the app's oz water display.
class GoalProfile {
  final double weightLb;
  final int heightIn;
  final int age;
  final BodyFormula formula;
  final ActivityLevel activity;
  final WeightGoal goal;

  const GoalProfile({
    required this.weightLb,
    required this.heightIn,
    required this.age,
    required this.formula,
    required this.activity,
    required this.goal,
  });

  Map<String, Object> toJson() => {
        'weightLb': weightLb,
        'heightIn': heightIn,
        'age': age,
        'formula': formula.name,
        'activity': activity.name,
        'goal': goal.name,
      };

  String encode() => jsonEncode(toJson());

  /// Returns null for malformed or outdated input instead of throwing,
  /// so a bad saved profile only means empty calculator fields.
  static GoalProfile? decode(String? source) {
    if (source == null || source.isEmpty) return null;
    try {
      final m = jsonDecode(source) as Map<String, dynamic>;
      return GoalProfile(
        weightLb: (m['weightLb'] as num).toDouble(),
        heightIn: m['heightIn'] as int,
        age: m['age'] as int,
        formula: BodyFormula.values.byName(m['formula'] as String),
        activity: ActivityLevel.values.byName(m['activity'] as String),
        goal: WeightGoal.values.byName(m['goal'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GoalProfile &&
      other.weightLb == weightLb &&
      other.heightIn == heightIn &&
      other.age == age &&
      other.formula == formula &&
      other.activity == activity &&
      other.goal == goal;

  @override
  int get hashCode => Object.hash(weightLb, heightIn, age, formula, activity, goal);
}

/// Mifflin-St Jeor estimate. Water is left null: the calculator does not set it.
///
/// calories = max(kMinCalories, round(BMR × activity + goal delta))
/// protein  = round(0.8 g × weight in lb)
/// fat      = round(30% of calories ÷ 9)
/// carbs    = remaining calories ÷ 4, never below 0
DailyGoals estimateGoals(GoalProfile p) {
  final kg = p.weightLb / kLbPerKg;
  final cm = p.heightIn * kCmPerIn;
  final bmr = 10 * kg + 6.25 * cm - 5 * p.age + p.formula.offset;
  final calories = math.max(kMinCalories, (bmr * p.activity.factor + p.goal.delta).round());
  final protein = (0.8 * p.weightLb).round();
  final fat = (calories * 0.30 / 9).round();
  final carbs = math.max(0, ((calories - protein * 4 - fat * 9) / 4).round());
  return DailyGoals(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat);
}
