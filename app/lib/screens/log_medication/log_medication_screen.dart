import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/medication.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/log_date_time_row.dart';
import '../../widgets/log_description_section.dart';
import '../../widgets/log_photo_section.dart';

class LogMedicationScreen extends StatefulWidget {
  const LogMedicationScreen({super.key});

  @override
  State<LogMedicationScreen> createState() => _LogMedicationScreenState();
}

class _LogMedicationScreenState extends State<LogMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _checkinDelayCtrl = TextEditingController(text: '90');

  final _aiService = AiService.fromEnv();
  final _storage = StorageService();
  final _notifications = NotificationService();
  final _settings = SettingsService();

  bool _aiEnabled = true;
  bool _isAutofilling = false;
  bool _isSaving = false;
  String? _errorMessage;

  DateTime _date = _today();
  TimeOfDay _time = TimeOfDay.now();
  Uint8List? _imageBytes;
  String? _selectedUnit;
  String? _selectedRoute;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isAiEnabled;
    if (mounted) setState(() => _aiEnabled = enabled);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _checkinDelayCtrl.dispose();
    super.dispose();
  }

  Future<void> _autofill() async {
    final text = _descCtrl.text.trim();
    final image = _imageBytes;
    if (text.isEmpty && image == null) {
      setState(() => _errorMessage = 'Add a description or photo before autofilling.');
      return;
    }
    setState(() {
      _isAutofilling = true;
      _errorMessage = null;
    });

    final result = await _aiService.parseMedication(
      text: text.isEmpty ? null : text,
      imageBytes: image,
    );

    if (!mounted) return;
    setState(() => _isAutofilling = false);

    if (!result.success) {
      setState(() => _errorMessage = result.errorMessage ?? 'Autofill failed.');
      return;
    }

    setState(() {
      if (_nameCtrl.text.trim().isEmpty && result.name != null) {
        _nameCtrl.text = result.name!;
      }
      if (_doseCtrl.text.trim().isEmpty && result.dose != null) {
        _doseCtrl.text = result.dose!.toStringAsFixed(
          result.dose! == result.dose!.truncateToDouble() ? 0 : 1,
        );
      }
      if (_selectedUnit == null && result.unit != null) _selectedUnit = result.unit;
      if (_selectedRoute == null && result.route != null) _selectedRoute = result.route;
      if (_notesCtrl.text.trim().isEmpty && result.notes != null) {
        _notesCtrl.text = result.notes!;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Medication name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final delay = int.tryParse(_checkinDelayCtrl.text.trim());
      final now = DateTime.now();
      final med = Medication(
        date: _date,
        time: _time.format(context),
        name: name,
        dose: double.tryParse(_doseCtrl.text.trim()),
        unit: _selectedUnit,
        route: _selectedRoute,
        checkinDelayMinutes: delay,
        rawInput: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        imageData: _imageBytes,
        createdAt: now,
      );

      final medId = await _storage.saveMedication(med);

      final entryTime = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute,
      );
      await _notifications.scheduleCheckin(
        medId,
        name,
        entryTime,
        delayMinutes: delay,
      );

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
      appBar: AppBar(title: const Text('Log Medication')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Date / Time ─────────────────────────────────────────────────
            LogDateTimeRow(
              date: _date,
              time: _time,
              enabled: !_isSaving,
              onDateChanged: (d) => setState(() => _date = d),
              onTimeChanged: (t) => setState(() => _time = t),
            ),
            const SizedBox(height: 12),

            // ── Name ─────────────────────────────────────────────────────────
            Semantics(
              identifier: 'log-med-name',
              child: TextField(
                controller: _nameCtrl,
                enabled: !_isSaving,
                style: theme.textTheme.titleMedium,
                decoration: const InputDecoration(
                  labelText: 'Medication / Supplement *',
                  hintText: 'e.g. Ibuprofen, Vitamin D3',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Photo ────────────────────────────────────────────────────────
            LogPhotoSection(
              imageBytes: _imageBytes,
              enabled: !_isSaving && !_isAutofilling,
              onImagePicked: (b) => setState(() => _imageBytes = b),
              onClear: () => setState(() => _imageBytes = null),
            ),
            const SizedBox(height: 12),

            // ── Description + Autofill ───────────────────────────────────────
            LogDescriptionSection(
              controller: _descCtrl,
              aiEnabled: _aiEnabled,
              isAutofilling: _isAutofilling,
              onAutofill: _autofill,
              hintText: 'Describe the medication or scan the label…',
            ),
            const SizedBox(height: 16),

            // ── Dose / Unit / Route ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _doseCtrl,
                    enabled: !_isSaving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: const InputDecoration(
                      labelText: 'Dose',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _LabeledDropdown<String>(
                  label: 'Unit',
                  value: _selectedUnit,
                  items: const [null, ...kMedUnits],
                  itemLabel: (v) => v ?? '—',
                  enabled: !_isSaving,
                  onChanged: (v) => setState(() => _selectedUnit = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: _LabeledDropdown<String>(
                  label: 'Route',
                  value: _selectedRoute,
                  items: const [null, ...kMedRoutes],
                  itemLabel: (v) => v ?? '—',
                  enabled: !_isSaving,
                  onChanged: (v) => setState(() => _selectedRoute = v),
                )),
              ],
            ),
            const SizedBox(height: 12),

            // ── Notes ────────────────────────────────────────────────────────
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

            // ── Check-in delay (not shown in card/summary) ───────────────────
            _CheckinDelayField(controller: _checkinDelayCtrl, enabled: !_isSaving),
            const SizedBox(height: 16),

            // ── Error ─────────────────────────────────────────────────────────
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],

            // ── Save ──────────────────────────────────────────────────────────
            Semantics(
              identifier: 'btn-save-medication',
              child: ElevatedButton(
                onPressed: _isSaving || _isAutofilling ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinDelayField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _CheckinDelayField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.notifications_outlined, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text('Check-in after', style: theme.textTheme.bodySmall),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('minutes', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T?> items;
  final String Function(T? v) itemLabel;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          items: items
              .map((v) => DropdownMenuItem<T?>(value: v, child: Text(itemLabel(v))))
              .toList(),
        ),
      ),
    );
  }
}
