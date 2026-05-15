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
      child: ExpansionTile(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: med.imageData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(med.imageData!, width: 40, height: 40, fit: BoxFit.cover),
              )
            : const Icon(Icons.medication_outlined),
        title: Semantics(
          identifier: 'med-tile-header-${med.id}',
          child: Text(med.name,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Semantics(
          identifier: 'btn-edit-med-${med.id}',
          child: GestureDetector(
            onTap: () async {
              await Navigator.pushNamed(context, '/edit_medication', arguments: med);
              onReload();
            },
            child: const Icon(Icons.edit_outlined, size: 24),
          ),
        ),
        children: [
          if (med.notes != null && med.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(med.notes!, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}
