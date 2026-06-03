import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/services/database/app_database.dart';

void main() {
  // ── Migration block ordering ──────────────────────────────────────────────
  //
  // These tests guard against the migration-ordering bug found during the v6
  // audit: the `if (from < 6)` block was placed BEFORE `if (from < 5)`.
  // While those two blocks are independent (different tables), wrong ordering
  // is a latent hazard for any future migration that depends on v5 schema
  // existing before v6 changes can apply.
  //
  // We test the source-code structure by reading the migration strategy
  // object and verifying the schema version.  Full DB migration path
  // (v4 → v6) requires an in-memory SQLite database which needs the
  // native sqlite3 plugin; that path is covered by on-device integration
  // tests.  This file covers what we CAN verify at pure-Dart level.

  group('[REGRESSION] AppDatabase schema version', () {
    test('schemaVersion is 11 after v11 food_suspicions migration', () {
      // AppDatabase is a singleton — we can't instantiate it in tests without
      // native sqlite3.  We verify the declared schemaVersion constant instead.
      // If this breaks, the DB won't open at all on first launch.
      expect(AppDatabase.currentSchemaVersion, 11);
    });

    test('migrationStepVersions includes the v11 step', () {
      expect(AppDatabase.migrationStepVersions.last, 11,
          reason: 'food_suspicions migration step must be declared');
    });
  });

  group('[REGRESSION] Migration block ordering — v5 before v6 invariant', () {
    // Guard against re-introduction of the bug where `if (from < 6)` appeared
    // before `if (from < 5)` in onUpgrade.  We verify this structurally by
    // checking the migration source returns steps in ascending version order.
    test('migration steps are declared in ascending version order', () {
      final steps = AppDatabase.migrationStepVersions;
      expect(steps, isNotEmpty, reason: 'migrationStepVersions must be populated');
      for (var i = 0; i < steps.length - 1; i++) {
        expect(
          steps[i],
          lessThanOrEqualTo(steps[i + 1]),
          reason:
              'Migration step ${steps[i]} appears before ${steps[i + 1]} — '
              'steps must be in non-decreasing order',
        );
      }
    });
  });
}
