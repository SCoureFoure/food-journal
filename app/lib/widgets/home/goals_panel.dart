import 'package:flutter/material.dart';

import '../../models/daily_goals.dart';
import '../../services/settings_service.dart';
import '../card_expansion_tile.dart';
import '../goal_fill_bar.dart';
import '../panel_container.dart';

/// Today's intake against today's targets. Fixed above the journal list.
/// Saving targets is the host's job: [onEdit] opens the dialog, saves, reloads.
class GoalsPanel extends StatefulWidget {
  final DailyGoals goals;
  final GoalIntake intake;
  final VoidCallback onEdit;
  final bool animateBars;

  const GoalsPanel({
    super.key,
    required this.goals,
    required this.intake,
    required this.onEdit,
    this.animateBars = true,
  });

  @override
  State<GoalsPanel> createState() => _GoalsPanelState();
}

class _GoalsPanelState extends State<GoalsPanel> {
  late final SettingsService _settings;
  bool _savedCollapsed = false;

  @override
  void initState() {
    super.initState();
    _settings = SettingsService();
    _loadCollapsed();
  }

  Future<void> _loadCollapsed() async {
    try {
      final collapsed = await _settings.isCardCollapsed('goals');
      if (mounted) setState(() => _savedCollapsed = collapsed);
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — stay expanded.
    }
  }

  void _onExpansionChanged(bool expanded) {
    _settings.setCardCollapsed('goals', !expanded).catchError((_) {});
  }

  String get _subtitle {
    final goals = widget.goals;
    if (goals.calories != null) {
      return '${widget.intake.calories} / ${goals.calories} kcal today';
    }
    if (goals.isEmpty) return 'No goals set';
    return 'Today';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'goals-panel',
      container: true,
      child: PanelContainer(
        accentColor: Colors.green.shade600,
        child: CardExpansionTile(
          title: 'Goals',
          semanticsId: 'item-header-goals',
          initiallyExpanded: !_savedCollapsed,
          onExpansionChanged: _onExpansionChanged,
          subtitle: Text(_subtitle, style: Theme.of(context).textTheme.bodySmall),
          children: _buildChildren(),
        ),
      ),
    );
  }

  List<Widget> _buildChildren() {
    final goals = widget.goals;
    final intake = widget.intake;

    if (goals.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Semantics(
            identifier: 'btn-set-goals',
            child: FilledButton.tonalIcon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Set goals'),
            ),
          ),
        ),
      ];
    }

    final rows = <Widget>[
      if (goals.calories != null)
        GoalFillBar(
          metric: 'calories',
          label: 'CAL',
          current: intake.calories,
          target: goals.calories!,
          unit: 'kcal',
          animated: widget.animateBars,
        ),
      if (goals.proteinG != null)
        GoalFillBar(
          metric: 'protein',
          label: 'PROT',
          current: intake.proteinG,
          target: goals.proteinG!,
          unit: 'g',
          animated: widget.animateBars,
        ),
      if (goals.carbsG != null)
        GoalFillBar(
          metric: 'carbs',
          label: 'CARBS',
          current: intake.carbsG,
          target: goals.carbsG!,
          unit: 'g',
          animated: widget.animateBars,
        ),
      if (goals.fatG != null)
        GoalFillBar(
          metric: 'fat',
          label: 'FAT',
          current: intake.fatG,
          target: goals.fatG!,
          unit: 'g',
          animated: widget.animateBars,
        ),
      if (goals.waterMl != null)
        GoalFillBar(
          metric: 'water',
          label: 'WATER',
          current: (intake.waterMl / kMlPerOz).round(),
          target: (goals.waterMl! / kMlPerOz).round(),
          unit: 'oz',
          fillColor: GoalFillBar.blueFill,
          trackColor: GoalFillBar.blueTrack,
          animated: widget.animateBars,
        ),
    ];

    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            identifier: 'btn-edit-goals',
            child: TextButton.icon(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(children: rows),
      ),
    ];
  }
}
