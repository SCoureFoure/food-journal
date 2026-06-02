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
        trailing: Semantics(
          identifier: 'btn-edit-feeling-${log.id}',
          child: GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/edit_checkin', arguments: log);
              onReload();
            },
            child: const Icon(Icons.edit_outlined, size: 24),
          ),
        ),
        children: [
          if (log.notes != null && log.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(log.notes!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
