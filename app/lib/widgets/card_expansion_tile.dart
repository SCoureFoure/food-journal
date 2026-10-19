import 'package:flutter/material.dart';

/// Collapsible section of a panel card. Built on the same [ExpansionTile] as the
/// journal's week and day sections, so it opens and closes with the same
/// animation. [semanticsId] goes on the title, per the anchor rule for
/// ExpansionTile headers.
class CardExpansionTile extends StatelessWidget {
  final String title;
  final String semanticsId;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget? subtitle;
  final List<Widget> children;

  const CardExpansionTile({
    super.key,
    required this.title,
    required this.semanticsId,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      // The saved choice arrives after the first build; a new key rebuilds the
      // tile in that state instead of animating into it.
      key: ValueKey(initiallyExpanded),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: onExpansionChanged,
      shape: const Border(),
      collapsedShape: const Border(),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Semantics(
        identifier: semanticsId,
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      subtitle: subtitle,
      children: children,
    );
  }
}
