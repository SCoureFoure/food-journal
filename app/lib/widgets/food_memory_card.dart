import 'package:flutter/material.dart';
import '../models/food_memory.dart';
import 'reaction_badge.dart';
import '../models/food_item.dart';

class FoodMemoryCard extends StatelessWidget {
  final FoodMemory memory;

  const FoodMemoryCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (memory.flagged)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.warning_amber, color: Colors.orange, size: 18),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memory.foodName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (memory.reactionPattern != null)
                    Text(
                      memory.reactionPattern!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ReactionBadge(level: ReactionLevel.mild), // TODO: derive from reactionPattern
                const SizedBox(height: 4),
                Text(
                  '${memory.occurrences}x',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
