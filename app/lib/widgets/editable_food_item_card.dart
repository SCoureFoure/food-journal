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
  int servings = 1;

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
    servings = item.servings;
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
    servings = d.servings;
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
      servings: servings,
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
          // Whole header row is the expand/collapse target.
          // TextField absorbs its own taps (editing) so they don't bubble up.
          // X button is wrapped opaque so it absorbs delete taps without triggering toggle.
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() => _expanded = !_expanded);
            },
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, size: 18, color: theme.colorScheme.outline),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: d.nameCtrl,
                      style: theme.textTheme.titleSmall,
                      decoration: InputDecoration(
                        hintText: 'Food name *',
                        border: InputBorder.none,
                        enabledBorder: _expanded
                            ? UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: theme.colorScheme.outline.withAlpha(80),
                                  width: 1,
                                ),
                              )
                            : InputBorder.none,
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.only(bottom: 3),
                      ),
                    ),
                  ),
                  // Servings stepper — opaque so taps don't toggle expand.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {}, // absorb; children handle their own taps
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _stepperBtn(
                          icon: Icons.remove,
                          onTap: d.servings > 1
                              ? () => setState(() => d.servings--)
                              : null,
                          theme: theme,
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${d.servings}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _stepperBtn(
                          icon: Icons.add,
                          onTap: () => setState(() => d.servings++),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  // Opaque GestureDetector consumes the tap so it never reaches the parent toggle.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.close, size: 18, color: theme.colorScheme.outline),
                    ),
                  ),
                ],
              ),
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

  Widget _stepperBtn({
    required IconData icon,
    required VoidCallback? onTap,
    required ThemeData theme,
  }) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 48,
          child: Icon(
            icon,
            size: 14,
            color: onTap != null ? theme.colorScheme.primary : theme.colorScheme.outline.withAlpha(80),
          ),
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
