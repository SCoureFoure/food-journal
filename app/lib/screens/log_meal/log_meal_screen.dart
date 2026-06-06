import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/ai_service.dart';
import '../../services/meal_memory/meal_memory_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/editable_food_item_card.dart';
import '../../widgets/error_display.dart';
import '../../widgets/create_saved_item_sheet.dart';
import '../../widgets/food_history_search_sheet.dart';
import '../../widgets/saved_items_sheet.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';
import '../../widgets/log_description_section.dart';
import '../../widgets/log_photo_section.dart';

class LogMealScreen extends StatefulWidget {
  final MealEntry? existingMeal;

  // Injection seams — production passes nothing; tests inject fakes so the
  // AI parse flow is exercisable without network or native SQLite.
  final StorageService? storageOverride;
  final AiService? aiOverride;
  final MealMemoryService? memoryOverride;
  final NotificationService? notificationsOverride;
  final SettingsService? settingsOverride;

  const LogMealScreen({
    super.key,
    this.existingMeal,
    this.storageOverride,
    this.aiOverride,
    this.memoryOverride,
    this.notificationsOverride,
    this.settingsOverride,
  });

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late final AiService _aiService;
  late final StorageService _storage;
  late final MealMemoryService _memory;
  late final NotificationService _notifications;
  late final SettingsService _settings;

  bool _aiEnabled = true;
  bool _isAutofilling = false;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<MealSuggestion> _suggestions = [];
  bool _suggestionDismissed = false;
  Timer? _debounce;

  String _mealType = DateTimeUtils.inferMealType();
  DateTime _mealDate = DateTimeUtils.today();
  TimeOfDay _mealTime = TimeOfDay.now();
  Uint8List? _imageBytes;

  final List<FoodItemFormData> _foodItems = [];

  bool get _isEditing => widget.existingMeal != null;

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void initState() {
    super.initState();
    _aiService = widget.aiOverride ?? AiService.fromEnv();
    _storage = widget.storageOverride ?? StorageService();
    _memory = widget.memoryOverride ?? MealMemoryService();
    _notifications = widget.notificationsOverride ?? NotificationService();
    _settings = widget.settingsOverride ?? SettingsService();
    _loadSettings();
    if (_isEditing) _loadExisting();
    _descCtrl.addListener(_onDescChanged);
  }

