import 'package:flutter/material.dart';

import '../../models/food_item.dart';

/// The four intensity stops a selected symptom can take, ordered low→high.
/// Slider position 0..3 maps to this list; persisted as the [ReactionLevel].
const List<ReactionLevel> kSymptomStops = [
  ReactionLevel.none,
  ReactionLevel.mild,
  ReactionLevel.moderate,
  ReactionLevel.bad,
];

const Color _paperColor = Color(0xFFFFFDF5);
const Color _ruleColor = Color(0xFFB9D9EB); // faint blue horizontal rule
const Color _marginColor = Color(0xFFE57373); // red vertical margin line
const Color _inkColor = Color(0xFF3F6FB5); // blue pen — slider track line

/// Per-intensity dot color: none=blue, mild=green, moderate=amber, bad=red.
Color _levelColor(ReactionLevel l) => switch (l) {
      ReactionLevel.none => const Color(0xFF3F6FB5),
      ReactionLevel.mild => const Color(0xFF4CAF50),
      ReactionLevel.moderate => const Color(0xFFE0A800),
      ReactionLevel.bad => const Color(0xFFE53935),
      _ => _inkColor,
    };
const double _rowHeight = 78;
const double _marginX = 28;

/// A ruled-notebook panel: one red-inked slider per selected symptom.
/// [levels] maps symptom name → current intensity; [onChanged] fires with the
/// new [ReactionLevel] for a symptom as its slider moves.
class NotebookSymptomSliders extends StatelessWidget {
  final Map<String, ReactionLevel> levels;
  final void Function(String symptom, ReactionLevel level) onChanged;

  const NotebookSymptomSliders({
    super.key,
    required this.levels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (levels.isEmpty) return const SizedBox.shrink();
    final names = levels.keys.toList();

    return Semantics(
      identifier: 'symptom-intensity-sheet',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _NotebookPaperPainter(rows: names.length),
          child: Column(
            children: [
              for (final name in names)
                SizedBox(
                  height: _rowHeight,
                  child: _SymptomSliderRow(
                    name: name,
                    level: levels[name]!,
                    onChanged: (lvl) => onChanged(name, lvl),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymptomSliderRow extends StatelessWidget {
  final String name;
  final ReactionLevel level;
  final ValueChanged<ReactionLevel> onChanged;

  const _SymptomSliderRow({
    required this.name,
    required this.level,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pos = kSymptomStops.indexOf(level).clamp(0, kSymptomStops.length - 1);
    final dotColor = _levelColor(level);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_marginX + 8, 6, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                level.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: dotColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: _inkColor,
              inactiveTrackColor: _inkColor.withAlpha(60),
              thumbColor: dotColor,
              overlayColor: dotColor.withAlpha(40),
              activeTickMarkColor: _inkColor,
              inactiveTickMarkColor: _inkColor.withAlpha(90),
              valueIndicatorColor: dotColor,
              trackShape: const RectangularSliderTrackShape(),
            ),
            child: Semantics(
              identifier: 'symptom-slider-$name',
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Decorative ghost rule — extends the blue line out toward the
                  // page margins behind the slider. Never the hit target.
                  Positioned(
                    left: -28,
                    right: -16,
                    child: IgnorePointer(
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _inkColor.withAlpha(0),
                              _inkColor.withAlpha(70),
                              _inkColor.withAlpha(70),
                              _inkColor.withAlpha(0),
                            ],
                            stops: const [0.0, 0.10, 0.90, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Slider(
                    value: pos.toDouble(),
                    min: 0,
                    max: (kSymptomStops.length - 1).toDouble(),
                    divisions: kSymptomStops.length - 1,
                    label: level.label,
                    onChanged: (v) => onChanged(kSymptomStops[v.round()]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotebookPaperPainter extends CustomPainter {
  final int rows;
  const _NotebookPaperPainter({required this.rows});

  @override
  void paint(Canvas canvas, Size size) {
    final paper = Paint()..color = _paperColor;
    canvas.drawRect(Offset.zero & size, paper);

    // Ruled lines fade toward both edges so the page reads like paper.
    final rule = Paint()
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x00B9D9EB), // transparent at left edge
          _ruleColor,
          _ruleColor,
          Color(0x00B9D9EB), // transparent at right edge
        ],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    for (var i = 1; i <= rows; i++) {
      final y = i * _rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    final margin = Paint()
      ..color = _marginColor.withAlpha(140)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(_marginX, 0), Offset(_marginX, size.height), margin);
  }

  @override
  bool shouldRepaint(_NotebookPaperPainter old) => old.rows != rows;
}
