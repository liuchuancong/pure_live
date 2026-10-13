import 'package:meta/meta.dart';

/// An integer pixel rectangle in screen space, so this package stays off
/// `dart:ui` and can be tested without a Flutter binding.
///
/// The unit is **logical pixels**, and it must stay that way everywhere in the
/// shell: the window managers report frames in logical pixels, the displays are
/// reported in logical pixels, and a geometry saved on a 150% monitor and
/// restored on a 100% one is only correct if nothing silently multiplied by a
/// device pixel ratio along the way. Mixing the two is the classic desktop bug
/// where a remembered window comes back half off the screen, which is why the
/// scale factor travels beside the frame ([WindowGeometry.scaleFactor]) instead
/// of being folded into it.
@immutable
final class PixelRect {
  /// A rectangle at [left], [top] with [width] by [height].
  const new(this.left, this.top, this.width, this.height);

  /// A rectangle between two corners.
  const new betweenCorners(this.left, this.top, int right, int bottom) : width = right - left, height = bottom - top;

  /// The left edge.
  final int left;

  /// The top edge.
  final int top;

  /// The width.
  final int width;

  /// The height.
  final int height;

  /// The right edge.
  int get right => left + width;

  /// The bottom edge.
  int get bottom => top + height;

  /// Whether the coordinates [x], [y] lie inside this rectangle.
  bool contains(int x, int y) => x >= left && x < right && y >= top && y < bottom;

  /// The overlap with [other], null when they do not meet.
  PixelRect? intersect(PixelRect other) {
    final x1 = left > other.left ? left : other.left;
    final y1 = top > other.top ? top : other.top;
    final x2 = right < other.right ? right : other.right;
    final y2 = bottom < other.bottom ? bottom : other.bottom;
    if (x2 <= x1 || y2 <= y1) {
      return null;
    }
    return PixelRect.betweenCorners(x1, y1, x2, y2);
  }

  @override
  bool operator ==(Object other) =>
      other is PixelRect && other.left == left && other.top == top && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'PixelRect($left,$top $width x $height)';
}

/// One display the shell may place a window on.
@immutable
final class DisplayFrame {
  /// A display with its whole [bounds] and the [workArea] left after the
  /// taskbar, dock and any reserved edge are taken out.
  const new({required this.id, required this.bounds, required this.workArea, this.scaleFactor = 1});

  /// The stable id of this display, as the window manager names it.
  final String id;

  /// The display's full extent.
  final PixelRect bounds;

  /// What a window may actually occupy: [bounds] minus the system bars.
  ///
  /// Maximising against [bounds] rather than [workArea] is the classic reason a
  /// desktop app covers the taskbar, so this is what the shell must clamp to.
  final PixelRect workArea;

  /// The display's scale factor, for converting to physical sizes.
  ///
  /// Carried rather than applied: [bounds] and [workArea] are in logical pixels
  /// like every other frame in this package.
  final double scaleFactor;
}

/// A window's remembered place: where, how big, and whether it was maximised.
///
/// All four, deliberately. Storing only width and height — the shortcut a lot of
/// desktop apps take — means a viewer who works on two screens and unplugs one
/// gets a window at coordinates that no longer exist, which they experience as
/// "the app opens but there is nothing to see". The display id plus the clamp in
/// [keepOnScreen] is what makes that recoverable.
@immutable
final class WindowGeometry {
  /// A place.
  const new({required this.frame, required this.maximized, this.displayId, this.scaleFactor = 1});

  /// The window's frame in screen pixels, in its maximised-or-not state.
  final PixelRect frame;

  /// Whether the window was maximised when this was taken.
  ///
  /// Kept separately from [frame] because asking the OS for the bounds of a
  /// maximised window returns the maximised rectangle, not the size it should
  /// restore to; without this, a maximised app restarts maximised *and*
  /// forgets the size the viewer dragged it to.
  final bool maximized;

  /// Which display it lived on, so the frame can be re-validated against it.
  final String? displayId;

  /// The scale factor the frame was recorded under.
  final double scaleFactor;

  /// A copy with a new frame or state.
  ///
  /// No scale in here: the scale a frame was recorded under belongs to the
  /// record as a whole, and nothing rebuilds a geometry with a new one.
  WindowGeometry copyWith({PixelRect? frame, bool? maximized, String? displayId}) => WindowGeometry(
    frame: frame ?? this.frame,
    maximized: maximized ?? this.maximized,
    displayId: displayId ?? this.displayId,
    scaleFactor: scaleFactor,
  );

  @override
  bool operator ==(Object other) =>
      other is WindowGeometry &&
      other.frame == frame &&
      other.maximized == maximized &&
      other.displayId == displayId &&
      other.scaleFactor == scaleFactor;

  @override
  int get hashCode => Object.hash(frame, maximized, displayId, scaleFactor);
}

/// The smallest part of a window's title bar that must stay on screen for the
/// window to be reachable by mouse.
const int kMinimumGrabWidth = 100;

/// Whether a remembered frame can still be grabbed on any of [displays].
bool isOnSomeDisplay(WindowGeometry geometry, List<DisplayFrame> displays) {
  final titleBar = PixelRect(
    geometry.frame.left,
    geometry.frame.top,
    geometry.frame.width < kMinimumGrabWidth ? geometry.frame.width : kMinimumGrabWidth,
    // The grab strip is the title bar's height; a window whose top edge is off
    // screen cannot be dragged back, so only this strip needs to be somewhere.
    1,
  );
  for (final display in displays) {
    final overlap = titleBar.intersect(display.workArea);
    if (overlap != null &&
        overlap.width >= (geometry.frame.width < kMinimumGrabWidth ? geometry.frame.width : kMinimumGrabWidth)) {
      return true;
    }
  }
  return false;
}

/// Moves [geometry] back onto a display it can be reached on, and returns it
/// unchanged when it already can.
///
/// The relocation keeps the frame's size and only slides it, because a window
/// the viewer sized on purpose is worth more than the coordinates they never
/// saw. It lands on the work area of the display the geometry names (or the
/// first one that exists), at that area's top edge.
WindowGeometry keepOnScreen(WindowGeometry geometry, List<DisplayFrame> displays) {
  if (displays.isEmpty || isOnSomeDisplay(geometry, displays)) {
    return geometry;
  }
  final display = displays.where((entry) => entry.id == geometry.displayId).firstOrNull ?? displays.first;
  final area = display.workArea;
  final frame = geometry.frame;
  final width = frame.width > area.width ? area.width : frame.width;
  final height = frame.height > area.height ? area.height : frame.height;
  final right = frame.right - frame.left + width;
  final shiftedLeft = right > area.width ? area.right - width : area.left;
  final shiftedTop = area.top;
  return geometry.copyWith(
    displayId: display.id,
    frame: PixelRect(shiftedLeft < area.left ? area.left : shiftedLeft, shiftedTop, width, height),
  );
}

/// Clamps a maximised frame to a display's work area.
///
/// Maximising must never cover the taskbar: the OS does the right thing when it
/// owns the caption, and gets it wrong the moment a frameless window maximises
/// itself — which is one of the things given up by `ChromePlan.select`'s second
/// stage, so the shell has to do it back.
PixelRect maximiseTo(PixelRect workArea) => PixelRect(workArea.left, workArea.top, workArea.width, workArea.height);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
