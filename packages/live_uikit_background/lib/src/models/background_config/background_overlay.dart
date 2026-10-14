part of 'background_config.dart';

/// A scrim painted over the base fill to preserve foreground legibility.
///
/// Attached to every [BackgroundConfig] variant so a page can dim a photo
/// or a video without wrapping it in an ad-hoc `Container(color: ...)`.
@immutable
final class BackgroundOverlay {
  /// Applies [color] at [opacity] over the base background.
  ///
  /// A positive [blurSigma] turns the flat wash into a frosted-glass
  /// scrim that also blurs the painted backdrop behind it, preserving
  /// legibility at opacities a flat dim could not. `0` keeps the flat
  /// wash and skips the offscreen blur pass entirely.
  const new({required this.color, this.opacity = 0.4, this.blurSigma = 0})
    : assert(blurSigma >= 0, 'blurSigma must not be negative');

  /// The scrim color; its alpha channel is ignored, only [opacity] is used.
  final Color color;

  /// Opacity in `[0, 1]`. `0` is a no-op, `1` fully hides the base.
  final double opacity;

  /// Gaussian sigma of the frosted-glass blur applied to the backdrop
  /// behind this scrim. Must not be negative; `0` disables the blur.
  final double blurSigma;
}
