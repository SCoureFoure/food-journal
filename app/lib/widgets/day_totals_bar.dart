import 'package:flutter/material.dart';

class DayTotalsBar extends StatelessWidget {
  final int cal;
  final double prot;
  final double carbs;
  final double fat;

  const DayTotalsBar({
    super.key,
    required this.cal,
    required this.prot,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    if (cal == 0 && prot == 0 && carbs == 0 && fat == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: primary,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: primary.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 12, color: primary),
              const SizedBox(width: 4),
              Text('DAY TOTALS', style: headerStyle),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (cal > 0) _TotalCell(label: 'CAL', value: '$cal', labelStyle: labelStyle, theme: theme),
              if (prot > 0) _TotalCell(label: 'PROT', value: '${prot.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (carbs > 0) _TotalCell(label: 'CARBS', value: '${carbs.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (fat > 0) _TotalCell(label: 'FAT', value: '${fat.toInt()}g', labelStyle: labelStyle, theme: theme),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;

  const _TotalCell({required this.label, required this.value, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
