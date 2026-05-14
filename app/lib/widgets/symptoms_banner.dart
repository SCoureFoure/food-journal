import 'package:flutter/material.dart';

class SymptomsBanner extends StatelessWidget {
  final String symptoms;
  final EdgeInsetsGeometry margin;

  const SymptomsBanner({
    super.key,
    required this.symptoms,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
        color: accent.withAlpha(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flag_outlined, size: 14, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'After-meal: $symptoms',
              style: theme.textTheme.bodySmall?.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
