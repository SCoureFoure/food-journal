import 'daily_goals.dart';
import 'goal_estimate.dart';
import 'weight_log.dart';

/// "170" for 170.0, "169.5" for 169.5.
String formatWeightLb(double lb) =>
    lb == lb.truncateToDouble() ? '${lb.toInt()}' : lb.toStringAsFixed(1);

class WeightGoalMet {
  final double targetWeightLb;
  final WeightDirection direction;

  const WeightGoalMet({required this.targetWeightLb, required this.direction});

  @override
  bool operator ==(Object other) =>
      other is WeightGoalMet &&
      other.targetWeightLb == targetWeightLb &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(targetWeightLb, direction);
}

/// Null when today's goal has no target or no qualifying weigh-in exists.
/// Weigh-ins with an id at or below [afterLogId] do not count.
WeightGoalMet? weightGoalMet(
    List<GoalSnapshot> history, List<WeightLog> logs, DateTime today,
    {int? afterLogId}) {
  final dayStart = DateTime(today.year, today.month, today.day);
  final eligible = history
      .where((s) => !s.effectiveDate.isAfter(dayStart))
      .toList()
    ..sort((a, b) {
      final c = a.effectiveDate.compareTo(b.effectiveDate);
      return c != 0 ? c : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  if (eligible.isEmpty) return null;

  final current = eligible.last.goals;
  final target = current.targetWeightLb;
  final dir = current.weightDirection;
  if (target == null || dir == null) return null;

  // The goal "run" is the unbroken stretch of snapshots sharing this target
  // and direction; weigh-ins only count from the run's start.
  var runStart = eligible.last.effectiveDate;
  for (var i = eligible.length - 1; i >= 0; i--) {
    final g = eligible[i].goals;
    if (g.targetWeightLb != target || g.weightDirection != dir) break;
    runStart = eligible[i].effectiveDate;
  }

  for (final log in logs) {
    if (afterLogId != null && (log.id ?? 0) <= afterLogId) continue;
    final logDay = DateTime(log.date.year, log.date.month, log.date.day);
    if (logDay.isBefore(runStart) || logDay.isAfter(dayStart)) continue;
    final lb = log.unit == 'kg' ? log.weightValue * kLbPerKg : log.weightValue;
    final reached = dir == WeightDirection.lose ? lb <= target : lb >= target;
    if (reached) return WeightGoalMet(targetWeightLb: target, direction: dir);
  }
  return null;
}
