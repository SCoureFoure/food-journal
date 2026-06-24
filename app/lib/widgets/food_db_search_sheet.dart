import 'dart:async';

import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../services/ai_service.dart';

// ignore_for_file: use_build_context_synchronously

/// Search an external open food database (USDA FoodData Central, proxied by the
/// Worker) for generic foods like "wheat bread" or "tuna sushi" and insert one
/// with its estimated macros. Distinct from [FoodHistorySearchSheet], which only
/// searches items the user has logged before.
class FoodDbSearchSheet extends StatefulWidget {
  final void Function(FoodItemDraft) onSelect;
  final AiService? aiOverride;

  const FoodDbSearchSheet({
    super.key,
    required this.onSelect,
    this.aiOverride,
  });

  @override
  State<FoodDbSearchSheet> createState() => _FoodDbSearchSheetState();
}

class _FoodDbSearchSheetState extends State<FoodDbSearchSheet> {
  static const _minQueryLength = 2;

  final _searchCtrl = TextEditingController();
  late final AiService _ai;
  Timer? _debounce;
  int _queryToken = 0;
  List<FoodItemDraft> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ai = widget.aiOverride ?? AiService.fromEnv();
    _searchCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(query));
  }

  Future<void> _search(String query) async {
    final token = ++_queryToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _ai.searchFoodDatabase(query);
    // Drop stale responses if a newer query has been issued.
    if (!mounted || token != _queryToken) return;
    setState(() {
      _loading = false;
      _searched = true;
      if (result.success) {
        _results = result.items ?? [];
      } else {
        _results = [];
        _error = result.errorMessage ?? 'Search failed.';
      }
    });
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
    return Semantics(
      identifier: 'food-db-search-sheet',
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Search food database', style: theme.textTheme.titleMedium),
                      ),
                      Icon(Icons.public, size: 18, color: theme.colorScheme.outline),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'USDA FoodData Central · macros are estimates',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    identifier: 'food-db-search-field',
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        hintText: 'e.g. wheat bread, tuna sushi…',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(child: _buildBody(theme)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _searched
              ? 'No matches for "${_searchCtrl.text.trim()}".'
              : 'Type at least $_minQueryLength characters to search.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final item = _results[i];
        return Semantics(
          identifier: 'food-db-item-$i',
          child: ListTile(
            title: Text(item.name),
            subtitle: _subtitle(item, theme),
            trailing: const Icon(Icons.add_circle_outline, size: 20),
            onTap: () {
              Navigator.of(context).pop();
              widget.onSelect(item);
            },
          ),
        );
      },
    );
  }

  Widget? _subtitle(FoodItemDraft item, ThemeData theme) {
    final parts = <String>[
      if (item.portion != null && item.portion!.isNotEmpty) item.portion!,
      if (item.calories != null) '${item.calories} cal',
      if (item.protein != null) '${item.protein}g protein',
      if (item.carbs != null) '${item.carbs}g carbs',
      if (item.fat != null) '${item.fat}g fat',
    ];
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
    );
  }
}
