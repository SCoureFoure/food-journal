enum ReactionLevel {
  pending,
  none,
  mild,
  moderate,
  bad;

  int toInt() => index;

  static ReactionLevel fromInt(int i) => ReactionLevel.values[i];

  static ReactionLevel fromLabel(String? label) => switch (label) {
        'No reaction' => ReactionLevel.none,
        'Mild'        => ReactionLevel.mild,
        'Moderate'    => ReactionLevel.moderate,
        'Bad'         => ReactionLevel.bad,
        _             => ReactionLevel.pending,
      };

  String get label => switch (this) {
        ReactionLevel.pending => 'Pending',
        ReactionLevel.none => 'No reaction',
        ReactionLevel.mild => 'Mild',
        ReactionLevel.moderate => 'Moderate',
        ReactionLevel.bad => 'Bad',
      };
}

class FoodItem {
  final int? id;
  final int mealId;
  final String name;
  final String? portion;
  final String? prep;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final ReactionLevel reaction;
  final String? notes;

  const FoodItem({
    this.id,
    required this.mealId,
    required this.name,
    this.portion,
    this.prep,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.reaction = ReactionLevel.pending,
    this.notes,
  });

  FoodItem copyWith({
    int? id,
    int? mealId,
    String? name,
    String? portion,
    String? prep,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    ReactionLevel? reaction,
    String? notes,
  }) {
    return FoodItem(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      name: name ?? this.name,
      portion: portion ?? this.portion,
      prep: prep ?? this.prep,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      reaction: reaction ?? this.reaction,
      notes: notes ?? this.notes,
    );
  }
}

class FoodItemDraft {
  final String name;
  final String? portion;
  final String? prep;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final List<String> ingredients;
  final String? notes;

  const FoodItemDraft({
    required this.name,
    this.portion,
    this.prep,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.ingredients = const [],
    this.notes,
  });

  factory FoodItemDraft.fromJson(Map<String, dynamic> json) {
    return FoodItemDraft(
      name: json['name'] as String,
      portion: json['portion'] as String?,
      prep: json['prep'] as String?,
      calories: (json['calories'] as num?)?.toInt(),
      protein: (json['protein'] as num?)?.toInt(),
      carbs: (json['carbs'] as num?)?.toInt(),
      fat: (json['fat'] as num?)?.toInt(),
      ingredients: List<String>.from(json['ingredients'] as List? ?? []),
      notes: json['notes'] as String?,
    );
  }
}
