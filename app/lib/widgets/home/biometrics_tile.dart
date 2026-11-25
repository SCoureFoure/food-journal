import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/watch_sample.dart';

class BiometricsTile extends StatelessWidget {
  final DateTime date;
  final WatchDaySummary summary;

  const BiometricsTile({super.key, required this.date, required this.summary});

  static String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h == 0 ? '${m}m' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final key = date.toIso8601String().substring(0, 10);
    final numbers = NumberFormat.decimalPattern();

    final parts = [
      if (summary.steps != null) '👣 ${numbers.format(summary.steps)}',
      if (summary.sleep != null) '😴 ${_duration(summary.sleep!)}',
      if (summary.hrMin != null)
        summary.hrMin == summary.hrMax
            ? '♥ ${summary.hrMin}'
            : '♥ ${summary.hrMin}–${summary.hrMax}',
    ];

    Widget section(String label, List<Widget> lines) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
              ...lines,
            ],
          ),
        );

    final stages = [
      if (summary.light > Duration.zero) 'Light ${_duration(summary.light)}',
      if (summary.deep > Duration.zero) 'Deep ${_duration(summary.deep)}',
      if (summary.rem > Duration.zero) 'REM ${_duration(summary.rem)}',
      if (summary.awake > Duration.zero) 'Awake ${_duration(summary.awake)}',
    ];

    String hourRange(DateTime h) {
      final next = DateTime(h.year, h.month, h.day, h.hour + 1);
      return '${DateFormat('h a').format(h)} – ${DateFormat('h a').format(next)}';
    }

    return Semantics(
      identifier: 'biometrics-tile-$key',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.monitor_heart_outlined),
        title: Semantics(
          identifier: 'biometrics-tile-header-$key',
          child: Text('Biometrics',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        subtitle: Text(parts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          if (summary.sleep != null)
            section('SLEEP', [
              Text('Sleep  ${_duration(summary.sleep!)}', style: theme.textTheme.bodyMedium),
              if (summary.asleepAt != null && summary.awakeAt != null)
                Text(
                    '${DateFormat.jm().format(summary.asleepAt!)} – ${DateFormat.jm().format(summary.awakeAt!)}',
                    style: theme.textTheme.bodySmall),
              if (stages.isNotEmpty)
                Text(stages.join(' · '), style: theme.textTheme.bodySmall),
            ]),
          if (summary.steps != null)
            section('STEPS', [
              Text('Steps  ${numbers.format(summary.steps)}', style: theme.textTheme.bodyMedium),
              if (summary.busiestHour != null)
                Text(
                    'busiest ${hourRange(summary.busiestHour!)} · ${summary.busiestHourSteps}',
                    style: theme.textTheme.bodySmall),
            ]),
          if (summary.hrMin != null)
            section('HEART RATE', [
              Text(
                  'Heart rate  ${summary.hrMin == summary.hrMax ? '${summary.hrMin}' : '${summary.hrMin}–${summary.hrMax}'} bpm',
                  style: theme.textTheme.bodyMedium),
              Text('avg ${summary.hrAvg} · ${summary.hrCount} readings',
                  style: theme.textTheme.bodySmall),
            ]),
        ],
      ),
    );
  }
}
