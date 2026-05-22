class FoodMemory {
  final int? id;
  final String foodName;
  final String? reactionPattern;
  final int occurrences;
  final DateTime lastSeen;
  final bool flagged;
  // TODO_FAVORITES: toggle via StorageService.toggleFoodFavorite(foodName)
  final bool favorited;

  const FoodMemory({
    this.id,
    required this.foodName,
    this.reactionPattern,
    required this.occurrences,
    required this.lastSeen,
    required this.flagged,
    this.favorited = false,
  });

  FoodMemory copyWith({
    int? id,
    String? foodName,
    String? reactionPattern,
    int? occurrences,
    DateTime? lastSeen,
    bool? flagged,
    bool? favorited,
  }) {
    return FoodMemory(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      reactionPattern: reactionPattern ?? this.reactionPattern,
      occurrences: occurrences ?? this.occurrences,
      lastSeen: lastSeen ?? this.lastSeen,
      flagged: flagged ?? this.flagged,
      favorited: favorited ?? this.favorited,
    );
  }
}
