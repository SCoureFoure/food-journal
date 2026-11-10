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
  bool? _goalBarsAnimated;
  bool? _petEnabled;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.settings.isAiEnabled,
      widget.settings.isLeftHanded,
      widget.settings.isGoalBarsAnimated,
      widget.settings.isPetEnabled,
    ]).then((values) {
      if (mounted) {
        setState(() {
          _aiEnabled = values[0];
          _leftHanded = values[1];
          _goalBarsAnimated = values[2];
          _petEnabled = values[3];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = _aiEnabled == null ||
        _leftHanded == null ||
        _goalBarsAnimated == null ||
        _petEnabled == null;
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
                Semantics(
                  identifier: 'switch-goal-bars-animated',
                  container: true,
                  child: SwitchListTile(
                    title: const Text('Moving goal bars'),
                    subtitle: const Text('Wavy fill in the Goals panel'),
                    value: _goalBarsAnimated!,
                    onChanged: (v) async {
                      await widget.settings.setGoalBarsAnimated(v);
                      if (mounted) setState(() => _goalBarsAnimated = v);
                    },
                  ),
                ),
                Semantics(
                  identifier: 'switch-pet-enabled',
                  container: true,
                  child: SwitchListTile(
                    title: const Text('Show pet'),
                    subtitle: const Text('Companion in the bottom corner'),
                    value: _petEnabled!,
                    onChanged: (v) async {
                      await widget.settings.setPetEnabled(v);
                      if (mounted) setState(() => _petEnabled = v);
                    },
                  ),
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
