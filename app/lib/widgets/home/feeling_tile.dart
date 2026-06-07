import 'package:flutter/material.dart';

import '../../models/food_suspicion.dart' show titleCase;
import '../../models/reaction_log.dart';
import '../../services/storage_service.dart';

class FeelingTile extends StatefulWidget {
  final ReactionLog log;
  final VoidCallback onReload;
  final StorageService? storageOverride; // test seam — fake storage

  const FeelingTile({
    super.key,
    required this.log,
    required this.onReload,
    this.storageOverride,
  });

  @override
  State<FeelingTile> createState() => _FeelingTileState();
}

class _FeelingTileState extends State<FeelingTile> {
  // Lazy — only built when the tile is expanded, so the DB read never fires for
  // collapsed tiles in the feed.
  late final StorageService _storage = widget.storageOverride ?? StorageService();
  List<String>? _blamed; // null = not loaded yet
  bool _loading = false;

  @override
  void dispose() {
    if (widget.storageOverride == null) _storage.dispose();
    super.dispose();
  }

  Future<void> _loadBlamed() async {
    if (_blamed != null || _loading || widget.log.id == null) return;
    _loading = true;
    try {
      final names = await _storage.getManualBlamedNamesForLog(widget.log.id!);
      if (mounted) setState(() => _blamed = names);
    } catch (_) {
      if (mounted) setState(() => _blamed = const []);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = widget.log;
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
        onExpansionChanged: (expanded) {
          if (expanded) _loadBlamed();
        },
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
          if (_blamed != null && _blamed!.isNotEmpty) _blamedSection(theme),
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
                    widget.onReload();
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

  Widget _blamedSection(ThemeData theme) {
    return Semantics(
      identifier: 'feeling-blamed-items-${widget.log.id}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text('Blamed',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final name in _blamed!)
                  Chip(
                    label: Text(titleCase(name)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
