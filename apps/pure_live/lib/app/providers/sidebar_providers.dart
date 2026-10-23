import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sidebar width the app starts with — the kit's designed width.
const double kSidebarDefaultWidth = 220;

/// The narrowest expanded sidebar a drag can produce.
const double kSidebarMinWidth = 200;

/// The widest a drag can grow the sidebar to.
const double kSidebarMaxWidth = 420;

/// A dragged width under this collapses the sidebar instead of resizing
/// it: dragging the edge far enough left is the gesture for "put it away".
const double kSidebarCollapseDragWidth = 168;

/// The least width the content beside the sidebar keeps: a drag never
/// grows the sidebar past `window - this`, and a sidebar remembered wider
/// than that renders at the window's allowance.
const double kSidebarContentFloor = 200;

/// The desktop sidebar's viewer state: whether the viewer wants it
/// expanded, and the width a drag left it at.
typedef DesktopSidebarState = ({bool expanded, double width});

/// Owns the desktop sidebar's expanded state and width. The window width
/// is not this controller's business: the desktop layout's caller folds
/// the window's size in — a narrow window folds the sidebar once, on the
/// crossing; the toggle always gets it back.
final class SidebarController extends Notifier<DesktopSidebarState> {
  @override
  DesktopSidebarState build() => (expanded: true, width: kSidebarDefaultWidth);

  /// Flips the stored preference; always effective, whatever the window's
  /// width.
  void toggle() => state = (expanded: !state.expanded, width: state.width);

  /// Puts the sidebar away; the window crossing under its threshold calls
  /// this, the viewer's own toggle does not.
  void collapse() => state = (expanded: false, width: state.width);

  /// Stores the width a drag produced, clamped to the drag clamps.
  void setWidth(double width) =>
      state = (expanded: state.expanded, width: width.clamp(kSidebarMinWidth, kSidebarMaxWidth));

  /// Puts the width back at the default, the double-click reset.
  void resetWidth() => state = (expanded: state.expanded, width: kSidebarDefaultWidth);
}

/// The desktop sidebar's expanded preference and dragged width.
final sidebarProvider = NotifierProvider<SidebarController, DesktopSidebarState>(SidebarController.new);
