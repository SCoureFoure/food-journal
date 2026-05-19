class WaterLog {
  final int? id;
  final DateTime date;
  final String time;
  final int amountMl;
  final String? notes;
  final DateTime createdAt;

  const WaterLog({
    this.id,
    required this.date,
    required this.time,
    required this.amountMl,
    this.notes,
    required this.createdAt,
  });

  double get amountOz => amountMl / 29.5735;

  String get displayOz {
    final oz = amountOz.round();
    return '$oz oz';
  }
}
