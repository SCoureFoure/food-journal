import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/food_suspicion.dart';
import '../../services/storage_service.dart';
import '../../widgets/reaction_badge.dart';

/// Lists every `(check-in, symptom)` episode the suspicion ledger has accrued
/// — both quietly auto-blamed and deliberately manual-blamed — so the user can
/// dismiss the ones a 3rd party (illness, etc.) actually caused. Dismissing
/// excludes the whole episode from `getSuspicionScores` aggregation without
/// touching the underlying check-in. See specs/blame_history.spec.md.
///
/// Deliberately read-only beyond the toggle: no time editing, no navigation
/// into the check-in — that stays in `log_feeling`'s native edit flow.
class BlameHistoryScreen extends StatefulWidget {
  final StorageService? storageOverride; // test seam — fake storage

  const BlameHistoryScreen({super.key, this.storageOverride});

  @override
  State<BlameHistoryScreen> createState() => _BlameHistoryScreenState();
}

class _BlameHistoryScreenState extends State<BlameHistoryScreen> {
  late final StorageService _storage = widget.storageOverride ?? StorageService();

  List<BlameHistoryEntry>? _entries; // null = still loading
  String? _error;

  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (widget.storageOverride == null) _storage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final entries = await _storage.getBlameHistory();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Couldn\'t load blame history: $e');
    }
  }

  Future<void> _toggle(BlameHistoryEntry entry) async {
    try {
      await _storage.toggleSuspicionExclusion(
        reactionLogId: entry.reactionLogId,
        symptom: entry.symptom,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Couldn\'t update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'blame-history-screen',
      child: Scaffold(
        appBar: AppBar(title: const Text('Blame History')),
        body: _buildBody(Theme.of(context)),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error)),
        ),
      );
    }
    final entries = _entries;
    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return Center(
        child: Semantics(
          identifier: 'blame-history-empty-state',
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No blamed episodes yet. Once a logged feeling accrues suspicion '
              "against foods or medications, it'll show up here so you can "
              'review it — and dismiss it if something else (like being sick) '
              'was really the cause.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _entryCard(theme, entries[i]),
    );
  }

  Widget _entryCard(ThemeData theme, BlameHistoryEntry entry) {
    final timeStr = TimeOfDay.fromDateTime(entry.checkinTime).format(context);
    final names = entry.blamedNames.map(titleCase).join(', ');
    final anchorId = '${entry.reactionLogId}-${_symptomSlug(entry.symptom)}';
    final dismissed = entry.dismissed;
    final mutedColor = theme.colorScheme.outline;

    return Semantics(
      identifier: 'blame-history-item-$anchorId',
      child: Card(
        color: dismissed ? theme.colorScheme.surfaceContainerLow : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.symptom,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration:
                                  dismissed ? TextDecoration.lineThrough : null,
                              color: dismissed ? mutedColor : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ReactionBadge(level: entry.severity),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_dateFmt.format(entry.checkinTime)} · $timeStr',
                      style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Blamed: $names',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        decoration: dismissed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                identifier: 'btn-blame-history-toggle-$anchorId',
                button: true,
                child: dismissed
                    ? OutlinedButton(
                        onPressed: () => _toggle(entry),
                        child: const Text('Restore'),
                      )
                    : TextButton(
                        onPressed: () => _toggle(entry),
                        child: const Text('Dismiss'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Anchor ids can't carry spaces — "Stomach pain" -> "stomach-pain".
  static String _symptomSlug(String symptom) =>
      symptom.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
}
