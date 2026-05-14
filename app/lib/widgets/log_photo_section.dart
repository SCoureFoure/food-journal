import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LogPhotoSection extends StatelessWidget {
  final Uint8List? imageBytes;
  final bool enabled;
  final ValueChanged<Uint8List> onImagePicked;
  final VoidCallback? onClear;

  const LogPhotoSection({
    super.key,
    required this.imageBytes,
    required this.onImagePicked,
    this.enabled = true,
    this.onClear,
  });

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    onImagePicked(bytes);
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pick(context, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(context, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: enabled ? () => _showSourceSheet(context) : null,
          icon: const Icon(Icons.add_a_photo, size: 16),
          label: Text(imageBytes == null ? 'Add Photo' : 'Change Photo'),
        ),
        if (imageBytes != null) ...[
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(imageBytes!, height: 48, width: 48, fit: BoxFit.cover),
          ),
          if (onClear != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onClear,
              tooltip: 'Remove photo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ],
    );
  }
}
