import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/reaction_log.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/error_display.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';

class CheckinScreen extends StatefulWidget {
  final int? mealId;          // null = standalone new check-in
  final ReactionLog? existingLog; // non-null = editing existing standalone log

  const CheckinScreen({super.key, this.mealId, this.existingLog});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _storage = StorageService();
  late final Set<String> _selectedSymptoms;
  late ReactionLevel _severity;
  final _notesController = TextEditingController();
  late DateTime _checkinDate;
  late TimeOfDay _checkinTime;
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isStandalone => widget.mealId == null && widget.existingLog == null;
  bool get _isEditing => widget.existingLog != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final log = widget.existingLog!;
      _selectedSymptoms = Set.from(log.symptoms);
      _severity = log.severity;
      _notesController.text = log.notes ?? '';
      _checkinDate = DateTime(log.checkinTime.year, log.checkinTime.month, log.checkinTime.day);
      _checkinTime = TimeOfDay.fromDateTime(log.checkinTime);
    } else {
      _selectedSymptoms = {};
      _severity = ReactionLevel.none;
      _checkinDate = DateTimeUtils.today();
      _checkinTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _storage.dispose();
    super.dispose();
  }

  String get _title {
    if (_isEditing) return 'Edit feeling';
    if (_isStandalone) return 'How are you feeling?';
    return 'How did you feel?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isEditing) ...[
                    LogDateTimeRow(
                      date: _checkinDate,
                      time: _checkinTime,
                      onDateChanged: (d) => setState(() => _checkinDate = d),
                      onTimeChanged: (t) => setState(() => _checkinTime = t),
                      trailing: GestureDetector(
                        onTap: _confirmDelete,
                        child: Icon(Icons.delete_outline, size: 22,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kSymptomOptions.map((s) {
                      final selected = _selectedSymptoms.contains(s);
                      return FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedSymptoms.add(s);
                          } else {
                            _selectedSymptoms.remove(s);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Severity', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<ReactionLevel>(
                    segments: [
                      ButtonSegment(value: ReactionLevel.none, label: Text(ReactionLevel.none.label)),
                      ButtonSegment(value: ReactionLevel.mild, label: Text(ReactionLevel.mild.label)),
                      ButtonSegment(value: ReactionLevel.moderate, label: Text(ReactionLevel.moderate.label)),
                      ButtonSegment(value: ReactionLevel.bad, label: Text(ReactionLevel.bad.label)),
                    ],
                    selected: {_severity},
                    onSelectionChanged: (s) => setState(() => _severity = s.first),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Notes (optional)…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _errorMessage!),
                  ],
                ],
              ),
            ),
          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: LoadingButton(
                isLoading: _isLoading,
                label: 'Save',
                onPressed: _save,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete check-in?'),
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
    await _storage.deleteReactionLog(widget.existingLog!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    try {
      final symptoms = _selectedSymptoms.toList();

      if (_isEditing) {
        final updated = ReactionLog(
          id: widget.existingLog!.id,
          mealId: widget.existingLog!.mealId,
          checkinTime: DateTime(_checkinDate.year, _checkinDate.month, _checkinDate.day,
              _checkinTime.hour, _checkinTime.minute),
          symptoms: symptoms,
          severity: _severity,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
        await _storage.updateReactionLog(updated);
      } else {
        await _storage.saveReactionLog(ReactionLog(
          mealId: widget.mealId,
          checkinTime: DateTime.now(),
          symptoms: symptoms,
          severity: _severity,
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        ));

        if (widget.mealId != null) {
          final parts = [
            if (_severity != ReactionLevel.none) _severity.label,
            if (symptoms.isNotEmpty) symptoms.join(', '),
          ];
          await _storage.updateMealSymptoms(
            widget.mealId!,
            parts.isEmpty ? 'No reaction' : parts.join(' · '),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Save failed: $e';
        _isLoading = false;
      });
    }
  }
}
