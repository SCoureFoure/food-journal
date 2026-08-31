import 'package:flutter/material.dart';

import 'folder_palette.dart';

export 'folder_palette.dart';

/// Tab geometry. The raised height is the bar's own height, so a selected tab
/// fills it and a recessed one sits lower with the folder edge over its base.
const double kTabRaisedHeight = 44;
const double kTabRecessedHeight = 36;

/// Where a tab's base line falls inside a [kToolbarHeight] toolbar. The AppBar
/// centres its title slot vertically, so the base is NOT the toolbar's bottom
/// edge — anything that has to meet the tabs (the folder body, its leading
/// edge) must measure from here or it lands several pixels low.
const double kTabBaseInToolbar = (kToolbarHeight + kTabRaisedHeight) / 2;

/// How long a tab takes to rise out of / drop back into the folder.
const Duration kTabPopDuration = Duration(milliseconds: 220);

class FolderTab {
  final String label;
  final String semanticsId;
  final Color color;
  const FolderTab({
    required this.label,
    required this.semanticsId,
    required this.color,
  });
}

class FolderTabBar extends StatelessWidget {
  final List<FolderTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const FolderTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // The bar shares the app bar's title slot with the action icons, so its
    // intrinsic width can exceed what it is given (it overflowed by 9px on a
    // 1080px device with three actions). Scrolling horizontally is the safety
    // valve: no overflow stripe, and a third tab later degrades gracefully
    // instead of clipping.
    return SizedBox(
      height: kTabRaisedHeight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _buildTabs(),
        ),
      ),
    );
  }

  List<Widget> _buildTabs() {
    final children = <Widget>[];
    for (int i = 0; i < tabs.length; i++) {
      if (i > 0) {
        children.add(const SizedBox(width: 3));
      }
      final isSelected = i == selectedIndex;
      final tab = tabs[i];
      children.add(
        Semantics(
          identifier: tab.semanticsId,
          button: true,
          selected: isSelected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            // The row is bottom-aligned and the folder's leading edge is drawn
            // over the tab bases, so growing the height lifts the tab up out of
            // the folder and shrinking it drops it back in — the pop.
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: isSelected ? 1.0 : 0.0),
              duration: kTabPopDuration,
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                final fill = folderTabFillAt(tab.color, t);
                return ClipPath(
                  clipper: const _FolderTabClipper(),
                  child: Container(
                    height: kTabRecessedHeight +
                        (kTabRaisedHeight - kTabRecessedHeight) * t,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    color: fill,
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 14 + t,
                        // Weight cannot be interpolated; flip it at the
                        // half-way point where the size change is least
                        // noticeable.
                        fontWeight:
                            t >= 0.5 ? FontWeight.w600 : FontWeight.w500,
                        color: folderTabInk(fill, selected: t >= 0.5),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }
    return children;
  }
}

class _FolderTabClipper extends CustomClipper<Path> {
  const _FolderTabClipper();

  static const double _slant = 12.0;
  static const double _radius = 14.0;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, h)
      // soft shoulder flaring up out of the folder body
      ..cubicTo(_slant * 0.55, h - 2, _slant * 0.35, _radius + 2, _slant, _radius)
      ..quadraticBezierTo(_slant, 0, _slant + _radius, 0)
      ..lineTo(w - _slant - _radius, 0)
      ..quadraticBezierTo(w - _slant, 0, w - _slant, _radius)
      ..cubicTo(w - _slant * 0.35, _radius + 2, w - _slant * 0.55, h - 2, w, h)
      ..close();
  }

  @override
  bool shouldReclip(_FolderTabClipper oldClipper) => false;
}
