import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/shell_actions.dart' show activateShellDestination;
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/follow/live_alert_service.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/input/clipboard_room_watcher.dart';
import 'package:pure_live/system/navigation/app_router.dart' show SettingsRoute;
import 'package:pure_live/system/resources/image_cache.dart' show cacheAutoClearWatcherProvider;
import 'package:pure_uikit/pure_uikit.dart';

/// The home shell: a bottom bar carrying the five primary branches under the
/// phone width, a navigation column from it — the labelled sidebar from the
/// expanded class, the icon rail below — with the brand living in the window's
/// title bar above (desktop) and the top-left menu owning the four tools. A
/// menu branch activates like a primary one, so the content pane shows it; a
/// phone has no pane and its menu pushes the pages instead.
///
/// The window's caption is not the shell's business: the app-level
/// `DesktopTitleFrame` draws it once above the whole navigator, so pushed
/// pages keep the strip (the reference frames the app, not the home page).
final class HomeShell extends ConsumerStatefulWidget {
  /// Wraps [navigationShell] in the shell chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

final class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    // 剪贴板口令: the clipboard's room links are looked for when the app
    // comes back to the foreground, for as long as the shell is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
          ..read(clipboardRoomWatcherProvider).start()
          ..read(cacheAutoClearWatcherProvider).start();
      }
    });
  }

  /// Hands a menu branch to the content pane — what the shell's chrome and
  /// the pages' own entries both land on across a wide layout.
  void _activateBranch(ShellBranch branch) {
    goShellBranch(ref, widget.navigationShell, branch.name);
  }

  @override
  Widget build(BuildContext context) {
    // 开播提醒: the interval pass over the followed rooms reports each room that
    // started since the last look. The shell owns the notice because it is the
    // only thing up for the whole visit, and listening here is what keeps the
    // service alive.
    ref.listen(liveAlertsProvider, (previous, next) {
      final room = next.value;
      if (room == null || !mounted) {
        return;
      }
      final anchor = room.anchor?.name.trim();
      final title = room.content.title.trim();
      final who = anchor == null || anchor.isEmpty ? room.ref.roomId : anchor;
      // 直播 · 主播 · 房间标题 — the three parts every locale already has words
      // for; a notice that names the room is the whole job.
      PureToast.show(context, [context.t.follow.liveRoom, who, if (title.isNotEmpty) title].join(' · '));
    });
    final navigationShell = widget.navigationShell;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final phone = !isHomeRailWidth(width);
        final branches = ref.watch(visibleShellBranchesProvider);
        final current = ShellBranch.at(navigationShell.currentIndex);
        // A removed or hidden destination falls back to the first one; a menu
        // branch is always allowed to stand where it is.
        final selected =
            current
                .isPrimary //
            ? (branches.contains(current) ? current : branches.first)
            : current;
        final body = HomeLayoutScope(
          phone: phone,
          activateBranch: _activateBranch,
          child: PopScope(
            // Android's back on the home page sends the app to the
            // background (the reference's moveToBack).
            canPop: !Platform.isAndroid,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && Platform.isAndroid) unawaited(SystemNavigator.pop());
            },
            child: navigationShell,
          ),
        );
        // The phone: the bottom bar carries the five primary branches and
        // nothing else — the tools live in the pages' own top-left menu.
        if (phone) {
          if (branches.length <= 1) return PureScaffold(body: body);
          return PureScaffold(
            bottomBar: PureBottomNavigation(
              destinations: shellPrimaryDestinations(context, branches: branches),
              selectedId: selected.isPrimary ? selected.name : branches.first.name,
              onDestinationSelected: (destination) =>
                  activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            ),
            body: body,
          );
        }
        // The column: the labelled sidebar from the expanded class, the icon
        // rail below it. The primaries come first, then — under the group
        // divider — the four menu branches as rows of their own; a menu
        // branch highlights its row like a primary one. The brand lives in
        // the window's title bar, and the foot is settings.
        final expanded = width >= AdaptiveBreakpoints.expanded;
        final destinations = shellColumnDestinations(context, branches: branches);
        final Widget navigation;
        if (expanded) {
          navigation = DesktopNavigation(
            key: const ValueKey('home-sidebar'),
            destinations: destinations,
            selectedId: selected.name,
            onDestinationSelected: (destination) =>
                activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            showBrand: false,
            // Transparent keeps the scaffold's surface (a window material
            // where one exists, the layout colour otherwise) running under
            // the column, so the sidebar reads as part of the page rather
            // than a panel on it.
            backgroundColor: Colors.transparent,
            footer: const _SettingsCard(),
          );
        } else {
          navigation = PureNavigationRail(
            key: const ValueKey('home-rail'),
            destinations: destinations,
            selectedId: selected.name,
            onDestinationSelected: (destination) =>
                activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            showBrand: false,
            backgroundColor: Colors.transparent,
            footer: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(child: _SettingsIcon()),
            ),
          );
        }
        return PureScaffold(
          body: SafeArea(
            child: Row(
              children: [
                // The column scrolls in short windows; its position must not
                // attach to the page's primary scroll controller.
                PrimaryScrollController.none(child: FocusTraversalGroup(child: navigation)),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The sidebar's footer: the settings entry — where the account card stood.
class _SettingsCard extends StatelessWidget {
  /// Draws the card.
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = AdaptiveSurfaceColors.of(context);
    return Semantics(
      button: true,
      label: t.tabs.settings,
      child: Tooltip(
        message: t.tabs.settings,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(const SettingsRoute().push<void>(context)),
            hoverColor: colors.hover,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: colors.brandSubtle, shape: BoxShape.circle),
                    child: Icon(Icons.settings_outlined, size: 16, color: colors.brand),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.tabs.settings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PureTheme.of(context).text.body.copyWith(fontSize: 13.5),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: colors.textTertiary),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's settings entry: the icon alone.
class _SettingsIcon extends StatelessWidget {
  /// Draws the entry.
  const new();

  @override
  Widget build(BuildContext context) {
    return PureIconButton(
      icon: Icons.settings_outlined,
      tooltip: context.t.tabs.settings,
      onPressed: () => unawaited(const SettingsRoute().push<void>(context)),
    );
  }
}
