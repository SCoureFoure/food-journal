import 'package:flutter/material.dart';

class LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T?> items;
  final String Function(T? v) itemLabel;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          items: items
              .map((v) => DropdownMenuItem<T?>(value: v, child: Text(itemLabel(v))))
              .toList(),
        ),
      ),
    );
  }
}
