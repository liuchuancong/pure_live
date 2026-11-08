import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart' show kToolbarHeight;
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/layout/window_breakpoints.dart';

/// The height of a toolbar in a short area (a phone held sideways, a phone's
/// split screen, a small window): [kToolbarHeight] otherwise.
const double compactToolbarHeight = 48;

/// The width classes an area reads as (the page classes of
/// [LiveWindow]: one column under [LiveWindow.compact], the desktop
/// surface from [LiveWindow.expanded]).
enum WindowWidthClass {
  /// Under [LiveWindow.compact]: toolbars stack, secondary actions become
  /// icons, a side panel is a bottom sheet.
  compact,

  /// Between the two page measures.
  medium,

  /// From [LiveWindow.expanded]: a page may hold its toolbar on one line.
  expanded;

  /// The class of an area [width] logical pixels wide.
  static WindowWidthClass of(double width) {
    if (width < LiveWindow.compact) return compact;
    if (width < LiveWindow.expanded) return medium;
    return expanded;
  }
}

/// Heights below this are compact (a phone held sideways, a split screen, a
/// small window).
const double windowCompactHeight = 480;

/// Heights from this on are expanded.
const double windowExpandedHeight = 900;

/// The height classes an area reads as.
enum WindowHeightClass {
  /// Under [windowCompactHeight].
  compact,

  /// Between the two measures.
  medium,

  /// From [windowExpandedHeight].
  expanded;

  /// The class of an area [height] logical pixels high.
  static WindowHeightClass of(double height) {
    if (height < windowCompactHeight) return compact;
    if (height < windowExpandedHeight) return medium;
    return expanded;
  }
}

/// The width and height classes of an area — a window, a page or a pane —
/// read from the constraints its parent gives. A page laid out by the
/// window's size is wrong the moment the window has a sidebar, a rail or a
/// second pane in it; the area's own constraints are what the page gets.
@immutable
final class WindowClass {
  /// Creates the classes from [width] and [height].
  const WindowClass({required this.width, required this.height});

  /// The classes of an area [size] large.
  factory WindowClass.of(Size size) =>
      WindowClass(width: WindowWidthClass.of(size.width), height: WindowHeightClass.of(size.height));

  /// The width class.
  final WindowWidthClass width;

  /// The height class.
  final WindowHeightClass height;

  /// Lower than [windowCompactHeight]: toolbars take the compact height.
  bool get isShort => height == WindowHeightClass.compact;

  /// A phone held sideways: short and at least [LiveWindow.compact] wide.
  /// "Height compact first": such an area lays out as a landscape phone
  /// whatever its width class — a split screen's half is short too but
  /// compact both ways, and keeps the upright layout.
  bool get isPhoneLandscape => isShort && width != WindowWidthClass.compact;

  @override
  bool operator ==(Object other) => other is WindowClass && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'WindowClass(${width.name}, ${height.name})';
}

/// Tells the widgets below the [WindowClass] of the area they are laid out
/// in. The app puts one over every page's content; a pane may put its own
/// over just itself.
///
/// Dependents rebuild only when a class changes, not on every pixel of a
/// window being dragged — and the class reads the area's constraints, so a
/// page beside a rail or a splitter lays out by the room it actually has.
class WindowClassScope extends StatelessWidget {
  /// Creates the scope over [child].
  const WindowClassScope({required this.child, super.key});

  /// The widgets below.
  final Widget child;

  /// The classes of the nearest scope's area; without a scope, of the
  /// window.
  static WindowClass of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_WindowClassData>()?.value ??
      WindowClass.of(MediaQuery.sizeOf(context));

  /// The height of a toolbar in [context]: [compactToolbarHeight] in a
  /// short area, [kToolbarHeight] otherwise.
  static double toolbarHeightOf(BuildContext context) => of(context).isShort ? compactToolbarHeight : kToolbarHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // An unbounded side (inside a scroll view) is as large as the window.
      final window = MediaQuery.sizeOf(context);
      final size = Size(
        constraints.maxWidth.isFinite ? constraints.maxWidth : window.width,
        constraints.maxHeight.isFinite ? constraints.maxHeight : window.height,
      );
      return _WindowClassData(value: WindowClass.of(size), child: child);
    },
  );
}

class _WindowClassData extends InheritedWidget {
  const _WindowClassData({required this.value, required super.child});

  final WindowClass value;

  @override
  bool updateShouldNotify(_WindowClassData oldWidget) => value != oldWidget.value;
}

/// A fold or hinge that splits the area in two: a hinge that hides part of
/// the screen, or a fold half open (book or tabletop posture). A flat fold
/// does not split anything — the screen is one surface — nor does the
/// camera's cut-out. Its [bounds] are in the window's logical pixels, as
/// `MediaQuery.displayFeatures` reports them.
@immutable
final class DisplayHinge {
  /// A hinge at [bounds].
  const DisplayHinge(this.bounds);

  /// Where the hinge is, in the window.
  final Rect bounds;

  /// A vertical hinge (left and right halves: book posture, dual screens).
  bool get vertical => bounds.height >= bounds.width;

  /// The hinge among [features] that splits an area [window] large, or
  /// null.
  static DisplayHinge? find(Iterable<DisplayFeature> features, Size window) {
    final area = Offset.zero & window;
    for (final feature in features) {
      if (feature.type == DisplayFeatureType.cutout) continue;
      final bounds = feature.bounds;
      final splits = bounds.shortestSide > 0 || feature.state == DisplayFeatureState.postureHalfOpened;
      if (!splits) continue;
      final across = bounds.top <= area.top && bounds.bottom >= area.bottom;
      final along = bounds.left <= area.left && bounds.right >= area.right;
      if (across || along) return DisplayHinge(bounds);
    }
    return null;
  }

  /// The hinge splitting the area [context] is in, or null.
  static DisplayHinge? maybeOf(BuildContext context) =>
      find(MediaQuery.displayFeaturesOf(context), MediaQuery.sizeOf(context));

  /// The side of this hinge that the point [anchor] is on (or nearer), in
  /// an area [window] large; both in the window's logical pixels.
  Rect sideOf(Offset anchor, Size window) {
    final area = Offset.zero & window;
    if (vertical) {
      return anchor.dx < bounds.center.dx
          ? Rect.fromLTRB(area.left, area.top, math.max(area.left, bounds.left), area.bottom)
          : Rect.fromLTRB(math.min(area.right, bounds.right), area.top, area.right, area.bottom);
    }
    return anchor.dy < bounds.center.dy
        ? Rect.fromLTRB(area.left, area.top, area.right, math.max(area.top, bounds.top))
        : Rect.fromLTRB(area.left, math.min(area.bottom, bounds.bottom), area.right, area.bottom);
  }

  /// Two panes of a row [width] wide whose left edge is [left] from the
  /// area's, split by this hinge: the start pane ends where the hinge
  /// begins and the end pane starts where it ends (`gap` between them).
  /// Null when the hinge is not vertical, misses the row, or leaves a pane
  /// narrower than [minPane].
  ({double start, double gap})? splitRow({required double left, required double width, double minPane = 320}) {
    if (!vertical) return null;
    final start = bounds.left - left;
    final end = bounds.right - left;
    if (start < minPane || width - end < minPane) return null;
    return (start: start, gap: end - start);
  }

  @override
  bool operator ==(Object other) => other is DisplayHinge && other.bounds == bounds;

  @override
  int get hashCode => bounds.hashCode;

  @override
  String toString() => 'DisplayHinge($bounds)';
}
