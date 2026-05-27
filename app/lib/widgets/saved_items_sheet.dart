import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/storage_service.dart';

class SavedItemsSheet extends StatefulWidget {
  final void Function(FoodItemDraft) onSelect;
  final StorageService? storageOverride;

  const SavedItemsSheet({super.key, required this.onSelect, this.storageOverride});

  @override
  State<SavedItemsSheet> createState() => _SavedItemsSheetState();
}

class _SavedItemsSheetState extends State<SavedItemsSheet> {
  final _searchCtrl = TextEditingController();
  late final StorageService _storage;
  List<FoodItemDraft> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageOverride ?? StorageService();
    _load('');
    _searchCtrl.addListener(() => _load(_searchCtrl.text));
  }

  Future<void> _load(String query) async {
    setState(() => _loading = true);
    final results = await _storage.searchSavedItems(query);
    if (mounted) setState(() { _items = results; _loading = false; });
  }

  Future<void> _delete(FoodItemDraft item) async {
    if (item.savedItemId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete saved item?'),
        content: Text('"${item.name}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _storage.deleteSavedItem(item.savedItemId!);
    if (mounted) _load(_searchCtrl.text);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('My Items', style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Semantics(
                  identifier: 'saved-items-search-field',
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: false,
                    decoration: const InputDecoration(
                      hintText: 'Search saved items…',
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
                    : _items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _searchCtrl.text.isEmpty
                                  ? 'No saved items yet — use Create item to build one.'
                                  : 'No saved items match "${_searchCtrl.text}".',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _items.length,
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final parts = <String>[
                                if (item.calories != null) '${item.calories} cal',
                                if (item.protein != null) '${item.protein}g protein',
                              ];
                              final componentSummary = item.ingredients.isNotEmpty
                                  ? item.ingredients.join(', ')
                                  : null;
                              return Semantics(
                                identifier: 'saved-item-$i',
                                child: ListTile(
                                  leading: Icon(
                                    Icons.bookmark_outline,
                                    size: 18,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                  title: Text(item.name),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (parts.isNotEmpty)
                                        Text(
                                          parts.join(' · '),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                      if (componentSummary != null)
                                        Text(
                                          componentSummary,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.outlineVariant,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Semantics(
                                        identifier: 'btn-delete-saved-item-$i',
                                        child: IconButton(
                                          icon: Icon(Icons.delete_outline,
                                              size: 20,
                                              color: theme.colorScheme.error),
                                          onPressed: () => _delete(item),
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Delete',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.add_circle_outline, size: 20),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    widget.onSelect(item);
                                  },
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
