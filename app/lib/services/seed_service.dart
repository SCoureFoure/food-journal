import '../models/food_item.dart';
import '../models/ingredient.dart';
import '../models/meal_entry.dart';
import 'storage_service.dart';

class SeedService {
  Future<void> seed(StorageService storage) async {
    await storage.clearAll();
    for (final m in _kMeals) {
      final entry = MealEntry(
        date: m.date,
        time: m.time,
        mealType: m.mealType,
        overallSymptoms: m.overallSymptoms,
        rawInput: null,
        createdAt: m.date,
      );
      final items = m.items
          .map((i) => FoodItem(
                mealId: 0,
                name: i.name,
                portion: i.portion,
                prep: i.prep,
                calories: i.calories,
                protein: i.protein,
                carbs: i.carbs,
                fat: i.fat,
                reaction: i.reaction,
                notes: i.notes,
              ))
          .toList();
      final ingredientsByItem = m.items
          .map((i) => i.ingredients.map((n) => Ingredient(foodItemId: 0, name: n)).toList())
          .toList();
      await storage.saveMeal(entry, items, ingredientsByItem);
    }
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _M {
  final DateTime date;
  final String time;
  final String mealType;
  final String? overallSymptoms;
  final List<_I> items;
  _M(this.date, this.time, this.mealType, this.items, {this.overallSymptoms});
}

class _I {
  final String name;
  final String? portion;
  final String? prep;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final ReactionLevel reaction;
  final String? notes;
  final List<String> ingredients;
  _I(
    this.name, {
    this.portion,
    this.prep,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.reaction = ReactionLevel.none,
    this.notes,
    this.ingredients = const [],
  });
}

// ─── Seed data — 5 days ───────────────────────────────────────────────────────

final _kMeals = [
  // ── May 8 ──────────────────────────────────────────────────────────────────
  _M(
    DateTime(2026, 5, 8),
    '7:45 AM',
    'Breakfast',
    [
      _I(
        'Steel-cut oatmeal',
        portion: '1 cup cooked',
        prep: 'Topped with banana slices, almond butter, honey',
        calories: 380,
        protein: 12,
        carbs: 58,
        fat: 11,
        reaction: ReactionLevel.none,
        ingredients: ['steel-cut oats', 'banana', 'almond butter', 'honey', 'water'],
      ),
      _I(
        'Black coffee',
        portion: '12 oz',
        prep: 'Black, no sugar',
        calories: 5,
        protein: 0,
        carbs: 1,
        fat: 0,
        reaction: ReactionLevel.none,
      ),
    ],
  ),
  _M(
    DateTime(2026, 5, 8),
    '6:30 PM',
    'Dinner',
    [
      _I(
        'Penne pasta',
        portion: '~2 cups cooked',
        prep: 'Marinara sauce, Italian sausage, parmesan',
        calories: 620,
        protein: 28,
        carbs: 72,
        fat: 22,
        reaction: ReactionLevel.mild,
        notes: 'Noticed bloating about 1hr after. Sausage or gluten?',
        ingredients: ['penne', 'marinara sauce', 'Italian sausage', 'parmesan', 'olive oil', 'garlic'],
      ),
      _I(
        'Caesar salad',
        portion: '~2 cups',
        prep: 'Romaine, croutons, Caesar dressing, parmesan',
        calories: 180,
        protein: 5,
        carbs: 12,
        fat: 13,
        reaction: ReactionLevel.none,
        ingredients: ['romaine lettuce', 'croutons', 'Caesar dressing', 'parmesan'],
      ),
    ],
    overallSymptoms: 'Mild bloating ~1hr after dinner, resolved by 9pm. Possible culprit: sausage or pasta volume.',
  ),

  // ── May 9 ──────────────────────────────────────────────────────────────────
  _M(
    DateTime(2026, 5, 9),
    '8:15 AM',
    'Breakfast',
    [
      _I(
        'Greek yogurt bowl',
        portion: '1 cup full-fat yogurt',
        prep: 'Topped with granola, mixed berries, drizzle of honey',
        calories: 340,
        protein: 18,
        carbs: 44,
        fat: 9,
        reaction: ReactionLevel.none,
        ingredients: ['full-fat Greek yogurt', 'granola', 'blueberries', 'strawberries', 'honey'],
      ),
    ],
  ),
  _M(
    DateTime(2026, 5, 9),
    '12:30 PM',
    'Lunch',
    [
      _I(
        'Turkey sandwich',
        portion: '1 sandwich',
        prep: 'Sourdough, sliced turkey, avocado, lettuce, tomato, mustard',
        calories: 480,
        protein: 32,
        carbs: 42,
        fat: 18,
        reaction: ReactionLevel.none,
        ingredients: ['sourdough bread', 'sliced turkey', 'avocado', 'romaine', 'tomato', 'Dijon mustard'],
      ),
      _I(
        'Honeycrisp apple',
        portion: '1 medium',
        prep: 'Whole',
        calories: 95,
        protein: 0,
        carbs: 25,
        fat: 0,
        reaction: ReactionLevel.none,
      ),
    ],
  ),
  _M(
    DateTime(2026, 5, 9),
    '7:00 PM',
    'Dinner',
    [
      _I(
        'Green Thai curry',
        portion: '~1.5 cups curry over rice',
        prep: 'Restaurant takeout — chicken, coconut milk, bell pepper, zucchini, Thai basil, jasmine rice',
        calories: 680,
        protein: 34,
        carbs: 62,
        fat: 28,
        reaction: ReactionLevel.moderate,
        notes: 'Significant bloating and cramping ~45min after. This is the second time coconut milk has done this.',
        ingredients: ['chicken', 'coconut milk', 'green curry paste', 'bell pepper', 'zucchini', 'Thai basil', 'jasmine rice', 'fish sauce'],
      ),
      _I(
        'Fried spring rolls',
        portion: '3 pieces',
        prep: 'Fried, pork and cabbage filling, sweet chili dipping sauce',
        calories: 210,
        protein: 8,
        carbs: 22,
        fat: 11,
        reaction: ReactionLevel.moderate,
        ingredients: ['spring roll wrappers', 'ground pork', 'cabbage', 'glass noodles', 'sweet chili sauce'],
      ),
    ],
    overallSymptoms: 'Significant bloating and cramping 45min post-meal, lasted ~3hrs. Likely coconut milk — high fat + possible sensitivity. Flag for follow-up.',
  ),

  // ── May 10 ─────────────────────────────────────────────────────────────────
  _M(
    DateTime(2026, 5, 10),
    '9:00 AM',
    'Breakfast',
    [
      _I(
        'Scrambled eggs',
        portion: '3 large eggs',
        prep: 'Cooked in butter, topped with fresh chives',
        calories: 230,
        protein: 18,
        carbs: 2,
        fat: 17,
        reaction: ReactionLevel.none,
        ingredients: ['eggs', 'butter', 'chives', 'salt', 'black pepper'],
      ),
      _I(
        'Avocado toast',
        portion: '1 slice sourdough + ½ avocado',
        prep: 'Toasted sourdough, smashed avocado, everything bagel seasoning, lemon',
        calories: 290,
        protein: 7,
        carbs: 28,
        fat: 18,
        reaction: ReactionLevel.none,
        ingredients: ['sourdough bread', 'avocado', 'everything bagel seasoning', 'lemon juice'],
      ),
      _I(
        'Orange juice',
        portion: '8 oz',
        prep: 'Fresh squeezed',
        calories: 110,
        protein: 2,
        carbs: 26,
        fat: 0,
        reaction: ReactionLevel.none,
      ),
    ],
  ),

  // ── May 11 ─────────────────────────────────────────────────────────────────
  _M(
    DateTime(2026, 5, 11),
    '7:30 PM',
    'Dinner',
    [
      _I(
        'Sweet potato',
        portion: '1 medium (~5–6 oz)',
        prep: 'Baked, topped with honey',
        calories: 160,
        protein: 2,
        carbs: 38,
        fat: 0,
        reaction: ReactionLevel.none,
        ingredients: ['sweet potato', 'honey'],
      ),
      _I(
        'Mixed greens salad',
        portion: '~3–4 cups',
        prep: 'Feta cheese, balsamic dressing',
        calories: 120,
        protein: 5,
        carbs: 8,
        fat: 7,
        reaction: ReactionLevel.none,
        ingredients: ['mixed greens', 'feta cheese', 'balsamic dressing', 'cucumber', 'cherry tomatoes'],
      ),
      _I(
        'Button/cremini mushrooms',
        portion: '~5–6 oz',
        prep: 'Sliced, cooked with olive oil, salt, pepper, mustard seed',
        calories: 100,
        protein: 4,
        carbs: 5,
        fat: 7,
        reaction: ReactionLevel.none,
        ingredients: ['cremini mushrooms', 'olive oil', 'mustard seed', 'salt', 'black pepper'],
      ),
      _I(
        'Sourdough bread',
        portion: '~2 oz (small chunk)',
        prep: 'Plain',
        calories: 140,
        protein: 5,
        carbs: 27,
        fat: 1,
        reaction: ReactionLevel.none,
      ),
    ],
  ),
  _M(
    DateTime(2026, 5, 11),
    '~12:00 AM',
    'Late Dinner',
    [
      _I(
        'Maruchan Instant Lunch ramen',
        portion: '1 cup (2.3 oz dry)',
        prep: 'Instant, prepared with hot water. Broth mostly discarded.',
        calories: 290,
        protein: 6,
        carbs: 39,
        fat: 12,
        reaction: ReactionLevel.mild,
        notes: 'Broth discarded — sodium significantly lower than label (~1,100mg). Slight lower abdomen bloating at 1am — likely normal digestion from earlier meals, not a clear ramen reaction.',
        ingredients: ['ramen noodles', 'seasoning packet (chicken)', 'hot water'],
      ),
    ],
    overallSymptoms: 'Slight lower abdomen bloating at 1am — likely normal, not a clear ramen reaction.',
  ),

  // ── May 12 (today) ─────────────────────────────────────────────────────────
  _M(
    DateTime(2026, 5, 12),
    '12:00 PM',
    'Lunch',
    [
      _I(
        'Button/cremini mushrooms',
        portion: '~5–6 oz',
        prep: 'Cooked with soy sauce, ginger, honey',
        calories: 110,
        protein: 4,
        carbs: 8,
        fat: 6,
        reaction: ReactionLevel.pending,
        ingredients: ['cremini mushrooms', 'soy sauce', 'ginger', 'honey', 'olive oil'],
      ),
      _I(
        'Sweet potato',
        portion: '1 medium (~5–6 oz)',
        prep: 'Baked, split open',
        calories: 130,
        protein: 2,
        carbs: 30,
        fat: 0,
        reaction: ReactionLevel.pending,
        ingredients: ['sweet potato'],
      ),
      _I(
        'Brown rice',
        portion: '~1 cup cooked',
        prep: 'Plain with cumin/caraway seeds',
        calories: 215,
        protein: 5,
        carbs: 45,
        fat: 2,
        reaction: ReactionLevel.pending,
        ingredients: ['brown rice', 'cumin seeds', 'caraway seeds'],
      ),
    ],
  ),
];
