import 'package:flutter/material.dart';

/// Food Journal — a soft sage drawn from the app's seed green (0xFF42725C),
/// desaturated so it sits on cream paper rather than shouting like an
/// office-supply tab.
const Color kTabFoodJournal = Color(0xFF8FB79C);

/// Meal Planning — the slate blue counterpart, echoing the green/blue pairing
/// on a real folder set.
const Color kTabMealPlanning = Color(0xFF93AFC6);

/// The manila the unselected tabs are mixed toward, so a deselected tab keeps
/// its identity while receding into the folder body.
const Color kFolderTabRecess = Color(0xFFDCCFB8);

/// The fill actually painted for a tab in the given state.
Color folderTabFill(Color base, {required bool selected}) =>
    selected ? base : Color.lerp(base, kFolderTabRecess, 0.55)!;

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
      height: 44,
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
      children.add(
        Semantics(
          identifier: tabs[i].semanticsId,
          button: true,
          selected: isSelected,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            child: ClipPath(
              clipper: const _FolderTabClipper(),
              child: Container(
                height: isSelected ? 44 : 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                color: folderTabFill(tabs[i].color, selected: isSelected),
                child: Text(
                  tabs[i].label,
                  style: TextStyle(
                    fontSize: isSelected ? 15 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF2E2A22)
                        : const Color(0xFF6F6455),
                  ),
                ),
              ),
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
