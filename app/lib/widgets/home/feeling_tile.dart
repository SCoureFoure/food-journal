import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/reaction_log.dart';

class FeelingTile extends StatelessWidget {
  final ReactionLog log;
  final VoidCallback onReload;

  const FeelingTile({super.key, required this.log, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = TimeOfDay.fromDateTime(log.checkinTime).format(context);
    final severityLabel = log.severity == ReactionLevel.none ? 'No reaction' : log.severity.label;
    final symptomStr = log.symptoms.isEmpty ? '' : log.symptoms.join(', ');
    final subtitle = [timeStr, severityLabel, if (symptomStr.isNotEmpty) symptomStr].join(' · ');

    return Semantics(
      identifier: 'feeling-tile-${log.id}',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.sentiment_satisfied_alt_outlined,
          color: theme.colorScheme.tertiary,
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
