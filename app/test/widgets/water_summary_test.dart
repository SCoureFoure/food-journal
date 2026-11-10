import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/water_log.dart';
import 'package:food_journal/widgets/home/water_summary.dart';

Widget _host(List<WaterLog> logs, {int? goalMl}) => MaterialApp(
      home: Scaffold(
        body: goalMl == null
            ? WaterSummary(logs: logs, onReload: () {})
            : WaterSummary(logs: logs, onReload: () {}, goalMl: goalMl),
      ),
    );

WaterLog _log(int ml) => WaterLog(
      id: 1,
      date: DateTime(2026, 1, 1),
      time: '12:00 PM',
      amountMl: ml,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('[MFT] WaterSummary per-day goal (AC12)', () {
    // testTheory: MFT
    // contract: a goalMl of 2366 renders the header target as 80 oz.
    // implication: if this fails, the per-day water target never reaches the
    // journal's water bar and it stays pinned to 64 oz.
    testWidgets('goalMl 2366 reads / 80 oz', (tester) async {
      await tester.pumpWidget(_host([_log(1000)], goalMl: 2366));
      await tester.pump();

      expect(find.text('34 / 80 oz'), findsOneWidget);
    });
  });

  group('[INV] WaterSummary default goal', () {
    // testTheory: INV
    // contract: without goalMl the target is the original 64 oz.
    // implication: if this fails, users who never set goals see their water
    // bar change behaviour.
    testWidgets('no goalMl reads / 64 oz', (tester) async {
      await tester.pumpWidget(_host([_log(1000)]));
      await tester.pump();

      expect(find.text('34 / 64 oz'), findsOneWidget);
    });
  });
}
