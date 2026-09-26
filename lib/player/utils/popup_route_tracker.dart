import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_floating/flutter_floating.dart';
import 'package:pure_live/get/get.dart';

/// Tracks open modal popups (menus, dialogs, bottom sheets).
///
/// The in-app floating player is an OverlayEntry inserted into the root
/// Navigator's overlay. Navigator inserts each new route directly above the
/// previous route, not at the top of the overlay, so every later popup would
/// otherwise render underneath the floating window (e.g. the home "search /
/// link / multiview" menu had its first two items covered).
class PopupRouteTracker extends NavigatorObserver {
  PopupRouteTracker._();

  static final PopupRouteTracker instance = PopupRouteTracker._();

  /// Number of popup routes currently on the navigator.
  static final RxInt openPopups = 0.obs;

  final Set<Route<dynamic>> _open = <Route<dynamic>>{};

  void _add(Route<dynamic>? route) {
    if (route is PopupRoute && _open.add(route)) openPopups.value = _open.length;
  }

  void _remove(Route<dynamic>? route) {
    if (route != null && _open.remove(route)) openPopups.value = _open.length;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _remove(oldRoute);
    _add(newRoute);
  }
}

/// Fades out and disables its child while a popup route is open, so a popup
/// is never covered by an overlay entry that sits above the navigator routes.
class PopupAwareVisibility extends StatelessWidget {
  const PopupAwareVisibility({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final obscured = PopupRouteTracker.openPopups.value > 0;
      return IgnorePointer(
        ignoring: obscured,
        child: ExcludeSemantics(
          excluding: obscured,
          child: AnimatedOpacity(opacity: obscured ? 0 : 1, duration: const Duration(milliseconds: 150), child: child),
        ),
      );
    });
  }
}

/// [PopupAwareVisibility] only fades the floating content: flutter_floating
/// wraps it in an opaque drag detector that keeps claiming taps, so a menu
/// under the invisible window (the home "search / open link" items) could not
/// be tapped. Offstage the whole floating view while a popup is open.
StreamSubscription<int> hideFloatingWhilePopupsOpen(FloatingOverlay overlay) {
  void apply(int openPopups) {
    if (!overlay.isShowing) return;
    if (openPopups > 0) {
      if (!overlay.isHidden) overlay.hide();
    } else if (overlay.isHidden) {
      overlay.show();
    }
  }

  final subscription = PopupRouteTracker.openPopups.listen(apply);
  apply(PopupRouteTracker.openPopups.value);
  return subscription;
}
