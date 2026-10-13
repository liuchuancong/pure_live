/// Paints a `BackgroundOverlay` scrim on top of an already-rendered base.
///
/// The overlay is applied uniformly regardless of which base variant is
/// underneath, which is what the design goal asks for: one readable
/// foreground across photos, videos and gradients without each style
/// adapter re-implementing a darkening layer.
library;

import 'package:flutter/widgets.dart';
import 'package:live_uikit_background/src/models/background_config/background_config.dart';

/// Wraps [child] with a translucent scrim derived from [overlay].
class BackgroundOverlayView extends StatelessWidget {
  /// Applies [overlay] over [child]. Passing `null` [overlay] is a no-op.
  const new({required this.overlay, required this.child, super.key});

  /// The scrim to paint; when `null` the child is returned unchanged.
  final BackgroundOverlay? overlay;

  /// The subtree the scrim is painted over.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effective = overlay;
    if (effective == null || effective.opacity <= 0) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: effective.color.withValues(alpha: effective.opacity.clamp(0, 1))),
          ),
        ),
      ],
    );
  }
}
