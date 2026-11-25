enum WatchKind { steps, sleep, hr } // stored as kind.name text

class WatchSample {
  final WatchKind kind;
  final DateTime time; // local DateTime of slot start
  final int value; // steps in slot / sleep stage 1-5 / bpm

  const WatchSample({required this.kind, required this.time, required this.value});

  @override
  bool operator ==(Object other) =>
      other is WatchSample &&
      other.kind == kind &&
      other.time == time &&
      other.value == value;

  @override
  int get hashCode => Object.hash(kind, time, value);
}

class WatchDaySummary {
  final int? steps; // null when no steps samples that day
  final Duration? sleep; // null when no counted sleep slots
  final int? hrMin, hrMax; // null when no hr samples
  final DateTime? asleepAt; // start of the earliest counted (1,2,3,5) slot in the sleep window
  final DateTime? awakeAt; // end (start + 10 min) of the latest counted slot in the window
  final Duration light, deep, rem, awake; // stage 2, 3, 5, 4 slots x 10 min in the window
  final DateTime? busiestHour; // local hour start with the most steps (earliest on tie)
  final int? busiestHourSteps;
  final int? hrAvg; // rounded mean of hr samples
  final int hrCount; // number of hr samples

  const WatchDaySummary({
    this.steps,
    this.sleep,
    this.hrMin,
    this.hrMax,
    this.asleepAt,
    this.awakeAt,
    this.light = Duration.zero,
    this.deep = Duration.zero,
    this.rem = Duration.zero,
    this.awake = Duration.zero,
    this.busiestHour,
    this.busiestHourSteps,
    this.hrAvg,
    this.hrCount = 0,
  });

  bool get isEmpty => steps == null && sleep == null && hrMin == null;

  @override
  bool operator ==(Object other) =>
      other is WatchDaySummary &&
      other.steps == steps &&
      other.sleep == sleep &&
      other.hrMin == hrMin &&
      other.hrMax == hrMax &&
      other.asleepAt == asleepAt &&
      other.awakeAt == awakeAt &&
      other.light == light &&
      other.deep == deep &&
      other.rem == rem &&
      other.awake == awake &&
      other.busiestHour == busiestHour &&
      other.busiestHourSteps == busiestHourSteps &&
      other.hrAvg == hrAvg &&
      other.hrCount == hrCount;

  @override
  int get hashCode => Object.hash(steps, sleep, hrMin, hrMax, asleepAt, awakeAt, light, deep,
      rem, awake, busiestHour, busiestHourSteps, hrAvg, hrCount);
}

/// Buckets samples by local calendar day key DateTime(y,m,d).
/// steps: sum per calendar day. hr: min/max per calendar day.
/// sleep: stages 1,2,3,5 (not 4) counted 10 min each, bucketed by the calendar day of
/// (time + 6 hours) — i.e. the window D-1 18:00 .. D 18:00 belongs to day D.
/// Stage 4 (awake) slots use the same bucketing but only feed `awake`; they never create
/// `sleep` or move asleepAt/awakeAt. Stage 1 counts toward sleep and times, no stage bucket.
/// Days with nothing are absent from the map.
Map<DateTime, WatchDaySummary> summarizeWatchDays(Iterable<WatchSample> samples) {
  const slot = Duration(minutes: 10);
  final steps = <DateTime, int>{};
  final stepsByHour = <DateTime, Map<DateTime, int>>{};
  final sleepSlots = <DateTime, int>{};
  final asleepAt = <DateTime, DateTime>{};
  final awakeAt = <DateTime, DateTime>{};
  final light = <DateTime, int>{};
  final deep = <DateTime, int>{};
  final rem = <DateTime, int>{};
  final awake = <DateTime, int>{};
  final hrMin = <DateTime, int>{};
  final hrMax = <DateTime, int>{};
  final hrSum = <DateTime, int>{};
  final hrCount = <DateTime, int>{};

  DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  for (final s in samples) {
    switch (s.kind) {
      case WatchKind.steps:
        final d = dayOf(s.time);
        steps[d] = (steps[d] ?? 0) + s.value;
        final hour = DateTime(s.time.year, s.time.month, s.time.day, s.time.hour);
        final hours = stepsByHour.putIfAbsent(d, () => {});
        hours[hour] = (hours[hour] ?? 0) + s.value;
      case WatchKind.sleep:
        // Calendar-field arithmetic (not Duration) so DST shifts don't move the bucket.
        final d = dayOf(DateTime(s.time.year, s.time.month, s.time.day,
            s.time.hour + 6, s.time.minute));
        if (s.value == 4) {
          awake[d] = (awake[d] ?? 0) + 1;
          break;
        }
        sleepSlots[d] = (sleepSlots[d] ?? 0) + 1;
        final start = asleepAt[d];
        if (start == null || s.time.isBefore(start)) asleepAt[d] = s.time;
        final end = s.time.add(slot);
        final lastEnd = awakeAt[d];
        if (lastEnd == null || end.isAfter(lastEnd)) awakeAt[d] = end;
        final bucket = switch (s.value) {
          2 => light,
          3 => deep,
          5 => rem,
          _ => null,
        };
        if (bucket != null) bucket[d] = (bucket[d] ?? 0) + 1;
      case WatchKind.hr:
        final d = dayOf(s.time);
        final lo = hrMin[d];
        final hi = hrMax[d];
        hrMin[d] = lo == null || s.value < lo ? s.value : lo;
        hrMax[d] = hi == null || s.value > hi ? s.value : hi;
        hrSum[d] = (hrSum[d] ?? 0) + s.value;
        hrCount[d] = (hrCount[d] ?? 0) + 1;
    }
  }

  Duration slots(Map<DateTime, int> m, DateTime d) => slot * (m[d] ?? 0);

  final days = <DateTime>{...steps.keys, ...sleepSlots.keys, ...hrMin.keys};
  return {
    for (final d in days)
      d: () {
        DateTime? busiest;
        int? busiestSteps;
        for (final e in (stepsByHour[d] ?? const <DateTime, int>{}).entries) {
          if (busiestSteps == null ||
              e.value > busiestSteps ||
              (e.value == busiestSteps && e.key.isBefore(busiest!))) {
            busiest = e.key;
            busiestSteps = e.value;
          }
        }
        return WatchDaySummary(
          steps: steps[d],
          sleep: sleepSlots[d] == null ? null : Duration(minutes: sleepSlots[d]! * 10),
          hrMin: hrMin[d],
          hrMax: hrMax[d],
          asleepAt: asleepAt[d],
          awakeAt: awakeAt[d],
          light: slots(light, d),
          deep: slots(deep, d),
          rem: slots(rem, d),
          awake: slots(awake, d),
          busiestHour: busiest,
          busiestHourSteps: busiestSteps,
          hrAvg: hrCount[d] == null ? null : (hrSum[d]! / hrCount[d]!).round(),
          hrCount: hrCount[d] ?? 0,
        );
      }(),
  };
}
