import 'package:flutter/material.dart';
import '../../models/daily_goals.dart';
import '../../models/pet_feed.dart';
import '../goal_fill_bar.dart';
import 'pet_block.dart';

Future<void> showPetSheet(BuildContext context, PetFeed feed,
        {bool animateBars = true, VoidCallback? onSetGoal}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PetSheet(feed: feed, animateBars: animateBars, onSetGoal: onSetGoal),
    );

class PetSheet extends StatelessWidget {
  final PetFeed feed;
  final bool animateBars;
  final VoidCallback? onSetGoal;
  const PetSheet({super.key, required this.feed, this.animateBars = true, this.onSetGoal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = feed.calorieGoal;
    return Semantics(
      identifier: 'pet-sheet',
      container: true,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your pet',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Center(child: PetBlock(size: 128)),
                const SizedBox(height: 24),
                GoalFillBar(
                  metric: 'food',
                  semanticsId: 'pet-meter-food',
                  label: 'FOOD',
                  current: feed.caloriesToday,
                  target: goal,
                  unit: 'kcal',
                  animated: animateBars,
                ),
                if (goal == null && onSetGoal != null)
                  Semantics(
                    identifier: 'btn-pet-set-goal',
                    container: true,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onSetGoal!();
                      },
                      child: const Text('Set a calorie goal'),
                    ),
                  ),
                GoalFillBar(
                  metric: 'water',
                  semanticsId: 'pet-meter-water',
                  label: 'WATER',
                  current: mlToOz(feed.waterMl),
                  target: mlToOz(feed.waterGoalMl),
                  unit: 'oz',
                  fillColor: GoalFillBar.blueFill,
                  trackColor: GoalFillBar.blueTrack,
                  animated: animateBars,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
