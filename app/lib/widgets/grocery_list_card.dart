import 'package:flutter/material.dart';

import '../models/grocery.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

class GroceryListCard extends StatefulWidget {
  const GroceryListCard({super.key});

  @override
  State<GroceryListCard> createState() => _GroceryListCardState();
}

class _GroceryListCardState extends State<GroceryListCard> {
  late final StorageService _storage;
  late final ExportService _export;
  late final SettingsService _settings;
  bool _aiEnabled = true;

  GroceryWindowMode _groceryMode = kDefaultGroceryWindowMode;
  int _groceryMealWindow = kDefaultGroceryMealWindow;
  int _groceryDayWindow = kDefaultGroceryDayWindow;
  bool _busy = false;

  int get _groceryWindowSize => _groceryMode == GroceryWindowMode.meals
      ? _groceryMealWindow
      : _groceryDayWindow;

  @override
  void initState() {
    super.initState();
    _storage = StorageService();
    _export = ExportService(_storage);
    _settings = SettingsService();
    _loadAiEnabled();
  }

  Future<void> _loadAiEnabled() async {
    try {
      final enabled = await _settings.isAiEnabled;
      if (mounted) setState(() => _aiEnabled = enabled);
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — keep the default.
    }
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Grocery list',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _aiEnabled
                  ? 'What you have been eating, most frequent first. Tidy with AI merges duplicates and groups by aisle.'
                  : 'What you have been eating, most frequent first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                Semantics(
                  identifier: 'chip-grocery-mode-meals',
                  child: ChoiceChip(
                    label: const Text('By meals'),
                    selected: _groceryMode == GroceryWindowMode.meals,
                    onSelected: (_) =>
                        setState(() => _groceryMode = GroceryWindowMode.meals),
                  ),
                ),
                Semantics(
                  identifier: 'chip-grocery-mode-days',
                  child: ChoiceChip(
                    label: const Text('By days'),
                    selected: _groceryMode == GroceryWindowMode.days,
                    onSelected: (_) =>
                        setState(() => _groceryMode = GroceryWindowMode.days),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              children: _groceryMode == GroceryWindowMode.meals
                  ? kGroceryMealWindows
                      .map((n) => Semantics(
                            identifier: 'chip-grocery-meals-$n',
                            child: ChoiceChip(
                              label: Text('$n meals'),
                              selected: n == _groceryMealWindow,
                              onSelected: (_) =>
                                  setState(() => _groceryMealWindow = n),
                            ),
                          ))
                      .toList()
                  : kGroceryDayWindows
                      .map((n) => Semantics(
                            identifier: 'chip-grocery-days-$n',
                            child: ChoiceChip(
                              label: Text('$n days'),
                              selected: n == _groceryDayWindow,
                              onSelected: (_) =>
                                  setState(() => _groceryDayWindow = n),
                            ),
                          ))
                      .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Semantics(
              identifier: 'btn-generate-grocery-list',
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _exportGroceryList,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shopping_cart_outlined),
                label: const Text('Generate & share'),
              ),
            ),
          ),
          if (_aiEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Semantics(
                identifier: 'btn-tidy-grocery-list',
                child: FilledButton.icon(
                  onPressed: _busy ? null : _exportTidiedGroceryList,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Tidy with AI & share'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportGroceryList() async {
    setState(() => _busy = true);
    try {
      await _export.exportGroceryList(mode: _groceryMode, size: _groceryWindowSize);
    } catch (e) {
      _showError('Grocery list failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportTidiedGroceryList() async {
    setState(() => _busy = true);
    try {
      await _export.exportTidiedGroceryList(
        mode: _groceryMode,
        size: _groceryWindowSize,
      );
    } catch (e) {
      _showError('Tidy failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _errorText(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception: '), '');
}
