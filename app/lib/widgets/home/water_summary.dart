import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';

import '../../models/water_log.dart';
import '../../screens/log_water/log_water_sheet.dart';

const _kGoalMl = 1893; // 64 oz

class WaterSummary extends StatelessWidget {
  final List<WaterLog> logs;
  final VoidCallback onReload;

  const WaterSummary({super.key, required this.logs, required this.onReload});

  int get _totalMl => logs.fold(0, (sum, l) => sum + l.amountMl);
  int get _totalOz => (_totalMl / 29.5735).round();
  int get _goalOz => (_kGoalMl / 29.5735).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_totalMl / _kGoalMl).clamp(0.0, 1.0);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 12, color: Colors.blue.shade600),
              const SizedBox(width: 4),
              Text('WATER', style: labelStyle),
              const Spacer(),
              Text(
                '$_totalOz / $_goalOz oz',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _totalMl >= _kGoalMl ? Colors.blue.shade700 : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...logs.map((log) => _WaterRow(log: log, onReload: onReload)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: LiquidLinearProgressIndicator(
              value: progress,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade300.withAlpha(110)),
              backgroundColor: Colors.blue.withAlpha(22),
              borderColor: Colors.transparent,
              borderWidth: 0,
              borderRadius: 8,
              direction: Axis.horizontal,
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _WaterRow extends StatelessWidget {
  final WaterLog log;
  final VoidCallback onReload;

  const _WaterRow({required this.log, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'water-row-${log.id}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(
              log.time,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(width: 8),
            Text(log.displayOz, style: theme.textTheme.bodySmall),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LogWaterSheet(existingLog: log),
                );
                onReload();
              },
              child: Icon(
                Icons.edit_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
