import 'package:flutter/material.dart';

import '../../services/import_service.dart';
import '../../services/storage_service.dart';

class ImportWizardScreen extends StatefulWidget {
  final String filePath;
  const ImportWizardScreen({super.key, required this.filePath});

  @override
  State<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends State<ImportWizardScreen> {
  final _storage = StorageService();
  late final ImportService _import;

  bool _isLoading = true;
  String? _error;
  ImportPayload? _payload;

  bool _includeMeals = true;
  bool _includeMedications = true;
  bool _includeMemories = true;
  bool _includeWater = true;
  bool _includeWeight = true;
  bool _includeSavedItems = true;

  Set<int> _selectedMeals = {};
  Set<int> _selectedMedications = {};
  Set<int> _selectedMemories = {};
  Set<int> _selectedWater = {};
  Set<int> _selectedWeight = {};
  Set<int> _selectedSavedItems = {};

  Set<int> _mealDupes = {};
  Set<int> _medDupes = {};
  Set<int> _memoryDupes = {};
  Set<int> _waterDupes = {};
  Set<int> _weightDupes = {};
  Set<int> _savedItemDupes = {};

  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _import = ImportService(_storage);
    _loadAndDetect();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  Future<void> _loadAndDetect() async {
    try {
      final payload = await _import.parseFile(widget.filePath);
      final dupes = await _import.detectDupes(payload);

      final selectedMeals = <int>{};
      for (var i = 0; i < payload.meals.length; i++) {
        if (!dupes.mealDupes.contains(i)) selectedMeals.add(i);
      }
      final selectedMedications = <int>{};
      for (var i = 0; i < payload.medications.length; i++) {
        if (!dupes.medDupes.contains(i)) selectedMedications.add(i);
      }
      final selectedMemories = <int>{};
      for (var i = 0; i < payload.foodMemories.length; i++) {
        if (!dupes.memoryDupes.contains(i)) selectedMemories.add(i);
      }
      final selectedWater = <int>{};
      for (var i = 0; i < payload.waterLogs.length; i++) {
        if (!dupes.waterDupes.contains(i)) selectedWater.add(i);
      }
      final selectedWeight = <int>{};
      for (var i = 0; i < payload.weightLogs.length; i++) {
        if (!dupes.weightDupes.contains(i)) selectedWeight.add(i);
      }
      final selectedSavedItems = <int>{};
      for (var i = 0; i < payload.savedItems.length; i++) {
        if (!dupes.savedItemDupes.contains(i)) selectedSavedItems.add(i);
      }

      if (!mounted) return;
      setState(() {
        _payload = payload;
        _mealDupes = dupes.mealDupes;
        _medDupes = dupes.medDupes;
        _memoryDupes = dupes.memoryDupes;
        _waterDupes = dupes.waterDupes;
        _weightDupes = dupes.weightDupes;
        _savedItemDupes = dupes.savedItemDupes;
        _selectedMeals = selectedMeals;
        _selectedMedications = selectedMedications;
        _selectedMemories = selectedMemories;
        _selectedWater = selectedWater;
        _selectedWeight = selectedWeight;
        _selectedSavedItems = selectedSavedItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to parse file: $e';
        _isLoading = false;
      });
    }
  }

  int get _importCount {
    int count = 0;
    if (_includeMeals) count += _selectedMeals.length;
    if (_includeMedications) count += _selectedMedications.length;
    if (_includeMemories) count += _selectedMemories.length;
    if (_includeWater) count += _selectedWater.length;
    if (_includeWeight) count += _selectedWeight.length;
    if (_includeSavedItems) count += _selectedSavedItems.length;
    return count;
  }

  Future<void> _doImport() async {
    final payload = _payload!;
    setState(() => _isImporting = true);
    try {
      final selection = ImportSelection(
        mealIndices: _includeMeals ? Set.of(_selectedMeals) : {},
        medicationIndices: _includeMedications ? Set.of(_selectedMedications) : {},
        foodMemoryIndices: _includeMemories ? Set.of(_selectedMemories) : {},
        waterIndices: _includeWater ? Set.of(_selectedWater) : {},
        weightIndices: _includeWeight ? Set.of(_selectedWeight) : {},
        savedItemIndices: _includeSavedItems ? Set.of(_selectedSavedItems) : {},
      );
      final count = await _import.importSelected(payload, selection);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $count ${count == 1 ? 'record' : 'records'}')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'import-wizard-screen',
      child: Scaffold(
        appBar: AppBar(title: const Text('Import')),
        body: _buildBody(),
        bottomNavigationBar: _payload != null ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final payload = _payload!;
    if (payload.meals.isEmpty &&
        payload.medications.isEmpty &&
        payload.foodMemories.isEmpty &&
        payload.waterLogs.isEmpty &&
        payload.weightLogs.isEmpty &&
        payload.savedItems.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No importable data found in file.', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      children: [
        if (payload.meals.isNotEmpty)
          _SectionTile(
            title: 'Meals',
            count: payload.meals.length,
            included: _includeMeals,
            onToggle: (v) => setState(() => _includeMeals = v),
            selectedCount: _selectedMeals.length,
            onSelectAll: () => setState(() {
              _selectedMeals = Set.from(List.generate(payload.meals.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedMeals = {}),
            children: List.generate(payload.meals.length, (i) {
              final record = payload.meals[i];
              final subtitle = record.foodItems.isEmpty
                  ? null
                  : record.foodItems.map((fi) => fi.name).join(', ');
              return _ItemRow(
                key: ValueKey('meal-$i'),
                title:
                    '${record.meal.date.toIso8601String().split('T').first} · ${record.meal.time} · ${record.meal.mealType}',
                subtitle: subtitle,
                isDupe: _mealDupes.contains(i),
                selected: _selectedMeals.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedMeals.add(i); }
                  else { _selectedMeals.remove(i); }
                }),
              );
            }),
          ),
        if (payload.medications.isNotEmpty)
          _SectionTile(
            title: 'Medications',
            count: payload.medications.length,
            included: _includeMedications,
            onToggle: (v) => setState(() => _includeMedications = v),
            selectedCount: _selectedMedications.length,
            onSelectAll: () => setState(() {
              _selectedMedications =
                  Set.from(List.generate(payload.medications.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedMedications = {}),
            children: List.generate(payload.medications.length, (i) {
              final med = payload.medications[i];
              final subtitle =
                  med.dose != null ? '${med.dose} ${med.unit ?? ''}'.trim() : null;
              return _ItemRow(
                key: ValueKey('med-$i'),
                title:
                    '${med.date.toIso8601String().split('T').first} · ${med.time} · ${med.name}',
                subtitle: subtitle,
                isDupe: _medDupes.contains(i),
                selected: _selectedMedications.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedMedications.add(i); }
                  else { _selectedMedications.remove(i); }
                }),
              );
            }),
          ),
        if (payload.foodMemories.isNotEmpty)
          _SectionTile(
            title: 'Food Memories',
            count: payload.foodMemories.length,
            included: _includeMemories,
            onToggle: (v) => setState(() => _includeMemories = v),
            selectedCount: _selectedMemories.length,
            onSelectAll: () => setState(() {
              _selectedMemories =
                  Set.from(List.generate(payload.foodMemories.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedMemories = {}),
            children: List.generate(payload.foodMemories.length, (i) {
              final mem = payload.foodMemories[i];
              return _ItemRow(
                key: ValueKey('mem-$i'),
                title: mem.foodName,
                subtitle: mem.reactionPattern,
                isDupe: _memoryDupes.contains(i),
                selected: _selectedMemories.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedMemories.add(i); }
                  else { _selectedMemories.remove(i); }
                }),
              );
            }),
          ),
        if (payload.waterLogs.isNotEmpty)
          _SectionTile(
            title: 'Water',
            count: payload.waterLogs.length,
            included: _includeWater,
            onToggle: (v) => setState(() => _includeWater = v),
            selectedCount: _selectedWater.length,
            onSelectAll: () => setState(() {
              _selectedWater = Set.from(List.generate(payload.waterLogs.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedWater = {}),
            children: List.generate(payload.waterLogs.length, (i) {
              final w = payload.waterLogs[i];
              return _ItemRow(
                key: ValueKey('water-$i'),
                title:
                    '${w.date.toIso8601String().split('T').first} · ${w.time} · ${w.amountMl} ml',
                subtitle: w.notes,
                isDupe: _waterDupes.contains(i),
                selected: _selectedWater.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedWater.add(i); }
                  else { _selectedWater.remove(i); }
                }),
              );
            }),
          ),
        if (payload.weightLogs.isNotEmpty)
          _SectionTile(
            title: 'Weight',
            count: payload.weightLogs.length,
            included: _includeWeight,
            onToggle: (v) => setState(() => _includeWeight = v),
            selectedCount: _selectedWeight.length,
            onSelectAll: () => setState(() {
              _selectedWeight = Set.from(List.generate(payload.weightLogs.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedWeight = {}),
            children: List.generate(payload.weightLogs.length, (i) {
              final w = payload.weightLogs[i];
              return _ItemRow(
                key: ValueKey('weight-$i'),
                title:
                    '${w.date.toIso8601String().split('T').first} · ${w.time} · ${w.weightValue} ${w.unit}',
                subtitle: w.notes,
                isDupe: _weightDupes.contains(i),
                selected: _selectedWeight.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedWeight.add(i); }
                  else { _selectedWeight.remove(i); }
                }),
              );
            }),
          ),
        if (payload.savedItems.isNotEmpty)
          _SectionTile(
            title: 'Saved Items',
            count: payload.savedItems.length,
            included: _includeSavedItems,
            onToggle: (v) => setState(() => _includeSavedItems = v),
            selectedCount: _selectedSavedItems.length,
            onSelectAll: () => setState(() {
              _selectedSavedItems =
                  Set.from(List.generate(payload.savedItems.length, (i) => i));
            }),
            onDeselectAll: () => setState(() => _selectedSavedItems = {}),
            children: List.generate(payload.savedItems.length, (i) {
              final s = payload.savedItems[i];
              final macros = s.calories != null ? '${s.calories} cal' : null;
              return _ItemRow(
                key: ValueKey('saved-$i'),
                title: s.name,
                subtitle: macros,
                isDupe: _savedItemDupes.contains(i),
                selected: _selectedSavedItems.contains(i),
                onChanged: (v) => setState(() {
                  if (v == true) { _selectedSavedItems.add(i); }
                  else { _selectedSavedItems.remove(i); }
                }),
              );
            }),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final count = _importCount;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Semantics(
          identifier: 'btn-import-confirm',
          child: ElevatedButton(
            onPressed: count == 0 || _isImporting ? null : _doImport,
            child: _isImporting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Import $count ${count == 1 ? 'item' : 'items'}'),
          ),
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final String title;
  final int count;
  final bool included;
  final ValueChanged<bool> onToggle;
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final List<Widget> children;

  const _SectionTile({
    required this.title,
    required this.count,
    required this.included,
    required this.onToggle,
    required this.selectedCount,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
          child: Row(
            children: [
              Switch(value: included, onChanged: onToggle),
              Text(
                '$title ($count)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: included ? null : theme.disabledColor,
                ),
              ),
              const Spacer(),
              if (included) ...[
                TextButton(onPressed: onSelectAll, child: const Text('All')),
                TextButton(onPressed: onDeselectAll, child: const Text('None')),
              ],
            ],
          ),
        ),
        if (included) ...children,
        const Divider(height: 1),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isDupe;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  const _ItemRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.isDupe,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      dense: true,
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDupe)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Tooltip(
                message: 'Possible duplicate',
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, overflow: TextOverflow.ellipsis, maxLines: 1)
          : null,
    );
  }
}
