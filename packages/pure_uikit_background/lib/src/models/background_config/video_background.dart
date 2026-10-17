part of 'background_config.dart';

/// A looping, muted video background. Decoding is reached through the
/// [BackgroundVideoSource] contract so this package does not bind a
/// specific player kernel; the app composition root wires media_core
/// there.
@immutable
final class VideoBackground extends BackgroundConfig {
  /// Renders [source] as a background video.
  ///
  /// Everything the previous draft baked in as a default is now an
  /// explicit field the caller fills in:
  ///
  /// * [underlay] — persistent bottom layer painted while the player
  ///   spins up or when there is no decoded frame yet. `null` means
  ///   the region is transparent until the first frame.
  /// * [fallback] — painted when the source cannot build a view.
  ///   `null` means the failure leaves only the [underlay] (or
  ///   nothing).
  /// * [blurSigma] — Gaussian blur applied to the decoded surface.
  ///
  /// The old `backgroundColor` field (defaulted to opaque black) is
  /// gone: use `underlay: SolidBackground(color: ...)` if you want a
  /// specific pre-frame colour.
  ///
  /// [loop] and [muted] default to `true` because the class name
  /// already promises a *background* video; overriding them is a
  /// caller decision (e.g. short-lived decorative plays) and both are
  /// accepted via the constructor.
  const new({
    required this.source,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.loop = true,
    this.muted = true,
    this.underlay,
    this.fallback,
    this.blurSigma = 0,
    super.overlay,
  }) : assert(
         fallback is! VideoBackground && underlay is! VideoBackground,
         'VideoBackground underlay/fallback must not be another VideoBackground',
       ),
       assert(blurSigma >= 0, 'blurSigma must be non-negative');

  /// The media contract the rendering layer drives.
  final BackgroundVideoSource source;

  /// How the video frame is inscribed into the available area. Passed
  /// to the source so a real decoder can honour it with knowledge of
  /// the frame's intrinsic size.
  final BoxFit fit;

  /// Which part of the frame stays visible when it is cropped. Passed
  /// to the source alongside [fit].
  final AlignmentGeometry alignment;

  /// Whether the video loops. Looping is the default because
  /// backgrounds are meant to run indefinitely.
  final bool loop;

  /// Whether the video is muted. Backgrounds must never produce audio;
  /// muting is the default and disabling it is opt-in.
  final bool muted;

  /// Config painted as a persistent bottom layer beneath the video,
  /// visible during the player's cold-start window or when the app
  /// has not wired a source for the current platform. `null` means
  /// no bottom layer.
  final BackgroundConfig? underlay;

  /// Config painted when the source cannot build a view. `null` means
  /// the failure leaves only the [underlay] (or nothing).
  final BackgroundConfig? fallback;

  /// Gaussian blur sigma applied to the video surface. `0` (default)
  /// leaves the frame sharp.
  final double blurSigma;
}
