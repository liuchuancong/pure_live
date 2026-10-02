import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:scroll_animator/scroll_animator.dart';

/// Uses Chromium's continuous ease-in/out curve for discrete wheel deltas.
///
/// The impulse curve restarts a short velocity burst for every wheel notch;
/// under load those bursts are perceived as separate steps. The retargetable
/// ease-in/out curve merges successive notches into one continuous trajectory.
/// Touch scrolling keeps Flutter's native position implementation.
ScrollController createPureLiveScrollController({double initialScrollOffset = 0}) {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    return AnimatedScrollController(
      animationFactory: const ChromiumEaseInOut(),
      initialScrollOffset: initialScrollOffset,
    );
  }
  return ScrollController(initialScrollOffset: initialScrollOffset);
}

/// Gives a single desktop route its own animated primary scroll controller.
///
/// A controller at the application root may become attached to multiple
/// offstage routes or tab views. Keeping the scope at route level lets
/// controller-less secondary pages inherit smooth Windows wheel handling while
/// pages that already own an explicit controller remain untouched.
class PureLiveRouteScrollScope extends StatelessWidget {
  const PureLiveRouteScrollScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.windows) return child;
    return AnimatedPrimaryScrollController(
      automaticallyInheritForPlatforms: const {TargetPlatform.windows},
      animationFactory: const ChromiumEaseInOut(),
      child: child,
    );
  }
}
