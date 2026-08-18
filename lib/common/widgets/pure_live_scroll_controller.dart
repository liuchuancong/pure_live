import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:scroll_animator/scroll_animator.dart';

/// Uses Chromium's Windows scrolling personality for discrete wheel deltas.
/// Touch scrolling keeps Flutter's native position implementation.
ScrollController createPureLiveScrollController({double initialScrollOffset = 0}) {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return AnimatedScrollController(
      animationFactory: const ChromiumImpulse(),
      initialScrollOffset: initialScrollOffset,
    );
  }
  return ScrollController(initialScrollOffset: initialScrollOffset);
}
