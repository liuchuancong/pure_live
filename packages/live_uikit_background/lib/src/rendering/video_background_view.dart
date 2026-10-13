/// Paints a `VideoBackground` by driving the [BackgroundVideoSource]
/// contract. The view has no policy of its own: every runtime signal
/// (pause, fallback, underlay, blur sigma) is passed in from above.
///
/// The source widget owns its BoxFit/alignment strategy because a real
/// decoder knows its intrinsic frame size and this package does not;
/// `ImageBackground.fit` and `ImageBackground.alignment` are handed to
/// the source through [BackgroundVideoSource.buildView].
library;

import 'package:flutter/widgets.dart';
import 'package:live_uikit_background/src/contracts/background_video_source.dart';
import 'package:live_uikit_background/src/models/background_config/background_config.dart';
import 'package:live_uikit_background/src/rendering/background_blur.dart';
import 'package:live_uikit_background/src/rendering/live_background.dart';

/// Renders the looping video described by [config].
class VideoBackgroundView extends StatelessWidget {
  /// Renders [config]. [paused] is supplied by the caller; the view
  /// does not read lifecycle state on its own.
  const new({required this.config, this.paused = false, super.key});

  /// The video description to paint.
  final VideoBackground config;

  /// Whether the source should pause its decode without tearing it
  /// down. Caller-owned signal — the package ships `AppVisibilityObserver`
  /// as an optional helper for wiring `WidgetsBindingObserver` into a
  /// rebuild, but this view does not depend on it.
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final media = _resolveSource();
    final blurred = blurBackground(sigma: config.blurSigma, child: media);
    final under = config.underlay;
    if (under == null) return blurred;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        LiveBackground(config: under),
        blurred,
      ],
    );
  }

  Widget _resolveSource() {
    try {
      return config.source.buildView(
        paused: paused,
        looping: config.loop,
        muted: config.muted,
        fit: config.fit,
        alignment: config.alignment,
      );
    } on Object {
      // A source that cannot build a view (unimplemented platform,
      // missing codec, adapter error) is turned into the caller's
      // `fallback` if one was provided; otherwise the layer collapses
      // to nothing so the underlay (or the app's own background)
      // shows through. The exception itself is surfaced through the
      // app's normal error reporting.
      final fallback = config.fallback;
      if (fallback == null) return const SizedBox.shrink();
      return LiveBackground(config: fallback);
    }
  }
}
