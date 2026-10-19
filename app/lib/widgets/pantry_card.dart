import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pantry_item.dart';
import '../models/receipt_parser.dart';
import '../screens/receipt_review/receipt_review_screen.dart';
import '../services/ai_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/storage_service.dart';
import 'folder_palette.dart';
import 'panel_container.dart';

class PantryCard extends StatefulWidget {
  /// Test seams — inject fakes. Null in production.
  final StorageService? storageOverride;
  final ReceiptReader? readerOverride;
  final AiService? aiOverride;
  final bool? aiEnabledOverride;
  final Future<Uint8List?> Function(BuildContext context)? pickImageOverride;

  const PantryCard({
    super.key,
    this.storageOverride,
    this.readerOverride,
    this.aiOverride,
    this.aiEnabledOverride,
    this.pickImageOverride,
  });

  @override
  State<PantryCard> createState() => _PantryCardState();
}

class _PantryCardState extends State<PantryCard> {
  StorageService? _ownedStorage;
  late final StorageService _storage;
  late final ReceiptReader _reader;
  List<PantryItem> _items = const [];
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    if (widget.storageOverride != null) {
      _storage = widget.storageOverride!;
    } else {
      _ownedStorage = StorageService();
      _storage = _ownedStorage!;
    }
    _reader = widget.readerOverride ?? OnnxReceiptReader();
    _load();
  }

  @override
  void dispose() {
    _ownedStorage?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<PantryItem> items;
    try {
      items = await _storage.getPantryItems();
    } catch (_) {
      items = const []; // no sqlite in widget tests
    }
    if (mounted) setState(() => _items = items);
  }

  Future<void> _delete(int id) async {
    try {
      await _storage.deletePantryItem(id);
    } catch (e) {
      _showError('Could not remove: $e');
    }
    await _load();
  }

  static const _spinner = SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  Future<Uint8List?> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return null;
    // No maxWidth/maxHeight — OCR needs the full-resolution photo.
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
    if (picked == null) return null;
    return picked.readAsBytes();
  }

  Future<void> _scan() async {
    final bytes = await (widget.pickImageOverride ?? _pickImage)(context);
    if (bytes == null || !mounted) return;
    setState(() => _reading = true);
    final String text;
    final List<ParsedReceiptItem> items;
    try {
      final lines = await _reader.readLines(bytes);
      text = lines.join('\n');
      items = mergeReceiptItems(parseReceiptText(text));
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _reading = false);
      return;
    }
    if (!mounted) return;
    setState(() => _reading = false);
    await _openReview(items, text, 'receipt');
  }

  Future<void> _addManual() => _openReview(const [], '', 'manual');

  Future<void> _openReview(List<ParsedReceiptItem> items, String text, String source) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReceiptReviewScreen(
        items: items,
        ocrText: text,
        source: source,
        storageOverride: widget.storageOverride,
        aiOverride: widget.aiOverride,
        aiEnabledOverride: widget.aiEnabledOverride,
      ),
    ));
    if (saved == true) await _load();
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pantry-card',
      child: PanelContainer(
        accentColor: kTabMealPlanning,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Pantry',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Nothing in the pantry yet.'),
              )
            else
              for (final item in _items)
                Semantics(
                  identifier: 'item-pantry-${item.id}',
                  child: ListTile(
                    dense: true,
                    title: Text(item.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatPantryQuantity(item.quantity, item.unit)),
                        Semantics(
                          identifier: 'btn-pantry-delete-${item.id}',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Remove',
                            onPressed: () => _delete(item.id!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Semantics(
                    identifier: 'btn-scan-receipt',
                    child: FilledButton.icon(
                      icon: _reading ? _spinner : const Icon(Icons.receipt_long),
                      label: Text(_reading ? 'Reading…' : 'Scan receipt'),
                      onPressed: _reading ? null : _scan,
                    ),
                  ),
                  Semantics(
                    identifier: 'btn-pantry-add',
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'),
                      onPressed: _addManual,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
