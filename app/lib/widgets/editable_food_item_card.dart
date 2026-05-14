import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_item.dart';
import '../models/ingredient.dart';

class FoodItemFormData {
  final nameCtrl = TextEditingController();
  final portionCtrl = TextEditingController();
  final prepCtrl = TextEditingController();
  final caloriesCtrl = TextEditingController();
  final proteinCtrl = TextEditingController();
  final carbsCtrl = TextEditingController();
  final fatCtrl = TextEditingController();
  final ingredientsCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  FoodItemFormData.blank();

  FoodItemFormData.fromExisting(FoodItem item, List<Ingredient> ingredients) {
    nameCtrl.text = item.name;
    portionCtrl.text = item.portion ?? '';
    prepCtrl.text = item.prep ?? '';
    caloriesCtrl.text = item.calories?.toString() ?? '';
    proteinCtrl.text = item.protein?.toString() ?? '';
    carbsCtrl.text = item.carbs?.toString() ?? '';
    fatCtrl.text = item.fat?.toString() ?? '';
    ingredientsCtrl.text = ingredients.map((i) {
      if (i.quantity != null && i.unit != null) return '${i.quantity} ${i.unit} ${i.name}';
      if (i.quantity != null) return '${i.quantity} ${i.name}';
      return i.name;
    }).join(', ');
    notesCtrl.text = item.notes ?? '';
  }

  FoodItemFormData.fromDraft(FoodItemDraft d) {
    nameCtrl.text = d.name;
    portionCtrl.text = d.portion ?? '';
    prepCtrl.text = d.prep ?? '';
    caloriesCtrl.text = d.calories?.toString() ?? '';
    proteinCtrl.text = d.protein?.toString() ?? '';
    carbsCtrl.text = d.carbs?.toString() ?? '';
    fatCtrl.text = d.fat?.toString() ?? '';
    ingredientsCtrl.text = d.ingredients.join(', ');
    notesCtrl.text = d.notes ?? '';
  }

  FoodItemDraft toDraft() {
    final ings = ingredientsCtrl.text.trim();
    return FoodItemDraft(
      name: nameCtrl.text.trim(),
      portion: portionCtrl.text.trim().isEmpty ? null : portionCtrl.text.trim(),
      prep: prepCtrl.text.trim().isEmpty ? null : prepCtrl.text.trim(),
      calories: int.tryParse(caloriesCtrl.text.trim()),
      protein: int.tryParse(proteinCtrl.text.trim()),
      carbs: int.tryParse(carbsCtrl.text.trim()),
      fat: int.tryParse(fatCtrl.text.trim()),
      ingredients: ings.isEmpty
          ? []
          : ings.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
  }

  void dispose() {
    nameCtrl.dispose();
    portionCtrl.dispose();
    prepCtrl.dispose();
    caloriesCtrl.dispose();
    proteinCtrl.dispose();
    carbsCtrl.dispose();
    fatCtrl.dispose();
    ingredientsCtrl.dispose();
    notesCtrl.dispose();
  }
}

class EditableFoodItemCard extends StatefulWidget {
  final FoodItemFormData data;
  final VoidCallback onDelete;

  const EditableFoodItemCard({super.key, required this.data, required this.onDelete});

  @override
  State<EditableFoodItemCard> createState() => _EditableFoodItemCardState();
}

class _EditableFoodItemCardState extends State<EditableFoodItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.data;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 8, 10),
            child: Row(
              children: [
                // Chevron is the only expand/collapse tap target
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, size: 18, color: theme.colorScheme.outline),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: d.nameCtrl,
                    style: theme.textTheme.titleSmall,
                    decoration: const InputDecoration(
                      hintText: 'Food name *',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  _row([
                    _field('Portion', d.portionCtrl, hint: 'e.g. 1 cup, 5 oz'),
                    _field('Prep', d.prepCtrl, hint: 'e.g. grilled'),
                  ]),
                  const SizedBox(height: 8),
                  _row([
                    _numField('Cal', d.caloriesCtrl),
                    _numField('Protein (g)', d.proteinCtrl),
                    _numField('Carbs (g)', d.carbsCtrl),
                    _numField('Fat (g)', d.fatCtrl),
                  ]),
                  const SizedBox(height: 8),
                  _field('Ingredients', d.ingredientsCtrl,
                      hint: 'comma-separated', expanded: true),
                  const SizedBox(height: 8),
                  _field('Notes', d.notesCtrl, hint: 'optional', expanded: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((w) => [Expanded(child: w), const SizedBox(width: 8)])
            .toList()
          ..removeLast(),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool expanded = false,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: expanded ? 2 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );

  Widget _numField(String label, TextEditingController ctrl) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      );
}
