import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/reaction_log.dart';
import '../../services/storage_service.dart';

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
    } else {
      _selectedSymptoms = {};
      _severity = ReactionLevel.none;
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
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
          checkinTime: widget.existingLog!.checkinTime,
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
