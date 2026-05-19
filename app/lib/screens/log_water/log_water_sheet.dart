import 'package:flutter/material.dart';

import '../../models/water_log.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/error_display.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';

const _kGoalMl = 1893; // 64 oz

const _kPresets = [
  (label: '8 oz', ml: 237),
  (label: '12 oz', ml: 355),
  (label: '16 oz', ml: 473),
  (label: '24 oz', ml: 710),
  (label: '32 oz', ml: 946),
];

class LogWaterSheet extends StatefulWidget {
  final WaterLog? existingLog;

  const LogWaterSheet({super.key, this.existingLog});

  @override
  State<LogWaterSheet> createState() => _LogWaterSheetState();
}

class _LogWaterSheetState extends State<LogWaterSheet> {
  final _storage = StorageService();
  final _customCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  int? _selectedPresetMl;
  DateTime _date = DateTimeUtils.today();
  TimeOfDay _time = TimeOfDay.now();

  bool get _isEditing => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _populate();
  }

  void _populate() {
    final log = widget.existingLog!;
    _date = DateTime(log.date.year, log.date.month, log.date.day);
    _time = DateTimeUtils.parseTime(log.time);
    _notesCtrl.text = log.notes ?? '';
    // Try to match a preset; otherwise show custom
    final match = _kPresets.where((p) => p.ml == log.amountMl).firstOrNull;
    if (match != null) {
      _selectedPresetMl = match.ml;
    } else {
      _customCtrl.text = log.amountOz.round().toString();
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int? get _resolvedMl {
    if (_selectedPresetMl != null) return _selectedPresetMl;
    final oz = double.tryParse(_customCtrl.text.trim());
    if (oz == null || oz <= 0) return null;
    return (oz * 29.5735).round();
  }

  Future<void> _save() async {
    final ml = _resolvedMl;
    if (ml == null) {
      setState(() => _errorMessage = 'Select an amount or enter a custom amount.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final now = DateTime.now();
      final log = WaterLog(
        id: widget.existingLog?.id,
        date: _date,
        time: _time.format(context),
        amountMl: ml,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.existingLog?.createdAt ?? now,
      );
      if (_isEditing) {
        await _storage.updateWaterLog(log);
      } else {
        await _storage.saveWaterLog(log);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete water log?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _storage.deleteWaterLog(widget.existingLog!.id!);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'log-water-sheet',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: Colors.blue.shade400, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Water Log' : 'Log Water',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_isEditing)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                    onPressed: _isSaving ? null : _delete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            LogDateTimeRow(
              date: _date,
              time: _time,
              enabled: !_isSaving,
              onDateChanged: (d) => setState(() => _date = d),
              onTimeChanged: (t) => setState(() => _time = t),
            ),
            const SizedBox(height: 16),
            Text('Amount', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kPresets.map((p) {
                final selected = _selectedPresetMl == p.ml && _customCtrl.text.isEmpty;
                return Semantics(
                  identifier: 'btn-water-${p.ml}ml',
                  child: ChoiceChip(
                    label: Text(p.label),
                    selected: selected,
                    onSelected: _isSaving
                        ? null
                        : (_) => setState(() {
                              _selectedPresetMl = p.ml;
                              _customCtrl.clear();
                            }),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    identifier: 'log-water-custom-oz',
                    child: TextField(
                      controller: _customCtrl,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Custom (oz)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() => _selectedPresetMl = null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _GoalIndicator(resolvedMl: _resolvedMl, goalMl: _kGoalMl),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              enabled: !_isSaving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 8),
            ],
            LoadingButton(
              isLoading: _isSaving,
              label: _isEditing ? 'Save Changes' : 'Save',
              onPressed: _save,
              semanticsId: 'btn-save-water',
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalIndicator extends StatelessWidget {
  final int? resolvedMl;
  final int goalMl;

  const _GoalIndicator({required this.resolvedMl, required this.goalMl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oz = resolvedMl != null ? (resolvedMl! / 29.5735).round() : 0;
    final goalOz = (goalMl / 29.5735).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$oz / $goalOz oz', style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          child: LinearProgressIndicator(
            value: resolvedMl != null ? (resolvedMl! / goalMl).clamp(0.0, 1.0) : 0.0,
            minHeight: 6,
            backgroundColor: Colors.blue.withAlpha(40),
            valueColor: AlwaysStoppedAnimation(Colors.blue.shade400),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
