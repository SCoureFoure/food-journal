import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/pet_feed.dart';

void main() {
  group('[MFT] PetFeed — foodLevel', () {
    test('0 meals gives 0.0', () {
      // testTheory: minimum functionality — empty day, empty food meter.
      // contract: mealsToday 0 → foodLevel 0.0.
      // implication: AC1 — the Food meter starts empty.
      expect(const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893).foodLevel, 0.0);
    });

    test('1 and 2 meals give 1/3 and 2/3', () {
      // testTheory: minimum functionality — partial feeding shows its ratio.
      // contract: mealsToday n → foodLevel n / kPetMealsPerDay.
      // implication: AC1 — each meal advances the Food meter by one third.
      expect(const PetFeed(mealsToday: 1, waterMl: 0, waterGoalMl: 1893).foodLevel, closeTo(1 / 3, 1e-9));
      expect(const PetFeed(mealsToday: 2, waterMl: 0, waterGoalMl: 1893).foodLevel, closeTo(2 / 3, 1e-9));
    });

    test('3 meals give 1.0', () {
      // testTheory: boundary value — exactly the daily meal count.
      // contract: mealsToday 3 → foodLevel 1.0.
      // implication: AC1 — three meals fill the Food meter.
      expect(const PetFeed(mealsToday: 3, waterMl: 0, waterGoalMl: 1893).foodLevel, 1.0);
    });

    test('4 meals clamp to 1.0', () {
      // testTheory: boundary value — above the daily meal count.
      // contract: mealsToday 4 → foodLevel 1.0 (clamped).
      // implication: AC1 — extra meals do not overflow the Food meter.
      expect(const PetFeed(mealsToday: 4, waterMl: 0, waterGoalMl: 1893).foodLevel, 1.0);
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
    const previous = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);

    test('a new meal counts as fed', () {
      // testTheory: directional — meals rising is a feeding event.
      // contract: meals 2 → 3, water unchanged → fedSince true.
      // implication: AC3 — logging a meal feeds the pet.
      expect(const PetFeed(mealsToday: 3, waterMl: 946, waterGoalMl: 1893).fedSince(previous), isTrue);
    });

    test('more water counts as fed', () {
      // testTheory: directional — water rising is a feeding event.
      // contract: waterMl 946 → 1196, meals unchanged → fedSince true.
      // implication: AC3 — logging water feeds the pet.
      expect(const PetFeed(mealsToday: 2, waterMl: 1196, waterGoalMl: 1893).fedSince(previous), isTrue);
    });

    test('identical feed is not fed', () {
      // testTheory: invariance — no change means no feeding.
      // contract: equal meals and water → fedSince false.
      // implication: AC3 — reloads without new entries do not feed the pet.
      expect(const PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893).fedSince(previous), isFalse);
    });

    test('fewer meals without more water is not fed', () {
      // testTheory: directional — a deletion alone does not feed.
      // contract: meals 2 → 1, water unchanged → fedSince false.
      // implication: AC3 — removing a meal does not count as feeding.
      expect(const PetFeed(mealsToday: 1, waterMl: 946, waterGoalMl: 1893).fedSince(previous), isFalse);
    });

    test('midnight rollover is not fed', () {
      // testTheory: boundary value — the day resets to zero.
      // contract: meals 2 → 0, water 946 → 0 → fedSince false.
      // implication: AC3 — the new day starts unfed.
      expect(const PetFeed(mealsToday: 0, waterMl: 0, waterGoalMl: 1893).fedSince(previous), isFalse);
    });

    test('a delete plus more water still counts as fed', () {
      // testTheory: directional — water rising is enough even if meals fall.
      // contract: meals 2 → 1, waterMl 946 → 1196 → fedSince true.
      // implication: AC3 — any increase in water counts as feeding.
      expect(const PetFeed(mealsToday: 1, waterMl: 1196, waterGoalMl: 1893).fedSince(previous), isTrue);
    });

    test('null previous is never fed', () {
      // testTheory: boundary value — no prior state.
      // contract: fedSince(null) → false for any feed.
      // implication: AC3 — the first load does not feed the pet.
      expect(const PetFeed(mealsToday: 3, waterMl: 2000, waterGoalMl: 1893).fedSince(null), isFalse);
    });
  });

  group('[INV] PetFeed — equality', () {
    test('equal values are == with equal hashCodes', () {
      // testTheory: invariance — value equality ignores instance identity.
      // contract: PetFeed(2, 946, 1893) == PetFeed(2, 946, 1893); hashCodes equal.
      // implication: AC3 — feed snapshots compare by value for change detection.
      const a = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);
      const b = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('differing goal is not ==', () {
      // testTheory: invariance — every field participates in equality.
      // contract: PetFeed(2, 946, 1893) != PetFeed(2, 946, 2366).
      // implication: AC3 — a goal change is a distinct feed state.
      const a = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 1893);
      const b = PetFeed(mealsToday: 2, waterMl: 946, waterGoalMl: 2366);
      expect(a == b, isFalse);
    });
  });

  group('[MFT] PetFeed — empty', () {
    test('PetFeed.empty has zero meals and water with the default goal', () {
      // testTheory: minimum functionality — the starting feed state.
      // contract: empty → mealsToday 0, waterMl 0, waterGoalMl 1893.
      // implication: AC1 — a fresh pet starts with nothing fed.
      expect(PetFeed.empty.mealsToday, 0);
      expect(PetFeed.empty.waterMl, 0);
      expect(PetFeed.empty.waterGoalMl, 1893);
    });
  });
}
