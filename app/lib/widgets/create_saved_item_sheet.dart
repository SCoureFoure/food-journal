import 'dart:async';

import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../models/saved_item.dart';
import '../services/ai_service.dart';
import '../services/meal_memory/meal_memory_service.dart';
import '../services/storage_service.dart';
import 'editable_food_item_card.dart';

class CreateSavedItemSheet extends StatefulWidget {
  final StorageService? storageOverride;
  final AiService? aiOverride;
  final MealMemoryService? memoryOverride;
  /// Called after save with the resulting draft, so caller can add it to the meal.
  final void Function(FoodItemDraft)? onCreated;

  const CreateSavedItemSheet({
    super.key,
    this.storageOverride,
    this.aiOverride,
    this.memoryOverride,
    this.onCreated,
  });

  @override
  State<CreateSavedItemSheet> createState() => _CreateSavedItemSheetState();
}

class _CreateSavedItemSheetState extends State<CreateSavedItemSheet> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _aiCtrl = TextEditingController();
  late final StorageService _storage;
  late final AiService _ai;
  late final MealMemoryService _memory;
  Timer? _debounce;

  final List<FoodItemFormData> _components = [];
  List<FoodItemDraft> _searchResults = [];
  bool _searching = false;
  bool _parsing = false;
  bool _saving = false;
  String? _error;

  // Live totals — rebuilt whenever a macro field changes.
  int _totalCalories = 0;
  int _totalProtein  = 0;
  int _totalCarbs    = 0;
  int _totalFat      = 0;

  @override
  void initState() {
    super.initState();
    _storage = widget.storageOverride ?? StorageService();
    _ai = widget.aiOverride ?? AiService.fromEnv();
    _memory = widget.memoryOverride ?? MealMemoryService();
    _searchCtrl.addListener(_onSearchChanged);
  }

  /// AI-optional: parses the description into component cards and prefills the
  /// name when empty. Any failure surfaces an error but leaves the manual form
  /// fully usable — never blocks.
  Future<void> _parse() async {
    final text = _aiCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a description to parse.');
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
    });

    // Pull historical meals into context when the text references past meals
    // ("leftovers", "same as last friday") — reuses the log-meal memory path.
    String? mealContext;
    if (_memory.isReferential(text)) {
      mealContext = await _memory.buildContextSnippet(text);
    }

    final result = await _ai.parseMeal(text: text, mealContext: mealContext);
    if (!mounted) return;

    if (!result.success || result.items == null || result.items!.isEmpty) {
      setState(() {
        _parsing = false;
        _error = result.errorMessage ?? 'Could not parse that — add items manually.';
      });
      return;
    }

    for (final draft in result.items!) {
      _addFormData(FoodItemFormData.fromDraft(draft));
    }
    final title = result.title?.trim();
    if (_nameCtrl.text.trim().isEmpty && title != null && title.isNotEmpty) {
      _nameCtrl.text = title;
    }
    setState(() => _parsing = false);
  }

  void _recomputeTotals() {
    setState(() {
      _totalCalories = _components.fold(0, (s, c) => s + (int.tryParse(c.caloriesCtrl.text.trim()) ?? 0));
      _totalProtein  = _components.fold(0, (s, c) => s + (int.tryParse(c.proteinCtrl.text.trim()) ?? 0));
      _totalCarbs    = _components.fold(0, (s, c) => s + (int.tryParse(c.carbsCtrl.text.trim()) ?? 0));
      _totalFat      = _components.fold(0, (s, c) => s + (int.tryParse(c.fatCtrl.text.trim()) ?? 0));
    });
  }

  void _addFormData(FoodItemFormData data) {
    data.caloriesCtrl.addListener(_recomputeTotals);
    data.proteinCtrl.addListener(_recomputeTotals);
    data.carbsCtrl.addListener(_recomputeTotals);
    data.fatCtrl.addListener(_recomputeTotals);
    setState(() => _components.add(data));
    _recomputeTotals();
  }

  void _addFromDraft(FoodItemDraft draft) {
    _addFormData(FoodItemFormData.fromDraft(draft));
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  void _addBlank() => _addFormData(FoodItemFormData.blank());

  void _removeComponent(int index) {
    final data = _components[index];
    data.caloriesCtrl.removeListener(_recomputeTotals);
    data.proteinCtrl.removeListener(_recomputeTotals);
    data.carbsCtrl.removeListener(_recomputeTotals);
    data.fatCtrl.removeListener(_recomputeTotals);
    data.dispose();
    setState(() => _components.removeAt(index));
    _recomputeTotals();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(_searchCtrl.text));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final results = await _storage.searchFoodHistory(query);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    if (_components.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final componentNames = _components
        .map((c) => c.nameCtrl.text.trim())
        .where((n) => n.isNotEmpty)
        .toList();

    final item = SavedItem(
      name: name,
      calories: _totalCalories > 0 ? _totalCalories : null,
      protein: _totalProtein  > 0 ? _totalProtein  : null,
      carbs:   _totalCarbs    > 0 ? _totalCarbs    : null,
      fat:     _totalFat      > 0 ? _totalFat      : null,
      components: componentNames,
      createdAt: DateTime.now(),
    );

    final id = await _storage.saveSavedItem(item);
    if (!mounted) return;

    final draft = FoodItemDraft(
      name: name,
      calories: item.calories,
      protein:  item.protein,
      carbs:    item.carbs,
      fat:      item.fat,
      ingredients: componentNames,
      isComposite: true,
      savedItemId: id,
    );

    Navigator.of(context).pop();
    widget.onCreated?.call(draft);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _aiCtrl.dispose();
    for (final c in _components) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                // ── Fixed header ─────────────────────────────────────────────
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Create saved item', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Build a reusable item from multiple ingredients — e.g. save your morning smoothie as one item.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_components.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$_totalCalories cal\n${_totalProtein}g P · ${_totalCarbs}g C · ${_totalFat}g F',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Semantics(
                    identifier: 'saved-item-name-field',
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Item name *',
                        hintText: 'e.g. Morning smoothie',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Scrollable body ──────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── AI parse (optional) ─────────────────────────────
                        Semantics(
                          identifier: 'saved-item-ai-field',
                          child: TextField(
                            controller: _aiCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Describe it for AI (optional)',
                              hintText: 'e.g. greek yogurt, granola, honey, blueberries',
                              prefixIcon: Icon(Icons.auto_awesome, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            identifier: 'btn-parse-saved-item-ai',
                            child: OutlinedButton.icon(
                              onPressed: _parsing ? null : _parse,
                              icon: _parsing
                                  ? const SizedBox(
                                      height: 15, width: 15,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.auto_awesome, size: 15),
                              label: Text(_parsing ? 'Parsing…' : 'Parse with AI'),
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        // Component cards
                        ...List.generate(
                          _components.length,
                          (i) => EditableFoodItemCard(
                            key: ValueKey(i),
                            data: _components[i],
                            onDelete: () => _removeComponent(i),
                          ),
                        ),
                        // Add buttons row
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                identifier: 'btn-create-item-add-blank',
                                child: OutlinedButton.icon(
                                  onPressed: _addBlank,
                                  icon: const Icon(Icons.add, size: 15),
                                  label: const Text('Add item'),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search from history
                        Semantics(
                          identifier: 'saved-item-search-field',
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Or search past items to add…',
                              prefixIcon: Icon(Icons.history, size: 18),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searching)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_searchResults.isNotEmpty)
                          ...List.generate(_searchResults.length, (i) {
                            final item = _searchResults[i];
                            final calStr = item.calories != null ? ' · ${item.calories} cal' : '';
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: Icon(
                                item.isComposite
                                    ? Icons.bookmark_outline
                                    : Icons.restaurant_outlined,
                                size: 16,
                                color: theme.colorScheme.outline,
                              ),
                              title: Text(item.name + calStr,
                                  style: theme.textTheme.bodyMedium),
                              trailing: const Icon(Icons.add_circle_outline, size: 20),
                              onTap: () => _addFromDraft(item),
                            );
                          }),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.error)),
                        ],
                        const SizedBox(height: 12),
                        Semantics(
                          identifier: 'btn-save-saved-item',
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(
                                    height: 18, width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Save item'),
                          ),
                        ),
                      ],
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
}
