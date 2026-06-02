import 'package:flutter/material.dart';

import 'food_item.dart';

/// Overall self-reported mood for a check-in. Independent of symptom
/// [ReactionLevel] severity — captures how the user feels overall.
/// Null on a log means mood was not recorded.
enum Mood {
  great,
  good,
  okay,
  low,
  awful;

  int toInt() => index;

  static Mood fromInt(int i) => Mood.values[i];

  String get label => switch (this) {
        Mood.great => 'Great',
        Mood.good => 'Good',
        Mood.okay => 'Okay',
        Mood.low => 'Low',
        Mood.awful => 'Awful',
      };

  /// Sentiment face shown on the journal feed.
  IconData get face => switch (this) {
        Mood.great => Icons.sentiment_very_satisfied,
        Mood.good => Icons.sentiment_satisfied_alt,
        Mood.okay => Icons.sentiment_neutral,
        Mood.low => Icons.sentiment_dissatisfied,
        Mood.awful => Icons.sentiment_very_dissatisfied,
      };

  /// True for moods that should read as "negative" (drives frown coloring).
  bool get isNegative => this == Mood.low || this == Mood.awful;
}

class ReactionLog {
  final int? id;
  final int? mealId; // null = standalone "Feeling..." check-in
  final DateTime checkinTime;
  final List<String> symptoms; // names, insertion-ordered (mirror of symptomLevels.keys)
  final Map<String, ReactionLevel> symptomLevels; // name -> per-symptom intensity
  final ReactionLevel severity; // derived = max of symptomLevels (none if empty)
  final Mood? mood;
  final String? notes;

  const ReactionLog({
    this.id,
    this.mealId,
    required this.checkinTime,
    required this.symptoms,
    this.symptomLevels = const {},
    required this.severity,
    this.mood,
    this.notes,
  });

  /// Overall severity = the worst per-symptom intensity, or [ReactionLevel.none]
  /// when no symptoms are present. Higher enum index = worse.
  static ReactionLevel deriveSeverity(Map<String, ReactionLevel> levels) {
    if (levels.isEmpty) return ReactionLevel.none;
    return levels.values.reduce((a, b) => a.index >= b.index ? a : b);
  }

  ReactionLog copyWith({
    int? id,
    int? mealId,
    DateTime? checkinTime,
    List<String>? symptoms,
    Map<String, ReactionLevel>? symptomLevels,
    ReactionLevel? severity,
    Mood? mood,
    String? notes,
  }) {
    return ReactionLog(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      checkinTime: checkinTime ?? this.checkinTime,
      symptoms: symptoms ?? this.symptoms,
      symptomLevels: symptomLevels ?? this.symptomLevels,
      severity: severity ?? this.severity,
      mood: mood ?? this.mood,
      notes: notes ?? this.notes,
    );
  }
}

const List<String> kSymptomOptions = [
  // Original GI set
  'Bloating',
  'Stomach pain',
  'Nausea',
  'Fatigue',
  'Brain fog',
  'Heartburn',
  'Diarrhea',
  'Constipation',
  // GI set
  'Gas',
  'Cramping',
  'Acid reflux',
  'Urgency',
  // Systemic set
  'Headache',
  'Joint pain',
  'Skin flare',
  'Dizziness',
  // Energy / mood-adjacent set
  'Anxiety',
  'Irritability',
  'Low energy',
  'Poor sleep',
  'Other',
];
