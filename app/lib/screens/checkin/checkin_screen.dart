import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/reaction_log.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/checkin/notebook_symptom_sliders.dart';
import '../../widgets/error_display.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';

class CheckinScreen extends StatefulWidget {
  final int? mealId;          // null = standalone new check-in
  final ReactionLog? existingLog; // non-null = editing existing standalone log
  final StorageService? storageOverride; // test seam — fake storage

  const CheckinScreen({super.key, this.mealId, this.existingLog, this.storageOverride});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  late final StorageService _storage = widget.storageOverride ?? StorageService();
  // Insertion-ordered: chip tap adds at Mild, slider adjusts, untap removes.
  late final Map<String, ReactionLevel> _symptomLevels;
  Mood? _mood;
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
      _symptomLevels = {
        for (final name in log.symptoms)
          name: log.symptomLevels[name] ?? ReactionLevel.mild,
      };
      _mood = log.mood;
      _notesController.text = log.notes ?? '';
      _checkinDate = DateTime(log.checkinTime.year, log.checkinTime.month, log.checkinTime.day);
      _checkinTime = TimeOfDay.fromDateTime(log.checkinTime);
    } else {
      _symptomLevels = {};
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
    return Semantics(
      identifier: 'checkin-screen',
      child: Scaffold(
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
                      trailing: Semantics(
                        identifier: 'btn-delete-feeling-${widget.existingLog!.id}',
                        child: GestureDetector(
                          onTap: _confirmDelete,
                          child: Icon(Icons.delete_outline, size: 22,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text('Mood', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Semantics(
                    identifier: 'mood-selector',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: Mood.values.map((m) {
                        final selected = _mood == m;
                        final color = m.isNegative
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary;
                        return Semantics(
                          identifier: 'mood-${m.name}',
                          child: GestureDetector(
                            onTap: () => setState(() => _mood = selected ? null : m),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  m.face,
                                  size: 34,
                                  color: selected
                                      ? color
                                      : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(120),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                    color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: kSymptomOptions.map((s) {
                      final selected = _symptomLevels.containsKey(s);
                      return FilterChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _symptomLevels[s] = ReactionLevel.mild;
                          } else {
                            _symptomLevels.remove(s);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  if (_symptomLevels.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('How bad?', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    NotebookSymptomSliders(
                      levels: _symptomLevels,
                      onChanged: (name, level) =>
                          setState(() => _symptomLevels[name] = level),
                    ),
                  ],
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
      final symptoms = _symptomLevels.keys.toList();
      final severity = ReactionLog.deriveSeverity(_symptomLevels);
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (_isEditing) {
        final updated = ReactionLog(
          id: widget.existingLog!.id,
          mealId: widget.existingLog!.mealId,
          checkinTime: DateTime(_checkinDate.year, _checkinDate.month, _checkinDate.day,
              _checkinTime.hour, _checkinTime.minute),
          symptoms: symptoms,
          symptomLevels: Map.of(_symptomLevels),
          severity: severity,
          mood: _mood,
          notes: notes,
        );
        await _storage.updateReactionLog(updated);
      } else {
        await _storage.saveReactionLog(ReactionLog(
          mealId: widget.mealId,
          checkinTime: DateTime.now(),
          symptoms: symptoms,
          symptomLevels: Map.of(_symptomLevels),
          severity: severity,
          mood: _mood,
          notes: notes,
        ));

        if (widget.mealId != null) {
          final summary = _symptomLevels.entries
              .map((e) => '${e.key} (${e.value.label})')
              .join(', ');
          await _storage.updateMealSymptoms(
            widget.mealId!,
            summary.isEmpty ? 'No reaction' : summary,
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
