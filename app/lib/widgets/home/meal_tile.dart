import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/food_item.dart';
import '../../models/ingredient.dart';
import '../../models/meal_entry.dart';
import '../../services/storage_service.dart';
import '../food_item_card.dart';
import '../symptoms_banner.dart';

class MealTile extends StatefulWidget {
  final MealEntry meal;
  final StorageService storage;
  final VoidCallback onReload;

  const MealTile({super.key, required this.meal, required this.storage, required this.onReload});

  @override
  State<MealTile> createState() => _MealTileState();
}

class _MealTileState extends State<MealTile> {
  final _tileKey = GlobalKey();
  bool _loaded = false;
  bool _loadingItems = false;
  List<({FoodItem item, List<Ingredient> ingredients})> _items = [];
  Set<String> _favoritedNames = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void didUpdateWidget(MealTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meal.id != widget.meal.id) {
      _loaded = false;
      _items = [];
      _loadItems();
    }
  }

  Future<void> _loadItems() async {
    if (_loaded || _loadingItems) return;
    setState(() => _loadingItems = true);
    try {
      final results = await Future.wait([
        widget.storage.getFoodItemsWithIngredients(widget.meal.id!),
        widget.storage.getFavoritedFoodNames(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<({FoodItem item, List<Ingredient> ingredients})>;
        _favoritedNames = results[1] as Set<String>;
        _loaded = true;
        _loadingItems = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingItems = false);
    }
  }

  Future<void> _toggleFavorite(String foodName) async {
    await widget.storage.toggleFoodFavorite(foodName);
    final updated = await widget.storage.getFavoritedFoodNames();
    if (mounted) setState(() => _favoritedNames = updated);
  }

  // Scrolls the minimum needed to keep this tile in view.
  // On expand: only scrolls if content would be off-screen.
  // On collapse: scrolls back to header if it's above the viewport.
  void _smartScroll(bool expanded) {
    final ctx = _tileKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return;
    final scrollableBox = scrollable.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null) return;

    final position = scrollable.position;
    final viewportH = position.viewportDimension;
    final tileTop = scrollableBox.globalToLocal(box.localToGlobal(Offset.zero)).dy;
    final tileH = box.size.height;
    final tileBottom = tileTop + tileH;

    const pad = 16.0;
    const headerH = 60.0;

    if (expanded) {
      if (tileTop >= pad && tileBottom <= viewportH - pad) return;
      if (tileTop < pad) {
        position.animateTo(
          position.pixels + tileTop - pad,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else if (tileBottom > viewportH - pad) {
        final overflow = tileBottom - (viewportH - pad);
        final maxScroll = (tileTop - headerH - pad).clamp(0.0, double.infinity);
        final scrollBy = overflow.clamp(0.0, maxScroll);
        if (scrollBy > 24) {
          position.animateTo(
            position.pixels + scrollBy,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
      }
    } else {
      if (tileTop < 0) {
        position.animateTo(
          position.pixels + tileTop - pad,
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meal = widget.meal;

    return Semantics(
      key: _tileKey,
      identifier: 'meal-tile-${meal.id}',
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        onExpansionChanged: (expanded) {
          Future.delayed(const Duration(milliseconds: 280), () {
            if (mounted) _smartScroll(expanded);
          });
        },
        leading: meal.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(meal.imageData!, width: 40, height: 40, fit: BoxFit.cover),
              )
            : const Icon(Icons.restaurant_outlined),
        title: Semantics(
          identifier: 'meal-tile-header-${meal.id}',
          child: Text(meal.mealType,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        subtitle: Text(meal.time, style: theme.textTheme.bodySmall),
        trailing: (_loaded && _items.isEmpty)
            ? GestureDetector(
                onTap: () async {
                  await Navigator.pushNamed(context, '/edit_meal', arguments: meal);
                  if (mounted) setState(() { _loaded = false; _items = []; });
                  unawaited(_loadItems());
                  widget.onReload();
                },
                child: const Icon(Icons.edit_outlined, size: 24),
              )
            : null,
        children: [
          if (_loadingItems)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else ...[
            if (meal.imageData != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                child: Image.memory(meal.imageData!, width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._items.map((i) => FoodItemCard(
                    item: i.item,
                    ingredients: i.ingredients,
                    favorited: _favoritedNames.contains(i.item.name.toLowerCase()),
                    onToggleFavorite: () => _toggleFavorite(i.item.name),
                    onEdit: () async {
                      await Navigator.pushNamed(context, '/edit_meal', arguments: meal);
                      if (mounted) setState(() { _loaded = false; _items = []; });
                      unawaited(_loadItems());
                      widget.onReload();
                    },
                  )),
                  if (meal.overallSymptoms != null && meal.overallSymptoms!.isNotEmpty)
                    SymptomsBanner(symptoms: meal.overallSymptoms!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
