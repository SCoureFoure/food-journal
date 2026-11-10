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
    final foodLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Center(child: PetBlock(size: 128)),
                const SizedBox(height: 24),
                if (feed.calorieGoal != null)
                  GoalFillBar(
                    metric: 'food',
                    semanticsId: 'pet-meter-food',
                    label: 'FOOD',
                    current: feed.caloriesToday,
                    target: feed.calorieGoal!,
                    unit: 'kcal',
                    animated: animateBars,
                  )
                else ...[
                  Semantics(
                    identifier: 'pet-meter-food',
                    container: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                      child: Row(children: [
                        Text('FOOD', style: foodLabelStyle),
                        const Spacer(),
                        Text('${feed.caloriesToday} kcal today'),
                      ]),
                    ),
                  ),
                  if (onSetGoal != null)
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
                ],
                GoalFillBar(
                  metric: 'water',
                  semanticsId: 'pet-meter-water',
                  label: 'WATER',
                  current: (feed.waterMl / kMlPerOz).round(),
                  target: (feed.waterGoalMl / kMlPerOz).round(),
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
