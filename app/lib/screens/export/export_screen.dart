import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/grocery.dart';
import '../../services/export_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../import/import_wizard_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late final StorageService _storage;
  late final ExportService _export;
  late final SettingsService _settings;
  bool _aiEnabled = true;

  DateTime? _from;
  DateTime? _to;
  bool _includeMeals = true;
  bool _includeMedications = true;
  bool _includeFoodMemories = true;
  bool _includePhotos = false;
  GroceryWindowMode _groceryMode = kDefaultGroceryWindowMode;
  int _groceryMealWindow = kDefaultGroceryMealWindow;
  int _groceryDayWindow = kDefaultGroceryDayWindow;
  bool _isLoading = false;
  String? _error;

  int get _groceryWindowSize => _groceryMode == GroceryWindowMode.meals
      ? _groceryMealWindow
      : _groceryDayWindow;

  final _fmt = DateFormat('MMM d, yyyy');

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
    return Semantics(
      identifier: 'export-screen',
      child: Scaffold(
        appBar: AppBar(title: const Text('Export / Import')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Date range ──────────────────────────────────────
                    Card(
                      child: Column(
                        children: [
                          Semantics(
                            identifier: 'btn-date-from',
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('From'),
                              subtitle: Text(
                                  _from == null ? 'All time' : _fmt.format(_from!)),
                              trailing: _from != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          setState(() => _from = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _pickFrom,
                            ),
                          ),
                          const Divider(height: 0),
                          Semantics(
                            identifier: 'btn-date-to',
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('To'),
                              subtitle: Text(
                                  _to == null ? 'Today' : _fmt.format(_to!)),
                              trailing: _to != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          setState(() => _to = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _pickTo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Include toggles ─────────────────────────────────
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Include',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-meals',
                            child: SwitchListTile(
                              title: const Text('Meals'),
                              value: _includeMeals,
                              onChanged: (v) =>
                                  setState(() => _includeMeals = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-medications',
                            child: SwitchListTile(
                              title: const Text('Medications'),
                              value: _includeMedications,
                              onChanged: (v) =>
                                  setState(() => _includeMedications = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-memories',
                            child: SwitchListTile(
                              title: const Text('Food Memories'),
                              value: _includeFoodMemories,
                              onChanged: (v) =>
                                  setState(() => _includeFoodMemories = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-photos',
                            child: SwitchListTile(
                              title: const Text('Photos'),
                              subtitle: const Text('Larger file — off by default'),
                              value: _includePhotos,
                              onChanged: (v) =>
                                  setState(() => _includePhotos = v),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Grocery list ─────────────────────────────────────
                    Card(
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
                                    selected:
                                        _groceryMode == GroceryWindowMode.meals,
                                    onSelected: (_) => setState(() =>
                                        _groceryMode = GroceryWindowMode.meals),
                                  ),
                                ),
                                Semantics(
                                  identifier: 'chip-grocery-mode-days',
                                  child: ChoiceChip(
                                    label: const Text('By days'),
                                    selected:
                                        _groceryMode == GroceryWindowMode.days,
                                    onSelected: (_) => setState(() =>
                                        _groceryMode = GroceryWindowMode.days),
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
                                            identifier:
                                                'chip-grocery-meals-$n',
                                            child: ChoiceChip(
                                              label: Text('$n meals'),
                                              selected:
                                                  n == _groceryMealWindow,
                                              onSelected: (_) => setState(
                                                  () => _groceryMealWindow =
                                                      n),
                                            ),
                                          ))
                                      .toList()
                                  : kGroceryDayWindows
                                      .map((n) => Semantics(
                                            identifier: 'chip-grocery-days-$n',
                                            child: ChoiceChip(
                                              label: Text('$n days'),
                                              selected: n == _groceryDayWindow,
                                              onSelected: (_) => setState(
                                                  () =>
                                                      _groceryDayWindow = n),
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
                                onPressed: _exportGroceryList,
                                icon: const Icon(Icons.shopping_cart_outlined),
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
                                  onPressed: _exportTidiedGroceryList,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Tidy with AI & share'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],

                    // ── Export button ───────────────────────────────────
                    Semantics(
                      identifier: 'btn-export-json',
                      child: ElevatedButton.icon(
                        onPressed: _exportJson,
                        icon: const Icon(Icons.upload),
                        label: const Text('Export as JSON'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Import button ───────────────────────────────────
                    Semantics(
                      identifier: 'btn-import-json',
                      child: OutlinedButton.icon(
                        onPressed: _pickAndImport,
                        icon: const Icon(Icons.download),
                        label: const Text('Import from JSON'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _to ?? DateTime.now(),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: _from ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _exportJson() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await _export.exportJson(
        from: _from,
        to: _to,
        types: ExportTypes(
          meals: _includeMeals,
          medications: _includeMedications,
          foodMemories: _includeFoodMemories,
          images: _includePhotos,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportGroceryList() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await _export.exportGroceryList(mode: _groceryMode, size: _groceryWindowSize);
    } catch (e) {
      _showError('Grocery list failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportTidiedGroceryList() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await _export.exportTidiedGroceryList(
        mode: _groceryMode,
        size: _groceryWindowSize,
      );
    } catch (e) {
      _showError('Tidy failed: ${_errorText(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImportWizardScreen(filePath: result.files.single.path!),
      ),
    );
  }
}
