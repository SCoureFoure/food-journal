import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  String _mealType = _inferMealType();
  Uint8List? _imageBytes;

  static const _mealTypes = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

  static String _inferMealType() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Breakfast';
    if (hour < 14) return 'Lunch';
    return 'Dinner';
  }

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
              icon: const Icon(Icons.photo_library),
              label: Text(_imageBytes == null ? 'Add Photo' : 'Change Photo'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(_imageBytes!, height: 48, width: 48, fit: BoxFit.cover),
              ),
            ],
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
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

    final result = await _aiService.parseMeal(text: text, imageBytes: _imageBytes);

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

class _FoodItemCard extends StatefulWidget {
  final FoodItemDraft item;
  const _FoodItemCard({required this.item});

  @override
  State<_FoodItemCard> createState() => _FoodItemCardState();
}

class _FoodItemCardState extends State<_FoodItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 18, color: theme.colorScheme.outline),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: theme.textTheme.titleSmall),
                        if (!_expanded && (item.portion != null || item.prep != null))
                          Text(
                            [item.portion, item.prep].whereType<String>().join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_expanded) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _MacroRow(
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                  ),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _DetailSection(item: item, theme: theme),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final FoodItemDraft item;
  final ThemeData theme;
  const _DetailSection({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.portion != null)
          _LabelValue(label: 'PORTION', value: item.portion!, labelStyle: labelStyle, theme: theme),
        if (item.prep != null)
          _LabelValue(label: 'PREP', value: item.prep!, labelStyle: labelStyle, theme: theme),
        if (item.portion != null || item.prep != null) const SizedBox(height: 8),
        _MacroGrid(
          calories: item.calories,
          protein: item.protein,
          carbs: item.carbs,
          fat: item.fat,
          labelStyle: labelStyle,
          theme: theme,
        ),
        if (item.ingredients.isNotEmpty) ...[
          const SizedBox(height: 8),
          _LabelValue(
            label: 'INGREDIENTS',
            value: item.ingredients.join(', '),
            labelStyle: labelStyle,
            theme: theme,
          ),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          _LabelValue(label: 'NOTES', value: item.notes!, labelStyle: labelStyle, theme: theme),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(width: 80, child: Text('REACTION', style: labelStyle)),
            const _ReactionTag(reaction: null),
          ],
        ),
      ],
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _LabelValue({required this.label, required this.value, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: labelStyle)),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _MacroGrid extends StatelessWidget {
  final int? calories, protein, carbs, fat;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _MacroGrid({
    this.calories, this.protein, this.carbs, this.fat,
    required this.labelStyle, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (calories == null && protein == null && carbs == null && fat == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (calories != null) _MacroCell(label: 'CAL', value: '$calories', labelStyle: labelStyle, theme: theme),
        if (protein != null) _MacroCell(label: 'PROT', value: '${protein}g', labelStyle: labelStyle, theme: theme),
        if (carbs != null) _MacroCell(label: 'CARBS', value: '${carbs}g', labelStyle: labelStyle, theme: theme),
        if (fat != null) _MacroCell(label: 'FAT', value: '${fat}g', labelStyle: labelStyle, theme: theme),
      ],
    );
  }
}

class _MacroCell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _MacroCell({required this.label, required this.value, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReactionTag extends StatelessWidget {
  final String? reaction;
  const _ReactionTag({required this.reaction});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (reaction) {
      null    => ('PENDING',     const Color(0xFFEEEBE5), const Color(0xFF7A6E62)),
      'none'  => ('NO REACTION', const Color(0xFFE8F0EA), const Color(0xFF4A7C59)),
      'mild'  => ('MILD',        const Color(0xFFFDF3E0), const Color(0xFFA06020)),
      'bad'   => ('BAD',         const Color(0xFFFCE8E4), const Color(0xFFC4502A)),
      _       => (reaction!.toUpperCase(), const Color(0xFFFDF3E0), const Color(0xFFA06020)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: bg,
      child: Text(
        label,
        style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: fg, fontWeight: FontWeight.w600),
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
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
