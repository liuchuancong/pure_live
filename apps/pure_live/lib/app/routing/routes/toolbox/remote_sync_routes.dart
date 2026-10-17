import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_page.dart';

/// The LAN sync page's route, written by hand: the typed-route codegen
/// (build_runner) is not running for this wave, so the module joins the
/// graph through the same shape the generator would emit — one [GoRoute]
/// under the module's `$appRoutes` table (toolbox_routes carries its own the
/// same way).
final List<RouteBase> $appRoutes = [
  GoRoute(path: RoutePath.remoteSync, builder: (context, state) => const RemoteSyncPage()),
];
