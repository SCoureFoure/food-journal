import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CheckinDelayField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const CheckinDelayField({super.key, required this.controller, required this.enabled});

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
