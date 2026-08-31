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

  /// [INV] AppShell settings position — holds the invariant that the settings gear sits at
  /// the far right and does not move when tabs change. The journal-only actions appear and
  /// disappear to its LEFT, so the control that is present on every tab is the one that
  /// stays put. If this regresses: the gear slides sideways the moment you switch tabs and
  /// a thumb heading for it lands on Export or Blame history instead — a presence-only
  /// assertion (which the other groups make) would never catch it, because all three
  /// buttons are still there.
  group('[INV] AppShell settings position', () {
    Finder anchor(String id) => find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == id,
        );

    testWidgets('the gear holds its x position across a tab switch',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final onJournal = tester.getTopRight(anchor('btn-settings'));

      await tester.ensureVisible(find.text('Meal Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      expect(tester.getTopRight(anchor('btn-settings')).dx, onJournal.dx);
    });

    testWidgets('the gear is the right-most action on the journal tab',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final gear = tester.getTopRight(anchor('btn-settings')).dx;
      expect(tester.getTopRight(anchor('btn-export')).dx, lessThan(gear));
      expect(tester.getTopRight(anchor('btn-blame-history')).dx, lessThan(gear));
    });
  });

  /// [DIR] AppShell tab wash — holds the contract that the band across the top of the page
  /// carries the ACTIVE tab's colour and fades to fully transparent, and that it never
  /// intercepts a pointer. If this regresses: either the page stops belonging to the tab
  /// standing above it (cosmetic), or the wash swallows every tap in the top third of the
  /// screen — the week cards, the grocery controls — which looks like the app has frozen.
  group('[DIR] AppShell tab wash', () {
    testWidgets('wash gradient starts with the active tab colour and fades to alpha 0',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final washContainer = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient),
      );
      final gradient =
          (washContainer.decoration as BoxDecoration).gradient as LinearGradient;

      // Assert the hue and the fade, not one exact alpha: how strong the wash
      // reads is a look-and-feel dial that gets tuned against a real screen,
      // and pinning its value here turns every such tweak into a test failure
      // that means nothing. What must hold is that the band is the tab's own
      // colour, visible at the top, and gone by the bottom.
      expect(gradient.colors.first.withAlpha(255), kTabFoodJournal.withAlpha(255));
      expect(gradient.colors.first.a, greaterThan(0));
      expect(gradient.colors.last.a, 0);
    });

    testWidgets('wash gradient switches colour with the active tab', (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Meal Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      final washContainer = tester.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient is LinearGradient),
      );
      final gradient =
          (washContainer.decoration as BoxDecoration).gradient as LinearGradient;

      expect(gradient.colors.first.withAlpha(255), kTabMealPlanning.withAlpha(255));
      expect(gradient.colors.first.a, greaterThan(0));
    });

    testWidgets('the folder body starts at the tab base, not the screen top',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final gradientFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient);

      // The block is the folder the tabs are attached to, so its top edge sits
      // at the bottom of the app bar — level with the tab's base line. If it
      // starts at the top of the screen instead, colour appears above and
      // beside the tabs and they read as floating in a tint rather than being
      // part of a folder, which is the whole complaint this fixed.
      final bodyTop = tester.getTopLeft(gradientFinder).dy;
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;

      expect(bodyTop, greaterThan(0));
      // At the tab base, or tucked just behind it — never butted below it
      // (which leaves a hairline of paper) and never up at the screen top.
      expect(bodyTop, lessThanOrEqualTo(appBarBottom));
      expect(bodyTop, greaterThan(appBarBottom - 24));
    });

    testWidgets('an IgnorePointer sits above the wash so it never eats a tap',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final gradientFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient is LinearGradient);

      expect(
        find.ancestor(
          of: gradientFinder,
          matching: find.byType(IgnorePointer),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });

  /// [INV] AppShell contract survives the wash restructure — holds the invariant that
  /// wrapping the Scaffold in a Stack for the wash did not disturb the shell's existing
  /// chrome contract. If this regresses: the wash implementation silently broke tab
  /// switching, the action visibility rule, or the journal's preserved State.
  group('[INV] AppShell contract survives the wash restructure', () {
    testWidgets('shell contract intact: one AppBar, index toggling, actions, state',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        0,
      );
      expect(_anchor('btn-settings'), findsOneWidget);
      expect(_anchor('btn-export'), findsOneWidget);
      expect(_anchor('btn-blame-history'), findsOneWidget);

      final stateBefore =
          tester.state<HomeScreenState>(find.byType(HomeScreen));

      await tester.ensureVisible(find.text('Meal Planning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meal Planning'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        1,
      );
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
      final stateAfter =
          tester.state<HomeScreenState>(find.byType(HomeScreen));
      expect(identical(stateBefore, stateAfter), isTrue);

      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(MealPlanningScreen, skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  /// [INV] AppShell folder alignment — holds the contract that the folder's top
  /// edge lands exactly on the tabs' base line and that nothing is painted over
  /// the tabs. The AppBar centres its title slot, so the base is 6px above the
  /// app bar's bottom edge; measuring from the wrong one leaves either a strip
  /// of bare paper under the tabs or a coloured band cutting across them. Both
  /// have shipped and both were reported by eye — no functional test catches
  /// either, which is why the edge is pinned to the tab bar's own geometry here.
  group('[INV] AppShell folder alignment', () {
    Finder washFinder() => find.byWidgetPredicate((w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).gradient is LinearGradient);

    testWidgets('the folder edge meets the tab bases exactly', (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(washFinder()).dy,
        tester.getBottomLeft(find.byType(FolderTabBar)).dy,
      );
    });

    testWidgets('the folder edge sits above the app bar bottom, not on it',
        (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      // The gap the centred title slot creates. Anchoring to the app bar
      // instead of the tabs drops the folder this far below them.
      final washTop = tester.getTopLeft(washFinder()).dy;
      final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      expect(washTop, lessThan(appBarBottom));
      expect(appBarBottom - washTop, (kToolbarHeight - kTabRaisedHeight) / 2);
    });

    testWidgets('nothing is painted over the tabs', (tester) async {
      await tester.pumpWidget(_shell());
      await tester.pumpAndSettle();

      final children = tester
          .widget<Stack>(find
              .descendant(of: find.byType(AppShell), matching: find.byType(Stack))
              .first)
          .children;

      // The tabs live in the Scaffold's AppBar. Anything after it in the Stack
      // lands on top of them — which is what put a band across the tabs once.
      expect(children.last, isA<Scaffold>());
    });
  });
}
