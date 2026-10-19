import 'package:flutter/material.dart';

import '../../models/pantry_item.dart';
import '../../models/receipt_parser.dart';
import '../../services/ai_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final List<ParsedReceiptItem> items;
  final String ocrText;
  final String source; // 'receipt' | 'manual'

  /// Test seams — inject fakes. Null in production.
  final StorageService? storageOverride;
  final AiService? aiOverride;
  final bool? aiEnabledOverride;
  final DateTime Function()? clock;

  const ReceiptReviewScreen({
    super.key,
    required this.items,
    required this.ocrText,
    this.source = 'receipt',
    this.storageOverride,
    this.aiOverride,
    this.aiEnabledOverride,
    this.clock,
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

/// Number text for a quantity field: no unit, no "×", no trailing zeros.
String _qtyText(double qty) => formatPantryQuantity(qty, 'lb').replaceFirst(' lb', '');

class _Row {
  final String raw;
  final TextEditingController name;
  final TextEditingController qty;
  String unit;
  bool include;
  bool edited;
  bool _applying = false;

  _Row({
    required this.raw,
    required String name,
    required String qty,
    required this.unit,
    required this.include,
    required this.edited,
    required VoidCallback onChanged,
  })  : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty) {
    this.name.addListener(() => _onText(onChanged));
    this.qty.addListener(() => _onText(onChanged));
  }

  factory _Row.fromItem(ParsedReceiptItem item, VoidCallback onChanged) => _Row(
        raw: item.raw,
        name: item.name ?? item.raw,
        qty: _qtyText(item.qty),
        unit: item.unit,
        include: item.food != false,
        edited: false,
        onChanged: onChanged,
      );

  void _onText(VoidCallback onChanged) {
    if (!_applying) edited = true;
    onChanged();
  }

  /// Applies an AI suggestion without marking the row as user-edited.
  void applyAi(ParsedReceiptItem ai) {
    _applying = true;
    name.text = ai.name ?? name.text;
    qty.text = _qtyText(ai.qty);
    _applying = false;
    unit = ai.unit;
    include = ai.food != false;
  }

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  StorageService? _ownedStorage;
  late final StorageService _storage;
  late final AiService _ai;
  final List<_Row> _rows = [];
  bool _aiEnabled = true;
  bool _busy = false;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    if (widget.storageOverride != null) {
      _storage = widget.storageOverride!;
    } else {
      _ownedStorage = StorageService();
      _storage = _ownedStorage!;
    }
    _ai = widget.aiOverride ?? AiService.fromEnv();
    for (final item in widget.items) {
      _rows.add(_Row.fromItem(item, _refresh));
    }
    if (widget.source == 'manual' && _rows.isEmpty) {
      _rows.add(_blankRow(edited: false));
    }
    if (widget.aiEnabledOverride != null) {
      _aiEnabled = widget.aiEnabledOverride!;
    } else {
      _loadAiEnabled();
    }
  }

  Future<void> _loadAiEnabled() async {
    try {
      final enabled = await SettingsService().isAiEnabled;
      if (mounted) setState(() => _aiEnabled = enabled);
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — keep the default.
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  _Row _blankRow({required bool edited}) => _Row(
        raw: '',
        name: '',
        qty: '1',
        unit: 'ea',
        include: true,
        edited: edited,
        onChanged: _refresh,
      );

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _ownedStorage?.dispose();
    super.dispose();
  }

  Future<void> _cleanUp() async {
    setState(() {
      _busy = true;
      _aiBusy = true;
    });
    try {
      List<String> known;
      try {
        known = await _storage.getKnownFoodNames();
      } catch (_) {
        known = [];
      }
      final r = await _ai.parseReceipt(widget.ocrText, knownFoods: known);
      if (!r.success || r.items == null) {
        _showError('AI clean-up failed: ${r.errorMessage}');
        return;
      }
      if (!mounted) return;
      final aiItems = mergeReceiptItems(r.items!);
      final matched = <_Row>{};
      final appended = <_Row>[];
      {
        for (final ai in aiItems) {
          final key = normalizeReceiptLine(ai.raw);
          _Row? hit;
          for (final row in _rows) {
            if (!matched.contains(row) && normalizeReceiptLine(row.raw) == key) {
              hit = row;
              break;
            }
          }
          if (hit == null) {
            var best = 0.0;
            for (final row in _rows) {
              if (matched.contains(row)) continue;
              final ratio = sequenceRatio(normalizeReceiptLine(row.raw), key);
              if (ratio >= 0.80 && ratio > best) {
                best = ratio;
                hit = row;
              }
            }
          }
          if (hit == null) {
            appended.add(_Row.fromItem(ai, _refresh));
            continue;
          }
          matched.add(hit);
          if (!hit.edited) hit.applyAi(ai);
        }
        _rows.addAll(appended);
      }
      setState(() {});
    } catch (e) {
      _showError('AI clean-up failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _aiBusy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final now = (widget.clock ?? DateTime.now)();
      final list = <PantryItem>[];
      for (final row in _rows) {
        final name = row.name.text.trim();
        if (!row.include || name.isEmpty) continue;
        var qty = double.tryParse(row.qty.text.trim()) ?? 1;
        if (qty <= 0) qty = 1;
        list.add(PantryItem(
          name: name,
          quantity: qty,
          unit: row.unit,
          source: widget.source,
          rawText: row.raw.isEmpty ? null : row.raw,
          addedAt: now,
        ));
      }
      await _storage.addPantryItems(list);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Could not save: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static const _spinner = SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  Widget _buildRow(int i, _Row row) {
    final showRaw = row.raw.isNotEmpty && row.raw != row.name.text;
    return Semantics(
      identifier: 'item-receipt-row-$i',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: row.include,
              onChanged: (v) => setState(() {
                row.include = v ?? false;
                row.edited = true;
              }),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: row.name,
                    decoration: const InputDecoration(isDense: true),
                  ),
                  if (showRaw)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(row.raw, style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: TextField(
                controller: row.qty,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: row.unit,
              items: const [
                DropdownMenuItem(value: 'ea', child: Text('ea')),
                DropdownMenuItem(value: 'lb', child: Text('lb')),
              ],
              onChanged: (v) => setState(() {
                if (v == null) return;
                row.unit = v;
                row.edited = true;
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAi = _aiEnabled && widget.source == 'receipt' && widget.ocrText.trim().isNotEmpty;
    return Semantics(
      identifier: 'receipt-review-screen',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.source == 'manual' ? 'Add to pantry' : 'Review receipt'),
          actions: [
            Semantics(
              identifier: 'btn-receipt-save',
              child: TextButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (showAi)
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  identifier: 'btn-receipt-ai-names',
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _cleanUp,
                    icon: _aiBusy ? _spinner : const Icon(Icons.auto_awesome),
                    label: Text(_aiBusy ? 'Cleaning up…' : 'Clean up names with AI'),
                  ),
                ),
              ),
            if (_rows.isEmpty)
              Semantics(
                identifier: 'receipt-review-empty',
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("Couldn't find any items on this receipt. Add them below."),
                ),
              ),
            for (var i = 0; i < _rows.length; i++) _buildRow(i, _rows[i]),
            Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                identifier: 'btn-receipt-add-row',
                child: TextButton.icon(
                  onPressed: () => setState(() => _rows.add(_blankRow(edited: true))),
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
