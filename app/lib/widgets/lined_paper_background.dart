import 'package:flutter/material.dart';

class LinedPaperBackground extends StatelessWidget {
  final Widget child;

  const LinedPaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LinedPaperPainter(),
      child: child,
    );
  }
}

class _LinedPaperPainter extends CustomPainter {
  static const _lineSpacing = 28.0;
  static const _marginX = 48.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Warm cream base
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F3EC),
    );

    // Ruled lines
    final linePaint = Paint()
      ..color = const Color(0x26769FCD)
      ..strokeWidth = 1.0;

    for (double y = _lineSpacing; y < size.height; y += _lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Left margin
    canvas.drawLine(
      const Offset(_marginX, 0),
      Offset(_marginX, size.height),
      Paint()
        ..color = const Color(0x33D95B5B)
        ..strokeWidth = 1.2,
    );

    // Vignette — top (strongest for status bar contrast)
    canvas.drawRect(
      Offset.zero & Size(size.width, 120),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x55000000), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, 120)),
    );

    // Vignette — bottom
    canvas.drawRect(
      Offset(0, size.height - 80) & Size(size.width, 80),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x33000000), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, size.height - 80, size.width, 80)),
    );

    // Vignette — left & right edges
    for (final isLeft in [true, false]) {
      final rect = isLeft
          ? Offset.zero & Size(40, size.height)
          : Offset(size.width - 40, 0) & Size(40, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [const Color(0x22000000), Colors.transparent],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_LinedPaperPainter old) => false;
}
