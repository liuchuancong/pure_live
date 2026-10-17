import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/features/login/account_page.dart';
import 'package:pure_live/features/login/login_page.dart';

part 'login_routes.g.dart';

/// The bilibili QR login page: `/login`, pushed from the account page.
@TypedGoRoute<LoginRoute>(path: RoutePath.login)
class LoginRoute extends GoRouteData with $LoginRoute {
  /// The login route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const LoginPage();
}

/// The account page: `/settings/account`, one level under the settings index.
@TypedGoRoute<AccountRoute>(path: RoutePath.settingsAccount)
class AccountRoute extends GoRouteData with $AccountRoute {
  /// The account route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AccountPage();
}
