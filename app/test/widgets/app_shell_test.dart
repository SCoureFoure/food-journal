import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/models/medication.dart';
import 'package:food_journal/models/reaction_log.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/models/weight_log.dart';
import 'package:food_journal/screens/home/home_screen.dart';
import 'package:food_journal/screens/meal_planning/meal_planning_screen.dart';
import 'package:food_journal/screens/shell/app_shell.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/folder_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The journal tab loads from sqlite3, which does not exist under `flutter
/// test`. Without a seam the real load never settles: the feed sits on its
/// spinner forever and leaves a pending timer behind at teardown. This fake
/// returns empty data so the shell's own chrome is what the tests measure.
class _FakeStorage extends StorageService {
  @override
  Future<List<MealEntry>> getAllMeals() async => [];

  @override
  Future<List<Medication>> getAllMedications() async => [];

  @override
  Future<List<ReactionLog>> getStandaloneReactionLogs() async => [];

  @override
  Future<List<WaterLog>> getAllWaterLogs() async => [];

  @override
  Future<List<WeightLog>> getAllWeightLogs() async => [];
}

Widget _shell() => MaterialApp(home: AppShell(journalStorageOverride: _FakeStorage()));

Finder _anchor(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  /// [MFT] AppShell composition — holds the contract that the shell renders
  /// exactly one AppBar carrying the FolderTabBar as its title, with both
  /// the Food Journal and Meal Planning tabs mounted simultaneously via an
  /// IndexedStack, and the settings/export/blame-history actions present on
  /// the journal tab. If this regresses: the shell either loses its tab
  /// chrome entirely or a doer leaves HomeScreen's own AppBar in place,
  /// stacking two title bars — invisible to any single-screen widget test.
  group('[MFT] AppShell composition', () {
    testWidgets('renders shell chrome, both tabs mounted, one AppBar',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      expect(_anchor('app-shell'), findsOneWidget);
      expect(find.byType(FolderTabBar), findsOneWidget);
      expect(find.text('Food Journal'), findsOneWidget);
      expect(find.text('Meal Planning'), findsOneWidget);

      // IndexedStack keeps every child in the tree but marks the ones it is not
      // showing as offstage, and finders skip offstage widgets by default. That
      // both tabs are *mounted* at once is the point of AC2 — so look offstage
      // too. If this ever finds nothing, the shell has stopped preserving the
      // inactive tab and AC8 (state survives a switch) cannot hold either.
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(MealPlanningScreen, skipOffstage: false),
        findsOneWidget,
      );

      final indexedStack =
          tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(indexedStack.index, 0);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);

      expect(_anchor('btn-settings'), findsOneWidget);
      expect(_anchor('btn-export'), findsOneWidget);
      expect(_anchor('btn-blame-history'), findsOneWidget);
    });
  });

  /// [DIR] AppShell tab switch — holds the contract that tapping a folder
  /// tab moves the IndexedStack index and that the journal-only actions
  /// (Export, Blame history) disappear on the Meal Planning tab while
  /// Settings stays put, and that a single AppBar survives the switch. If
  /// this regresses: a doer renders one shared action row on both tabs, so
  /// Export/Blame history leak into Meal Planning where they have no
  /// meaning.
  group('[DIR] AppShell tab switch', () {
    testWidgets('switching tabs moves the index and toggles actions',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Meal Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        1,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(_anchor('btn-settings'), findsOneWidget);
      expect(_anchor('btn-export'), findsNothing);
      expect(_anchor('btn-blame-history'), findsNothing);

      await tester.ensureVisible(find.text('Food Journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food Journal'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        0,
      );
      expect(find.byType(AppBar), findsOneWidget);
      expect(_anchor('btn-settings'), findsOneWidget);
      expect(_anchor('btn-export'), findsOneWidget);
      expect(_anchor('btn-blame-history'), findsOneWidget);
    });
  });

  /// [INV] AppShell tab-state preservation — holds the invariant that
  /// switching tabs preserves the journal's State object, because the shell
  /// uses an IndexedStack rather than swapping routes. If this regresses:
  /// every trip to the Meal Planning tab discards the journal's loaded feed
  /// and scroll position, so the user lands back at the top of the list and
  /// pays a reload — a papercut that no journal test would ever catch,
  /// because it only manifests through the shell.
  group('[INV] AppShell tab-state preservation', () {
    testWidgets('HomeScreen State survives a round trip through the tabs',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final stateBefore =
          tester.state<HomeScreenState>(find.byType(HomeScreen));

      await tester.ensureVisible(find.text('Meal Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Food Journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food Journal'));
      await tester.pumpAndSettle();

      final stateAfter =
          tester.state<HomeScreenState>(find.byType(HomeScreen));

      expect(identical(stateBefore, stateAfter), isTrue);
    });
  });
}
