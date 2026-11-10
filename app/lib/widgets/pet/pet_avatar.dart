import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/pet_feed.dart';
import 'pet_block.dart';

class PetAvatar extends StatefulWidget {
  final ValueListenable<PetFeed?> feed;
  final VoidCallback onTap;

  const PetAvatar({super.key, required this.feed, required this.onTap});

  @override
  State<PetAvatar> createState() => _PetAvatarState();
}

class _PetAvatarState extends State<PetAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  PetFeed? _last;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // Snap back to 0 so the resting offset is exactly zero (sin(pi) is not).
    _bounce.addStatusListener((status) {
      if (status == AnimationStatus.completed) _bounce.value = 0;
    });
    _last = widget.feed.value;
    widget.feed.addListener(_onFeed);
  }

  @override
  void didUpdateWidget(PetAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed != widget.feed) {
      oldWidget.feed.removeListener(_onFeed);
      widget.feed.addListener(_onFeed);
      _last = widget.feed.value;
    }
  }

  void _onFeed() {
    final next = widget.feed.value;
    if (next != null &&
        next.fedSince(_last) &&
        !MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
    _last = next;
  }

  @override
  void dispose() {
    widget.feed.removeListener(_onFeed);
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'pet-avatar',
      container: true,
      button: true,
      label: 'Open pet',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) => Transform.translate(
            key: const ValueKey('pet-avatar-bounce'),
            // up and back down once: 0 at rest, -12 at the midpoint
            offset: Offset(0, -12 * math.sin(math.pi * _bounce.value)),
            child: child,
          ),
          child: const PetBlock(size: 48),
        ),
      ),
    );
  }
}
