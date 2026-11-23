import 'package:flutter/material.dart';

/// Placeholder creature until the user's own pixel art exists.
///
/// Deliberately a chunky, low-res code-drawn blob (16x16 pixels, hard edges) so
/// it reads as a stand-in, not finished art. All original, no asset files, no IP.
/// Swap for the user's own sprite strips later (see specs/virtual_pet.spec.md).
class PetBlock extends StatelessWidget {
  final double size;
  const PetBlock({super.key, required this.size});

  // 16x16. '.' transparent, O outline, B body, E eye, M mouth, S sprout.
  static const List<String> _grid = [
    '................',
    '.......SS.......',
    '.......SS.......',
    '......OOOO......',
    '....OOBBBBOO....',
    '...OBBBBBBBBO...',
    '..OBBBBBBBBBBO..',
    '..OBBEBBBBEBBO..',
    '..OBBEBBBBEBBO..',
    '..OBBBBBBBBBBO..',
    '..OBBBMMMMBBBO..',
    '...OBBBBBBBBO...',
    '....OBBBBBBO....',
    '.....OOOOOO.....',
    '......O..O......',
    '................',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      isComplex: false,
      painter: _PetPainter(
        grid: _grid,
        body: scheme.primaryContainer,
        outline: scheme.primary,
        eye: scheme.onPrimaryContainer,
        mouth: scheme.primary,
        sprout: scheme.primary,
      ),
    );
  }
}

class _PetPainter extends CustomPainter {
  final List<String> grid;
  final Color body;
  final Color outline;
  final Color eye;
  final Color mouth;
  final Color sprout;

  _PetPainter({
    required this.grid,
    required this.body,
    required this.outline,
    required this.eye,
    required this.mouth,
    required this.sprout,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int rows = grid.length;
    final int cols = grid.first.length;
    final double px = size.width / cols;
    final double py = size.height / rows;
    final paint = Paint()..isAntiAlias = false;
    for (int y = 0; y < rows; y++) {
      final row = grid[y];
      for (int x = 0; x < cols; x++) {
        final Color? c = switch (row[x]) {
          'B' => body,
          'O' => outline,
          'E' => eye,
          'M' => mouth,
          'S' => sprout,
          _ => null,
        };
        if (c == null) continue;
        paint.color = c;
        // +0.5 overscan so neighbouring cells of the same colour don't show seams.
        canvas.drawRect(
          Rect.fromLTWH(x * px, y * py, px + 0.5, py + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PetPainter old) =>
      old.body != body ||
      old.outline != outline ||
      old.eye != eye ||
      old.mouth != mouth ||
      old.sprout != sprout ||
      old.grid != grid;
}
