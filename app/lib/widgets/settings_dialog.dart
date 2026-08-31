import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class SettingsDialog extends StatefulWidget {
  final SettingsService settings;
  const SettingsDialog({super.key, required this.settings});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool? _aiEnabled;
  bool? _leftHanded;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.settings.isAiEnabled,
      widget.settings.isLeftHanded,
    ]).then((values) {
      if (mounted) {
        setState(() {
          _aiEnabled = values[0];
          _leftHanded = values[1];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = _aiEnabled == null || _leftHanded == null;
    return AlertDialog(
      title: const Text('Settings'),
      content: loading
          ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('AI features'),
                  subtitle: const Text('Autofill with AI on log screens'),
                  value: _aiEnabled!,
                  onChanged: (v) async {
                    await widget.settings.setAiEnabled(v);
                    if (mounted) setState(() => _aiEnabled = v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Left-handed mode'),
                  subtitle: const Text('Move + button to left side'),
                  value: _leftHanded!,
                  onChanged: (v) async {
                    await widget.settings.setLeftHanded(v);
                    if (mounted) setState(() => _leftHanded = v);
                  },
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
