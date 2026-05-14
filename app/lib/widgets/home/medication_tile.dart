import 'package:flutter/material.dart';

import '../../models/medication.dart';

class MedicationTile extends StatelessWidget {
  final Medication med;
  final VoidCallback onReload;

  const MedicationTile({super.key, required this.med, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doseStr = [
      if (med.dose != null)
        med.dose! == med.dose!.truncateToDouble()
            ? med.dose!.toInt().toString()
            : med.dose!.toStringAsFixed(1),
      if (med.unit != null) med.unit!,
    ].join(' ');
    final subtitle = [
      med.time,
      if (doseStr.isNotEmpty) doseStr,
      if (med.route != null) med.route!,
    ].join(' · ');

    return Semantics(
      identifier: 'med-tile-${med.id}',
      child: ListTile(
        tileColor: theme.colorScheme.surfaceContainerHighest,
        leading: med.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(med.imageData!, width: 40, height: 40, fit: BoxFit.cover),
              )
            : const Icon(Icons.medication_outlined),
        title: Text(med.name,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-med-${med.id}',
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () async {
              await Navigator.pushNamed(context, '/edit_medication', arguments: med);
              onReload();
            },
          ),
        ),
      ),
    );
  }
}
