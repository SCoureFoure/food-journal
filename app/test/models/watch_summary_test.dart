import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/watch_sample.dart';

WatchSample _s(WatchKind k, DateTime t, int v) => WatchSample(kind: k, time: t, value: v);

void main() {
  final d = DateTime(2026, 11, 23);
  final d1 = DateTime(2026, 11, 24);

  group('[MFT] summarizeWatchDays day math (AC5)', () {
    // testTheory: MFT
    // contract: steps = calendar-day sum; sleep = stage 1/2/3/5 slots from D-1 18:00 to D 18:00 x 10 min (stage 4 excluded); hr = calendar-day min-max.
    // implication: AC5 — if this fails, the journal shows the wrong steps, sleep or heart-rate range for a day.
    test('night spanning midnight, steps and hr on D', () {
      final samples = [
        // 22:30 D-1 .. 06:30 D: 7 slots of stage 2, one stage 4, one stage 3 at 06:30.
        for (var i = 0; i < 7; i++)
          _s(WatchKind.sleep, DateTime(2026, 11, 22, 22, 30 + i * 10), 2),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 0, 0), 4),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 6, 30), 3),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 9, 0), 1000),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 9, 10), 2360),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 9, 0), 62),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 12, 0), 109),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 15, 0), 80),
      ];
      final m = summarizeWatchDays(samples);
      // 22:30..23:30 -> 7 slots, plus 06:30 -> 8 counted slots = 80 min; stage 4 excluded.
      expect(m[d]!.steps, 3360);
      expect(m[d]!.sleep, const Duration(minutes: 80));
      expect(m[d]!.hrMin, 62);
      expect(m[d]!.hrMax, 109);
      expect(m.containsKey(DateTime(2026, 11, 22)), isFalse);
    });

    test('nap at 19:00 D counts to D+1, not D', () {
      final m = summarizeWatchDays([
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 19, 0), 2),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 17, 50), 2),
      ]);
      expect(m[d1]!.sleep, const Duration(minutes: 10));
      expect(m[d]!.sleep, const Duration(minutes: 10));
      expect(m[d]!.steps, isNull);
      expect(m[d]!.hrMin, isNull);
    });

    test('empty input yields empty map; summary isEmpty when nothing set', () {
      expect(summarizeWatchDays(const []), isEmpty);
      expect(const WatchDaySummary().isEmpty, isTrue);
    });
  });

  group('[MFT] summarizeWatchDays detail math (AC10)', () {
    // testTheory: MFT
    // contract: stage durations, asleep/awake clock times, busiest hour + steps, rounded hr average and reading count are exact.
    // implication: AC10 — if this fails, the expanded Biometrics tile shows wrong detail numbers.
    test('night with all stages, steps and hr on D', () {
      final m = summarizeWatchDays([
        _s(WatchKind.sleep, DateTime(2026, 11, 22, 23, 20), 1),
        _s(WatchKind.sleep, DateTime(2026, 11, 22, 23, 30), 2),
        _s(WatchKind.sleep, DateTime(2026, 11, 22, 23, 40), 2),
        _s(WatchKind.sleep, DateTime(2026, 11, 22, 23, 50), 3),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 0, 0), 5),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 0, 10), 4),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 0, 20), 4),
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 6, 20), 2),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 8, 0), 200),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 8, 50), 210),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 12, 0), 100),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 9, 0), 60),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 9, 15), 70),
        _s(WatchKind.hr, DateTime(2026, 11, 23, 9, 30), 81),
      ]);
      final s = m[d]!;
      expect(s.asleepAt, DateTime(2026, 11, 22, 23, 20));
      expect(s.awakeAt, DateTime(2026, 11, 23, 6, 30));
      expect(s.light, const Duration(minutes: 30));
      expect(s.deep, const Duration(minutes: 10));
      expect(s.rem, const Duration(minutes: 10));
      expect(s.awake, const Duration(minutes: 20));
      expect(s.sleep, const Duration(minutes: 60));
      expect(s.busiestHour, DateTime(2026, 11, 23, 8));
      expect(s.busiestHourSteps, 410);
      expect(s.hrAvg, 70);
      expect(s.hrCount, 3);
    });

    test('awake-only night does not create sleep', () {
      final m = summarizeWatchDays([
        _s(WatchKind.sleep, DateTime(2026, 11, 23, 0, 0), 4),
        _s(WatchKind.steps, DateTime(2026, 11, 23, 9, 0), 5),
      ]);
      expect(m[d]!.sleep, isNull);
      expect(m[d]!.asleepAt, isNull);
    });
  });
}
