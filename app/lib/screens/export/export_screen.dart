import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/export_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../services/watch_folder.dart';
import '../../services/watch_import_service.dart';
import '../../services/watch_sync_service.dart';
import '../import/import_wizard_screen.dart';

class ExportScreen extends StatefulWidget {
  /// Test seams — fakes keep widget tests off the platform channel. Null in
  /// production, where the real implementations are used.
  final WatchFolderAccess? watchAccess;
  final SettingsService? settings;

  const ExportScreen({super.key, this.watchAccess, this.settings});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late final StorageService _storage;
  late final ExportService _export;
  late final SettingsService _settings = widget.settings ?? SettingsService();
  late final WatchFolderAccess _watchAccess =
      widget.watchAccess ?? PlatformWatchFolderAccess();
  late final WatchSyncService _watchSync = WatchSyncService(
    storage: _storage,
    settings: _settings,
    access: _watchAccess,
  );
  String? _watchLabel;

  DateTime? _from;
  DateTime? _to;
  bool _includeMeals = true;
  bool _includeMedications = true;
  bool _includeFoodMemories = true;
  bool _includePhotos = false;
  bool _isLoading = false;
  String? _error;

  final _fmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _storage = StorageService();
    _export = ExportService(_storage);
    _loadWatchLabel();
  }

  Future<void> _loadWatchLabel() async {
    try {
      final label = await _settings.watchFolderLabel;
      if (mounted) setState(() => _watchLabel = label);
    } catch (_) {
      // Prefs unavailable: the card just reads "Not set".
    }
  }

  @override
  void dispose() {
    _storage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'export-screen',
      child: Scaffold(
        appBar: AppBar(title: const Text('Export / Import')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Date range ──────────────────────────────────────
                    Card(
                      child: Column(
                        children: [
                          Semantics(
                            identifier: 'btn-date-from',
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('From'),
                              subtitle: Text(
                                  _from == null ? 'All time' : _fmt.format(_from!)),
                              trailing: _from != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          setState(() => _from = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _pickFrom,
                            ),
                          ),
                          const Divider(height: 0),
                          Semantics(
                            identifier: 'btn-date-to',
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('To'),
                              subtitle: Text(
                                  _to == null ? 'Today' : _fmt.format(_to!)),
                              trailing: _to != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          setState(() => _to = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _pickTo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Include toggles ─────────────────────────────────
                    Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              'Include',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-meals',
                            child: SwitchListTile(
                              title: const Text('Meals'),
                              value: _includeMeals,
                              onChanged: (v) =>
                                  setState(() => _includeMeals = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-medications',
                            child: SwitchListTile(
                              title: const Text('Medications'),
                              value: _includeMedications,
                              onChanged: (v) =>
                                  setState(() => _includeMedications = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-memories',
                            child: SwitchListTile(
                              title: const Text('Food Memories'),
                              value: _includeFoodMemories,
                              onChanged: (v) =>
                                  setState(() => _includeFoodMemories = v),
                              dense: true,
                            ),
                          ),
                          Semantics(
                            identifier: 'toggle-include-photos',
                            child: SwitchListTile(
                              title: const Text('Photos'),
                              subtitle: const Text('Larger file — off by default'),
                              value: _includePhotos,
                              onChanged: (v) =>
                                  setState(() => _includePhotos = v),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null) ...[
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],

                    // ── Export button ───────────────────────────────────
                    Semantics(
                      identifier: 'btn-export-json',
                      child: ElevatedButton.icon(
                        onPressed: _exportJson,
                        icon: const Icon(Icons.upload),
                        label: const Text('Export as JSON'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Import button ───────────────────────────────────
                    Semantics(
                      identifier: 'btn-import-json',
                      child: OutlinedButton.icon(
                        onPressed: _pickAndImport,
                        icon: const Icon(Icons.download),
                        label: const Text('Import from JSON'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Watch data card ─────────────────────────────────
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
                              child: Text(
                                'Watch data (Gadgetbridge)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Semantics(
                              identifier: 'watch-folder-path',
                              child: ListTile(
                                leading: const Icon(Icons.folder_outlined),
                                title: const Text('Folder'),
                                subtitle: Text(_watchLabel ?? 'Not set'),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                Semantics(
                                  identifier: 'btn-watch-set-folder',
                                  child: OutlinedButton.icon(
                                    onPressed: _setWatchFolder,
                                    icon: const Icon(Icons.drive_folder_upload),
                                    label: const Text('Set folder'),
                                  ),
                                ),
                                Semantics(
                                  identifier: 'btn-watch-import-now',
                                  child: FilledButton.tonalIcon(
                                    onPressed:
                                        _watchLabel == null ? null : _importWatchNow,
                                    icon: const Icon(Icons.sync),
                                    label: const Text('Import now'),
                                  ),
                                ),
                                Semantics(
                                  identifier: 'btn-import-watch',
                                  child: TextButton.icon(
                                    onPressed: _pickAndImportWatch,
                                    icon: const Icon(Icons.file_open_outlined),
                                    label: const Text('Import file…'),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                              child: Text(
                                'Gadgetbridge.db in this folder is imported automatically when the app opens.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _to ?? DateTime.now(),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: _from ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _exportJson() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      await _export.exportJson(
        from: _from,
        to: _to,
        types: ExportTypes(
          meals: _includeMeals,
          medications: _includeMedications,
          foodMemories: _includeFoodMemories,
          images: _includePhotos,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setWatchFolder() async {
    final link = await _watchAccess.pickFolder();
    if (link == null) return;
    await _settings.setWatchFolder(link);
    if (!mounted) return;
    setState(() => _watchLabel = link.label);
    await _importWatchNow();
  }

  Future<void> _importWatchNow() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final o = await _watchSync.syncIfNewer(force: true);
      if (!mounted) return;
      final String message;
      switch (o.state) {
        case WatchSyncState.imported:
          final r = o.result!;
          message = r.changed == 0
              ? 'No new watch data'
              : 'Imported ${r.changed} watch samples (${_fmt.format(r.first!)} – ${_fmt.format(r.last!)})';
        case WatchSyncState.missing:
          message = 'Gadgetbridge.db not found in that folder';
        case WatchSyncState.noAccess:
          message = 'Folder access was lost — set the folder again';
        case WatchSyncState.failed:
          message = o.error ?? 'Import failed';
        // UNDECIDED: Import now message for notLinked/unchanged (unreachable: button disabled without folder, force skips unchanged)
        case WatchSyncState.notLinked:
        case WatchSyncState.unchanged:
          message = 'No new watch data';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndImportWatch() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _error = null;
      _isLoading = true;
    });
    try {
      final r = await WatchImportService(_storage).importGadgetbridge(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.changed == 0
              ? 'No new watch data'
              : 'Imported ${r.changed} watch samples (${_fmt.format(r.first!)} – ${_fmt.format(r.last!)})'),
        ));
      }
    } on WatchImportException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImportWizardScreen(filePath: result.files.single.path!),
      ),
    );
  }
}
