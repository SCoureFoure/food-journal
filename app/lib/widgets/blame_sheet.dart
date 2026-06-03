import 'package:flutter/material.dart';

import '../models/food_suspicion.dart';
import '../services/storage_service.dart';

/// Modal for manually blaming recent food items / medications for the symptoms
/// in the current check-in. Lists everything logged within [kManualBlameWindow]
/// before [anchor], multi-select; returns the chosen [BlameCandidate]s via
/// `Navigator.pop`. See specs/food_blame.spec.md.
class BlameSheet extends StatefulWidget {
  final DateTime anchor;
  final Set<String> initiallySelectedKeys;
  final StorageService? storageOverride;

  const BlameSheet({
    super.key,
    required this.anchor,
    this.initiallySelectedKeys = const {},
    this.storageOverride,
  });

  @override
  State<BlameSheet> createState() => _BlameSheetState();
}

class _BlameSheetState extends State<BlameSheet> {
  late final StorageService _storage = widget.storageOverride ?? StorageService();
  final _searchCtrl = TextEditingController();
  List<BlameCandidate> _all = [];
  late Set<String> _selected;
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelectedKeys};
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim()));
    _load();
  }

  Future<void> _load() async {
    final results = await _storage.getBlameCandidates(
      anchor: widget.anchor,
      window: kManualBlameWindow,
    );
    if (mounted) setState(() { _all = results; _loading = false; });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    if (widget.storageOverride == null) _storage.dispose();
    super.dispose();
  }

  List<BlameCandidate> get _visible {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((c) => c.name.toLowerCase().contains(q)).toList();
  }

  void _confirm() {
    final chosen = _all.where((c) => _selected.contains(c.key)).toList();
    Navigator.of(context).pop(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'blame-sheet',
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('What might have caused this?',
                      style: theme.textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: Text('Recent foods & meds (past 24h)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    identifier: 'blame-search-field',
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search recent items…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _visible.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _all.isEmpty
                                    ? 'Nothing logged in the past 24 hours.'
                                    : 'No items match "$_query".',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.colorScheme.outline),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _visible.length,
                              itemBuilder: (context, i) {
                                final c = _visible[i];
                                final selected = _selected.contains(c.key);
                                final typeSlug = c.type == SuspicionTargetType.food
                                    ? 'food'
                                    : 'med';
                                return Semantics(
                                  identifier: 'blame-item-$typeSlug-${c.targetId}',
                                  child: CheckboxListTile(
                                    value: selected,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    secondary: Icon(
                                      c.type == SuspicionTargetType.food
                                          ? Icons.restaurant
                                          : Icons.medication_outlined,
                                      size: 20,
                                      color: theme.colorScheme.outline,
                                    ),
                                    title: Text(c.name),
                                    subtitle: Text(
                                      _subtitle(c),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.outline),
                                    ),
                                    onChanged: (v) => setState(() {
                                      if (v == true) {
                                        _selected.add(c.key);
                                      } else {
                                        _selected.remove(c.key);
                                      }
                                    }),
                                  ),
                                );
                              },
                            ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Semantics(
                    identifier: 'btn-blame-confirm',
                    child: FilledButton(
                      onPressed: _confirm,
                      child: Text(_selected.isEmpty
                          ? 'Done'
                          : 'Blame ${_selected.length} item${_selected.length == 1 ? '' : 's'}'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(BlameCandidate c) {
    final time = TimeOfDay.fromDateTime(c.timestamp).format(context);
    return c.subtitle != null && c.subtitle!.isNotEmpty
        ? '${c.subtitle} · $time'
        : time;
  }
}
