import 'package:flutter/foundation.dart';

/// The window-size classes the layouts switch on.
///
/// Four classes instead of a bare pixel width: a page asks which class it
/// is in, and the class is computed from a configurable [LiveBreakpoints]
/// set, so phones, desktop windows and TVs all answer the same vocabulary.
enum LiveWindowSizeClass {
  /// Phones in portrait; small windows.
  compact,

  /// Phones in landscape, tablets, narrow desktop windows.
  medium,

  /// Desktop and tablet windows.
  expanded,

  /// Wide desktop windows and TVs.
  large;

  /// Whether the class has room for a persistent side rail.
  bool get hasRoomForRail => this == LiveWindowSizeClass.expanded || this == LiveWindowSizeClass.large;
}

/// The width thresholds between [LiveWindowSizeClass] values, and between
/// the mobile and desktop layout modes.
///
/// Everything is configurable and nothing is a magic number in a page:
/// pass a custom set to [LiveBreakpoints.withScale] when a design language
/// or a TV build wants larger steps.
@immutable
final class LiveBreakpoints {
  /// The default thresholds, in logical pixels.
  const new({this.compact = 600, this.medium = 840, this.expanded = 1240, this.desktop = 900, this.tablet = 720});

  /// Below this width the window is [LiveWindowSizeClass.compact].
  final double compact;

  /// Below this width (and at or above [compact]) it is [LiveWindowSizeClass.medium].
  final double medium;

  /// Below this width (and at or above [medium]) it is [LiveWindowSizeClass.expanded].
  final double expanded;

  /// The width at which a desktop window switches to the desktop layout.
  final double desktop;

  /// The width at which a mobile device switches to the desktop layout.
  final double tablet;

  /// Every threshold scaled by [factor], for TV builds and large-picture
  /// densities.
  LiveBreakpoints withScale(double factor) => LiveBreakpoints(
    compact: compact * factor,
    medium: medium * factor,
    expanded: expanded * factor,
    desktop: desktop * factor,
    tablet: tablet * factor,
  );

  /// The size class of a window [width].
  LiveWindowSizeClass sizeClassOf(double width) {
    if (width < compact) {
      return LiveWindowSizeClass.compact;
    }
    if (width < medium) {
      return LiveWindowSizeClass.medium;
    }
    if (width < expanded) {
      return LiveWindowSizeClass.expanded;
    }
    return LiveWindowSizeClass.large;
  }
}
