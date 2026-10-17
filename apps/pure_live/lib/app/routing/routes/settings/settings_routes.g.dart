// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
  $settingsRoute,
  $appearanceRoute,
  $fontManagerRoute,
  $cacheDataRoute,
];

RouteBase get $settingsRoute => GoRouteData.$route(
  path: '/settings',
  hasOverriddenOnExit: false,
  factory: $SettingsRoute._fromState,
);

mixin $SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location('/settings');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $appearanceRoute => GoRouteData.$route(
  path: '/settings/appearance',
  hasOverriddenOnExit: false,
  factory: $AppearanceRoute._fromState,
);

mixin $AppearanceRoute on GoRouteData {
  static AppearanceRoute _fromState(GoRouterState state) =>
      const AppearanceRoute();

  @override
  String get location => GoRouteData.$location('/settings/appearance');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $fontManagerRoute => GoRouteData.$route(
  path: '/settings/fonts',
  hasOverriddenOnExit: false,
  factory: $FontManagerRoute._fromState,
);

mixin $FontManagerRoute on GoRouteData {
  static FontManagerRoute _fromState(GoRouterState state) =>
      const FontManagerRoute();

  @override
  String get location => GoRouteData.$location('/settings/fonts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $cacheDataRoute => GoRouteData.$route(
  path: '/settings/data',
  hasOverriddenOnExit: false,
  factory: $CacheDataRoute._fromState,
);

mixin $CacheDataRoute on GoRouteData {
  static CacheDataRoute _fromState(GoRouterState state) =>
      const CacheDataRoute();

  @override
  String get location => GoRouteData.$location('/settings/data');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
