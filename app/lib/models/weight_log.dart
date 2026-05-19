class WeightLog {
  final int? id;
  final DateTime date;
  final String time;
  final double weightValue;
  final String unit; // 'lbs' or 'kg'
  final String? notes;
  final DateTime createdAt;

  const WeightLog({
    this.id,
    required this.date,
    required this.time,
    required this.weightValue,
    required this.unit,
    this.notes,
    required this.createdAt,
  });

  String get displayWeight {
    final val = weightValue == weightValue.truncateToDouble()
        ? weightValue.toInt().toString()
        : weightValue.toStringAsFixed(1);
    return '$val $unit';
  }
}
