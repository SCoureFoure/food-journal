import 'package:flutter/material.dart';

import '../../models/weight_log.dart';

class WeightTile extends StatelessWidget {
  final WeightLog log;
  final VoidCallback onReload;

  const WeightTile({super.key, required this.log, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = '${log.time} · ${log.displayWeight}';

    return Semantics(
      identifier: 'weight-tile-${log.id}',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(
          Icons.monitor_weight_outlined,
          color: theme.colorScheme.secondary,
        ),
        title: Semantics(
          identifier: 'weight-tile-header-${log.id}',
          child: Text(
            'Weigh-in',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-weight-${log.id}',
          child: GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/edit_weight', arguments: log);
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
