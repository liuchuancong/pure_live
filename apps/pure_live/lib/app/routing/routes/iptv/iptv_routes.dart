import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/iptv/iptv_page.dart';
import 'package:pure_live/features/iptv/iptv_play_page.dart';

part 'iptv_routes.g.dart';

/// The IPTV library page: imported playlists, their channels grouped.
@TypedGoRoute<IptvRoute>(path: RoutePath.iptv)
class IptvRoute extends GoRouteData with $IptvRoute {
  /// The IPTV route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const IptvPage();
}

/// One IPTV channel playing; [name] only titles the bar.
@TypedGoRoute<IptvPlayRoute>(path: RoutePath.iptvPlay)
class IptvPlayRoute extends GoRouteData with $IptvPlayRoute {
  /// The channel play route.
  const new({required this.channelId, this.name = ''});

  /// The library channel id.
  final String channelId;

  /// A caller-provided title hint.
  final String name;

  @override
  Widget build(BuildContext context, GoRouterState state) => IptvPlayPage(channelId: channelId, name: name);
}
