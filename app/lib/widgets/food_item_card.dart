import 'package:flutter/material.dart';

import '../models/food_item.dart';
import '../models/ingredient.dart';
import 'reaction_badge.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final List<Ingredient> ingredients;

  const FoodItemCard({super.key, required this.item, required this.ingredients});

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
              _LabelRow(label: 'PORTION', value: item.portion!, labelStyle: labelStyle, theme: theme),
            if (item.prep != null)
              _LabelRow(label: 'PREP', value: item.prep!, labelStyle: labelStyle, theme: theme),
            if (item.portion != null || item.prep != null) const SizedBox(height: 8),
            _MacroGrid(item: item, labelStyle: labelStyle, theme: theme),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              _LabelRow(
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
              _LabelRow(label: 'NOTES', value: item.notes!, labelStyle: labelStyle, theme: theme),
            ],
            if (item.reaction != ReactionLevel.pending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(width: 88, child: Text('REACTION', style: labelStyle)),
                  ReactionBadge(level: item.reaction),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;

  const _LabelRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.theme,
  });

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

  const _Cell({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.theme,
  });

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
