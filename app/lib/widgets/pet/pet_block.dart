import 'package:flutter/material.dart';

/// Placeholder creature until the user's own pixel art exists.
class PetBlock extends StatelessWidget {
  final double size;
  const PetBlock({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
    );
  }
}
