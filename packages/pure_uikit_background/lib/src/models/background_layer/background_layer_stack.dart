part of '../background_config/background_config.dart';

/// A bottom-to-top stack of [BackgroundLayer]s rendered as a single
/// background. The rendering pipeline treats the stack as one visual unit
/// so pages can compose "photo + scrim + subtle tint" without each style
/// adapter re-implementing the layering.
///
/// The "at least one layer" invariant is enforced at render time because
/// `List.length` is not const-evaluable and pages are expected to declare
/// stacks as `const` values.
@immutable
final class BackgroundLayerStack extends BackgroundConfig {
  /// Paints [layers] in order; the first entry is the bottom-most.
  const new({required this.layers, super.overlay});

  /// The stack, bottom first.
  final List<BackgroundLayer> layers;
}
