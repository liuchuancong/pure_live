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

/// The labelled sidebar's width bounds and default — what the drag handle
/// clamps to and what a double tap takes back.
const double _sidebarMinWidth = 150;
const double _sidebarMaxWidth = 300;
const double _sidebarDefaultWidth = 180;

final class _HomeShellState extends ConsumerState<HomeShell>
    with SingleTickerProviderStateMixin {
  /// The branch swap's fade-and-slide driver. go_router keeps every branch's
  /// navigator alive and shows one at a time with no transition of its own,
  /// so the shell owns the motion: on a branch change the incoming page fades
  /// in with a short push from the travel direction. This also covers the
  /// one-frame flash a re-arming page used to leave behind on an instant cut.
  late final AnimationController _branchSwap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  /// +1 when the last switch moved down the branch list, -1 when up; the
  /// slide comes from the direction travelled.
  double _swapDirection = 1;

  int? _lastBranchIndex;

  /// The width while a drag is moving the handle; null lets the stored value
  /// rule.
  double? _dragWidth;

  @override
  void initState() {
    super.initState();
    _lastBranchIndex = widget.navigationShell.currentIndex;
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

  @override
  void didUpdateWidget(HomeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final index = widget.navigationShell.currentIndex;
    if (index != _lastBranchIndex) {
      _swapDirection = _lastBranchIndex == null || index > _lastBranchIndex! ? 1 : -1;
      _lastBranchIndex = index;
      _branchSwap.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _branchSwap.dispose();
    super.dispose();
  }

  /// Persists the dragged width; the store's own debounce batches a drag
  /// into one write.
  void _storeWidth(double value) {
    unawaited(
      ref.read(appPreferencesProvider.notifier).update((preferences) => preferences.copyWith(sidebarWidth: value)),
    );
  }

  /// Writes the wide column's shape; the next build draws it.
  void _setExpanded(bool expanded) {
    unawaited(
      ref
          .read(appPreferencesProvider.notifier)
          .update((preferences) => preferences.copyWith(shellNavExpanded: expanded)),
    );
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
        final preferences = ref.watch(appPreferencesProvider);
        final phone = usesHomeBottomBar(
          width,
          bottomBarOnWide: preferences.homeBottomBarOnWide,
          mobile: Platform.isAndroid || Platform.isIOS,
        );
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
            child: AnimatedBuilder(
              animation: _branchSwap,
              child: navigationShell,
              builder: (context, child) => FadeTransition(
                opacity: CurvedAnimation(parent: _branchSwap, curve: Curves.easeOutCubic),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(_swapDirection * 0.04, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _branchSwap, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ),
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
        // The column's shape is width first, then the user's toggle: a wide
        // window draws the labelled sidebar unless they collapsed it, and a
        // narrow one draws the rail whatever the toggle says.
        final expanded = width >= AdaptiveBreakpoints.expanded && preferences.shellNavExpanded;
        final destinations = shellColumnDestinations(context, branches: branches);
        // The labelled sidebar's width is the user's: dragged on the handle
        // between the panes, held in the preferences, reset by a double tap.
        final sidebarWidth = (_dragWidth ?? ref.watch(appPreferencesProvider).sidebarWidth).clamp(
          _sidebarMinWidth,
          _sidebarMaxWidth,
        );
        final toggle = PureIconButton(
          key: const ValueKey('home-nav-toggle'),
          icon: Icons.view_sidebar_rounded,
          tooltip: ref.watch(appPreferencesProvider).shellNavExpanded
              ? context.t.common.collapseSidebar
              : context.t.common.expandSidebar,
          onPressed: () => _setExpanded(!ref.watch(appPreferencesProvider).shellNavExpanded),
        );
        final Widget navigation;
        if (expanded) {
          navigation = DesktopNavigation(
            key: const ValueKey('home-sidebar'),
            width: sidebarWidth,
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
            header: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
              child: Row(children: [toggle]),
            ),
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
            header: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(child: toggle),
            ),
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
                if (expanded)
                  _ColumnResizeHandle(
                    width: sidebarWidth,
                    onChanged: (value) => setState(() => _dragWidth = value),
                    onChangeEnd: _storeWidth,
                    onReset: () {
                      setState(() => _dragWidth = _sidebarDefaultWidth);
                      _storeWidth(_sidebarDefaultWidth);
                    },
                  ),
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The grip between the sidebar and the content: drag it to change the
/// column's width, double-tap to take the default back. The pill stays
/// invisible until the pointer arrives, so the resting edge is the column's
/// own border.
class _ColumnResizeHandle extends StatefulWidget {
  /// Draws the handle for a column [width] wide.
  const new({required this.width, required this.onChanged, required this.onChangeEnd, required this.onReset});

  /// The column's current width — the drag adds to it.
  final double width;

  /// Carries the width the drag has reached.
  final ValueChanged<double> onChanged;

  /// The drag ended; the width is final.
  final ValueChanged<double> onChangeEnd;

  /// The default width was asked for.
  final VoidCallback onReset;

  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) =>
            widget.onChanged((widget.width + details.delta.dx).clamp(_sidebarMinWidth, _sidebarMaxWidth)),
        onHorizontalDragEnd: (_) => widget.onChangeEnd(widget.width),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: 6,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 3,
              height: _hover ? 56 : 0,
              decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(1.5)),
            ),
          ),
        ),
      ),
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
