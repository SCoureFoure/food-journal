import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/grocery.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';

class GroceryListCard extends StatefulWidget {
  /// Test seam — inject a fake-backed service. Null in production.
  final ExportService? exportOverride;

  const GroceryListCard({super.key, this.exportOverride});

  @override
  State<GroceryListCard> createState() => _GroceryListCardState();
}

class _GroceryListCardState extends State<GroceryListCard> {
  StorageService? _ownedStorage;
  late final ExportService _export;
  late final SettingsService _settings;

  final _controller = TextEditingController();
  bool _busy = false;
  bool _aiEnabled = true;
  GroceryWindowMode _groceryMode = kDefaultGroceryWindowMode;
  int _groceryMealWindow = kDefaultGroceryMealWindow;
  int _groceryDayWindow = kDefaultGroceryDayWindow;

  int get _groceryWindowSize => _groceryMode == GroceryWindowMode.meals
      ? _groceryMealWindow
      : _groceryDayWindow;

  @override
  void initState() {
    super.initState();
    if (widget.exportOverride != null) {
      _export = widget.exportOverride!;
    } else {
      _ownedStorage = StorageService();
      _export = ExportService(_ownedStorage!);
    }
    _settings = SettingsService();
    _controller.addListener(_onControllerChanged);
    _loadAiEnabled();
    _loadDraft();
  }

  Future<void> _loadAiEnabled() async {
    try {
      final enabled = await _settings.isAiEnabled;
      if (mounted) setState(() => _aiEnabled = enabled);
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — keep the default.
    }
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _settings.groceryDraft;
      if (mounted) _controller.text = draft;
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — keep the default.
    }
  }

  void _onControllerChanged() {
    _settings.setGroceryDraft(_controller.text);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _ownedStorage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasList = _controller.text.trim().isNotEmpty;
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
                  ? 'What you have been eating, most frequent first. Edit it, then copy or share. Tidy with AI merges duplicates and groups by aisle.'
                  : 'What you have been eating, most frequent first. Edit it, then copy or share.',
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
            child: hasList ? _buildListSection() : _buildGenerateButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Semantics(
      identifier: 'btn-generate-grocery-list',
      child: FilledButton.icon(
        onPressed: _busy ? null : _generate,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.shopping_cart_outlined),
        label: const Text('Generate list'),
      ),
    );
  }

  Widget _buildListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'grocery-list-field',
          child: TextField(
            controller: _controller,
            maxLines: null,
            minLines: 6,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              identifier: 'btn-copy-grocery-list',
              child: FilledButton.icon(
                onPressed: _busy ? null : _copy,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            Semantics(
              identifier: 'btn-share-grocery-list',
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Share'),
              ),
            ),
            if (_aiEnabled)
              Semantics(
                identifier: 'btn-tidy-grocery-list',
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _tidy,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tidy with AI'),
                ),
              ),
            Semantics(
              identifier: 'btn-retry-grocery-list',
              child: TextButton.icon(
                onPressed: _busy ? null : _retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            Semantics(
              identifier: 'btn-clear-grocery-list',
              child: TextButton.icon(
                onPressed: _busy ? null : _clear,
                icon: const Icon(Icons.close),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final text = await _export.buildGroceryListText(
        mode: _groceryMode,
        size: _groceryWindowSize,
      );
      _controller.text = text;
    } catch (e) {
      _showError('Grocery list failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async => _generate();

  Future<void> _tidy() async {
    setState(() => _busy = true);
    try {
      final text = await _export.tidyGroceryListText(_controller.text);
      _controller.text = text;
    } catch (e) {
      _showError('Tidy failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Future<void> _share() async {
    await _export.shareText(_controller.text);
  }

  void _clear() {
    _controller.clear();
    _settings.clearGroceryDraft();
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
