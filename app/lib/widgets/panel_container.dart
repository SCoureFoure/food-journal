import 'package:flutter/material.dart';

/// Shared chrome for every top-level collapsible section in the app — the
/// journal's week/date panels and the planning tab's cards.
///
/// Keeping one widget here is what makes the two tabs line up: same horizontal
/// margin (so the same width), same corner radius, same layered lift shadow,
/// and the same optional coloured left edge. Screens supply only the parts that
/// legitimately differ (accent colour, surface tone, vertical margin).
class PanelContainer extends StatelessWidget {
  /// Horizontal inset shared by every panel. Screens that host panels should
  /// leave their scroll view's horizontal padding at zero and let this govern
  /// the width, otherwise the insets stack and the panel narrows.
  static const double horizontalMargin = 12;

  /// Margin for a panel that starts a group (a week, a planning card).
  static const EdgeInsets sectionMargin =
      EdgeInsets.fromLTRB(horizontalMargin, 12, horizontalMargin, 4);

  /// Margin for a panel nested inside another (a day inside a week).
  static const EdgeInsets nestedMargin =
      EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 4);

  /// Three stacked shadows read as one soft lift off the lined-paper
  /// background; a single shadow looks flat against the texture.
  static final List<BoxShadow> shadows = [
    BoxShadow(color: Colors.black.withAlpha(18), offset: const Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Colors.black.withAlpha(38), offset: const Offset(0, 5), blurRadius: 10),
    BoxShadow(color: Colors.black.withAlpha(60), offset: const Offset(0, 12), blurRadius: 20),
  ];

  final Widget child;

  /// Colour of the 3px left edge. Null draws no edge (nested panels).
  final Color? accentColor;

  /// Defaults to `surfaceContainerHigh` at 95% so the paper texture shows.
  final Color? backgroundColor;

  final EdgeInsets margin;

  const PanelContainer({
    super.key,
    required this.child,
    this.accentColor,
    this.backgroundColor,
    this.margin = sectionMargin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ??
            theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: accentColor == null
            ? null
            : Border(left: BorderSide(color: accentColor!, width: 3)),
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}
