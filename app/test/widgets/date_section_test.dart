import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_journal/models/food_item.dart';
import 'package:food_journal/models/ingredient.dart';
import 'package:food_journal/models/meal_entry.dart';
import 'package:food_journal/services/storage_service.dart';
import 'package:food_journal/widgets/home/date_section.dart';

class _FakeStorage extends StorageService {
  final fetched = <List<int>>[];

  @override
  Future<({int cal, double prot, double carbs, double fat})> getMacroTotalsForMeals(
      List<int> mealIds) async {
    fetched.add(mealIds);
    return (cal: 100 * mealIds.length, prot: 0.0, carbs: 0.0, fat: 0.0);
  }

  @override
  Future<List<({FoodItem item, List<Ingredient> ingredients})>> getFoodItemsWithIngredients(
          int mealId) async =>
      [];

  @override
  Future<Set<String>> getFavoritedFoodNames() async => {};
}

final _day = DateTime(2026, 5, 11);

MealEntry _meal(int id) => MealEntry(
      id: id,
      date: _day,
      time: '12:00 PM',
      mealType: 'lunch',
      createdAt: DateTime(2026, 5, 11, 12),
    );

Widget _wrap(StorageService storage, List<MealEntry> meals) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DateSection(
            date: _day,
            meals: meals,
            medications: const [],
            feelings: const [],
            waterLogs: const [],
            weightLogs: const [],
            storage: storage,
            isToday: false,
            onReload: () {},
          ),
        ),
      ),
    );

void main() {
  /// [DIR] Day totals follow the meals — the journal keeps week sections (and
  /// the day sections inside them) alive while scrolling, so a day section
  /// outlives the meal list it first loaded totals for. When the journal
  /// reloads with a meal added to an opened day, the day totals must be
  /// fetched again for the new meal ids instead of keeping the old total.
  group('[DIR] DateSection — day totals refresh when meals change', () {
    testWidgets('adding a meal to an opened day refetches the totals', (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(_wrap(storage, [_meal(1)]));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(storage.fetched, [
        [1]
      ]);
      expect(find.text('100'), findsOneWidget);

      await tester.pumpWidget(_wrap(storage, [_meal(1), _meal(2)]));
      await tester.pumpAndSettle();
      expect(storage.fetched.last, [1, 2]);
      expect(find.text('200'), findsOneWidget);
    });

    testWidgets('a rebuild with the same meals does not refetch', (tester) async {
      final storage = _FakeStorage();
      await tester.pumpWidget(_wrap(storage, [_meal(1)]));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_wrap(storage, [_meal(1)]));
      await tester.pumpAndSettle();
      expect(storage.fetched.length, 1);
    });
  });
}
