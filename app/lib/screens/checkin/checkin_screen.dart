import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/reaction_log.dart';
import '../../services/storage_service.dart';

class CheckinScreen extends StatefulWidget {
  final int mealId;

  const CheckinScreen({super.key, required this.mealId});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final _storage = StorageService();
  final Set<String> _selectedSymptoms = {};
  ReactionLevel _severity = ReactionLevel.none;
  final _notesController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    _storage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How do you feel?')),
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
      await _storage.saveReactionLog(ReactionLog(
        mealId: widget.mealId,
        checkinTime: DateTime.now(),
        symptoms: symptoms,
        severity: _severity,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      ));

      final parts = [
        if (_severity != ReactionLevel.none) _severity.label,
        if (symptoms.isNotEmpty) symptoms.join(', '),
      ];
      await _storage.updateMealSymptoms(
        widget.mealId,
        parts.isEmpty ? 'No reaction' : parts.join(' · '),
      );

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
