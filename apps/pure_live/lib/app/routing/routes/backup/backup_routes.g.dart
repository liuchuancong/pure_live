// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$backupRoute];

RouteBase get $backupRoute => GoRouteData.$route(
  path: '/settings/backup',
  hasOverriddenOnExit: false,
  factory: $BackupRoute._fromState,
);

mixin $BackupRoute on GoRouteData {
  static BackupRoute _fromState(GoRouterState state) => const BackupRoute();

  @override
  String get location => GoRouteData.$location('/settings/backup');

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
