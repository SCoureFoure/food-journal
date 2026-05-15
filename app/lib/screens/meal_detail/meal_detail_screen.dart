import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/export_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/error_display.dart';
import '../../widgets/food_item_card.dart';
import '../../widgets/macro_totals_bar.dart';
import '../../widgets/symptoms_banner.dart';

class MealDetailScreen extends StatefulWidget {
  final int mealId;
  const MealDetailScreen({super.key, required this.mealId});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final _storage = StorageService();
  late final ExportService _export;

  bool _isLoading = true;
  bool _isSharing = false;
  String? _errorMessage;
  MealEntry? _meal;
  List<({FoodItem item, List<Ingredient> ingredients})> _items = [];

  @override
  void initState() {
    super.initState();
    _export = ExportService(_storage);
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

      final items = await _storage.getFoodItemsWithIngredients(widget.mealId);

      if (!mounted) return;
      setState(() {
        _meal = meal;
        _items = items;
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
          if (meal != null) ...[
            Semantics(
              identifier: 'btn-share-meal',
              child: IconButton(
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                tooltip: 'Share meal',
                onPressed: _isSharing ? null : _shareMeal,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: 'Log Check-in',
              onPressed: () =>
                  Navigator.pushNamed(context, '/checkin', arguments: meal.id),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Future<void> _shareMeal() async {
    if (_meal == null) return;
    setState(() => _isSharing = true);
    try {
      await _export.exportMealJson(_meal!.id!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return ErrorRetry(message: _errorMessage!, onRetry: _load);
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
              ..._items.map((i) => FoodItemCard(item: i.item, ingredients: i.ingredients)),
              if (meal.overallSymptoms != null && meal.overallSymptoms!.isNotEmpty)
                SymptomsBanner(
                  symptoms: meal.overallSymptoms!,
                  margin: const EdgeInsets.only(top: 4),
                ),
            ],
          ),
        ),
      ],
    );
  }
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
