import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouteData, StatefulNavigationShell;
import 'package:pure_live/app/shell/home_views.dart' show HomeLayoutScope;
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart' show goShellBranch;
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Activates a navigation destination by id: a branch id — primary or menu —
/// walks the shell, so the content pane shows it with the re-tap and last-tab
/// bookkeeping; the settings entry pushes its page everywhere.
void activateShellDestination(
  BuildContext context, {
  required WidgetRef ref,
  required StatefulNavigationShell navigationShell,
  required String id,
}) => switch (id) {
  'settings' => unawaited(const SettingsRoute().push<void>(context)),
  _ => goShellBranch(ref, navigationShell, id),
};

/// The route a menu branch pushes where there is no content pane.
GoRouteData menuRouteOf(ShellBranch branch) => switch (branch) {
  ShellBranch.multiview => const MultiviewRoute(),
  ShellBranch.toolbox => const ToolboxRoute(),
  ShellBranch.search => const SearchRoute(),
  ShellBranch.history => const HistoryRoute(),
  _ => throw ArgumentError.value(branch, 'branch', 'not a menu branch'),
};

/// Opens a menu branch from page content: on a wide layout it activates the
/// branch through the shell's own scope — the content pane shows it — and on
/// a phone, where there is no pane, it is pushed as a page above the shell.
void openMenuBranch(BuildContext context, ShellBranch branch) {
  final scope = HomeLayoutScope.maybeOf(context);
  if (scope != null && !scope.phone && scope.activateBranch != null) {
    scope.activateBranch!(branch);
    return;
  }
  unawaited(menuRouteOf(branch).push<void>(context));
}

/// Opens the phone's navigation drawer: the four menu branches and the
/// settings entry, sliding in from the start edge over a scrim. A drawer is
/// where a phone keeps what a wide column lists — it has no pane, so every
/// entry opens its page as a route.
Future<void> showHomeDrawer(BuildContext context) {
  final outer = context;
  final rtl = Directionality.of(context) == TextDirection.rtl;
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.t.common.menu,
    barrierColor: adaptiveDrawerScrim(isDark: PureTheme.of(context).isDark),
    transitionDuration: AdaptiveShellDurations.normal,
    pageBuilder: (_, _, _) => _HomeDrawer(outer: outer),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(
        begin: Offset(rtl ? 1 : -1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: Align(alignment: AlignmentDirectional.centerStart, child: child),
    ),
  );
}

/// The phone's drawer: the brand on top — a phone has no title bar to carry
/// it — then the four menu branches and the settings entry.
class _HomeDrawer extends StatelessWidget {
  /// Draws the drawer; [outer] is the context the entries push their routes
  /// through, so closing the drawer and opening the page is one gesture.
  const new({required this.outer});

  final BuildContext outer;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final destinations = shellDrawerDestinations(context);
    return Material(
      color: theme.colors.bgContainer,
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: 268,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const AdaptiveBrandMark(size: 26),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        context.t.app.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.text.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: theme.colors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.sm, vertical: PureSpacing.xs),
                  children: [
                    for (final destination in destinations)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: PureNavigationTile(
                          destination: destination,
                          selected: false,
                          onTap: () {
                            Navigator.of(context).pop();
                            switch (destination.id) {
                              case 'settings':
                                unawaited(const SettingsRoute().push<void>(outer));
                              default:
                                unawaited(menuRouteOf(ShellBranch.fromId(destination.id)).push<void>(outer));
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The menu button at the top-left of a phone's home tabs: it opens the
/// navigation drawer (the reference's `MenuButton` slot).
class HomeMenuButton extends StatelessWidget {
  /// The menu button.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return PureIconButton(
      key: const ValueKey('home-menu'),
      icon: Icons.menu_rounded,
      tooltip: context.t.common.menu,
      onPressed: () => unawaited(showHomeDrawer(context)),
    );
  }
}
