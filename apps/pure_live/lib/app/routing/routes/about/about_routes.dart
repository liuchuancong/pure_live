import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/about/about_page.dart';

part 'about_routes.g.dart';

/// The about page: identity, update check, release notes, licenses and the
/// project page.
@TypedGoRoute<AboutRoute>(path: RoutePath.about)
class AboutRoute extends GoRouteData with $AboutRoute {
  /// The about route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AboutPage();
}
