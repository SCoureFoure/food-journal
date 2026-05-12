import 'package:flutter/material.dart';
import '../models/food_item.dart';

class ReactionBadge extends StatelessWidget {
  final ReactionLevel level;

  const ReactionBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (color, textColor) = switch (level) {
      ReactionLevel.none => (const Color(0xFFE8F0EA), const Color(0xFF4A7C59)),
      ReactionLevel.mild => (const Color(0xFFFDF3E0), const Color(0xFFA06020)),
      ReactionLevel.moderate => (const Color(0xFFFDE8D0), const Color(0xFFC06010)),
      ReactionLevel.bad => (const Color(0xFFFCE8E4), const Color(0xFFC4502A)),
      ReactionLevel.pending => (const Color(0xFFEEEBE5), const Color(0xFF7A6E62)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          fontSize: 10,
          color: textColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
