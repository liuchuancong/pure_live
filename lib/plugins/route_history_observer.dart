import 'package:flutter/material.dart';

class RouteHistoryObserver extends NavigatorObserver {
  static final List<Route<dynamic>> _routeHistory = [];

  static List<Route<dynamic>> get routeHistory => _routeHistory;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeHistory.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeHistory.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeHistory.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _routeHistory.remove(oldRoute);
    if (newRoute != null) _routeHistory.add(newRoute);
  }
}
