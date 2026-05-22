import 'dart:async';

import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/storage_service.dart';

class FoodHistorySearchSheet extends StatefulWidget {
  final void Function(FoodItemDraft) onSelect;
  // Injected for testing; defaults to the shared singleton in production.
  final StorageService? storageOverride;

  const FoodHistorySearchSheet({
    super.key,
    required this.onSelect,
    this.storageOverride,
  });

  @override
  State<FoodHistorySearchSheet> createState() => _FoodHistorySearchSheetState();
}

class _FoodHistorySearchSheetState extends State<FoodHistorySearchSheet> {
  final _searchCtrl = TextEditingController();
  late final StorageService _storage;
  Timer? _debounce;
  List<FoodItemDraft> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageOverride ?? StorageService();
    _load('');
    _searchCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load(_searchCtrl.text));
  }

  Future<void> _load(String query) async {
    setState(() => _loading = true);
    final results = await _storage.searchFoodHistory(query);
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onChanged);
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Add from history', style: theme.textTheme.titleMedium),
                    ),
                    // TODO_FAVORITES: Add a filter chip or tab here to toggle between
                    // "History" (all items) and "Favorites" (favorited == true).
                    // Storage already has toggleFoodFavorite(foodName) and searchFoodHistory
                    // returns FoodItemDraft — add a favorites query variant alongside it.
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Semantics(
                  identifier: 'food-history-search-field',
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search past items…',
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
                    : _results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _searchCtrl.text.isEmpty
                                  ? 'No meal history yet.'
                                  : 'No items match "${_searchCtrl.text}".',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final item = _results[i];
                              return Semantics(
                                identifier: 'history-item-$i',
                                child: ListTile(
                                  title: Text(item.name),
                                  subtitle: _subtitle(item, theme),
                                  trailing: const Icon(Icons.add_circle_outline, size: 20),
                                  // TODO_FAVORITES: Add a bookmark/star IconButton here.
                                  // On tap: call _storage.toggleFoodFavorite(item.name)
                                  // then setState to refresh the list (or update local state).
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

  Widget? _subtitle(FoodItemDraft item, ThemeData theme) {
    final parts = <String>[
      if (item.portion != null && item.portion!.isNotEmpty) item.portion!,
      if (item.calories != null) '${item.calories} cal',
      if (item.protein != null) '${item.protein}g protein',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
    );
  }
}
