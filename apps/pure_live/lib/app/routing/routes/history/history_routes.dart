import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/history/history_page.dart';

part 'history_routes.g.dart';

/// The watch history, pushed from the shell's menu — the reference keeps it in
/// `MenuButton`'s list (`menu_button.dart:10`), not among the tabs.
@TypedGoRoute<HistoryRoute>(path: RoutePath.history)
class HistoryRoute extends GoRouteData with $HistoryRoute {
  /// The history route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HistoryPage();
}
