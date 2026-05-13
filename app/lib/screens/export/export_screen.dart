import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/export_service.dart';
import '../../services/storage_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late final StorageService _storage;
  late final ExportService _export;

  DateTime? _from;
  DateTime? _to;
  bool _isLoading = false;
  String? _error;

  final _fmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _storage = StorageService();
    _export = ExportService(_storage);
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
        appBar: AppBar(title: const Text('Export')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Column(
                        children: [
                          Semantics(
                            identifier: 'btn-date-from',
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: const Text('From'),
                              subtitle: Text(_from == null ? 'All time' : _fmt.format(_from!)),
                              trailing: _from != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _from = null),
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
                              subtitle: Text(_to == null ? 'Today' : _fmt.format(_to!)),
                              trailing: _to != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _to = null),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _pickTo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                    ],
                    Semantics(
                      identifier: 'btn-export-json',
                      child: ElevatedButton.icon(
                        onPressed: _exportJson,
                        icon: const Icon(Icons.download),
                        label: const Text('Export as JSON'),
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
      await _export.exportMealsJson(from: _from, to: _to);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
