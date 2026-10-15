import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/iptv/iptv_page.dart';

part 'iptv_routes.g.dart';

/// The IPTV library page: imported playlists, their channels grouped.
@TypedGoRoute<IptvRoute>(path: RoutePath.iptv)
class IptvRoute extends GoRouteData with $IptvRoute {
  /// The IPTV route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const IptvPage();
}
