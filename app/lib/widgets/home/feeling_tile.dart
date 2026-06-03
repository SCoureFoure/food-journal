import 'package:flutter/material.dart';

import '../../models/reaction_log.dart';

class FeelingTile extends StatelessWidget {
  final ReactionLog log;
  final VoidCallback onReload;

  const FeelingTile({super.key, required this.log, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = TimeOfDay.fromDateTime(log.checkinTime).format(context);
    final symptomStr = log.symptoms
        .map((s) {
          final lvl = log.symptomLevels[s];
          return lvl == null ? s : '$s (${lvl.label})';
        })
        .join(', ');
    final subtitle = [
      timeStr,
      if (log.mood != null) log.mood!.label,
      if (symptomStr.isEmpty) 'No reaction' else symptomStr,
    ].join(' · ');

    final faceIcon = log.mood?.face ?? Icons.sentiment_satisfied_alt_outlined;
    final faceColor = (log.mood?.isNegative ?? false)
        ? theme.colorScheme.error
        : theme.colorScheme.tertiary;

    return Semantics(
      identifier: 'feeling-tile-${log.id}',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          faceIcon,
          color: faceColor,
        ),
        title: Semantics(
          identifier: 'feeling-tile-header-${log.id}',
          child: Text(
            'How I felt',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        // Edit lives in the expanded body (mirrors MealTile's FoodItemCard.onEdit),
        // not the header trailing — a trailing tap target fights the ExpansionTile
        // InkWell and never reliably wins the gesture arena. Default chevron stays.
        children: [
          if (log.notes != null && log.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(log.notes!, style: theme.textTheme.bodySmall),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                identifier: 'btn-edit-feeling-${log.id}',
                button: true,
                child: TextButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/edit_checkin', arguments: log);
                    onReload();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
