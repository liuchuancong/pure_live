import 'dart:math' as math;
import 'dart:ui';

import 'package:live_playback/src/presentation/window_geometry.dart';
import 'package:media_core/geometry/video_geometry.dart';

/// Where a small window's margin and chrome sit inside its surface.
final class WindowClearance {
  /// Creates a clearance.
  const new({this.edge = 16, this.top = 0, this.bottom = 0});

  /// The margin kept on the left, right and unspecified edges.
  final double edge;

  /// Space to keep clear at the top (a status bar, a title bar).
  final double top;

  /// Space to keep clear at the bottom (a navigation bar, a tab bar).
  final double bottom;

  /// No clearance at all — a fullscreen surface.
  static const WindowClearance none = WindowClearance(edge: 0);

  /// The margin on the top edge.
  double get topMargin => math.max(edge, top);

  /// The margin on the bottom edge.
  double get bottomMargin => math.max(edge, bottom);
}

/// Geometry for the small windows: what size one opens at, and where a
/// viewer's rect is allowed to live.
///
/// Pure math over the video's shape, the surface and the viewer's remembered
/// layout — no state, no platform calls, so every rule is testable and the
/// widget layer can ask without owning policy.
final class WindowSizingEngine {
  /// Creates a sizing engine.
  const new();

  /// The size a window opens at when nothing has been remembered.
  ///
  /// A landscape video keeps its 16:9-ish shape with the *width* as the long
  /// side; a portrait video gets a tall window whose long side is the height,
  /// which is what makes a vertical live room readable in a corner. The
  /// policy's scale decides how much of the screen's short side the long side
  /// takes.
  Size naturalSize({
    required Size screen,
    required VideoGeometry geometry,
    WindowSizePolicy policy = WindowSizePolicy.primary,
  }) {
    final videoSize = geometry.videoSize;
    final aspectRatio = _safeAspectRatio(videoSize.width.toDouble(), videoSize.height.toDouble());
    final shortSide = math.min(screen.width, screen.height);
    final base = shortSide * policy.scale;

    if (aspectRatio >= 1) {
      return Size(base, base / aspectRatio);
    }

    final height = base * 1.2;
    final width = height * aspectRatio;
    if (width < policy.minPortraitWidth) {
      return Size(policy.minPortraitWidth, policy.minPortraitWidth / aspectRatio);
    }
    return Size(width, height);
  }

  /// The rect a window opens at: the natural size parked in the bottom-right
  /// corner, inside the surface's clearance.
  Rect defaultRect({
    required Size area,
    required Size window,
    WindowSizePolicy policy = WindowSizePolicy.primary,
    WindowClearance clearance = const WindowClearance(),
  }) {
    final left = area.width - window.width - clearance.edge;
    final top = area.height - window.height - clearance.bottomMargin;
    return clampRect(
      rect: Rect.fromLTWH(left, top, window.width, window.height),
      area: area,
      aspectRatio: _safeAspectRatio(window.width, window.height),
      policy: policy,
      clearance: clearance,
    );
  }

  /// Fits [rect] into [area], keeping the video's shape and the policy's
  /// minimums.
  ///
  /// The rect may come from a different screen: remembered coordinates
  /// describe the surface they were captured on, which a rotation or a resized
  /// desktop window has since changed. Clamping here means a remembered rect
  /// is never off-screen and never a sliver.
  Rect clampRect({
    required Rect rect,
    required Size area,
    required double aspectRatio,
    WindowSizePolicy policy = WindowSizePolicy.primary,
    WindowClearance clearance = const WindowClearance(),
  }) {
    final ratio = _safeAspectRatio(aspectRatio, 1);
    final isPortrait = ratio < 1;

    final availableWidth = math.max(1, area.width - clearance.edge * 2);
    final availableHeight = math.max(1, area.height - clearance.topMargin - clearance.bottomMargin);
    final absoluteCap = math.min(area.width, area.height) * policy.maxShortSideFraction;
    final fittingCap = isPortrait
        ? math.min(availableHeight, availableWidth / ratio)
        : math.min(availableWidth, availableHeight * ratio);
    final upper = math.max(1, math.min(absoluteCap, fittingCap));

    final wantedLongSide = isPortrait ? rect.height : rect.width;
    final lower = math.min(policy.minLongSide, wantedLongSide);
    final longSide = wantedLongSide.clamp(math.min(lower, upper), upper).toDouble();

    final size = isPortrait ? Size(longSide * ratio, longSide) : Size(longSide, longSide / ratio);

    final maxLeft = math.max(clearance.edge, area.width - size.width - clearance.edge);
    final maxTop = math.max(clearance.topMargin, area.height - size.height - clearance.bottomMargin);
    final left = rect.left.clamp(math.min(clearance.edge, maxLeft), maxLeft).toDouble();
    final top = rect.top.clamp(math.min(clearance.topMargin, maxTop), maxTop).toDouble();

    return Rect.fromLTWH(left, top, size.width, size.height);
  }

  double _safeAspectRatio(double width, double height, [double fallback = 16 / 9]) {
    if (width <= 0 || height <= 0) {
      return fallback;
    }
    final ratio = width / height;
    if (ratio.isNaN || ratio.isInfinite || ratio <= 0) {
      return fallback;
    }
    return ratio;
  }
}
