import 'package:flutter/material.dart';

import '../../models/weight_log.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/error_display.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';

class LogWeightScreen extends StatefulWidget {
  final WeightLog? existingLog;

  const LogWeightScreen({super.key, this.existingLog});

  @override
  State<LogWeightScreen> createState() => _LogWeightScreenState();
}

class _LogWeightScreenState extends State<LogWeightScreen> {
  final _storage = StorageService();
  final _weightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
  String _unit = 'lbs';
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
    _unit = log.unit;
    _notesCtrl.text = log.notes ?? '';
    _weightCtrl.text = log.weightValue == log.weightValue.truncateToDouble()
        ? log.weightValue.toInt().toString()
        : log.weightValue.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete weigh-in?'),
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
    await _storage.deleteWeightLog(widget.existingLog!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final value = double.tryParse(_weightCtrl.text.trim());
    if (value == null || value <= 0) {
      setState(() => _errorMessage = 'Enter a valid weight.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final now = DateTime.now();
      final log = WeightLog(
        id: widget.existingLog?.id,
        date: _date,
        time: _time.format(context),
        weightValue: value,
        unit: _unit,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: widget.existingLog?.createdAt ?? now,
      );
      if (_isEditing) {
        await _storage.updateWeightLog(log);
      } else {
        await _storage.saveWeightLog(log);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Weigh-in' : 'Log Weigh-in'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LogDateTimeRow(
                date: _date,
                time: _time,
                enabled: !_isSaving,
                onDateChanged: (d) => setState(() => _date = d),
                onTimeChanged: (t) => setState(() => _time = t),
                trailing: _isEditing
                    ? GestureDetector(
                        onTap: _isSaving ? null : _confirmDelete,
                        child: Icon(
                          Icons.delete_outline,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      identifier: 'log-weight-value',
                      child: TextField(
                        controller: _weightCtrl,
                        enabled: !_isSaving,
                        autofocus: !_isEditing,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: theme.textTheme.headlineMedium,
                        decoration: InputDecoration(
                          labelText: 'Weight',
                          hintText: _unit == 'lbs' ? '175' : '80',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    identifier: 'log-weight-unit-toggle',
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'lbs', label: Text('lbs')),
                        ButtonSegment(value: 'kg', label: Text('kg')),
                      ],
                      selected: {_unit},
                      onSelectionChanged: _isSaving
                          ? null
                          : (s) => setState(() => _unit = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                ErrorBanner(message: _errorMessage!),
                const SizedBox(height: 8),
              ],
              LoadingButton(
                isLoading: _isSaving,
                label: _isEditing ? 'Save Changes' : 'Save',
                onPressed: _save,
                semanticsId: 'btn-save-weight',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
