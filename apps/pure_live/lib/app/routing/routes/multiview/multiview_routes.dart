import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/multiview/multiview_page.dart';

part 'multiview_routes.g.dart';

/// The multi-view page: up to four rooms playing side by side.
@TypedGoRoute<MultiviewRoute>(path: RoutePath.multiview)
class MultiviewRoute extends GoRouteData with $MultiviewRoute {
  /// The multiview route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const MultiviewPage();
}
