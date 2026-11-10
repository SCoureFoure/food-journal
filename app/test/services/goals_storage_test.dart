// ignore_for_file: depend_on_referenced_packages
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/services/database/app_database.dart' show AppDatabase;
import 'package:food_journal/services/storage_service.dart';

void main() {
  late AppDatabase db;
  late StorageService storage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    storage = StorageService(database: db);
  });
  tearDown(() => db.close());

  group('[MFT] goal storage round trip', () {
    // testTheory: minimum functionality — what is saved is what is read back.
    // contract: saveGoals stores all five targets with effectiveDate = local
    //   midnight of now and createdAt = now; getGoalsForDate reads them back.
    // implication: AC2 — targets persist and null targets stay null.
    test('AC2: saved targets read back, unset ones null', () async {
      await storage.saveGoals(
        const DailyGoals(calories: 2000, proteinG: 140),
        now: DateTime(2026, 11, 10, 15, 30),
      );
      final g = await storage.getGoalsForDate(DateTime(2026, 11, 10));
      expect(g, const DailyGoals(calories: 2000, proteinG: 140));
      expect(g.carbsG, isNull);
      expect(g.fatG, isNull);
      expect(g.waterMl, isNull);
      expect(g.effectiveWaterMl, 1893);
    });

    test('snapshot has midnight effectiveDate, exact createdAt, and an id', () async {
      await storage.saveGoals(
        const DailyGoals(calories: 2000),
        now: DateTime(2026, 11, 10, 15, 30),
      );
      final h = await storage.getGoalHistory();
      expect(h, hasLength(1));
      expect(h.single.effectiveDate, DateTime(2026, 11, 10));
      expect(h.single.createdAt, DateTime(2026, 11, 10, 15, 30));
      expect(h.single.id, isNotNull);
    });
  });

  group('[DIR] goals apply by date', () {
    // testTheory: directional — later saves affect only later days.
    // contract: getGoalsForDate returns the latest snapshot on or before the day.
    // implication: AC3 — past days keep the goals they had.
    test('AC3: 11-05 -> 2000, 11-10 -> 1800, 10-31 -> none', () async {
      await storage.saveGoals(const DailyGoals(calories: 2000),
          now: DateTime(2026, 11, 1, 9));
      await storage.saveGoals(const DailyGoals(calories: 1800),
          now: DateTime(2026, 11, 10, 9));
      expect(await storage.getGoalsForDate(DateTime(2026, 11, 5)),
          const DailyGoals(calories: 2000));
      expect(await storage.getGoalsForDate(DateTime(2026, 11, 10)),
          const DailyGoals(calories: 1800));
      expect(await storage.getGoalsForDate(DateTime(2026, 10, 31)),
          DailyGoals.none);
    });
  });

  group('[INV] same-day re-save', () {
    // testTheory: invariance — saving appends, never overwrites.
    // contract: two saves on one day keep two history rows; the later one wins.
    // implication: AC4 — history is append-only.
    test('AC4: two saves -> 2 rows, target 2100', () async {
      await storage.saveGoals(const DailyGoals(calories: 2000),
          now: DateTime(2026, 11, 10, 8));
      await storage.saveGoals(const DailyGoals(calories: 2100),
          now: DateTime(2026, 11, 10, 9));
      expect(await storage.getGoalHistory(), hasLength(2));
      expect(await storage.getGoalsForDate(DateTime(2026, 11, 10)),
          const DailyGoals(calories: 2100));
    });
  });

  group('[BVA] clearing goals', () {
    // testTheory: boundary — all targets null.
    // contract: saving DailyGoals.none after a save on the same day clears the day.
    // implication: a user can remove all goals.
    test('none after 2000 same day -> none', () async {
      await storage.saveGoals(const DailyGoals(calories: 2000),
          now: DateTime(2026, 11, 10, 8));
      await storage.saveGoals(DailyGoals.none, now: DateTime(2026, 11, 10, 9));
      expect(await storage.getGoalsForDate(DateTime(2026, 11, 10)),
          DailyGoals.none);
    });
  });

  group('[MFT] history order', () {
    // testTheory: minimum functionality — ordering is by effectiveDate.
    // contract: getGoalHistory returns effectiveDate asc, then id asc.
    // implication: insert order must not leak into the timeline.
    test('saved 11-10 then 11-01 -> [11-01, 11-10]', () async {
      await storage.saveGoals(const DailyGoals(calories: 1800),
          now: DateTime(2026, 11, 10, 9));
      await storage.saveGoals(const DailyGoals(calories: 2000),
          now: DateTime(2026, 11, 1, 9));
      final h = await storage.getGoalHistory();
      expect(h.map((s) => s.effectiveDate).toList(),
          [DateTime(2026, 11, 1), DateTime(2026, 11, 10)]);
    });
  });
}
