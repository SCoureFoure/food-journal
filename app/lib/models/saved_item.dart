class SavedItem {
  final int? id;
  final String name;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final List<String> components;
  final DateTime createdAt;

  const SavedItem({
    this.id,
    required this.name,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.components,
    required this.createdAt,
  });
}
