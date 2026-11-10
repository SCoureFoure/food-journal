import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/daily_goals.dart';
import '../../models/goal_estimate.dart';
import '../../services/settings_service.dart';

/// Opens the calculator. Returns the estimated targets, or null on cancel.
/// Never saves goals — the caller only pre-fills the edit dialog with the result.
Future<DailyGoals?> showGoalCalculator(BuildContext context,
        {double? latestWeightLb, SettingsService? settings}) =>
    showDialog<DailyGoals>(
        context: context,
        builder: (_) => GoalCalculatorDialog(
            latestWeightLb: latestWeightLb, settings: settings ?? SettingsService()));

class GoalCalculatorDialog extends StatefulWidget {
  final double? latestWeightLb;
  final SettingsService settings;

  const GoalCalculatorDialog({super.key, this.latestWeightLb, required this.settings});

  @override
  State<GoalCalculatorDialog> createState() => _GoalCalculatorDialogState();
}

class _GoalCalculatorDialogState extends State<GoalCalculatorDialog> {
  final _weight = TextEditingController();
  final _heightFt = TextEditingController();
  final _heightIn = TextEditingController();
  final _age = TextEditingController();
  BodyFormula? _formula;
  ActivityLevel _activity = ActivityLevel.light;
  WeightGoal _goal = WeightGoal.maintain;
  final Map<String, String> _errors = {};

  static String _formatWeight(double lb) =>
      lb == lb.truncateToDouble() ? lb.toInt().toString() : lb.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    final latest = widget.latestWeightLb;
    if (latest != null) _weight.text = _formatWeight(latest);
    widget.settings.goalProfile.then((p) {
      if (p == null || !mounted) return;
      setState(() {
        _heightFt.text = '${p.heightIn ~/ 12}';
        _heightIn.text = '${p.heightIn % 12}';
        _age.text = '${p.age}';
        _formula = p.formula;
        _activity = p.activity;
        _goal = p.goal;
        if (latest == null) _weight.text = _formatWeight(p.weightLb);
      });
    });
  }

  @override
  void dispose() {
    _weight.dispose();
    _heightFt.dispose();
    _heightIn.dispose();
    _age.dispose();
    super.dispose();
  }

  GoalProfile? _read({required bool showErrors}) {
    final errors = <String, String>{};

    final weight = double.tryParse(_weight.text.trim());
    if (weight == null || weight < 50 || weight > 700) errors['weight'] = 'Enter 50–700 lb';

    final inchesText = _heightIn.text.trim();
    final inches = inchesText.isEmpty ? 0 : int.tryParse(inchesText);
    if (inches == null || inches < 0 || inches > 11) errors['height-in'] = 'Enter 0–11';

    final ft = int.tryParse(_heightFt.text.trim());
    final totalIn = ft == null ? null : ft * 12 + (inches ?? 0);
    if (totalIn == null || totalIn < 48 || totalIn > 96) errors['height-ft'] = 'Enter 4–8 ft';

    final age = int.tryParse(_age.text.trim());
    if (age == null || age < 18 || age > 100) errors['age'] = 'Enter an age from 18 to 100';

    if (_formula == null) errors['formula'] = 'Pick a formula';

    if (errors.isNotEmpty) {
      if (showErrors) {
        setState(() => _errors
          ..clear()
          ..addAll(errors));
      }
      return null;
    }
    return GoalProfile(
      weightLb: weight!,
      heightIn: totalIn!,
      age: age!,
      formula: _formula!,
      activity: _activity,
      goal: _goal,
    );
  }

  Future<void> _apply() async {
    final p = _read(showErrors: true);
    if (p == null) return;
    await widget.settings.setGoalProfile(p);
    if (mounted) Navigator.pop(context, estimateGoals(p));
  }

  Widget _numberField(String input, String label, TextEditingController controller,
      {bool decimal = false}) {
    return Semantics(
      identifier: 'field-calc-$input',
      container: true,
      child: TextField(
        controller: controller,
        keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: [
          decimal
              ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d?'))
              : FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, errorText: _errors[input]),
      ),
    );
  }

  Widget _dropdown<T>(String input, String label, T? value, List<T> values,
      String Function(T) labelOf, ValueChanged<T?> onChanged) {
    return Semantics(
      identifier: 'field-calc-$input',
      container: true,
      child: DropdownButtonFormField<T>(
        key: ValueKey(value),
        initialValue: value,
        isExpanded: true,
        items: [
          for (final v in values) DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
        decoration: InputDecoration(labelText: label, errorText: _errors[input]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _read(showErrors: false);
    String result = 'Fill in all fields to see an estimate.';
    if (p != null) {
      final g = estimateGoals(p);
      result =
          '${g.calories} kcal · protein ${g.proteinG} g · carbs ${g.carbsG} g · fat ${g.fatG} g';
    }

    return Semantics(
      identifier: 'goal-calculator-dialog',
      container: true,
      child: AlertDialog(
        title: const Text('Estimate goals'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField('weight', 'Weight (lb)', _weight, decimal: true),
              Row(
                children: [
                  Expanded(child: _numberField('height-ft', 'Height (ft)', _heightFt)),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField('height-in', '(in)', _heightIn)),
                ],
              ),
              _numberField('age', 'Age', _age),
              _dropdown<BodyFormula>('formula', 'Formula', _formula, BodyFormula.values,
                  (v) => v.label, (v) => _formula = v),
              _dropdown<ActivityLevel>('activity', 'Activity', _activity, ActivityLevel.values,
                  (v) => v.label, (v) => _activity = v ?? _activity),
              _dropdown<WeightGoal>('goal', 'Goal', _goal, WeightGoal.values, (v) => v.label,
                  (v) => _goal = v ?? _goal),
              const SizedBox(height: 12),
              Semantics(
                identifier: 'calc-result',
                container: true,
                child: Text(result),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimate only, not medical advice.',
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
            identifier: 'btn-calc-apply',
            container: true,
            child: FilledButton(onPressed: _apply, child: const Text('Use these')),
          ),
        ],
      ),
    );
  }
}
