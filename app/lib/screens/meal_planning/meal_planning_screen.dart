import 'package:flutter/material.dart';

import '../../widgets/folder_palette.dart';
import '../../widgets/grocery_list_card.dart';
import '../../widgets/panel_container.dart';

class MealPlanningScreen extends StatelessWidget {
  const MealPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'meal-planning-screen',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Horizontal inset comes from each panel's own margin, so the cards
        // land at the same width as the journal's week/day panels.
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          children: const [
            _PlannerStubCard(),
            GroceryListCard(),
          ],
        ),
      ),
    );
  }
}

class _PlannerStubCard extends StatelessWidget {
  const _PlannerStubCard();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'planner-stub-card',
      child: PanelContainer(
        accentColor: kTabMealPlanning,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "This week's meals",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Nothing planned yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Planning lands in the next update. For now, the grocery list below '
                'is built from what you have actually been eating.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
