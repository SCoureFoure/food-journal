import 'package:flutter/material.dart';

import '../models/food_entity.dart';

/// Inline "you've logged this before — reuse it?" chip (Layer B reuse nudge).
/// One tap adopts the matched history item; the × dismisses. Pure presentation —
/// the host owns the match lookup and the adopt/dismiss actions.
/// See specs/food_entity_resolution.spec.md.
class ReuseSuggestionChip extends StatelessWidget {
  /// Semantics anchor — `food-reuse-suggestion-<i>` (meal) / `med-reuse-suggestion`.
  final String semanticsId;
  final NameMatch match;
  final VoidCallback onAdopt;
  final VoidCallback onDismiss;

  const ReuseSuggestionChip({
    super.key,
    required this.semanticsId,
    required this.match,
    required this.onAdopt,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: semanticsId,
      button: true,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onAdopt,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history,
                        size: 15, color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Reuse "${match.candidate}"',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Opaque so the dismiss tap never bubbles to onAdopt.
                    Semantics(
                      identifier: '$semanticsId-dismiss',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDismiss,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
