import 'package:flutter/widgets.dart' show ModalRoute, RouteObserver;

/// The observer every route-aware feature subscribes to; the router
/// installs it, and a page asking "am I visible again?" reads it instead
/// of guessing from lifecycles.
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