  void _onDescChanged() {
    if (_aiEnabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final text = _descCtrl.text.trim();
      if (text.isEmpty) {
        if (mounted) setState(() { _suggestions = []; _suggestionDismissed = false; });
        return;
      }
      final results = await _memory.findReferentialMeals(text);
      if (mounted) setState(() { _suggestions = results; _suggestionDismissed = false; });
    });
  }

  Future<void> _applyMealSuggestion(MealSuggestion suggestion) async {
    final withIngredients = await _storage.getFoodItemsWithIngredients(suggestion.mealId);
    if (!mounted) return;
    final formData = await Future.wait(
      withIngredients.map((r) async => FoodItemFormData.fromExisting(r.item, r.ingredients)),
    );
    if (!mounted) return;
    for (final f in _foodItems) {
      f.dispose();
    }
    setState(() {
      _suggestions = [];
      _suggestionDismissed = true;
      _foodItems
        ..clear()
        ..addAll(formData);
    });
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isAiEnabled;
    if (mounted) setState(() => _aiEnabled = enabled);
  }

  Future<void> _loadExisting() async {
    final meal = widget.existingMeal!;
    setState(() => _isLoading = true);

    _titleCtrl.text = meal.mealType;
    _descCtrl.text = meal.rawInput ?? '';
    _imageBytes = meal.imageData;

    final mealType = _mealTypes.contains(meal.mealType) ? meal.mealType : _mealType;

    final withIngredients = await _storage.getFoodItemsWithIngredients(meal.id!);
    final formData = await Future.wait(
      withIngredients.map((r) async => FoodItemFormData.fromExisting(r.item, r.ingredients)),
    );

    if (!mounted) return;
    setState(() {
      _mealDate = DateTime(meal.date.year, meal.date.month, meal.date.day);
      _mealTime = DateTimeUtils.parseTime(meal.time);
      _mealType = mealType;
      _foodItems
        ..clear()
        ..addAll(formData);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _descCtrl.removeListener(_onDescChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final f in _foodItems) {
      f.dispose();
    }
    super.dispose();
  }

  Widget _buildDidYouMeanBanner(ThemeData theme) {
    final s = _suggestions.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you mean?',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.displayLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _applyMealSuggestion(s),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text('Use this meal'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => setState(() => _suggestionDismissed = true),
              visualDensity: VisualDensity.compact,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autofill() async {
    final text = _descCtrl.text.trim();
    final image = _imageBytes;
    if (text.isEmpty && image == null) {
      setState(() => _errorMessage = 'Add a description or photo before autofilling.');
      return;
    }
    setState(() {
      _isAutofilling = true;
      _errorMessage = null;
    });

    String? mealContext;
    if (_aiEnabled && text.isNotEmpty && _memory.isReferential(text)) {
      mealContext = await _memory.buildContextSnippet(text);
    }

    final result = await _aiService.parseMeal(
      text: text.isEmpty ? null : text,
      imageBytes: image,
      mealType: _mealType,
      mealContext: mealContext,
    );

    if (!mounted) return;
    setState(() => _isAutofilling = false);

    if (!result.success || result.items == null) {
      setState(() => _errorMessage = result.errorMessage ?? 'Autofill failed.');
      return;
    }

    if (_titleCtrl.text.trim().isEmpty && result.title != null) {
      _titleCtrl.text = result.title!;
    }

    for (final f in _foodItems) {
      f.dispose();
    }
    setState(() {
      _foodItems
        ..clear()
        ..addAll(result.items!.map(FoodItemFormData.fromDraft));
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete meal?'),
        content: const Text('This cannot be undone.'),
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
    await _storage.deleteMeal(widget.existingMeal!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final drafts = _foodItems
          .map((f) => f.toDraft())
          .where((d) => d.name.isNotEmpty)
          .toList();

      final items = drafts
          .map((d) => FoodItem(
                mealId: 0,
                name: d.name,
                portion: d.portion,
                prep: d.prep,
                calories: d.calories,
                protein: d.protein,
                carbs: d.carbs,
                fat: d.fat,
                notes: d.notes,
                servings: d.servings,
              ))
          .toList();

      final ingredientsByItem = drafts
          .map((d) => d.ingredients
              .map((name) => Ingredient(foodItemId: 0, name: name))
              .toList())
          .toList();

      final now = DateTime.now();

      if (_isEditing) {
        final existing = widget.existingMeal!;
        final updated = MealEntry(
          id: existing.id,
          date: _mealDate,
          time: _mealTime.format(context),
          mealType: title,
          overallSymptoms: existing.overallSymptoms,
          rawInput: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          createdAt: existing.createdAt,
          imageData: _imageBytes,
        );
        await _storage.updateMeal(updated, items, ingredientsByItem);
      } else {
        final meal = MealEntry(
          date: _mealDate,
          time: _mealTime.format(context),
          mealType: title,
          rawInput: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          createdAt: now,
          imageData: _imageBytes,
        );
        final mealId = await _storage.saveMeal(meal, items, ingredientsByItem);
        final entryTime = DateTime(
          _mealDate.year, _mealDate.month, _mealDate.day,
          _mealTime.hour, _mealTime.minute,
        );
        await _notifications.scheduleCheckin(mealId, title, entryTime);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addBlankItem() {
    setState(() => _foodItems.add(FoodItemFormData.blank()));
  }

  Future<void> _addFromHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FoodHistorySearchSheet(
        onSelect: (draft) => setState(() => _foodItems.add(FoodItemFormData.fromDraft(draft))),
      ),
    );
  }

  Future<void> _addFromFavorites() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FoodHistorySearchSheet(
        initialFavoritesOnly: true,
        onSelect: (draft) => setState(() => _foodItems.add(FoodItemFormData.fromDraft(draft))),
      ),
    );
  }

  Future<void> _openMyItems() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SavedItemsSheet(
        onSelect: (draft) => setState(() => _foodItems.add(FoodItemFormData.fromDraft(draft))),
      ),
    );
  }

  Future<void> _openCreateItem() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateSavedItemSheet(
        onCreated: (draft) => setState(() => _foodItems.add(FoodItemFormData.fromDraft(draft))),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _foodItems[index].dispose();
      _foodItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'log-meal-screen',
      child: Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Meal' : 'Log Meal')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LogDateTimeRow(
                    date: _mealDate,
                    time: _mealTime,
                    enabled: !_isSaving,
                    onDateChanged: (d) => setState(() => _mealDate = d),
                    onTimeChanged: (t) => setState(() => _mealTime = t),
                    trailing: _isEditing
                        ? GestureDetector(
                            onTap: _isSaving ? null : _confirmDelete,
                            child: Icon(Icons.delete_outline,
                                size: 22, color: theme.colorScheme.onSurfaceVariant),
                          )
                        : null,
                    leading: DropdownButton<String>(
                      value: _mealType,
                      underline: const SizedBox.shrink(),
                      items: _mealTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: _isSaving ? null : (v) => setState(() => _mealType = v!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    identifier: 'log-meal-title',
                    child: TextField(
                      controller: _titleCtrl,
                      enabled: !_isSaving,
                      style: theme.textTheme.titleMedium,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        hintText: 'e.g. Chicken salad, Breakfast bowl',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LogPhotoSection(
                    imageBytes: _imageBytes,
                    enabled: !_isSaving && !_isAutofilling,
                    onImagePicked: (b) => setState(() => _imageBytes = b),
                    onClear: () => setState(() => _imageBytes = null),
                  ),
                  const SizedBox(height: 12),
                  LogDescriptionSection(
                    controller: _descCtrl,
                    aiEnabled: _aiEnabled,
                    isAutofilling: _isAutofilling,
                    onAutofill: _autofill,
                    hintText: 'Describe your meal…',
                    inputSemanticsId: 'log-meal-input',
                    autofillSemanticsId: 'btn-autofill-meal',
                  ),
                  const SizedBox(height: 20),
                  if (!_aiEnabled && _suggestions.isNotEmpty && !_suggestionDismissed)
                    _buildDidYouMeanBanner(theme),
                  Text('Food items', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  // Discovery row — compact labeled icon buttons
                  Row(
                    children: [
                      Semantics(
                        identifier: 'btn-add-from-favorites',
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _addFromFavorites,
                          icon: const Icon(Icons.star_outline, size: 15),
                          label: const Text('Favorites'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      Semantics(
                        identifier: 'btn-add-from-history',
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _addFromHistory,
                          icon: const Icon(Icons.history, size: 15),
                          label: const Text('History'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                      Semantics(
                        identifier: 'btn-my-items',
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _openMyItems,
                          icon: const Icon(Icons.bookmark_outline, size: 15),
                          label: const Text('My Items'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Action row — two equal-width buttons
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          identifier: 'btn-create-item',
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _openCreateItem,
                            icon: const Icon(Icons.add_box_outlined, size: 16),
                            label: const Text('Create item'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          identifier: 'btn-add-item',
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _addBlankItem,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add item'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (_foodItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No items yet — autofill or add manually.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ),
                  ...List.generate(
                    _foodItems.length,
                    (i) => EditableFoodItemCard(
                      key: ValueKey(i),
                      data: _foodItems[i],
                      onDelete: () => _removeItem(i),
                      reuseStorage: _storage,
                      reuseSemanticsId: 'food-reuse-suggestion-$i',
                      enabled: !_isSaving,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(message: _errorMessage!),
                  ],
                  const SizedBox(height: 16),
                  LoadingButton(
                    isLoading: _isSaving,
                    disabled: _isAutofilling,
                    label: _isEditing ? 'Save Changes' : 'Save Meal',
                    onPressed: _save,
                    semanticsId: 'btn-save-meal',
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }
}
