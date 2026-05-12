class FoodMemory {
  final int? id;
  final String foodName;
  final String? reactionPattern;
  final int occurrences;
  final DateTime lastSeen;
  final bool flagged;

  const FoodMemory({
    this.id,
    required this.foodName,
    this.reactionPattern,
    required this.occurrences,
    required this.lastSeen,
    required this.flagged,
  });

  FoodMemory copyWith({
    int? id,
    String? foodName,
    String? reactionPattern,
    int? occurrences,
    DateTime? lastSeen,
    bool? flagged,
  }) {
    return FoodMemory(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      reactionPattern: reactionPattern ?? this.reactionPattern,
      occurrences: occurrences ?? this.occurrences,
      lastSeen: lastSeen ?? this.lastSeen,
      flagged: flagged ?? this.flagged,
    );
  }
}
