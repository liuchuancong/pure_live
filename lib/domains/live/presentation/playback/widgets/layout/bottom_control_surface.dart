import 'package:flutter/material.dart';

/// Presentation shell shared by the one-row and portrait two-row controls.
class BottomControlSurface extends StatelessWidget {
  const BottomControlSurface({super.key, required this.visible, required this.height, required this.child});

  final bool visible;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A mode change replaces a one-row child with a two-row child immediately.
    // Interpolating its height would constrain the new child to the old 56 dp
    // for the first frames. Animate only visibility, never layout constraints.
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: height,
      child: IgnorePointer(
        ignoring: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          // A paint-only slide does not mark the enclosing Stack as having
          // layout overflow. Clip here so hidden controls cannot paint over
          // the resolution row / danmaku panel below the video viewport.
          child: ClipRect(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 300),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
