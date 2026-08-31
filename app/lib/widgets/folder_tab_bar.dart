import 'package:flutter/material.dart';

const Color kFolderTabSelected = Color(0xFFF7F3EC);   // matches LinedPaperBackground base
const Color kFolderTabUnselected = Color(0xFFDCCFB8); // darker manila

class FolderTab {
  final String label;
  final String semanticsId;
  const FolderTab({required this.label, required this.semanticsId});
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
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _buildTabs(),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                color: isSelected ? kFolderTabSelected : kFolderTabUnselected,
                child: Text(
                  tabs[i].label,
                  style: TextStyle(
                    fontSize: isSelected ? 15 : 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF3E3529)
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

  static const double _slant = 9.0;
  static const double _radius = 8.0;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(_slant, _radius)
      ..quadraticBezierTo(_slant, 0, _slant + _radius, 0)
      ..lineTo(size.width - _slant - _radius, 0)
      ..quadraticBezierTo(size.width - _slant, 0, size.width - _slant, _radius)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_FolderTabClipper oldClipper) => false;
}
