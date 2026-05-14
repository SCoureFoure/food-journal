import 'dart:typed_data';

const kMedUnits = ['mg', 'g', 'mL', 'mcg', 'tablets', 'capsules', 'other'];
const kMedRoutes = ['oral', 'topical', 'inhaled', 'sublingual', 'IV', 'other'];

class Medication {
  final int? id;
  final DateTime date;
  final String time;
  final String name;
  final double? dose;
  final String? unit;
  final String? route;
  final int? checkinDelayMinutes;
  final String? rawInput;
  final String? notes;
  final Uint8List? imageData;
  final DateTime createdAt;

  const Medication({
    this.id,
    required this.date,
    required this.time,
    required this.name,
    this.dose,
    this.unit,
    this.route,
    this.checkinDelayMinutes,
    this.rawInput,
    this.notes,
    this.imageData,
    required this.createdAt,
  });
}
