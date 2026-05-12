class Ingredient {
  final int? id;
  final int foodItemId;
  final String name;
  final String? quantity;
  final String? unit;

  const Ingredient({
    this.id,
    required this.foodItemId,
    required this.name,
    this.quantity,
    this.unit,
  });

  Ingredient copyWith({
    int? id,
    int? foodItemId,
    String? name,
    String? quantity,
    String? unit,
  }) {
    return Ingredient(
      id: id ?? this.id,
      foodItemId: foodItemId ?? this.foodItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
