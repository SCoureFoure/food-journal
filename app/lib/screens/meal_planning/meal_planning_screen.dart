import 'package:flutter/material.dart';

import '../../widgets/grocery_list_card.dart';

class MealPlanningScreen extends StatelessWidget {
  const MealPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'meal-planning-screen',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: const [
            _PlannerStubCard(),
            SizedBox(height: 16),
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
      child: Card(
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
