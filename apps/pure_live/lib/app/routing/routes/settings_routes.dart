import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/features/settings/settings_page.dart';

part 'settings_routes.g.dart';

/// The settings route: `/settings`, a full page above the shell.
///
/// Declared apart from the shell table so the chrome and the pages can
/// navigate here without importing the router back.
@TypedGoRoute<SettingsRoute>(path: '/settings')
class SettingsRoute extends GoRouteData with $SettingsRoute {
  /// The settings route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SettingsPage();
}
