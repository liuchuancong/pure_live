/// Renders a `BackgroundLayerStack` by delegating each layer back to
/// [PureBackground] and compositing the results in a `Stack`.
///
/// The per-layer opacity and blend are applied with an [Opacity] /
/// [ColorFiltered] wrapper so pages that need "photo at 60% over a warm
/// gradient" get it without a bespoke shader.
library;

import 'package:flutter/widgets.dart';
import 'package:pure_uikit_background/src/models/background_config/background_config.dart';
import 'package:pure_uikit_background/src/rendering/live_background.dart';

/// Paints the layers of [stack] bottom-to-top.
class BackgroundLayerStackView extends StatelessWidget {
  /// Renders [stack].
  const new({required this.stack, super.key});

  /// The stack to paint.
  final BackgroundLayerStack stack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [for (final layer in stack.layers) Positioned.fill(child: _LayerSlice(layer: layer))],
    );
  }
}

class _LayerSlice extends StatelessWidget {
  const new({required this.layer});

  final BackgroundLayer layer;

  @override
  Widget build(BuildContext context) {
    final base = PureBackground(config: layer.config);
    final withOpacity = layer.opacity >= 1 ? base : Opacity(opacity: layer.opacity.clamp(0, 1), child: base);
    if (layer.blend == BlendMode.srcOver) return withOpacity;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(const Color(0xFFFFFFFF).withValues(alpha: layer.opacity), layer.blend),
      child: withOpacity,
    );
  }
}
