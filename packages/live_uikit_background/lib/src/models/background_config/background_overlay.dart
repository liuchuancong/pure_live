part of 'background_config.dart';

/// A scrim painted over the base fill to preserve foreground legibility.
///
/// Attached to every [BackgroundConfig] variant so a page can dim a photo
/// or a video without wrapping it in an ad-hoc `Container(color: ...)`.
@immutable
final class BackgroundOverlay {
  /// Applies [color] at [opacity] over the base background.
  const new({required this.color, this.opacity = 0.4});

  /// The scrim color; its alpha channel is ignored, only [opacity] is used.
  final Color color;

  /// Opacity in `[0, 1]`. `0` is a no-op, `1` fully hides the base.
  final double opacity;
}
