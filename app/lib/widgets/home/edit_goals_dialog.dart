import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/daily_goals.dart';
import 'goal_calculator_dialog.dart';

/// Opens the editor pre-filled with [current]. Returns the new targets, or null on cancel.
Future<DailyGoals?> showEditGoalsDialog(BuildContext context, DailyGoals current,
        {double? latestWeightLb}) =>
    showDialog<DailyGoals>(
        context: context,
        builder: (_) => EditGoalsDialog(initial: current, latestWeightLb: latestWeightLb));

class EditGoalsDialog extends StatefulWidget {
  final DailyGoals initial;
  final double? latestWeightLb;

  const EditGoalsDialog({super.key, required this.initial, this.latestWeightLb});

  @override
  State<EditGoalsDialog> createState() => _EditGoalsDialogState();
}

class _EditGoalsDialogState extends State<EditGoalsDialog> {
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _water;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final g = widget.initial;
    _calories = TextEditingController(text: g.calories?.toString() ?? '');
    _protein = TextEditingController(text: g.proteinG?.toString() ?? '');
    _carbs = TextEditingController(text: g.carbsG?.toString() ?? '');
    _fat = TextEditingController(text: g.fatG?.toString() ?? '');
    _water = TextEditingController(
      text: g.waterMl == null ? '' : (g.waterMl! / kMlPerOz).round().toString(),
    );
  }

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    _water.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final g = await showGoalCalculator(context, latestWeightLb: widget.latestWeightLb);
    if (g == null || !mounted) return;
    setState(() {
      _calories.text = '${g.calories}';
      _protein.text = '${g.proteinG}';
      _carbs.text = '${g.carbsG}';
      _fat.text = '${g.fatG}';
      _errors.clear();
    });
  }

  void _save() {
    final errors = <String, String>{};

    int? parse(String metric, TextEditingController controller) {
      final text = controller.text.trim();
      if (text.isEmpty) return null;
      final value = int.parse(text);
      if (value == 0) errors[metric] = 'Enter a number above 0';
      return value;
    }

    final calories = parse('calories', _calories);
    final protein = parse('protein', _protein);
    final carbs = parse('carbs', _carbs);
    final fat = parse('fat', _fat);
    final oz = parse('water', _water);

    if (errors.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errors));
      return;
    }

    Navigator.pop(
      context,
      DailyGoals(
        calories: calories,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
        waterMl: oz == null ? null : (oz * kMlPerOz).round(),
      ),
    );
  }

  Widget _field(String metric, String label, TextEditingController controller) {
    return Semantics(
      identifier: 'field-goal-$metric',
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label, errorText: _errors[metric]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'edit-goals-dialog',
      child: AlertDialog(
        title: const Text('Daily goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  identifier: 'btn-calc-goals',
                  container: true,
                  child: TextButton.icon(
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calculate from body stats'),
                    onPressed: _calculate,
                  ),
                ),
              ),
              _field('calories', 'Calories (kcal)', _calories),
              _field('protein', 'Protein (g)', _protein),
              _field('carbs', 'Carbs (g)', _carbs),
              _field('fat', 'Fat (g)', _fat),
              _field('water', 'Water (oz)', _water),
              const SizedBox(height: 8),
              Text(
                'Leave a field empty to clear that goal.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          Semantics(
            identifier: 'btn-save-goals',
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
    );
  }
}
