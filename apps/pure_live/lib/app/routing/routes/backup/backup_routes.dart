import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/backup/backup_page.dart';

part 'backup_routes.g.dart';

/// The backup and restore page, under the settings cluster.
@TypedGoRoute<BackupRoute>(path: RoutePath.settingsBackup)
class BackupRoute extends GoRouteData with $BackupRoute {
  /// The backup route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const BackupPage();
}
