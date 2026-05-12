import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/storage_service.dart';
import '../../widgets/macro_totals_bar.dart';
import '../../widgets/reaction_badge.dart';

class MealDetailScreen extends StatefulWidget {
  final int mealId;
  const MealDetailScreen({super.key, required this.mealId});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final _storage = StorageService();

  bool _isLoading = true;
  String? _errorMessage;
  MealEntry? _meal;
  List<_ItemWithIngredients> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final meal = await _storage.getMealById(widget.mealId);
      if (meal == null) throw Exception('Meal not found.');

      final foodItems = await _storage.getFoodItemsForMeal(widget.mealId);
      final withIngredients = await Future.wait(
        foodItems.map((item) async {
          final ings = item.id != null
              ? await _storage.getIngredientsForFoodItem(item.id!)
              : <Ingredient>[];
          return _ItemWithIngredients(item, ings);
        }),
      );

      if (!mounted) return;
      setState(() {
        _meal = meal;
        _items = withIngredients;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = _meal;
    return Scaffold(
      appBar: AppBar(
        title: Text(meal?.mealType ?? 'Meal Detail'),
        actions: [
          if (meal != null)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Log Check-in',
              onPressed: () => Navigator.pushNamed(context, '/checkin', arguments: meal.id),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final meal = _meal!;

    final totalCal = _items.fold(0, (s, i) => s + (i.item.calories ?? 0));
    final totalProt = _items.fold(0, (s, i) => s + (i.item.protein ?? 0));
    final totalCarbs = _items.fold(0, (s, i) => s + (i.item.carbs ?? 0));
    final totalFat = _items.fold(0, (s, i) => s + (i.item.fat ?? 0));

    return Column(
      children: [
        _MealHeader(meal: meal),
        if (totalCal > 0 || totalProt > 0 || totalCarbs > 0 || totalFat > 0)
          MacroTotalsBar(
            calories: totalCal,
            protein: totalProt,
            carbs: totalCarbs,
            fat: totalFat,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._items.map((i) => _FoodItemCard(item: i.item, ingredients: i.ingredients)),
              if (meal.overallSymptoms != null && meal.overallSymptoms!.isNotEmpty)
                _SymptomsCard(symptoms: meal.overallSymptoms!),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemWithIngredients {
  final FoodItem item;
  final List<Ingredient> ingredients;
  const _ItemWithIngredients(this.item, this.ingredients);
}

class _MealHeader extends StatelessWidget {
  final MealEntry meal;
  const _MealHeader({required this.meal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dateStr = DateFormat('EEEE, MMMM d').format(meal.date);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateStr,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: accent),
                ),
                child: Text(
                  meal.mealType.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meal.time,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final List<Ingredient> ingredients;
  const _FoodItemCard({required this.item, required this.ingredients});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (item.portion != null)
              _Row(label: 'PORTION', value: item.portion!, labelStyle: labelStyle, theme: theme),
            if (item.prep != null)
              _Row(label: 'PREP', value: item.prep!, labelStyle: labelStyle, theme: theme),
            if (item.portion != null || item.prep != null) const SizedBox(height: 8),
            _MacroGrid(item: item, labelStyle: labelStyle, theme: theme),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              _Row(
                label: 'INGREDIENTS',
                value: ingredients.map((i) {
                  if (i.quantity != null && i.unit != null) return '${i.quantity} ${i.unit} ${i.name}';
                  if (i.quantity != null) return '${i.quantity} ${i.name}';
                  return i.name;
                }).join(', '),
                labelStyle: labelStyle,
                theme: theme,
              ),
            ],
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _Row(label: 'NOTES', value: item.notes!, labelStyle: labelStyle, theme: theme),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 88, child: Text('REACTION', style: labelStyle)),
                ReactionBadge(level: item.reaction),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _Row({required this.label, required this.value, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(label, style: labelStyle)),
          Expanded(child: Text(value, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _MacroGrid extends StatelessWidget {
  final FoodItem item;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _MacroGrid({required this.item, required this.labelStyle, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (item.calories == null && item.protein == null && item.carbs == null && item.fat == null) {
      return const SizedBox.shrink();
    }
    return Row(
      children: [
        if (item.calories != null) _Cell(label: 'CAL', value: '${item.calories}', labelStyle: labelStyle, theme: theme),
        if (item.protein != null) _Cell(label: 'PROT', value: '${item.protein}g', labelStyle: labelStyle, theme: theme),
        if (item.carbs != null) _Cell(label: 'CARBS', value: '${item.carbs}g', labelStyle: labelStyle, theme: theme),
        if (item.fat != null) _Cell(label: 'FAT', value: '${item.fat}g', labelStyle: labelStyle, theme: theme),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;
  const _Cell({required this.label, required this.value, required this.labelStyle, required this.theme});

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

class _SymptomsCard extends StatelessWidget {
  final String symptoms;
  const _SymptomsCard({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: accent.withAlpha(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'After-meal: $symptoms',
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
