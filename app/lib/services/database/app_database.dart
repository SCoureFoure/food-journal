import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

class Meals extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get time => text()();
  TextColumn get mealType => text()();
  TextColumn get overallSymptoms => text().nullable()();
  TextColumn get rawInput => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  BlobColumn get imageData => blob().nullable()();
}

class FoodItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(Meals, #id)();
  TextColumn get name => text()();
  TextColumn get portion => text().nullable()();
  TextColumn get prep => text().nullable()();
  IntColumn get calories => integer().nullable()();
  IntColumn get protein => integer().nullable()();
  IntColumn get carbs => integer().nullable()();
  IntColumn get fat => integer().nullable()();
  IntColumn get reaction => integer().withDefault(const Constant(0))(); // ReactionLevel index
  TextColumn get notes => text().nullable()();
}

class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get foodItemId => integer().references(FoodItems, #id)();
  TextColumn get name => text()();
  TextColumn get quantity => text().nullable()();
  TextColumn get unit => text().nullable()();
}

class ReactionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(Meals, #id)();
  DateTimeColumn get checkinTime => dateTime()();
  TextColumn get symptoms => text()(); // JSON-encoded List<String>
  IntColumn get severity => integer()(); // ReactionLevel index
  TextColumn get notes => text().nullable()();
}

class FoodMemories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get foodName => text().unique()();
  TextColumn get reactionPattern => text().nullable()();
  IntColumn get occurrences => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeen => dateTime()();
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Meals, FoodItems, Ingredients, ReactionLogs, FoodMemories])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(meals, meals.imageData);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'food_journal');
  }
}
