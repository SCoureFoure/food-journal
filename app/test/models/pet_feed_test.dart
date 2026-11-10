import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pet_feed.dart';

void main() {
  group('[MFT] PetFeed — foodLevel', () {
    test('0 kcal against a 2000 goal gives 0.0', () {
      // testTheory: minimum functionality — empty day, empty food meter.
      // contract: caloriesToday 0, calorieGoal 2000 → foodLevel 0.0.
      // implication: AC1 — the Food meter starts empty.
      expect(const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893, calorieGoal: 2000).foodLevel, 0.0);
    });

    test('1450 kcal against a 2000 goal gives its ratio', () {
      // testTheory: minimum functionality — partial intake shows its ratio.
      // contract: caloriesToday 1450, calorieGoal 2000 → foodLevel closeTo(0.725, 1e-9).
      // implication: AC1 — calories advance the Food meter against the goal.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 0, waterGoalMl: 1893, caloriesToday: 1450, calorieGoal: 2000).foodLevel,
        closeTo(0.725, 1e-9),
      );
    });

    test('2000 kcal against a 2000 goal gives 1.0', () {
      // testTheory: boundary value — exactly the calorie goal.
      // contract: caloriesToday 2000, calorieGoal 2000 → foodLevel 1.0.
      // implication: AC1 — reaching the goal fills the Food meter.
      expect(
        const PetFeed(mealsToday: 3, waterMl: 0, waterGoalMl: 1893, caloriesToday: 2000, calorieGoal: 2000).foodLevel,
        1.0,
      );
    });

    test('2150 kcal against a 2000 goal clamps to 1.0', () {
      // testTheory: boundary value — above the calorie goal.
      // contract: caloriesToday 2150, calorieGoal 2000 → foodLevel 1.0 (clamped).
      // implication: AC1 — extra calories do not overflow the Food meter.
      expect(
        const PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893, caloriesToday: 2150, calorieGoal: 2000).foodLevel,
        1.0,
      );
    });

    test('no calorie goal gives 0.0', () {
      // testTheory: boundary value — no goal set, so no ratio exists.
      // contract: caloriesToday 1450, calorieGoal omitted → foodLevel 0.0.
      // implication: AC1 — an unset calorie goal leaves the Food meter empty.
      expect(const PetFeed(mealsToday: 2, waterMl: 0, waterGoalMl: 1893, caloriesToday: 1450).foodLevel, 0.0);
    });

    test('calorie goal 0 gives 0.0', () {
      // testTheory: boundary value — zero goal must not divide by zero.
      // contract: caloriesToday 1450, calorieGoal 0 → foodLevel 0.0.
      // implication: AC1 — a zero calorie goal cannot crash the pet view.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 0, waterGoalMl: 1893, caloriesToday: 1450, calorieGoal: 0).foodLevel,
        0.0,
      );
    });
  });

  group('[MFT] PetFeed — waterLevel', () {
    test('946 of 1893 ml gives its ratio', () {
      // testTheory: minimum functionality — partial water shows its ratio.
      // contract: waterMl 946, goal 1893 → waterLevel closeTo(946/1893, 1e-9).
      // implication: AC2 — the Water meter reflects intake against the goal.
      expect(const PetFeed(mealsToday: 0, waterMl: 946, waterGoalMl: 1893).waterLevel, closeTo(946 / 1893, 1e-9));
    });

    test('over goal clamps to 1.0', () {
      // testTheory: boundary value — water above goal.
      // contract: waterMl 2000, goal 1893 → waterLevel 1.0.
      // implication: AC2 — over-goal water does not overflow the Water meter.
      expect(const PetFeed(mealsToday: 0, waterMl: 2000, waterGoalMl: 1893).waterLevel, 1.0);
    });

    test('goal 0 gives 0.0', () {
      // testTheory: boundary value — zero goal must not divide by zero.
      // contract: waterGoalMl 0 → waterLevel 0.0.
      // implication: AC2 — an unset water goal cannot crash the pet view.
      expect(const PetFeed(mealsToday: 0, waterMl: 500, waterGoalMl: 0).waterLevel, 0.0);
    });

    test('zero water gives 0.0', () {
      // testTheory: boundary value — no water logged.
      // contract: waterMl 0, goal 1893 → waterLevel 0.0.
      // implication: AC2 — an empty day shows an empty Water meter.
      expect(const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893).waterLevel, 0.0);
    });
  });

  group('[DIR] PetFeed — fedSince', () {
    const previous = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650);

    test('a new meal counts as fed', () {
      // testTheory: directional — meals rising is a feeding event.
      // contract: meals 2 → 3, water and kcal unchanged → fedSince true.
      // implication: AC3 — logging a meal feeds the pet.
      expect(
        const PetFeed(mealsToday: 3, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650).fedSince(previous),
        isTrue,
      );
    });

    test('more water counts as fed', () {
      // testTheory: directional — water rising is a feeding event.
      // contract: waterMl 946 → 1196, meals and kcal unchanged → fedSince true.
      // implication: AC3 — logging water feeds the pet.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 1196, waterGoalMl: 1893, caloriesToday: 650).fedSince(previous),
        isTrue,
      );
    });

    test('more calories counts as fed', () {
      // testTheory: directional — calories rising is a feeding event.
      // contract: caloriesToday 650 → 900, meals and water unchanged → fedSince true.
      // implication: AC3 — adding calories to a meal feeds the pet.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 900).fedSince(previous),
        isTrue,
      );
    });

    test('identical feed is not fed', () {
      // testTheory: invariance — no change means no feeding.
      // contract: equal meals, water and kcal → fedSince false.
      // implication: AC3 — reloads without new entries do not feed the pet.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650).fedSince(previous),
        isFalse,
      );
    });

    test('fewer meals without more water or kcal is not fed', () {
      // testTheory: directional — a deletion alone does not feed.
      // contract: meals 2 → 1, water and kcal unchanged → fedSince false.
      // implication: AC3 — removing a meal does not count as feeding.
      expect(
        const PetFeed(mealsToday: 1, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650).fedSince(previous),
        isFalse,
      );
    });

    test('midnight rollover is not fed', () {
      // testTheory: boundary value — the day resets to zero.
      // contract: meals 2 → 0, water 946 → 0, kcal 650 → 0 → fedSince false.
      // implication: AC3 — the new day starts unfed.
      expect(
        const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893, caloriesToday: 0).fedSince(previous),
        isFalse,
      );
    });

    test('a delete plus more water still counts as fed', () {
      // testTheory: directional — water rising is enough even if meals fall.
      // contract: meals 2 → 1, waterMl 946 → 1196, kcal 650 → 400 → fedSince true.
      // implication: AC3 — any increase in water counts as feeding.
      expect(
        const PetFeed(mealsToday: 1, waterMl: 1196, waterGoalMl: 1893, caloriesToday: 400).fedSince(previous),
        isTrue,
      );
    });

    test('a delete with fewer kcal is not fed', () {
      // testTheory: directional — falling calories alone do not feed.
      // contract: meals 2 → 1, waterMl unchanged, kcal 650 → 400 → fedSince false.
      // implication: AC3 — removing calories does not count as feeding.
      expect(
        const PetFeed(mealsToday: 1, waterMl: 946, waterGoalMl: 1893, caloriesToday: 400).fedSince(previous),
        isFalse,
      );
    });

    test('only calorie goal changes is not fed', () {
      // testTheory: invariance — the goal is not intake.
      // contract: calorieGoal null → 2000, meals, water and kcal unchanged → fedSince false.
      // implication: AC3 — editing the calorie goal does not feed the pet.
      expect(
        const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650, calorieGoal: 2000)
            .fedSince(previous),
        isFalse,
      );
    });

    test('null previous is never fed', () {
      // testTheory: boundary value — no prior state.
      // contract: fedSince(null) → false for any feed.
      // implication: AC3 — the first load does not feed the pet.
      expect(
        const PetFeed(mealsToday: 3, waterMl: 2000, waterGoalMl: 1893, caloriesToday: 2000).fedSince(null),
        isFalse,
      );
    });
  });

  group('[INV] PetFeed — equality', () {
    test('equal values are == with equal hashCodes', () {
      // testTheory: invariance — value equality ignores instance identity.
      // contract: PetFeed(2, 946, 1893, kcal 650, goal 2000) == same; hashCodes equal.
      // implication: AC3 — feed snapshots compare by value for change detection.
      const a = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650, calorieGoal: 2000);
      const b = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650, calorieGoal: 2000);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('differing water goal is not ==', () {
      // testTheory: invariance — every field participates in equality.
      // contract: PetFeed(2, 946, 1893) != PetFeed(2, 946, 2366).
      // implication: AC3 — a goal change is a distinct feed state.
      const a = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);
      const b = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 2366);
      expect(a == b, isFalse);
    });

    test('differing calorie goal is not ==', () {
      // testTheory: invariance — the calorie goal participates in equality.
      // contract: PetFeed(2, 946, 1893, kcal 650, goal 2000) != same with goal null.
      // implication: AC3 — a calorie goal change is a distinct feed state.
      const a = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650, calorieGoal: 2000);
      const b = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893, caloriesToday: 650);
      expect(a == b, isFalse);
    });
  });

  group('[MFT] PetFeed — empty', () {
    test('PetFeed.empty has zero meals, water and kcal with the default goal', () {
      // testTheory: minimum functionality — the starting feed state.
      // contract: empty → mealsToday 0, waterMl 0, waterGoalMl 1893, caloriesToday 0, calorieGoal null.
      // implication: AC1 — a fresh pet starts with nothing fed.
      expect(PetFeed.empty.mealsToday, 0);
      expect(PetFeed.empty.waterMl, 0);
      expect(PetFeed.empty.waterGoalMl, 1893);
      expect(PetFeed.empty.caloriesToday, 0);
      expect(PetFeed.empty.calorieGoal, isNull);
    });
  });
}
