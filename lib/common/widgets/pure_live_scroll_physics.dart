import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Uses the native touch model instead of forcing the iOS spring model on
/// Android and desktop lists.
class PureLiveScrollPhysics extends ScrollPhysics {
  const PureLiveScrollPhysics({super.parent});

  @override
  PureLiveScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PureLiveScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  ScrollPhysics buildParent(ScrollPhysics? ancestor) {
    final parent = super.buildParent(ancestor);

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return BouncingScrollPhysics(parent: parent);

      case TargetPlatform.android:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return ClampingScrollPhysics(parent: parent);
    }
  }
}

/// A platform-independent hard boundary for navigation strips and paged views.
///
/// Content lists keep [PureLiveScrollPhysics] so iOS/macOS retain their native
/// spring. Navigation, filters and other finite selectors must never expose an
/// offset before their first item or after their last item, even when their
/// contents shrink while the route stays mounted.
class PureLiveBoundedScrollPhysics extends ClampingScrollPhysics {
  const PureLiveBoundedScrollPhysics({super.parent});

  @override
  PureLiveBoundedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PureLiveBoundedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );

    return adjusted.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent).toDouble();
  }
}

/// Short enough to feel immediate on high-refresh displays while leaving the
/// tab indicator and page transition enough frames to remain visually linear.
const Duration pureLiveTabTransitionDuration = Duration(milliseconds: 220);
