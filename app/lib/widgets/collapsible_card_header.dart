import 'package:flutter/material.dart';

/// Title row of a collapsible panel card. Tapping anywhere on the row toggles
/// the card; [summary] shows next to the chevron while collapsed.
class CollapsibleCardHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final String semanticsId;
  final String? summary;

  const CollapsibleCardHeader({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.semanticsId,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsId,
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (!expanded && summary != null)
                Text(summary!, style: Theme.of(context).textTheme.bodySmall),
              Icon(expanded ? Icons.expand_less : Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}
