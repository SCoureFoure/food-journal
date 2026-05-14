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
      child: ListTile(
        tileColor: theme.colorScheme.surfaceContainerHighest,
        leading: Icon(
          Icons.sentiment_satisfied_alt_outlined,
          color: theme.colorScheme.tertiary,
        ),
        title: Text(
          'How I felt',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-feeling-${log.id}',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () async {
              await Navigator.pushNamed(context, '/edit_checkin', arguments: log);
              onReload();
            },
          ),
        ),
      ),
    );
  }
}
