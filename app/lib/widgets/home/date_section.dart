import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/meal_entry.dart';
import '../../models/medication.dart';
import '../../models/reaction_log.dart';
import '../../models/water_log.dart';
import '../../models/weight_log.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../day_totals_bar.dart';
import 'feeling_tile.dart';
import 'meal_tile.dart';
import 'medication_tile.dart';
import 'water_summary.dart';
import 'weight_tile.dart';

class DateSection extends StatefulWidget {
  final DateTime date;
  final List<MealEntry> meals;
  final List<Medication> medications;
  final List<ReactionLog> feelings;
  final List<WaterLog> waterLogs;
  final List<WeightLog> weightLogs;
  final StorageService? storage;
  final bool isToday;
  final VoidCallback onReload;

  const DateSection({
    super.key,
    required this.date,
    required this.meals,
    required this.medications,
    required this.feelings,
    required this.waterLogs,
    required this.weightLogs,
    this.storage,
    required this.isToday,
    required this.onReload,
  });

  @override
  State<DateSection> createState() => _DateSectionState();
}

class _DateSectionState extends State<DateSection> {
  ({int cal, double prot, double carbs, double fat})? _totals;
  bool _totalsLoaded = false;

  Future<void> _loadTotals() async {
    if (_totalsLoaded || widget.storage == null) return;
    final ids = widget.meals.where((m) => m.id != null).map((m) => m.id!).toList();
    final t = await widget.storage!.getMacroTotalsForMeals(ids);
    if (!mounted) return;
    setState(() {
      _totals = t;
      _totalsLoaded = true;
    });
  }

  DateTime _toDateTime(DateTime date, String timeStr) {
    final t = DateTimeUtils.parseTime(timeStr);
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  List<Widget> _buildSortedEntries() {
    final entries = <({DateTime sortTime, Widget tile})>[];
    for (final m in widget.meals) {
      entries.add((
        sortTime: _toDateTime(m.date, m.time),
        tile: MealTile(meal: m, storage: widget.storage!, onReload: widget.onReload),
      ));
    }
    for (final m in widget.medications) {
      entries.add((
        sortTime: _toDateTime(m.date, m.time),
        tile: MedicationTile(med: m, onReload: widget.onReload),
      ));
    }
    for (final f in widget.feelings) {
      entries.add((
        sortTime: f.checkinTime,
        tile: FeelingTile(log: f, onReload: widget.onReload),
      ));
    }
    for (final w in widget.weightLogs) {
      entries.add((
        sortTime: _toDateTime(w.date, w.time),
        tile: WeightTile(log: w, onReload: widget.onReload),
      ));
    }
    entries.sort((a, b) => b.sortTime.compareTo(a.sortTime));
    return entries.map((e) => e.tile).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = widget.isToday
        ? 'Today · ${DateFormat('MMM d').format(widget.date)}'
        : DateFormat('EEEE, MMMM d').format(widget.date);

    final totalWaterMl = widget.waterLogs.fold(0, (sum, l) => sum + l.amountMl);
    final totalWaterOz = (totalWaterMl / 29.5735).round();

    final mealCount = widget.meals.length;
    final medCount = widget.medications.length;
    final feelingCount = widget.feelings.length;
    final weightCount = widget.weightLogs.length;
    final parts = [
      if (mealCount > 0) '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
      if (medCount > 0) '$medCount ${medCount == 1 ? 'medication' : 'medications'}',
      if (feelingCount > 0) '$feelingCount ${feelingCount == 1 ? 'check-in' : 'check-ins'}',
      if (totalWaterMl > 0) '💧 ${totalWaterOz}oz',
      if (weightCount > 0) '⚖ ${widget.weightLogs.first.displayWeight}',
    ];
    final subtitle = parts.isEmpty ? 'No entries' : parts.join(' · ');

    return Semantics(
      identifier: 'date-section-${widget.date.toIso8601String().substring(0, 10)}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(18), offset: const Offset(0, 1), blurRadius: 2),
            BoxShadow(color: Colors.black.withAlpha(38), offset: const Offset(0, 5), blurRadius: 10),
            BoxShadow(color: Colors.black.withAlpha(60), offset: const Offset(0, 12), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExpansionTile(
              initiallyExpanded: false,
              shape: const Border(),
              collapsedShape: const Border(),
              onExpansionChanged: (expanded) {
                if (expanded && widget.meals.isNotEmpty) _loadTotals();
              },
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(dateStr, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
              children: [
                if (_totals != null && widget.meals.isNotEmpty)
                  DayTotalsBar(cal: _totals!.cal, prot: _totals!.prot, carbs: _totals!.carbs, fat: _totals!.fat),
                if (widget.waterLogs.isNotEmpty)
                  WaterSummary(logs: widget.waterLogs, onReload: widget.onReload),
                ..._buildSortedEntries(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
