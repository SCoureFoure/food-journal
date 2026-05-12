import 'dart:typed_data';

class MealEntry {
  final int? id;
  final DateTime date;
  final String time;
  final String mealType;
  final String? overallSymptoms;
  final String? rawInput;
  final DateTime createdAt;
  final Uint8List? imageData;

  const MealEntry({
    this.id,
    required this.date,
    required this.time,
    required this.mealType,
    this.overallSymptoms,
    this.rawInput,
    required this.createdAt,
    this.imageData,
  });

  MealEntry copyWith({
    int? id,
    DateTime? date,
    String? time,
    String? mealType,
    String? overallSymptoms,
    String? rawInput,
    DateTime? createdAt,
    Uint8List? imageData,
  }) {
    return MealEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      mealType: mealType ?? this.mealType,
      overallSymptoms: overallSymptoms ?? this.overallSymptoms,
      rawInput: rawInput ?? this.rawInput,
      createdAt: createdAt ?? this.createdAt,
      imageData: imageData ?? this.imageData,
    );
  }
}
