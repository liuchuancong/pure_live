part of 'settings_split_view.dart';

// The pages of a split view's two navigators, and the observers that tell
// the view what is on them.

/// The page one pane pushes over the list. It holds the detail navigator,
/// unless a newer page took it while this one animates out.
class _DetailHost extends StatelessWidget {
  const _DetailHost({
    required this.generation,
    required this.background,
    required this.child,
  });

  final int generation;
  final Color? background;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = SettingsSplitScope.maybeOf(context);
    if (scope != null && scope.hostGeneration != generation) {
      return ColoredBox(color: background ?? const Color(0x00000000));
    }
    return child;
  }
}

/// A page without a transition: the list under one pane, and the root of
/// the detail pane, which iPad, Android and Chrome all swap in place.
class _PlainPage extends Page<void> {
  const _PlainPage({
    required LocalKey super.key,
    super.name,
    super.restorationId,
    required this.child,
  });

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _PlainPageRoute(this);
}

class _PlainPageRoute extends PageRoute<void> {
  _PlainPageRoute(_PlainPage page) : super(settings: page);

  _PlainPage get _page => settings as _PlainPage;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: _page.child,
    );
  }
}

/// Knows its navigator's top route.
class _TopRouteObserver extends NavigatorObserver {
  /// The navigator's top route.
  Route<dynamic>? top;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == top) top = previousRoute;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route == top) top = previousRoute;
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute == top) top = newRoute;
  }
}

/// Watches the one-pane navigator for routes pushed from the list pane:
/// routes without a page, such as a tile's own `Navigator.push`, a menu or
/// a bottom sheet.
class _StackObserver extends _TopRouteObserver {
  _StackObserver(this.onChanged);

  /// Called when a route pushed from the list pane has finished animating
  /// out. Pushes and pops also dispatch a [NavigationNotification].
  final VoidCallback onChanged;

  /// Routes without a page, until they have animated out.
  final Set<Route<dynamic>> _pageless = <Route<dynamic>>{};

  bool get topIsPageless {
    final top = this.top;
    return top != null && top.settings is! Page;
  }

  bool get hasPageless => _pageless.isNotEmpty;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings is! Page) _pageless.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _release(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _pageless.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _pageless.remove(oldRoute);
    if (newRoute != null && newRoute.settings is! Page) _pageless.add(newRoute);
  }

  /// Forgets [route] once its exit animation is over.
  void _release(Route<dynamic> route) {
    if (!_pageless.contains(route)) return;
    final animation = route is TransitionRoute<dynamic>
        ? route.animation
        : null;
    if (animation == null || animation.isDismissed) {
      _pageless.remove(route);
      return;
    }
    void handleStatus(AnimationStatus status) {
      if (!status.isDismissed) return;
      animation.removeStatusListener(handleStatus);
      if (_pageless.remove(route)) onChanged();
    }

    animation.addStatusListener(handleStatus);
  }
}

/// Watches the detail navigator for pages opened from inside the pane.
class _DetailObserver extends _TopRouteObserver {
  _DetailObserver(this.onUserPush);

  final VoidCallback onUserPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null && route.settings is! Page) {
      onUserPush();
      // The detail navigator doesn't move the focus by itself: give it to a
      // page opened from inside the pane, as a navigator normally does.
      if (route is ModalRoute<dynamic>) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final context = route.subtreeContext;
          if (route.isActive && route.isCurrent && context != null) {
            FocusScope.of(context).requestFocus();
          }
        });
      }
    }
  }
}
