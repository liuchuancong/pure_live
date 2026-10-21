import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart' show environmentProvider;
import 'package:pure_live/app/routing/app_router.dart' show AccountRoute;
import 'package:pure_live/app/services/clipboard_room_watcher.dart';
import 'package:pure_live/app/services/image_cache.dart' show cacheAutoClearWatcherProvider;
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/shell_actions.dart' show activateShellDestination;
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/follow/live_alert_service.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The home shell, in the design table's shape: a bottom bar under the phone
/// width, a navigation column from it — the labelled sidebar with the brand,
/// the grouped destinations and the account footer while a desktop window has
/// the room for it and the user has not collapsed it, the icon rail the rest
/// of the time. The collapse is the user's choice (the `shellNavExpanded`
/// preference) and survives restarts; the width classes apply on top and
/// never rewrite it.
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

  /// Writes the desktop column's shape; the next build draws it.
  void _setExpanded(bool expanded) {
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update((preferences) => preferences.copyWith(shellNavExpanded: expanded)),
    );
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
        final branches = ref.watch(visibleShellBranchesProvider);
        final current = ShellBranch.at(navigationShell.currentIndex);
        // A removed or hidden destination falls back to the first one.
        final selected = branches.contains(current) ? current : branches.first;
        final body = HomeLayoutScope(
          phone: !isHomeRailWidth(width),
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
        // The phone: the bottom bar carries the user's tabs and nothing else
        // — the tools live in the pages' own bars.
        if (!isHomeRailWidth(width)) {
          if (branches.length <= 1) return PureScaffold(body: body);
          return PureScaffold(
            bottomBar: PureBottomNavigation(
              destinations: [
                for (final branch in branches)
                  PureNavDestination(id: branch.name, label: branch.label(context), icon: branch.icon),
              ],
              selectedId: selected.name,
              onDestinationSelected: (destination) =>
                  activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            ),
            body: body,
          );
        }
        // The column: the labelled sidebar while the window has the room and
        // — on a desktop window, where collapsing is a choice — the user has
        // not collapsed it; the icon rail the rest of the time. A narrow
        // window draws the rail without rewriting the choice.
        final desktop = ref.watch(environmentProvider).runtime.formFactor == FormFactor.desktop;
        final expanded =
            width >= AdaptiveBreakpoints.expanded && (!desktop || ref.watch(appPreferencesProvider).shellNavExpanded);
        final toggle = desktop
            ? PureIconButton(
                key: const ValueKey('home-nav-toggle'),
                icon: Icons.menu_rounded,
                tooltip: context.t.common.menu,
                onPressed: () => _setExpanded(!expanded),
              )
            : null;
        final destinations = shellNavDestinations(context, branches: branches);
        final Widget navigation;
        if (expanded) {
          navigation = DesktopNavigation(
            key: const ValueKey('home-sidebar'),
            destinations: destinations,
            selectedId: selected.name,
            onDestinationSelected: (destination) =>
                activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            // Transparent keeps the scaffold's surface (a window material
            // where one exists, the layout colour otherwise) running under
            // the column, so the sidebar reads as part of the page rather
            // than a panel on it.
            backgroundColor: Colors.transparent,
            header: _BrandHeader(toggle: toggle, onBrandTap: () => _selectFirst(branches)),
            footer: const _AccountCard(),
          );
        } else {
          navigation = PureNavigationRail(
            key: const ValueKey('home-rail'),
            destinations: destinations,
            selectedId: selected.name,
            onDestinationSelected: (destination) =>
                activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: destination.id),
            backgroundColor: Colors.transparent,
            header: toggle == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(child: toggle),
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

  /// Walks to the first visible tab — the brand's tap (usually "go home").
  void _selectFirst(List<ShellBranch> branches) {
    if (branches.isEmpty) {
      return;
    }
    goShellBranch(ref, widget.navigationShell, branches.first.name);
  }
}

/// The navigation column's head: the collapse toggle beside the brand lockup
/// — the design's mark + wordmark; tapping the lockup goes to the first tab.
class _BrandHeader extends StatelessWidget {
  /// Draws the head; [toggle] is null where collapsing is not offered.
  const new({required this.onBrandTap, this.toggle});

  /// Goes to the first tab.
  final VoidCallback onBrandTap;

  /// The expand/collapse button, when the form factor offers one.
  final Widget? toggle;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: Row(
        children: [
          ?toggle,
          Expanded(
            child: Semantics(
              button: true,
              label: t.app.title,
              child: InkWell(
                onTap: onBrandTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: [
                      const AdaptiveBrandMark(size: 26),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          t.app.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PureTheme.of(context).text.body.copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sidebar's footer: the account card — the design's user block. The
/// account hub it opens holds every platform's sign-in.
class _AccountCard extends StatelessWidget {
  /// Draws the card.
  const new();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = AdaptiveSurfaceColors.of(context);
    return Semantics(
      button: true,
      label: t.account.title,
      child: Tooltip(
        message: t.account.title,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => unawaited(const AccountRoute().push<void>(context)),
            hoverColor: colors.hover,
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: colors.brandSubtle, shape: BoxShape.circle),
                    child: Icon(Icons.person_outline_rounded, size: 16, color: colors.brand),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.account.title,
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
