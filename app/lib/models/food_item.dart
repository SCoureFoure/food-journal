/// Formats a (possibly fractional) serving count for compact display.
/// Whole numbers drop the decimal (2.0 → "2"); common fractions render as
/// glyphs (0.5 → "½", 1.5 → "1½", 0.25 → "¼", 0.75 → "¾"); anything else
/// falls back to a trimmed decimal (1.2 → "1.2").
String formatServings(double s) {
  if (s == s.roundToDouble()) return s.toInt().toString();
  final whole = s.floor();
  final frac = s - whole;
  String? glyph;
  if ((frac - 0.5).abs() < 0.01) {
    glyph = '½';
  } else if ((frac - 0.25).abs() < 0.01) {
    glyph = '¼';
  } else if ((frac - 0.75).abs() < 0.01) {
    glyph = '¾';
  }
  if (glyph != null) return whole == 0 ? glyph : '$whole$glyph';
  return s.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

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
  final double servings;

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
    this.servings = 1,
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
    double? servings,
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
      servings: servings ?? this.servings,
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
  /// Only populated when loaded from history search; always false for AI-parsed drafts.
  final bool favorited;
  /// True when this draft came from a saved composite item rather than meal history.
  final bool isComposite;
  /// Non-null when [isComposite] is true — the id in the saved_items table.
  final int? savedItemId;
  final double servings;

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
    this.favorited = false,
    this.isComposite = false,
    this.savedItemId,
    this.servings = 1,
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
      servings: (json['servings'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
