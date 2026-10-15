// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolbox_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$toolboxRoute];

RouteBase get $toolboxRoute =>
    GoRouteData.$route(path: '/toolbox', hasOverriddenOnExit: false, factory: $ToolboxRoute._fromState);

mixin $ToolboxRoute on GoRouteData {
  static ToolboxRoute _fromState(GoRouterState state) => const ToolboxRoute();

  @override
  String get location => GoRouteData.$location('/toolbox');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) => context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
