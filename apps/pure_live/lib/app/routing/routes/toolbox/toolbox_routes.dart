import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/toolbox/toolbox_page.dart';

part 'toolbox_routes.g.dart';

/// The toolbox: link resolution, a full page above the shell.
@TypedGoRoute<ToolboxRoute>(path: RoutePath.toolbox)
class ToolboxRoute extends GoRouteData with $ToolboxRoute {
  /// The toolbox route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ToolboxPage();
}
