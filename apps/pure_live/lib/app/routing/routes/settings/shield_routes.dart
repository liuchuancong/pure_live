import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/shield/shield_page.dart';

part 'shield_routes.g.dart';

/// The danmaku shield page, under the settings cluster.
@TypedGoRoute<ShieldRoute>(path: RoutePath.settingsShield)
class ShieldRoute extends GoRouteData with $ShieldRoute {
  /// The shield route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ShieldPage();
}
