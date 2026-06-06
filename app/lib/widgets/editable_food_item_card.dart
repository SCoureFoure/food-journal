import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/food_entity.dart';
import '../models/food_item.dart';
import '../models/ingredient.dart';
import '../services/storage_service.dart';
import 'reuse_suggestion.dart';

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

  /// When non-null, the card surfaces a reuse nudge: as the name is typed it
  /// searches food history and, on a close lexical match, shows an inline chip
  /// that adopts the matched item (name + macros) on tap. Null → no nudge.
  /// Production passes the screen's StorageService; tests inject a fake.
  final StorageService? reuseStorage;

  /// Semantics id for the reuse chip (per-item, e.g. `food-reuse-suggestion-0`).
  final String reuseSemanticsId;

  /// When false (e.g. save in progress) the chip is hidden and lookup is skipped.
  final bool enabled;

  const EditableFoodItemCard({
    super.key,
    required this.data,
    required this.onDelete,
    this.reuseStorage,
    this.reuseSemanticsId = 'food-reuse-suggestion',
    this.enabled = true,
  });

  @override
  State<EditableFoodItemCard> createState() => _EditableFoodItemCardState();
}

class _EditableFoodItemCardState extends State<EditableFoodItemCard> {
  bool _expanded = false;

  Timer? _reuseDebounce;
  NameMatch? _reuseMatch;
  List<FoodItemDraft> _reuseResults = const [];
  String _lastQueried = '';

  @override
  void initState() {
    super.initState();
    if (widget.reuseStorage != null) {
      widget.data.nameCtrl.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() {
    _reuseDebounce?.cancel();
    _reuseDebounce = Timer(const Duration(milliseconds: 400), _lookupReuse);
  }

  Future<void> _lookupReuse() async {
    final storage = widget.reuseStorage;
    if (storage == null || !widget.enabled) return;
    final typed = widget.data.nameCtrl.text.trim();
    final canon = canonicalize(typed);
    // Guard on canonical so "Burger" → "burger" doesn't re-query the same results.
    if (canon == _lastQueried) return;
    _lastQueried = canon;
    if (canon.isEmpty) {
      if (mounted) setState(() => _reuseMatch = null);
      return;
    }
    // Fetch the full recent history (not filtered by typed substring) so the
    // fuzzy matcher can reach items that don't contain the typed string as a
    // literal substring — e.g. "hamburger" typed, "burger" in history.
    final results = await storage.searchFoodHistory('');
    if (!mounted) return;
    final match = bestNameMatch(typed, results.map((d) => d.name));
    setState(() {
      _reuseResults = results;
      _reuseMatch = match;
    });
  }

  void _adoptReuse() {
    final m = _reuseMatch;
    if (m == null) return;
    final draft = _reuseResults.firstWhere(
      (d) => d.name == m.candidate,
      orElse: () => FoodItemDraft(name: m.candidate),
    );
    final d = widget.data;
    setState(() {
      d.nameCtrl.text = draft.name;
      if (draft.portion != null) d.portionCtrl.text = draft.portion!;
      if (draft.prep != null) d.prepCtrl.text = draft.prep!;
      if (draft.calories != null) d.caloriesCtrl.text = draft.calories!.toString();
      if (draft.protein != null) d.proteinCtrl.text = draft.protein!.toString();
      if (draft.carbs != null) d.carbsCtrl.text = draft.carbs!.toString();
      if (draft.fat != null) d.fatCtrl.text = draft.fat!.toString();
      if (draft.ingredients.isNotEmpty) {
        d.ingredientsCtrl.text = draft.ingredients.join(', ');
      }
      d.servings = draft.servings;
      _reuseMatch = null;
    });
  }

  @override
  void dispose() {
    _reuseDebounce?.cancel();
    if (widget.reuseStorage != null) {
      widget.data.nameCtrl.removeListener(_onNameChanged);
    }
    super.dispose();
  }

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
          if (_reuseMatch != null && widget.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: ReuseSuggestionChip(
                semanticsId: widget.reuseSemanticsId,
                match: _reuseMatch!,
                onAdopt: _adoptReuse,
                onDismiss: () => setState(() => _reuseMatch = null),
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
