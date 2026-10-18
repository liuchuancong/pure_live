import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/routing/routes/login/login_routes.dart' show AccountRoute;
import 'package:pure_live/app/shell/main_sidebar.dart';
import 'package:pure_live/app/shell/main_workspace.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The one desktop/tablet/phone chrome: an [AdaptiveScaffold] whose navigation
/// mode is pinned by the device's form factor and, on desktop, by the window
/// width.
///
/// * phone → bottom bar, with the full destination set (branches, utilities,
///   the account entry) in a drawer the page app bars open;
/// * tablet → the 88px icon rail;
/// * desktop → the labelled sidebar from 1024 up, the icon rail below;
/// * TV keeps the TV shell — the router never mounts this widget there.
///
/// Pinning by device is the point: a landscape tablet keeps the rail (a rail
/// is the tablet contract), and a desktop window keeps its navigation inline
/// whatever the width — only the desktop decides between sidebar and rail from
/// the width.
///
/// The Windows self-drawn title bar rides above the scaffold exactly as the
/// old desktop shell composed it: startup-frozen through
/// [windowChromeProvider], outside the scaffold's route tree.
final class AdaptiveShell extends ConsumerStatefulWidget {
  /// Wraps [navigationShell] in the adaptive chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AdaptiveShell> createState() => _AdaptiveShellState();
}

final class _AdaptiveShellState extends ConsumerState<AdaptiveShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Resolves the mode for the form factor this boot declared.
  PureNavigationMode _modeFor(FormFactor factor) => switch (factor) {
    FormFactor.phone => PureNavigationMode.bottomBar,
    FormFactor.tablet => PureNavigationMode.rail,
    FormFactor.desktop || FormFactor.tv => AdaptiveBreakpoints.of(context).isAtLeastExpanded
        ? PureNavigationMode.sidebar
        : PureNavigationMode.rail,
  };

  void _select(String id) {
    openShellRailDestination(context, ref, widget.navigationShell, id);
  }

  void _goHome() => goShellBranch(ref, widget.navigationShell, ShellBranch.follow.name);

  Future<void> _openAccount() => const AccountRoute().push<void>(context);

  @override
  Widget build(BuildContext context) {
    final formFactor = ref.watch(environmentProvider).runtime.formFactor;
    final drawsTitleBar = formFactor == FormFactor.desktop && ref.watch(windowChromeProvider) == ShellWindowChrome.app;
    final mode = _modeFor(formFactor);
    final wide = mode == PureNavigationMode.sidebar || mode == PureNavigationMode.rail;

    final scaffold = AdaptiveScaffold(
      scaffoldKey: _scaffoldKey,
      destinations: shellAdaptiveDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
      selectedId: ShellBranch.at(widget.navigationShell.currentIndex).name,
      onDestinationSelected: (destination) => _select(destination.id),
      navigationMode: mode,
      brand: MainSidebarBrand(onTap: _goHome),
      logo: MainSidebarBrand(onTap: _goHome),
      navigationFooter: wide ? const ShellRailActions() : null,
      drawer: formFactor == FormFactor.phone ? _buildDrawer() : null,
      appBar: _emptyAppBar,
      body: MainWorkspaceHost(child: widget.navigationShell),
    );

    return AdaptiveShellScope(
      scaffoldKey: _scaffoldKey,
      hasDrawer: formFactor == FormFactor.phone,
      child: drawsTitleBar
          ? Column(
              children: [
                PureTitleBar(
                  labels: PureTitleBarLabels(
                    title: context.t.app.title,
                    minimize: context.t.window.minimize,
                    maximize: context.t.window.maximize,
                    restore: context.t.window.restore,
                    close: context.t.window.close,
                  ),
                  actions: const WindowManagerChromeActions(),
                ),
                Expanded(child: scaffold),
              ],
            )
          : scaffold,
    );
  }

  /// The phone drawer: every destination plus the account entry. The bottom
  /// bar's four branch tabs come from `showInCompactBar`, so one list serves
  /// both surfaces.
  PureNavigationDrawer _buildDrawer() {
    return PureNavigationDrawer(
      destinations: shellAdaptiveDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
      selectedId: ShellBranch.at(widget.navigationShell.currentIndex).name,
      onDestinationSelected: (destination) => _select(destination.id),
      accountSubtitle: context.t.account.notSignedInHint,
      onAccountTap: () => unawaited(_openAccount()),
      closeTooltip: context.t.window.close,
    );
  }

  /// The shell paints no app bar of its own: the page frame below owns the top
  /// edge, so a zero-height stand-in keeps the scaffold's slot filled without
  /// stacking a second bar over the pages'.
  static const PreferredSizeWidget _emptyAppBar = PreferredSize(
    preferredSize: Size.fromHeight(0),
    child: SizedBox.shrink(),
  );
}

/// Tells the pages below the shell whether a drawer is available, and carries
/// the key that opens it.
///
/// The page scaffolds are real `Scaffold`s for some languages, so
/// `Scaffold.of(context)` from a page would find the page's own scaffold and
/// never the shell's; the key is the only deterministic door.
class AdaptiveShellScope extends InheritedWidget {
  /// Publishes [scaffoldKey] and [hasDrawer] to the shell's subtree.
  const new({required this.scaffoldKey, required this.hasDrawer, required super.child, super.key});

  /// The shell scaffold's key; its state is null before the first frame.
  final GlobalKey<ScaffoldState> scaffoldKey;

  /// Whether the shell scaffold carries a drawer — the phone boot only.
  final bool hasDrawer;

  /// Opens the shell's drawer; a no-op before the scaffold exists.
  void openDrawer() => scaffoldKey.currentState?.openDrawer();

  /// The nearest scope, null outside the adaptive shell.
  static AdaptiveShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdaptiveShellScope>();

  @override
  bool updateShouldNotify(AdaptiveShellScope oldWidget) => scaffoldKey != oldWidget.scaffoldKey;
}
