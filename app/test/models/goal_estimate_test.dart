import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/goal_estimate.dart';

const _maleBase = GoalProfile(
  weightLb: 180.0,
  heightIn: 70,
  age: 30,
  formula: BodyFormula.male,
  activity: ActivityLevel.moderate,
  goal: WeightGoal.lose1,
);

void main() {
  group('[MFT] estimateGoals — male, moderate, lose 1 lb/week (AC13)', () {
    // testTheory: minimum functionality — a typical profile gives the documented numbers.
    // contract: Mifflin-St Jeor BMR x activity + goal delta; protein 0.8 g/lb; fat 30% kcal.
    // implication: AC13 — the calculator's headline output is stable.
    test('180 lb, 70 in, 30 y -> 2263 kcal, 144 P, 253 C, 75 F, no water', () {
      expect(
        estimateGoals(_maleBase),
        const DailyGoals(calories: 2263, proteinG: 144, carbsG: 253, fatG: 75),
      );
      expect(estimateGoals(_maleBase).waterMl, isNull);
    });
  });

  group('[MFT] estimateGoals — female, light, maintain', () {
    // testTheory: minimum functionality — the female formula path.
    // contract: female offset -161 with light activity 1.375 and zero goal delta.
    // implication: a second formula/activity/goal combination produces its own numbers.
    test('150 lb, 65 in, 40 y -> 1858 kcal, 120 P, 205 C, 62 F', () {
      const p = GoalProfile(
        weightLb: 150.0,
        heightIn: 65,
        age: 40,
        formula: BodyFormula.female,
        activity: ActivityLevel.light,
        goal: WeightGoal.maintain,
      );
      expect(
        estimateGoals(p),
        const DailyGoals(calories: 1858, proteinG: 120, carbsG: 205, fatG: 62),
      );
    });
  });

  group('[BVA] estimateGoals — 1200 kcal floor (AC14)', () {
    // testTheory: boundary — raw estimate falls below kMinCalories.
    // contract: calories = max(1200, round(...)); macros derive from the floored value.
    // implication: AC14 — a small sedentary profile never gets a dangerously low target.
    test('110 lb, 60 in, 60 y, female, sedentary, lose 1 lb -> 1200 kcal floor', () {
      const p = GoalProfile(
        weightLb: 110.0,
        heightIn: 60,
        age: 60,
        formula: BodyFormula.female,
        activity: ActivityLevel.sedentary,
        goal: WeightGoal.lose1,
      );
      expect(
        estimateGoals(p),
        const DailyGoals(calories: 1200, proteinG: 88, carbsG: 122, fatG: 40),
      );
    });
  });

  group('[DIR] estimateGoals — goal order', () {
    // testTheory: directional — more aggressive weight goals yield fewer calories.
    // contract: calories rise monotonically lose1 < lose05 < maintain < gain05;
    //   gain05 - maintain equals 250 (within 1 kcal of rounding).
    // implication: the goal picker moves the target in the expected direction.
    test('calories strictly increase from lose1 to gain05', () {
      int cal(WeightGoal g) => estimateGoals(GoalProfile(
            weightLb: _maleBase.weightLb,
            heightIn: _maleBase.heightIn,
            age: _maleBase.age,
            formula: _maleBase.formula,
            activity: _maleBase.activity,
            goal: g,
          )).calories!;

      final lose1 = cal(WeightGoal.lose1);
      final lose05 = cal(WeightGoal.lose05);
      final maintain = cal(WeightGoal.maintain);
      final gain05 = cal(WeightGoal.gain05);

      expect(lose1 < lose05, isTrue);
      expect(lose05 < maintain, isTrue);
      expect(maintain < gain05, isTrue);
      expect((gain05 - maintain - 250).abs() <= 1, isTrue);
    });
  });

  group('[DIR] estimateGoals — activity order', () {
    // testTheory: directional — higher activity burns more, so the target rises.
    // contract: calories strictly increase sedentary < light < moderate < veryActive.
    // implication: the activity picker moves the target in the expected direction.
    test('calories strictly increase with activity level', () {
      int cal(ActivityLevel a) => estimateGoals(GoalProfile(
            weightLb: _maleBase.weightLb,
            heightIn: _maleBase.heightIn,
            age: _maleBase.age,
            formula: _maleBase.formula,
            activity: a,
            goal: WeightGoal.maintain,
          )).calories!;

      final sedentary = cal(ActivityLevel.sedentary);
      final light = cal(ActivityLevel.light);
      final moderate = cal(ActivityLevel.moderate);
      final veryActive = cal(ActivityLevel.veryActive);

      expect(sedentary < light, isTrue);
      expect(light < moderate, isTrue);
      expect(moderate < veryActive, isTrue);
    });
  });

  group('[INV] estimateGoals — formula gap', () {
    // testTheory: invariance — only the formula varies; the gap is fixed by the offsets.
    // contract: male - female = (5 - (-161)) x 1.2 = 199.2 kcal, within 1 kcal of rounding.
    // implication: the male/female toggle changes the target by the documented amount.
    test('same stats, maintain, sedentary: male - female is about 199 kcal', () {
      GoalProfile withFormula(BodyFormula f) => GoalProfile(
            weightLb: 180.0,
            heightIn: 70,
            age: 30,
            formula: f,
            activity: ActivityLevel.sedentary,
            goal: WeightGoal.maintain,
          );
      final male = estimateGoals(withFormula(BodyFormula.male)).calories!;
      final female = estimateGoals(withFormula(BodyFormula.female)).calories!;
      expect((male - female - 199).abs() <= 1, isTrue);
    });
  });

  group('[INV] estimateGoals — macro energy balance', () {
    // testTheory: invariance — macros reconstruct the calorie total.
    // contract: protein x 4 + carbs x 4 + fat x 9 is within 6 kcal of calories.
    // implication: the displayed macro targets are consistent with the calorie target.
    test('case 1 and case 2 profiles reconcile within 6 kcal', () {
      const female = GoalProfile(
        weightLb: 150.0,
        heightIn: 65,
        age: 40,
        formula: BodyFormula.female,
        activity: ActivityLevel.light,
        goal: WeightGoal.maintain,
      );

      for (final p in [_maleBase, female]) {
        final g = estimateGoals(p);
        final energy = g.proteinG! * 4 + g.carbsG! * 4 + g.fatG! * 9;
        expect((energy - g.calories!).abs() <= 6, isTrue);
      }
    });
  });

  group('[MFT] GoalProfile — encode/decode round trip', () {
    // testTheory: minimum functionality — serialisation is lossless.
    // contract: GoalProfile.decode(p.encode()) == p.
    // implication: the saved calculator inputs reload exactly.
    test('case 1 profile survives encode then decode', () {
      expect(GoalProfile.decode(_maleBase.encode()), _maleBase);
    });
  });

  group('[BVA] GoalProfile.decode — bad input yields null', () {
    // testTheory: boundary — absent, empty, malformed, incomplete, and unknown-enum input.
    // contract: decode never throws; each of these returns null.
    // implication: a corrupt or outdated saved profile only empties the calculator fields.
    test('null, empty, non-JSON, missing fields, unknown formula -> null', () {
      final unknownFormula =
          _maleBase.encode().replaceFirst('"formula":"male"', '"formula":"other"');

      expect(GoalProfile.decode(null), isNull);
      expect(GoalProfile.decode(''), isNull);
      expect(GoalProfile.decode('not json'), isNull);
      expect(GoalProfile.decode('{"weightLb":180}'), isNull);
      expect(GoalProfile.decode(unknownFormula), isNull);
    });
  });
}
