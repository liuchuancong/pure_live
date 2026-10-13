part of 'background_config.dart';

/// A still-image background sourced from the network, an asset or a
/// caller-supplied [ImageProvider]. Loading and failure are described by
/// data on this class; the rendering layer applies them but does not
/// invent defaults.
@immutable
final class ImageBackground extends BackgroundConfig {
  /// Displays [source] behind the subtree.
  ///
  /// Every "what to paint when..." question is answered by an explicit
  /// field on this config; nothing is decided inside the package:
  ///
  /// * [underlay] — persistent bottom layer (cold-start surface,
  ///   letterbox bars, missing provider). `null` means "no bottom
  ///   layer".
  /// * [fallback] — painted when the image fails to load. `null`
  ///   means "render nothing on failure".
  /// * [placeholderColor] — painted while the image decodes. `null`
  ///   means "leave the underlay visible".
  /// * [letterboxBlurSigma] — when non-null, the same provider is
  ///   drawn under the primary image with `BoxFit.cover` and a
  ///   Gaussian blur of this sigma, filling the bars a letterboxing
  ///   [fit] would leave. `null` disables the effect entirely.
  /// * [blurSigma] — Gaussian blur applied to the primary image.
  ///   `0` (default) short-circuits the filter.
  ///
  /// [underlay] and [fallback] reject another [VideoBackground] so a
  /// failure never cascades into a second decoder.
  const new({
    required this.source,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholderColor,
    this.underlay,
    this.fallback,
    this.letterboxBlurSigma,
    this.blurSigma = 0,
    super.overlay,
  }) : assert(
         fallback is! VideoBackground && underlay is! VideoBackground,
         'ImageBackground underlay/fallback must not be a VideoBackground',
       ),
       assert(blurSigma >= 0, 'blurSigma must be non-negative'),
       assert(
         letterboxBlurSigma == null || letterboxBlurSigma >= 0,
         'letterboxBlurSigma must be non-negative when provided',
       );

  /// Where the image bytes come from.
  final ImageSource source;

  /// How the image is inscribed into the available area.
  final BoxFit fit;

  /// Which part of the image stays visible when it is cropped.
  final AlignmentGeometry alignment;

  /// Color shown while the image decodes. When `null`, the rendering
  /// layer shows nothing until the first frame is ready.
  final Color? placeholderColor;

  /// Config painted as a persistent bottom layer beneath the image.
  /// `null` means the region is transparent while the image is not
  /// painted.
  final BackgroundConfig? underlay;

  /// Config painted when the image fails to load. `null` means the
  /// failure leaves only the [underlay] (or nothing).
  final BackgroundConfig? fallback;

  /// When non-null, the rendering layer draws a blurred, cover-fitted
  /// copy of the same image below the primary layer with this sigma.
  /// Set it explicitly; the package does not decide which `BoxFit`
  /// values "need" a fill.
  final double? letterboxBlurSigma;

  /// Gaussian blur sigma applied to the image surface. `0` (default)
  /// leaves the picture sharp.
  final double blurSigma;
}
