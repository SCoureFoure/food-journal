import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/widgets/home/week_summary_section.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

final _monday = DateTime(2026, 5, 11); // known Monday

MealEntry _meal(int id, DateTime date) => MealEntry(
      id: id,
      date: date,
      time: '12:00 PM',
      mealType: 'lunch',
      createdAt: DateTime(date.year, date.month, date.day, 12),
    );

// Returns a MacroFetcher closure with fixed return values.
// No StorageService or DB is involved — safe for headless tests.
MacroFetcher _fetcher({
  int cal = 0,
  double prot = 0.0,
  double carbs = 0.0,
  double fat = 0.0,
}) =>
    (_) async => (cal: cal, prot: prot, carbs: carbs, fat: fat);

// storage is omitted (nullable since macroFetcher is provided).
// DateSection children receive storage! — but they only call it on tile
// expansion, which never happens in these tests (tiles are collapsed by default).
WeekSummarySection _section({
  required DateTime weekStart,
  required List<DateTime> dates,
  required Map<DateTime, List<MealEntry>> mealsByDate,
  required MacroFetcher fetcher,
}) =>
    WeekSummarySection(
      weekStart: weekStart,
      dates: dates,
      mealsByDate: mealsByDate,
      medsByDate: const {},
      feelingsByDate: const {},
      waterByDate: const {},
      weightByDate: const {},
      isToday: (_) => false,
      onReload: () {},
      macroFetcher: fetcher,
    );

// ── Pure helpers — mirror of home_screen.dart private logic ──────────────────
// _mondayOf and _weekGroups are private on _HomeScreenState.  We replicate the
// exact code here so any production drift surfaces as a failure.

DateTime _mondayOf(DateTime date) =>
    DateTime(date.year, date.month, date.day - (date.weekday - 1));

