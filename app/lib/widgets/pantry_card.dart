import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/pantry_item.dart';
import '../models/receipt_parser.dart';
import '../screens/receipt_review/receipt_review_screen.dart';
import '../services/ai_service.dart';
import '../services/receipt_queue.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import 'collapsible_card_header.dart';
import 'folder_palette.dart';
import 'panel_container.dart';

class PantryCard extends StatefulWidget {
  /// Test seams — inject fakes. Null in production.
  final StorageService? storageOverride;
  final ReceiptQueue? queueOverride;
  final AiService? aiOverride;
  final bool? aiEnabledOverride;
  final Future<List<Uint8List>> Function(BuildContext context)? pickImagesOverride;

  const PantryCard({
    super.key,
    this.storageOverride,
    this.queueOverride,
    this.aiOverride,
    this.aiEnabledOverride,
    this.pickImagesOverride,
  });

  @override
  State<PantryCard> createState() => _PantryCardState();
}

class _PantryCardState extends State<PantryCard> {
  StorageService? _ownedStorage;
  late final StorageService _storage;
  late final ReceiptQueue _queue = widget.queueOverride ?? ReceiptQueue.shared;
  final _settings = SettingsService();
  List<PantryItem> _items = const [];
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    if (widget.storageOverride != null) {
      _storage = widget.storageOverride!;
    } else {
      _ownedStorage = StorageService();
      _storage = _ownedStorage!;
    }
    _queue.addListener(_onQueue);
    _queue.start().catchError((_) {}); // no cache dir in widget tests
    _load();
    _loadCollapsed();
  }

  Future<void> _loadCollapsed() async {
    try {
      final collapsed = await _settings.isCardCollapsed('pantry');
      if (mounted) setState(() => _collapsed = collapsed);
    } catch (_) {
      // Settings unreadable (no plugin in a widget test) — stay expanded.
    }
  }

  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    _settings.setCardCollapsed('pantry', _collapsed).catchError((_) {});
  }

  @override
  void dispose() {
    _queue.removeListener(_onQueue);
    _ownedStorage?.dispose();
    super.dispose();
  }

  void _onQueue() {
    if (mounted) setState(() {});
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

  Future<List<Uint8List>> _pickImages(BuildContext context) async {
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
    if (source == null) return const [];
    // No maxWidth/maxHeight — OCR needs the full-resolution photo.
    final List<XFile> files;
    if (source == ImageSource.camera) {
      final one = await ImagePicker().pickImage(source: source, imageQuality: 95);
      files = one == null ? const [] : [one];
    } else {
      files = await ImagePicker().pickMultiImage(imageQuality: 95);
    }
    final out = <Uint8List>[];
    for (final x in files) {
      out.add(await x.readAsBytes());
      try {
        await File(x.path).delete(); // the picker's own copy
      } catch (_) {}
    }
    return out;
  }

  Future<void> _scan() async {
    final photos = await (widget.pickImagesOverride ?? _pickImages)(context);
    if (!mounted) return;
    for (final p in photos) {
      try {
        await _queue.add(p);
      } catch (e) {
        _showError('Could not queue the receipt: $e');
        return;
      }
    }
  }

  Future<void> _reviewNext() async {
    final r = _queue.ready.first;
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReceiptReviewScreen(
        items: r.items,
        ocrText: r.ocrText,
        source: 'receipt',
        showDiscard: true,
        storageOverride: widget.storageOverride,
        aiOverride: widget.aiOverride,
        aiEnabledOverride: widget.aiEnabledOverride,
      ),
    ));
    if (result == true) {
      await _queue.remove(r.id);
      await _load();
    } else if (result == false) {
      await _queue.remove(r.id);
    }
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
            CollapsibleCardHeader(
              title: 'Pantry',
              semanticsId: 'btn-pantry-toggle',
              expanded: !_collapsed,
              onToggle: _toggleCollapsed,
              summary: _items.length == 1 ? '1 item' : '${_items.length} items',
            ),
            if (_collapsed)
              const SizedBox.shrink()
            else if (_items.isEmpty)
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
            if (_queue.readingCount > 0 || _queue.ready.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Semantics(
                  identifier: 'receipt-queue-status',
                  child: Text([
                    if (_queue.readingCount > 0) '${_queue.readingCount} reading…',
                    if (_queue.ready.isNotEmpty) '${_queue.ready.length} ready to review',
                  ].join(' · ')),
                ),
              ),
            if (_queue.failedCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Semantics(
                  identifier: 'receipt-queue-failed',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_queue.failedCount == 1
                            ? "1 receipt couldn't be read"
                            : "${_queue.failedCount} receipts couldn't be read"),
                      ),
                      Semantics(
                        identifier: 'btn-receipt-failed-dismiss',
                        child: TextButton(
                          onPressed: _queue.dismissFailed,
                          child: const Text('Dismiss'),
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
                      icon: const Icon(Icons.receipt_long),
                      label: const Text('Scan receipt'),
                      onPressed: _scan,
                    ),
                  ),
                  if (_queue.ready.isNotEmpty)
                    Semantics(
                      identifier: 'btn-receipt-review-next',
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Review'),
                        onPressed: _reviewNext,
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
