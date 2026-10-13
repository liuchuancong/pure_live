part of '../background_config/background_config.dart';

/// One painted slice of a [BackgroundLayerStack].
///
/// Pairs a [BackgroundConfig] with an effective [opacity] and a [blend]
/// mode. Lives in the same library as [BackgroundConfig] because
/// [BackgroundLayerStack] is a sealed subtype and Dart requires every
/// sealed subtype to be declared inside the supertype's library.
@immutable
final class BackgroundLayer {
  /// Wraps [config] with an effective [opacity] and [blend].
  const new({required this.config, this.opacity = 1, this.blend = BlendMode.srcOver})
    : assert(opacity >= 0 && opacity <= 1, 'opacity must be in [0, 1]');

  /// The described content of this layer.
  final BackgroundConfig config;

  /// Multiplied onto every pixel produced for this layer.
  final double opacity;

  /// How this layer is blended onto the layers below it.
  final BlendMode blend;
}
