import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/storage_service.dart';
import '../../widgets/food_item_card.dart';
import '../../widgets/macro_totals_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService();
  Map<DateTime, List<MealEntry>> _mealsByDate = {};
  List<DateTime> _sortedDates = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final meals = await _storage.getAllMeals();
      final grouped = <DateTime, List<MealEntry>>{};
      for (final meal in meals) {
        final key = DateTime(meal.date.year, meal.date.month, meal.date.day);
        grouped.putIfAbsent(key, () => []).add(meal);
      }
      final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      if (!mounted) return;
      setState(() {
        _mealsByDate = grouped;
        _sortedDates = sortedDates;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Journal'),
        actions: [
          Semantics(
            identifier: 'btn-export',
            child: IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => Navigator.pushNamed(context, '/export'),
              tooltip: 'Export',
            ),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: Semantics(
        identifier: 'btn-log-meal',
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.pushNamed(context, '/log');
            _loadMeals();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Semantics(
          identifier: 'home-loading',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Semantics(
          identifier: 'home-error',
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadMeals, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_mealsByDate.isEmpty) {
      return Center(
        child: Semantics(
          identifier: 'home-empty-state',
          child: const Text('No meals logged yet.'),
        ),
      );
    }

    return Semantics(
      identifier: 'home-meal-list',
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sortedDates.length,
        itemBuilder: (_, i) {
          final date = _sortedDates[i];
          return _DateSection(
            date: date,
            meals: _mealsByDate[date]!,
            storage: _storage,
            isToday: _isToday(date),
          );
        },
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  final DateTime date;
  final List<MealEntry> meals;
  final StorageService storage;
  final bool isToday;

  const _DateSection({
    required this.date,
    required this.meals,
    required this.storage,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = isToday
        ? 'Today · ${DateFormat('MMM d').format(date)}'
        : DateFormat('EEEE, MMMM d').format(date);
    final count = meals.length;

    return Semantics(
      identifier: 'date-section-${date.toIso8601String().substring(0, 10)}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ExpansionTile(
          initiallyExpanded: isToday,
          title: Text(
            dateStr,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$count ${count == 1 ? 'meal' : 'meals'}',
            style: theme.textTheme.bodySmall,
          ),
          children: meals.map((m) => _MealTile(meal: m, storage: storage)).toList(),
        ),
      ),
    );
  }
}

class _MealTile extends StatefulWidget {
  final MealEntry meal;
  final StorageService storage;

  const _MealTile({required this.meal, required this.storage});

  @override
  State<_MealTile> createState() => _MealTileState();
}

class _MealTileState extends State<_MealTile> {
  bool _loaded = false;
  bool _loadingItems = false;
  List<_ItemWithIngredients> _items = [];

  Future<void> _loadItems() async {
    if (_loaded || _loadingItems) return;
    setState(() => _loadingItems = true);
    try {
      final foodItems = await widget.storage.getFoodItemsForMeal(widget.meal.id!);
      final withIngredients = await Future.wait(
        foodItems.map((item) async {
          final ings = item.id != null
              ? await widget.storage.getIngredientsForFoodItem(item.id!)
              : <Ingredient>[];
          return _ItemWithIngredients(item, ings);
        }),
      );
      if (!mounted) return;
      setState(() {
        _items = withIngredients;
        _loaded = true;
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = widget.meal;

    final int totalCal = _items.fold(0, (s, i) => s + (i.item.calories ?? 0));
    final int totalProt = _items.fold(0, (s, i) => s + (i.item.protein ?? 0));
    final int totalCarbs = _items.fold(0, (s, i) => s + (i.item.carbs ?? 0));
    final int totalFat = _items.fold(0, (s, i) => s + (i.item.fat ?? 0));
    final hasMacros = totalCal > 0 || totalProt > 0 || totalCarbs > 0 || totalFat > 0;

    return Semantics(
      identifier: 'meal-tile-${meal.id}',
      child: ExpansionTile(
        onExpansionChanged: (expanded) {
          if (expanded) _loadItems();
        },
        leading: meal.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  meal.imageData!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            : const Icon(Icons.restaurant_outlined),
        title: Semantics(
          identifier: 'meal-tile-header-${meal.id}',
          child: Text(
            meal.mealType,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Text(meal.time, style: theme.textTheme.bodySmall),
        children: [
          if (_loadingItems)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (meal.imageData != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: Image.memory(
                  meal.imageData!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
            if (hasMacros)
              MacroTotalsBar(
                calories: totalCal,
                protein: totalProt,
                carbs: totalCarbs,
                fat: totalFat,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._items.map((i) => FoodItemCard(item: i.item, ingredients: i.ingredients)),
                  if (meal.overallSymptoms != null && meal.overallSymptoms!.isNotEmpty)
                    _SymptomsRow(symptoms: meal.overallSymptoms!),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.checklist, size: 16),
                      label: const Text('Log Check-in'),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/checkin', arguments: meal.id),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemWithIngredients {
  final FoodItem item;
  final List<Ingredient> ingredients;
  const _ItemWithIngredients(this.item, this.ingredients);
}

class _SymptomsRow extends StatelessWidget {
  final String symptoms;
  const _SymptomsRow({required this.symptoms});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