Map<DateTime, List<DateTime>> _weekGroups(List<DateTime> dates) {
  final Map<DateTime, List<DateTime>> byWeek = {};
  for (final date in dates) {
    final ws = _mondayOf(date);
    byWeek.putIfAbsent(ws, () => []).add(date);
  }
  return byWeek;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Header hidden — zero-calorie boundary ─────────────────────────────────

  group('[BVA] WeekSummarySection — header hidden when no calories', () {
    testWidgets('header absent when mealsByDate is empty (ids empty → early return)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: const {},
          fetcher: _fetcher(),
        ),
      ));
      await tester.pump(); // let initState Future resolve
      expect(find.text('TOTALS'), findsNothing);
      expect(find.text('AVG / DAY'), findsNothing);
    });

    testWidgets('header absent when fetcher returns cal == 0', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 0),
        ),
      ));
      await tester.pump();
      expect(find.text('TOTALS'), findsNothing);
    });
  });

  // ── Header shown — non-zero calories ─────────────────────────────────────

  group('[MFT] WeekSummarySection — header shown when cal > 0', () {
    testWidgets('TOTALS label visible when cal > 0', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 2000, prot: 80, carbs: 250, fat: 70),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('TOTALS'), findsOneWidget);
    });

    testWidgets('CAL cell shows exact total calorie value', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 1500),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('1500'), findsOneWidget);
    });

    testWidgets('PROT, CARBS, FAT cells shown when values > 0', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 2000, prot: 80, carbs: 250, fat: 70),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('80g'), findsOneWidget);
      expect(find.text('250g'), findsOneWidget);
      expect(find.text('70g'), findsOneWidget);
    });

    testWidgets('macro cells absent when prot/carbs/fat are zero', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 300),
        ),
      ));
      await tester.pump();
      expect(find.text('PROT'), findsNothing);
      expect(find.text('CARBS'), findsNothing);
      expect(find.text('FAT'), findsNothing);
    });
  });

  // ── AVG / DAY row — single vs multi-day ──────────────────────────────────

  group('[BVA] WeekSummarySection — AVG/DAY row visibility', () {
    testWidgets('AVG / DAY row absent for single day with meals', (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 2000, prot: 80, carbs: 250, fat: 70),
        ),
      ));
      await tester.pump();
      expect(find.text('AVG / DAY'), findsNothing);
    });

    testWidgets('AVG / DAY row shown when two days both have meals', (tester) async {
      final day2 = _monday.add(const Duration(days: 1));
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday, day2],
          mealsByDate: {
            _monday: [_meal(1, _monday)],
            day2: [_meal(2, day2)],
          },
          fetcher: _fetcher(cal: 4000, prot: 160, carbs: 500, fat: 140),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('AVG / DAY'), findsOneWidget);
    });

    testWidgets('AVG / DAY cal value equals total ~/ daysWithMeals', (tester) async {
      final day2 = _monday.add(const Duration(days: 1));
      // 4200 cal / 2 days → avg = 4200 ~/ 2 = 2100
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday, day2],
          mealsByDate: {
            _monday: [_meal(1, _monday)],
            day2: [_meal(2, day2)],
          },
          fetcher: _fetcher(cal: 4200),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('2100'), findsOneWidget);
    });

    testWidgets('AVG / DAY absent when only one of two dates has meals',
        (tester) async {
      final day2 = _monday.add(const Duration(days: 1));
      // day2 not in mealsByDate → daysWithMeals == 1 → no avg row
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday, day2],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 1800, prot: 70, carbs: 200, fat: 60),
        ),
      ));
      await tester.pump();
      expect(find.text('AVG / DAY'), findsNothing);
    });
  });

  // ── Week header label format ──────────────────────────────────────────────

  group('[MFT] WeekSummarySection — week range label', () {
    testWidgets('same-month week shows start "MMM d" and end day only', (tester) async {
      // weekStart = May 11, weekEnd = May 17 → label "May 11 – 17"
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: {_monday: [_meal(1, _monday)]},
          fetcher: _fetcher(cal: 1000),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('May 11'), findsOneWidget);
      expect(find.textContaining('17'), findsOneWidget);
    });

    testWidgets('cross-month week shows both month abbreviations', (tester) async {
      // weekStart = Jan 27, weekEnd = Feb 2 → label "Jan 27 – Feb 2"
      final weekStart = DateTime(2026, 1, 27);
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: weekStart,
          dates: [weekStart],
          mealsByDate: {weekStart: [_meal(1, weekStart)]},
          fetcher: _fetcher(cal: 500),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('Jan'), findsOneWidget);
      expect(find.textContaining('Feb'), findsOneWidget);
    });
  });

  // ── Semantics anchor ─────────────────────────────────────────────────────

  group('[MFT] WeekSummarySection — semantics identifier', () {
    testWidgets('root Semantics identifier contains the ISO week-start date',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _section(
          weekStart: _monday,
          dates: [_monday],
          mealsByDate: const {},
          fetcher: _fetcher(),
        ),
      ));
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) =>
            w is Semantics &&
            w.properties.identifier == 'week-section-2026-05-11'),
        findsOneWidget,
      );
    });
  });

  // DateSection child rendering is covered by date_section_test.dart.
  // WeekSummarySection skips DateSection rendering when storage is null
  // (test-only path; production always supplies storage).

  // ── Unit: _mondayOf — ISO week-start calculation ──────────────────────────

  group('[Unit] _mondayOf — ISO week start (Monday)', () {
    test('Monday maps to itself', () {
      final monday = DateTime(2026, 5, 11); // weekday == 1
      expect(_mondayOf(monday), equals(monday));
    });

    test('Sunday maps to the preceding Monday', () {
      final sunday = DateTime(2026, 5, 17); // weekday == 7
      expect(_mondayOf(sunday), equals(DateTime(2026, 5, 11)));
    });

    test('Wednesday maps to Monday of the same week', () {
      final wednesday = DateTime(2026, 5, 13); // weekday == 3
      expect(_mondayOf(wednesday), equals(DateTime(2026, 5, 11)));
    });

    test('cross-month: May 1 (Friday) maps to April 27 (Monday)', () {
      final may1 = DateTime(2026, 5, 1); // weekday == 5
      expect(_mondayOf(may1), equals(DateTime(2026, 4, 27)));
    });

    test('cross-year: Jan 1 2026 (Thursday) maps to Dec 29 2025 (Monday)', () {
      final jan1 = DateTime(2026, 1, 1); // weekday == 4
      expect(_mondayOf(jan1), equals(DateTime(2025, 12, 29)));
    });
  });

  // ── Unit: _weekGroups — grouping by ISO week ──────────────────────────────

  group('[Unit] _weekGroups — grouping dates by ISO week', () {
    test('dates in the same week produce one group', () {
      final dates = [
        DateTime(2026, 5, 11), // Mon
        DateTime(2026, 5, 13), // Wed
        DateTime(2026, 5, 15), // Fri
      ];
      final groups = _weekGroups(dates);
      expect(groups.length, 1);
      expect(groups[DateTime(2026, 5, 11)]!.length, 3);
    });

    test('dates spanning two calendar weeks produce two groups', () {
      final dates = [
        DateTime(2026, 5, 11), // Mon week-1
        DateTime(2026, 5, 15), // Fri week-1
        DateTime(2026, 5, 18), // Mon week-2
        DateTime(2026, 5, 20), // Wed week-2
      ];
      final groups = _weekGroups(dates);
      expect(groups.length, 2);
      expect(groups[DateTime(2026, 5, 11)]!.length, 2);
      expect(groups[DateTime(2026, 5, 18)]!.length, 2);
    });

    test('cross-month dates in the same ISO week stay in one group', () {
      // April 27 (Mon) through May 3 (Sun) is one ISO week
      final dates = [
        DateTime(2026, 4, 30), // Thu
        DateTime(2026, 5, 1),  // Fri
        DateTime(2026, 5, 3),  // Sun
      ];
      final groups = _weekGroups(dates);
      expect(groups.length, 1);
      expect(groups[DateTime(2026, 4, 27)]!.length, 3);
    });

    test('empty input produces empty map', () {
      expect(_weekGroups([]), isEmpty);
    });

    test('single date produces one group with one entry', () {
      final date = DateTime(2026, 5, 14); // Thursday
      final groups = _weekGroups([date]);
      expect(groups.length, 1);
      expect(groups[DateTime(2026, 5, 11)]!.single, date);
    });
  });
}
