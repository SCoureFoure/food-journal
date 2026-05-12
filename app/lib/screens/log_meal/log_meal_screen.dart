import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/ai_service.dart';
import '../../services/storage_service.dart';

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _textController = TextEditingController();
  final _aiService = AiService();
  final _storage = StorageService();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<FoodItemDraft>? _parsedItems;
  String _mealType = 'Lunch';

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsedItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (parsed == null) ..._inputSection(),
            if (parsed != null) ..._reviewSection(parsed),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            if (parsed == null)
              ElevatedButton(
                onPressed: _isLoading ? null : _parse,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Parse with AI'),
              ),
            if (parsed != null) ...[
              OutlinedButton(
                onPressed: _isLoading || _isSaving
                    ? null
                    : () => setState(() => _parsedItems = null),
                child: const Text('Re-enter'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Meal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _inputSection() => [
        TextField(
          controller: _textController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe your meal…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _pickImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Add Photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ];

  List<Widget> _reviewSection(List<FoodItemDraft> items) => [
        Row(
          children: [
            const Text('Meal type:'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _mealType,
              items: _mealTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _mealType = v!),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _FoodItemCard(item: item)),
        const SizedBox(height: 8),
      ];

  Future<void> _pickImage() async {
    // TODO: implement image picker
  }

  Future<void> _parse() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Enter a meal description.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final result = await _aiService.parseMeal(text: text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success || result.items == null) {
      setState(() => _errorMessage = result.errorMessage ?? 'Parse failed.');
      return;
    }

    setState(() => _parsedItems = result.items);
  }

  Future<void> _save() async {
    final drafts = _parsedItems;
    if (drafts == null || drafts.isEmpty) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final meal = MealEntry(
        date: DateTime(now.year, now.month, now.day),
        time: TimeOfDay.now().format(context),
        mealType: _mealType,
        rawInput: _textController.text.trim(),
        createdAt: now,
      );

      final items = drafts
          .map((d) => FoodItem(
                mealId: 0, // overwritten by saveMeal transaction
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

      await _storage.saveMeal(meal, items, ingredientsByItem);

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _FoodItemCard extends StatelessWidget {
  final FoodItemDraft item;
  const _FoodItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: theme.textTheme.titleSmall),
            if (item.portion != null || item.prep != null)
              Text(
                [item.portion, item.prep].whereType<String>().join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            _MacroRow(
              calories: item.calories,
              protein: item.protein,
              carbs: item.carbs,
              fat: item.fat,
            ),
            if (item.ingredients.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.ingredients.join(', '),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final int? calories, protein, carbs, fat;
  const _MacroRow({this.calories, this.protein, this.carbs, this.fat});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (calories != null) '${calories}kcal',
      if (protein != null) 'P ${protein}g',
      if (carbs != null) 'C ${carbs}g',
      if (fat != null) 'F ${fat}g',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
