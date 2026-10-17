import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/version/version_page.dart';

part 'version_routes.g.dart';

/// The version page: `/about/version`, one level under the about cluster —
/// the reference's routed update page (3.x `RoutePath.kVersionPage`),
/// carrying the update check the about page's verdict dialogs used to open.
@TypedGoRoute<VersionRoute>(path: RoutePath.version)
class VersionRoute extends GoRouteData with $VersionRoute {
  /// The version route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const VersionPage();
}
