import 'package:flutter/material.dart';
import 'package:liquid_progress_indicator_v2/liquid_progress_indicator.dart';

class GoalFillBar extends StatelessWidget {
  static final Color greenFill = Colors.green.shade400.withAlpha(110);
  static final Color greenTrack = Colors.green.withAlpha(22);
  static final Color blueFill = Colors.blue.shade300.withAlpha(110);
  static final Color blueTrack = Colors.blue.withAlpha(22);

  final String metric;
  final String label;
  final int current;
  final int target;
  final String unit;
  final Color? fillColor;
  final Color? trackColor;
  final bool animated;

  const GoalFillBar({
    super.key,
    required this.metric,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    this.fillColor,
    this.trackColor,
    this.animated = true,
  });

  double get progress {
    if (target <= 0) return 0.0;
    return (current / target).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      letterSpacing: 0.6,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600);

    return Semantics(
      identifier: 'goal-row-$metric',
      container: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: animated
                  ? LiquidLinearProgressIndicator(
                      value: progress,
                      valueColor: AlwaysStoppedAnimation(fillColor ?? greenFill),
                      backgroundColor: trackColor ?? greenTrack,
                      borderColor: Colors.transparent,
                      borderWidth: 0,
                      borderRadius: 8,
                      direction: Axis.horizontal,
                    )
                  : ColoredBox(
                      color: trackColor ?? greenTrack,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          heightFactor: 1,
                          child: ColoredBox(color: fillColor ?? greenFill),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
              child: Row(
                children: [
                  Text(label, style: labelStyle),
                  const Spacer(),
                  Text('$current / $target $unit', style: valueStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
