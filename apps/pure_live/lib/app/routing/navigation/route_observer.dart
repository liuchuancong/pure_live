import 'package:flutter/widgets.dart' show ModalRoute, RouteObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The observer a window's router installs and its route-aware pages
/// subscribe to.
///
/// One per window: Flutter forbids attaching the same `NavigatorObserver` to
/// two navigators, and every window has its own navigator. The per-window
/// scope in `AppWindowRoot` overrides this; the root scope serves the
/// single-window (phone/TV) app.
final routeObserverProvider = Provider<RouteObserver<ModalRoute<void>>>((ref) => RouteObserver<ModalRoute<void>>());
