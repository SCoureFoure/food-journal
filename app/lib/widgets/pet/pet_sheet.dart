import 'package:flutter/material.dart';
import 'package:food_journal/models/daily_goals.dart';
import 'package:food_journal/models/pet_feed.dart';
import 'package:food_journal/widgets/goal_fill_bar.dart';
import 'package:food_journal/widgets/pet/pet_block.dart';

Future<void> showPetSheet(BuildContext context, PetFeed feed, {bool animateBars = true}) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PetSheet(feed: feed, animateBars: animateBars),
    );

class PetSheet extends StatelessWidget {
  final PetFeed feed;
  final bool animateBars;
  const PetSheet({super.key, required this.feed, this.animateBars = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pet-sheet',
      container: true,
      child: SafeArea(
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
              GoalFillBar(
                metric: 'food',
                semanticsId: 'pet-meter-food',
                label: 'FOOD',
                current: feed.mealsToday,
                target: kPetMealsPerDay,
                unit: 'meals',
                animated: animateBars,
              ),
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
    );
  }
}
