import 'food_item.dart';

class ReactionLog {
  final int? id;
  final int? mealId; // null = standalone "Feeling..." check-in
  final DateTime checkinTime;
  final List<String> symptoms;
  final ReactionLevel severity;
  final String? notes;

  const ReactionLog({
    this.id,
    this.mealId,
    required this.checkinTime,
    required this.symptoms,
    required this.severity,
    this.notes,
  });

  ReactionLog copyWith({
    int? id,
    int? mealId,
    DateTime? checkinTime,
    List<String>? symptoms,
    ReactionLevel? severity,
    String? notes,
  }) {
    return ReactionLog(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      checkinTime: checkinTime ?? this.checkinTime,
      symptoms: symptoms ?? this.symptoms,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
    );
  }
}

const List<String> kSymptomOptions = [
  'Bloating',
  'Stomach pain',
  'Nausea',
  'Fatigue',
  'Brain fog',
  'Heartburn',
  'Diarrhea',
  'Constipation',
  'Other',
];
