/// Paints a `BackgroundOverlay` scrim on top of an already-rendered base.
///
/// The overlay is applied uniformly regardless of which base variant is
/// underneath, which is what the design goal asks for: one readable
/// foreground across photos, videos and gradients without each style
/// adapter re-implementing a darkening layer.
///
/// With `BackgroundOverlay.blurSigma` positive the scrim becomes a
/// frosted-glass wash built on the `blur` package: the backdrop blur and
/// the colour wash composite in a single layer, so a page keeps text
/// legible at a lower opacity than a flat dim needs. Every parameter is
/// forwarded explicitly — the plugin's own defaults are never inherited.
/// Both paths stay gesture-transparent through `IgnorePointer`, and a
/// non-positive sigma keeps the cheap flat `ColoredBox` path.
library;

import 'package:blur/blur.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_uikit_background/src/models/background_config/background_config.dart';

/// Wraps [child] with a translucent — optionally frosted — scrim derived
/// from [overlay].
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

    final alpha = effective.opacity.clamp(0.0, 1.0);
    final sigma = effective.blurSigma;

    if (sigma <= 0) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: effective.color.withValues(alpha: alpha)),
            ),
          ),
        ],
      );
    }

    return IgnorePointer(
      child: Blur(blur: sigma, blurColor: effective.color, colorOpacity: alpha, child: child),
    );
  }
}
