import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/meal_entry.dart';
import '../../models/medication.dart';
import '../../models/reaction_log.dart';
import '../../models/water_log.dart';
import '../../models/weight_log.dart';
import '../../services/storage_service.dart';
import 'date_section.dart';

typedef MacroFetcher = Future<({int cal, double prot, double carbs, double fat})>
    Function(List<int> ids);

class WeekSummarySection extends StatefulWidget {
  final DateTime weekStart;
  final List<DateTime> dates;
  final Map<DateTime, List<MealEntry>> mealsByDate;
  final Map<DateTime, List<Medication>> medsByDate;
  final Map<DateTime, List<ReactionLog>> feelingsByDate;
  final Map<DateTime, List<WaterLog>> waterByDate;
  final Map<DateTime, List<WeightLog>> weightByDate;
  final StorageService? storage;
  final bool Function(DateTime) isToday;
  final VoidCallback onReload;
  // When provided, replaces storage.getMacroTotalsForMeals for the week header.
  // Required when storage is null (tests that inject a fetcher directly).
  final MacroFetcher? macroFetcher;

  const WeekSummarySection({
    super.key,
    required this.weekStart,
    required this.dates,
    required this.mealsByDate,
    required this.medsByDate,
    required this.feelingsByDate,
    required this.waterByDate,
    required this.weightByDate,
    this.storage,
    required this.isToday,
    required this.onReload,
    this.macroFetcher,
  }) : assert(storage != null || macroFetcher != null,
            'Provide storage or macroFetcher');

  @override
  State<WeekSummarySection> createState() => _WeekSummarySectionState();
}

class _WeekSummarySectionState extends State<WeekSummarySection> {
  ({int cal, double prot, double carbs, double fat})? _totals;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    final ids = widget.dates
        .expand<MealEntry>((d) => widget.mealsByDate[d] ?? [])
        .where((m) => m.id != null)
        .map((m) => m.id!)
        .toList();
    if (ids.isEmpty) return;
    final fetch = widget.macroFetcher ?? widget.storage!.getMacroTotalsForMeals;
    final t = await fetch(ids);
    if (!mounted) return;
    setState(() => _totals = t);
  }

  String _weekLabel() {
    final end = widget.weekStart.add(const Duration(days: 6));
    final start = DateFormat('MMM d').format(widget.weekStart);
    final endStr = widget.weekStart.month == end.month
        ? DateFormat('d').format(end)
        : DateFormat('MMM d').format(end);
    return '$start – $endStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;

    final totalMeals = widget.dates
        .expand<MealEntry>((d) => widget.mealsByDate[d] ?? [])
        .length;
    final daysWithMeals = widget.dates
        .where((d) => (widget.mealsByDate[d] ?? []).isNotEmpty)
        .length;

    final subtitleParts = <String>[
      '$totalMeals ${totalMeals == 1 ? "meal" : "meals"}',
      if (_totals != null && _totals!.cal > 0) '${_totals!.cal} cal',
    ];

    return Semantics(
      identifier: 'week-section-${widget.weekStart.toIso8601String().substring(0, 10)}',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(18), offset: const Offset(0, 1), blurRadius: 2),
            BoxShadow(color: Colors.black.withAlpha(38), offset: const Offset(0, 5), blurRadius: 10),
            BoxShadow(color: Colors.black.withAlpha(60), offset: const Offset(0, 12), blurRadius: 20),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Icon(Icons.calendar_view_week_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                _weekLabel(),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          subtitle: Text(subtitleParts.join(' · '), style: theme.textTheme.bodySmall),
          children: [
            if (_totals != null && _totals!.cal > 0)
              _WeekMacroBar(totals: _totals!, daysWithMeals: daysWithMeals),
            if (widget.storage case final storage?)
              ...widget.dates.map(
                (date) => DateSection(
                  date: date,
                  meals: widget.mealsByDate[date] ?? [],
                  medications: widget.medsByDate[date] ?? [],
                  feelings: widget.feelingsByDate[date] ?? [],
                  waterLogs: widget.waterByDate[date] ?? [],
                  weightLogs: widget.weightByDate[date] ?? [],
                  storage: storage,
                  isToday: widget.isToday(date),
                  onReload: widget.onReload,
                ),
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _WeekMacroBar extends StatelessWidget {
  final ({int cal, double prot, double carbs, double fat}) totals;
  final int daysWithMeals;

  const _WeekMacroBar({required this.totals, required this.daysWithMeals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondary;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );

    final avgCal = daysWithMeals > 0 ? totals.cal ~/ daysWithMeals : 0;
    final avgProt = daysWithMeals > 0 ? totals.prot / daysWithMeals : 0.0;
    final avgCarbs = daysWithMeals > 0 ? totals.carbs / daysWithMeals : 0.0;
    final avgFat = daysWithMeals > 0 ? totals.fat / daysWithMeals : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TOTALS', style: labelStyle),
          const SizedBox(height: 4),
          Row(children: [
            if (totals.cal > 0) _Cell(label: 'CAL', value: '${totals.cal}', labelStyle: labelStyle, theme: theme),
            if (totals.prot > 0) _Cell(label: 'PROT', value: '${totals.prot.toInt()}g', labelStyle: labelStyle, theme: theme),
            if (totals.carbs > 0) _Cell(label: 'CARBS', value: '${totals.carbs.toInt()}g', labelStyle: labelStyle, theme: theme),
            if (totals.fat > 0) _Cell(label: 'FAT', value: '${totals.fat.toInt()}g', labelStyle: labelStyle, theme: theme),
          ]),
          if (daysWithMeals > 1) ...[
            const SizedBox(height: 8),
            Text('AVG / DAY', style: labelStyle),
            const SizedBox(height: 4),
            Row(children: [
              if (avgCal > 0) _Cell(label: 'CAL', value: '$avgCal', labelStyle: labelStyle, theme: theme),
              if (avgProt > 0) _Cell(label: 'PROT', value: '${avgProt.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (avgCarbs > 0) _Cell(label: 'CARBS', value: '${avgCarbs.toInt()}g', labelStyle: labelStyle, theme: theme),
              if (avgFat > 0) _Cell(label: 'FAT', value: '${avgFat.toInt()}g', labelStyle: labelStyle, theme: theme),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final ThemeData theme;

  const _Cell({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          Text(value, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
