import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

/// Uses the native touch model instead of forcing the iOS spring model on
/// Android and desktop lists.
///
/// iOS/macOS retain the native bouncing behavior, while Android and desktop
/// platforms use a strict clamping boundary.
class PureLiveScrollPhysics extends ScrollPhysics {
  const PureLiveScrollPhysics({super.parent});

  bool get _isBouncingPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;

      case TargetPlatform.android:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  PureLiveScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return PureLiveScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // Keep the native bouncing behavior on iOS/macOS.
    if (_isBouncingPlatform) {
      return super.applyBoundaryConditions(position, value);
    }

    // Prevent scrolling beyond the leading edge on Android and desktop.
    if (value < position.minScrollExtent && position.pixels <= position.minScrollExtent) {
      return value - position.minScrollExtent;
    }

    // Prevent scrolling beyond the trailing edge on Android and desktop.
    if (value > position.maxScrollExtent && position.pixels >= position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }

    // Prevent crossing the leading edge in a single scroll update.
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }

    // Prevent crossing the trailing edge in a single scroll update.
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }

    return 0.0;
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // Let the native bouncing physics handle ballistic scrolling on
    // iOS/macOS.
    if (_isBouncingPlatform) {
      return const BouncingScrollPhysics().createBallisticSimulation(position, velocity);
    }

    // Use clamping behavior on Android and desktop.
    return const ClampingScrollPhysics().createBallisticSimulation(position, velocity);
  }

  @override
  double carriedMomentum(double existingVelocity) {
    if (_isBouncingPlatform) {
      return const BouncingScrollPhysics().carriedMomentum(existingVelocity);
    }

    return const ClampingScrollPhysics().carriedMomentum(existingVelocity);
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

    // Always keep the position inside the new content bounds.
    return adjusted.clamp(newPosition.minScrollExtent, newPosition.maxScrollExtent).toDouble();
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
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }

    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }

    return 0.0;
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
