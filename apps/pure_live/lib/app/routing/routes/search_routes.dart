import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/features/search/search_page.dart';

part 'search_routes.g.dart';

/// The search route: `/search`, a full page above the shell. Declared
/// apart from the shell table, like the settings route, so the home menu
/// reaches it without importing the router back.
@TypedGoRoute<SearchRoute>(path: '/search')
class SearchRoute extends GoRouteData with $SearchRoute {
  /// The search route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SearchPage();
}
