import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/editable_food_item_card.dart';
import '../../widgets/log_date_time_row.dart';
import '../../widgets/log_description_section.dart';
import '../../widgets/log_photo_section.dart';

class LogMealScreen extends StatefulWidget {
  final MealEntry? existingMeal;

  const LogMealScreen({super.key, this.existingMeal});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _aiService = AiService.fromEnv();
  final _storage = StorageService();
  final _notifications = NotificationService();
  final _settings = SettingsService();

  bool _aiEnabled = true;
  bool _isAutofilling = false;
  bool _isSaving = false;
  bool _isLoading = false;
  String? _errorMessage;

  String _mealType = _inferMealType();
  DateTime _mealDate = _today();
  TimeOfDay _mealTime = TimeOfDay.now();
  Uint8List? _imageBytes;

  final List<FoodItemFormData> _foodItems = [];

  bool get _isEditing => widget.existingMeal != null;

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  static String _inferMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Breakfast';
    if (hour < 14) return 'Lunch';
    return 'Dinner';
  }

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (_isEditing) _loadExisting();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isAiEnabled;
    if (mounted) setState(() => _aiEnabled = enabled);
  }

  TimeOfDay _parseTime(String timeStr) {
    final m = RegExp(r'(\d+):(\d+)(?:\s*(AM|PM))?', caseSensitive: false).firstMatch(timeStr);
    if (m == null) return TimeOfDay.now();
    int hour = int.parse(m.group(1)!);
    final minute = int.parse(m.group(2)!);
    final period = m.group(3)?.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour % 24, minute: minute);
  }

  Future<void> _loadExisting() async {
    final meal = widget.existingMeal!;
    setState(() => _isLoading = true);

    _titleCtrl.text = meal.mealType;
    _descCtrl.text = meal.rawInput ?? '';
    _imageBytes = meal.imageData;

    final mealType = _mealTypes.contains(meal.mealType) ? meal.mealType : _mealType;

    final foodItems = await _storage.getFoodItemsForMeal(meal.id!);
    final withIngredients = await Future.wait(
      foodItems.map((item) async {
        final ings = item.id != null
            ? await _storage.getIngredientsForFoodItem(item.id!)
            : <Ingredient>[];
        return FoodItemFormData.fromExisting(item, ings);
      }),
    );

    if (!mounted) return;
    setState(() {
      _mealDate = DateTime(meal.date.year, meal.date.month, meal.date.day);
      _mealTime = _parseTime(meal.time);
      _mealType = mealType;
      _foodItems
        ..clear()
        ..addAll(withIngredients);
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    for (final f in _foodItems) {
      f.dispose();
    }
    super.dispose();
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

    final result = await _aiService.parseMeal(
      text: text.isEmpty ? null : text,
      imageBytes: image,
      mealType: _mealType,
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

  void _removeItem(int index) {
    setState(() {
      _foodItems[index].dispose();
      _foodItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Meal' : 'Log Meal')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Type / Date / Time ──────────────────────────────────────────
                  LogDateTimeRow(
                    date: _mealDate,
                    time: _mealTime,
                    enabled: !_isSaving,
                    onDateChanged: (d) => setState(() => _mealDate = d),
                    onTimeChanged: (t) => setState(() => _mealTime = t),
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

                  // ── Title ───────────────────────────────────────────────────────
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

                  // ── Photo ───────────────────────────────────────────────────────
                  LogPhotoSection(
                    imageBytes: _imageBytes,
                    enabled: !_isSaving && !_isAutofilling,
                    onImagePicked: (b) => setState(() => _imageBytes = b),
                    onClear: () => setState(() => _imageBytes = null),
                  ),
                  const SizedBox(height: 12),

                  // ── Description + Autofill ──────────────────────────────────────
                  LogDescriptionSection(
                    controller: _descCtrl,
                    aiEnabled: _aiEnabled,
                    isAutofilling: _isAutofilling,
                    onAutofill: _autofill,
                    hintText: 'Describe your meal…',
                  ),
                  const SizedBox(height: 20),

                  // ── Food items ──────────────────────────────────────────────────
                  Row(
                    children: [
                      Text('Food items', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _isSaving ? null : _addBlankItem,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add item'),
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
                    ),
                  ),

                  // ── Error ───────────────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),

                  // ── Save ────────────────────────────────────────────────────────
                  Semantics(
                    identifier: 'btn-save-meal',
                    child: ElevatedButton(
                      onPressed: _isSaving || _isAutofilling ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? 'Save Changes' : 'Save Meal'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
