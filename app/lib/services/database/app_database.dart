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
  IntColumn get mealId => integer().nullable()(); // null = standalone "Feeling..." check-in
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

class Medications extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get time => text()();
  TextColumn get name => text()();
  RealColumn get dose => real().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get route => text().nullable()();
  IntColumn get checkinDelayMinutes => integer().nullable()();
  TextColumn get rawInput => text().nullable()();
  TextColumn get notes => text().nullable()();
  BlobColumn get imageData => blob().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Meals, FoodItems, Ingredients, ReactionLogs, FoodMemories, Medications])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(meals, meals.imageData);
      }
      if (from < 3) {
        // Recreate reaction_logs with nullable meal_id (SQLite can't ALTER NOT NULL)
        await customStatement('''
          CREATE TABLE reaction_logs_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            meal_id INTEGER,
            checkin_time INTEGER NOT NULL,
            symptoms TEXT NOT NULL,
            severity INTEGER NOT NULL,
            notes TEXT
          )
        ''');
        await customStatement(
          'INSERT INTO reaction_logs_new SELECT id, meal_id, checkin_time, symptoms, severity, notes FROM reaction_logs',
        );
        await customStatement('DROP TABLE reaction_logs');
        await customStatement('ALTER TABLE reaction_logs_new RENAME TO reaction_logs');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            time TEXT NOT NULL,
            name TEXT NOT NULL,
            dose REAL,
            unit TEXT,
            route TEXT,
            checkin_delay_minutes INTEGER,
            raw_input TEXT,
            notes TEXT,
            image_data BLOB,
            created_at INTEGER NOT NULL
          )
        ''');
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'food_journal');
  }
}
