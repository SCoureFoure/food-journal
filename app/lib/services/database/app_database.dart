import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../models/food_entity.dart';

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
  IntColumn get servings => integer().withDefault(const Constant(1))();
  // Canonical identity (lowercase/trim/punct-collapsed name) for cross-log
  // accumulation. Computed at save via canonicalize(). See
  // specs/food_entity_resolution.spec.md.
  TextColumn get canonicalName => text().nullable()();
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
  IntColumn get severity => integer()(); // derived: max ReactionLevel index across symptomLevels
  IntColumn get mood => integer().nullable()(); // Mood index, null = not recorded
  TextColumn get symptomLevels => text().nullable()(); // JSON {name: ReactionLevel index}; null = legacy
  TextColumn get notes => text().nullable()();
}

class FoodMemories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get foodName => text().unique()();
  TextColumn get reactionPattern => text().nullable()();
  IntColumn get occurrences => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeen => dateTime()();
  BoolColumn get flagged => boolean().withDefault(const Constant(false))();
  // TODO_FAVORITES: toggle this via StorageService.toggleFoodFavorite(foodName)
  BoolColumn get favorited => boolean().withDefault(const Constant(false))();
}

class FoodSuspicions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get reactionLogId =>
      integer().references(ReactionLogs, #id, onDelete: KeyAction.cascade)();
  TextColumn get symptom => text()();
  TextColumn get targetType => text()(); // 'food' | 'medication'
  IntColumn get targetId => integer()(); // food_items.id | medications.id
  TextColumn get targetName => text()(); // denormalized, lowercased for aggregation
  RealColumn get baseWeight => real()(); // ReactionLevel index at log time
  TextColumn get source => text()(); // 'manual' | 'auto'
  DateTimeColumn get createdAt => dateTime()(); // decay input
}

/// User-dismissed `(check-in, symptom)` episodes — see specs/blame_history.spec.md.
/// Lives apart from [FoodSuspicions] because `applyBlame` wipes-and-rewrites that
/// table on every check-in save; a flag column there would be lost on the next
/// unrelated save. This table survives that regenerate untouched and cascades on
/// log delete just like the ledger does.
class SuspicionExclusions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get reactionLogId =>
      integer().references(ReactionLogs, #id, onDelete: KeyAction.cascade)();
  TextColumn get symptom => text()();
  DateTimeColumn get createdAt => dateTime()(); // when the user dismissed it

  @override
  List<Set<Column>> get uniqueKeys => [
        {reactionLogId, symptom},
      ];
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
  // Canonical identity — see FoodItems.canonicalName.
  TextColumn get canonicalName => text().nullable()();
}

class MealFingerprints extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealId => integer().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get date => text()(); // ISO 8601 "2026-05-14"
  TextColumn get mealType => text().nullable()();
  TextColumn get foodsSummary => text()();
  IntColumn get totalCals => integer().nullable()();
  RealColumn get totalProtein => real().nullable()();
  IntColumn get createdAt => integer()(); // Unix ms
}

class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get time => text()();
  IntColumn get amountMl => integer()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class WeightLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get time => text()();
  RealColumn get weightValue => real()();
  TextColumn get unit => text()(); // 'lbs' or 'kg'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class SavedItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get calories => integer().nullable()();
  IntColumn get protein => integer().nullable()();
  IntColumn get carbs => integer().nullable()();
  IntColumn get fat => integer().nullable()();
  TextColumn get componentsJson => text()(); // JSON array of component names
  DateTimeColumn get createdAt => dateTime()();
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Meals, FoodItems, Ingredients, ReactionLogs, FoodMemories, Medications, MealFingerprints, WaterLogs, WeightLogs, SavedItems, FoodSuspicions, SuspicionExclusions])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() => _instance;

  AppDatabase._internal() : super(_openConnection());

  // Exposed as a static constant so tests can assert the current version
  // without instantiating the singleton (which requires native sqlite3).
  static const int currentSchemaVersion = 13;

  // The declared migration ceiling versions in the order they appear in
  // onUpgrade.  Must be non-decreasing — tested in migration_order_test.dart.
  static const List<int> migrationStepVersions = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13];

  @override
  int get schemaVersion => currentSchemaVersion;

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
      if (from < 4) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS meal_fingerprints (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            meal_id INTEGER NOT NULL REFERENCES meals(id) ON DELETE CASCADE,
            date TEXT NOT NULL,
            meal_type TEXT,
            foods_summary TEXT NOT NULL,
            total_cals INTEGER,
            total_protein REAL,
            created_at INTEGER NOT NULL
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_fingerprints_date ON meal_fingerprints(date DESC)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_fingerprints_type ON meal_fingerprints(meal_type, date DESC)',
        );
      }
      if (from < 5) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS water_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            time TEXT NOT NULL,
            amount_ml INTEGER NOT NULL,
            notes TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await customStatement('''
          CREATE TABLE IF NOT EXISTS weight_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date INTEGER NOT NULL,
            time TEXT NOT NULL,
            weight_value REAL NOT NULL,
            unit TEXT NOT NULL,
            notes TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
      }
      if (from < 6) {
        await customStatement(
          'ALTER TABLE food_memories ADD COLUMN favorited INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 7) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS saved_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            calories INTEGER,
            protein INTEGER,
            carbs INTEGER,
            fat INTEGER,
            components_json TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      }
      if (from < 8) {
        await customStatement(
          'ALTER TABLE food_items ADD COLUMN servings INTEGER NOT NULL DEFAULT 1',
        );
      }
      if (from < 9) {
        await customStatement(
          'ALTER TABLE reaction_logs ADD COLUMN mood INTEGER',
        );
      }
      if (from < 10) {
        await customStatement(
          'ALTER TABLE reaction_logs ADD COLUMN symptom_levels TEXT',
        );
      }
      if (from < 11) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS food_suspicions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reaction_log_id INTEGER NOT NULL REFERENCES reaction_logs(id) ON DELETE CASCADE,
            symptom TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id INTEGER NOT NULL,
            target_name TEXT NOT NULL,
            base_weight REAL NOT NULL,
            source TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_suspicion_target ON food_suspicions(target_name, symptom)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_suspicion_log ON food_suspicions(reaction_log_id)',
        );
      }
      if (from < 12) {
        await customStatement(
          'ALTER TABLE food_items ADD COLUMN canonical_name TEXT',
        );
        await customStatement(
          'ALTER TABLE medications ADD COLUMN canonical_name TEXT',
        );
        // Backfill existing rows with the real canonicalize() (SQLite has no
        // regex; applying the Dart fn keeps the key identical to new saves).
        await _backfillCanonicalNames('food_items');
        await _backfillCanonicalNames('medications');
      }
      if (from < 13) {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS suspicion_exclusions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            reaction_log_id INTEGER NOT NULL REFERENCES reaction_logs(id) ON DELETE CASCADE,
            symptom TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            UNIQUE(reaction_log_id, symptom)
          )
        ''');
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_exclusion_log ON suspicion_exclusions(reaction_log_id)',
        );
      }
    },
  );

  /// Populates [table].canonical_name from its raw `name` using [canonicalize],
  /// so historical rows share buckets with freshly-saved ones (v12 backfill).
  Future<void> _backfillCanonicalNames(String table) async {
    final rows =
        await customSelect('SELECT id, name FROM $table').get();
    for (final r in rows) {
      await customStatement(
        'UPDATE $table SET canonical_name = ? WHERE id = ?',
        [canonicalize(r.read<String>('name')), r.read<int>('id')],
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'food_journal');
  }
}
