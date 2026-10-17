import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/splash/splash_screen.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

part 'splash_routes.g.dart';

/// The start-up splash: `/splash`, the launch route ahead of the shell
/// (3.x `RoutePath.kSplash`).
///
/// Everything the boot initialises — the service graph, the desktop window,
/// the provider overrides — is ready before the first frame, so the splash
/// is branding and a bounded timer only. When the timer ends the app lands
/// on the launch branch's root, replacing the splash.
@TypedGoRoute<SplashRoute>(path: RoutePath.splash)
class SplashRoute extends GoRouteData with $SplashRoute {
  /// The splash route.
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final theme = PureTheme.of(context);
    // The handover target is the user's launch page (general settings), or
    // the branch the app was last left on when the navigation preference
    // asks for it — read once, when the splash routes on.
    return Consumer(
      builder: (context, ref, _) => SplashScreen(
        // The app ships no icon asset, so the brand block carries the glyph —
        // the about page's identity tile, enlarged.
        logo: Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colors.primary.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: theme.colors.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Icon(Icons.live_tv_rounded, size: 56, color: theme.colors.primary),
        ),
        showTextLogo: true,
        logoText: context.t.splash.welcome,
        loaderType: LoaderType.progressBar,
        duration: const Duration(seconds: 2),
        onNextPressed: () => context.go(launchLocationFor(ref.read(appPreferencesProvider))),
      ),
    );
  }
}
