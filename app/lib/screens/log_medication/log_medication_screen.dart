import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/medication.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/checkin_delay_field.dart';
import '../../widgets/error_display.dart';
import '../../widgets/labeled_dropdown.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/log_date_time_row.dart';
import '../../widgets/log_description_section.dart';
import '../../widgets/log_photo_section.dart';

class LogMedicationScreen extends StatefulWidget {
  final Medication? existingMed;
  final StorageService? storageOverride;
  final AiService? aiOverride;
  final NotificationService? notificationsOverride;
  final SettingsService? settingsOverride;

  const LogMedicationScreen({
    super.key,
    this.existingMed,
    this.storageOverride,
    this.aiOverride,
    this.notificationsOverride,
    this.settingsOverride,
  });

  @override
  State<LogMedicationScreen> createState() => _LogMedicationScreenState();
}

class _LogMedicationScreenState extends State<LogMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _checkinDelayCtrl = TextEditingController(text: '90');

  late final AiService _aiService = widget.aiOverride ?? AiService.fromEnv();
  late final StorageService _storage = widget.storageOverride ?? StorageService();
  late final NotificationService _notifications =
      widget.notificationsOverride ?? NotificationService();
  late final SettingsService _settings = widget.settingsOverride ?? SettingsService();

  bool _aiEnabled = true;
  bool _isAutofilling = false;
  bool _isSaving = false;
  String? _errorMessage;

  DateTime _date = DateTimeUtils.today();
  TimeOfDay _time = TimeOfDay.now();
  Uint8List? _imageBytes;
  String? _selectedUnit;
  String? _selectedRoute;

  bool get _isEditing => widget.existingMed != null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (_isEditing) _populateExisting();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isAiEnabled;
    if (mounted) setState(() => _aiEnabled = enabled);
  }

  void _populateExisting() {
    final med = widget.existingMed!;
    _nameCtrl.text = med.name;
    _doseCtrl.text = med.dose == null
        ? ''
        : med.dose! == med.dose!.truncateToDouble()
            ? med.dose!.toInt().toString()
            : med.dose!.toStringAsFixed(1);
    _descCtrl.text = med.rawInput ?? '';
    _notesCtrl.text = med.notes ?? '';
    _checkinDelayCtrl.text = med.checkinDelayMinutes?.toString() ?? '90';
    _imageBytes = med.imageData;
    _date = DateTime(med.date.year, med.date.month, med.date.day);
    _time = DateTimeUtils.parseTime(med.time);
    _selectedUnit = med.unit;
    _selectedRoute = med.route;
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

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete medication?'),
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
    await _storage.deleteMedication(widget.existingMed!.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
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
        id: widget.existingMed?.id,
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
        createdAt: widget.existingMed?.createdAt ?? now,
      );

      final entryTime = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      if (_isEditing) {
        final medId = widget.existingMed!.id!;
        await _storage.updateMedication(med);
        // Reschedule: edits to time/delay must move the existing check-in,
        // not leave it firing at the original time. Cancel then re-arm.
        await _notifications.cancelCheckin(medId);
        await _notifications.scheduleCheckin(medId, name, entryTime, delayMinutes: delay);
      } else {
        final medId = await _storage.saveMedication(med);
        await _notifications.scheduleCheckin(medId, name, entryTime, delayMinutes: delay);
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
    return Semantics(
      identifier: 'log-medication-screen',
      child: Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Medication' : 'Log Medication')),
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
                  ? Semantics(
                      identifier: 'btn-delete-medication',
                      child: GestureDetector(
                        onTap: _isSaving ? null : _confirmDelete,
                        child: Icon(Icons.delete_outline,
                            size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
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
            LogPhotoSection(
              imageBytes: _imageBytes,
              enabled: !_isSaving && !_isAutofilling,
              onImagePicked: (b) => setState(() => _imageBytes = b),
              onClear: () => setState(() => _imageBytes = null),
            ),
            const SizedBox(height: 12),
            LogDescriptionSection(
              controller: _descCtrl,
              aiEnabled: _aiEnabled,
              isAutofilling: _isAutofilling,
              onAutofill: _autofill,
              hintText: 'Describe the medication or scan the label…',
              autofillSemanticsId: 'btn-autofill-medication',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Semantics(
                    identifier: 'log-med-dose',
                    child: TextField(
                      controller: _doseCtrl,
                      enabled: !_isSaving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Dose',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    identifier: 'log-med-unit',
                    child: LabeledDropdown<String>(
                      label: 'Unit',
                      value: _selectedUnit,
                      items: const [null, ...kMedUnits],
                      itemLabel: (v) => v ?? '—',
                      enabled: !_isSaving,
                      onChanged: (v) => setState(() => _selectedUnit = v),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    identifier: 'log-med-route',
                    child: LabeledDropdown<String>(
                      label: 'Route',
                      value: _selectedRoute,
                      items: const [null, ...kMedRoutes],
                      itemLabel: (v) => v ?? '—',
                      enabled: !_isSaving,
                      onChanged: (v) => setState(() => _selectedRoute = v),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              identifier: 'log-med-notes',
              child: TextField(
                controller: _notesCtrl,
                enabled: !_isSaving,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'optional',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              identifier: 'log-med-checkin-delay',
              child: CheckinDelayField(controller: _checkinDelayCtrl, enabled: !_isSaving),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              ErrorBanner(message: _errorMessage!),
              const SizedBox(height: 8),
            ],
            LoadingButton(
              isLoading: _isSaving,
              disabled: _isAutofilling,
              label: _isEditing ? 'Save Changes' : 'Save',
              onPressed: _save,
              semanticsId: 'btn-save-medication',
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }
}
