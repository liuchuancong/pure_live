import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_navigation.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/drawer_navigation.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';

/// The responsive application shell.
///
/// The shell chooses a navigation surface for the available width:
///
/// * compact (`< 600`) → bottom bar or drawer
/// * medium (`600–1023`) → icon rail
/// * expanded (`>= 1024`) → labelled desktop sidebar
/// * TV → focus-first TV rail
///
/// A caller-supplied [header] is placed above [body] in the content column;
/// this is where a search toolbar belongs. On compact windows the default
/// [AppBar] carries the brand mark, drawer button, and [actions].
class AdaptiveScaffold extends StatelessWidget {
  /// A scaffold for [destinations] around [body].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    required this.body,
    this.header,
    this.brand,
    this.logo,
    this.actions = const <Widget>[],
    this.compactDestinations,
    this.navigationMode,
    this.compactNavigation = PureCompactNavigationStyle.bottomBar,
    this.isTelevision = false,
    this.sidebarWidth,
    this.railWidth,
    this.tvWidth,
    this.bottomBarHeight,
    this.showBrand = true,
    this.showDrawerButton,
    this.drawerOpenButtonTooltip = 'Open navigation',
    this.drawer,
    this.drawerWidth,
    this.drawerHeader,
    this.drawerFooter,
    this.accountName,
    this.accountSubtitle,
    this.onAccountTap,
    this.navigationFooter,
    this.appBar,
    this.backgroundColor,
    this.floatingActionButton,
    this.extendBody = false,
    this.resizeToAvoidBottomInset = true,
    this.scaffoldKey,
    super.key,
  });

  /// The full destination set.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// The routed content.
  final Widget body;

  /// Content shown above [body], typically a search / toolbar row.
  final Widget? header;

  /// Optional brand widget for the app bar and desktop navigation.
  final Widget? brand;

  /// Optional logo-only mark for the medium rail and TV navigation.
  final Widget? logo;

  /// App-bar actions shown on compact and drawer layouts.
  final List<Widget> actions;

  /// Alternative destination set used by the compact bottom bar.
  final List<PureNavDestination>? compactDestinations;

  /// Forces a navigation mode; by default it is derived from the breakpoint.
  final PureNavigationMode? navigationMode;

  /// Chooses bottom bar or drawer navigation on compact windows.
  final PureCompactNavigationStyle compactNavigation;

  /// Uses the focus-first TV rail.
  final bool isTelevision;

  /// Overrides the sidebar's width.
  final double? sidebarWidth;

  /// Overrides the rail's width.
  final double? railWidth;

  /// Overrides the TV rail's width.
  final double? tvWidth;

  /// Overrides the bottom bar's height.
  final double? bottomBarHeight;

  /// Whether the brand header is shown on inline navigation.
  final bool showBrand;

  /// Shows the drawer menu button. Defaults to true whenever a drawer exists.
  final bool? showDrawerButton;

  /// The drawer button's tooltip, localized by the app.
  final String drawerOpenButtonTooltip;

  /// Custom drawer. When omitted and drawer navigation is required, a
  /// [PureNavigationDrawer] is built from [destinations].
  final Widget? drawer;

  /// The drawer's preferred width.
  final double? drawerWidth;

  /// Content beneath the drawer's brand row.
  final Widget? drawerHeader;

  /// Content pinned below the drawer's destination list.
  final Widget? drawerFooter;

  /// The signed-in account's name for the drawer's account card.
  final String? accountName;

  /// The account card's subtitle; null hides the card.
  final String? accountSubtitle;

  /// The account card's tap handler.
  final VoidCallback? onAccountTap;

  /// Footer content for the inline navigation surfaces.
  final Widget? navigationFooter;

  /// Fully custom app bar. When set, no automatic drawer button is added.
  final PreferredSizeWidget? appBar;

  /// The key handed to the inner scaffold, so a host above the shell can open
  /// its drawer deterministically — page-level scaffolds shadow
  /// `Scaffold.of` for some design languages.
  final GlobalKey<ScaffoldState>? scaffoldKey;

  /// Overrides the scaffold's background.
  final Color? backgroundColor;

  /// The floating action button, passed through to the scaffold.
  final Widget? floatingActionButton;

  /// Whether the body extends behind the bottom bar.
  final bool extendBody;

  /// Whether the body resizes for insets.
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final mode = AdaptiveNavigation.resolveMode(
      context,
      overrideMode: navigationMode,
      compactStyle: compactNavigation,
      isTelevision: isTelevision,
    );
    final needsDrawer = drawer != null || mode == PureNavigationMode.drawer;
    final resolvedDrawer = needsDrawer ? _buildDrawer() : null;
    final resolvedBackground = backgroundColor ?? colors.background;

    if (mode.isBottom || mode == PureNavigationMode.drawer) {
      return _buildCompactOrDrawer(
        context: context,
        mode: mode,
        drawer: resolvedDrawer,
        backgroundColor: resolvedBackground,
      );
    }

    return _buildWide(
      context: context,
      mode: mode,
      backgroundColor: resolvedBackground,
    );
  }

  Widget _buildCompactOrDrawer({
    required BuildContext context,
    required PureNavigationMode mode,
    required Widget? drawer,
    required Color backgroundColor,
  }) {
    final colors = AdaptiveSurfaceColors.of(context);
    final hasDrawer = drawer != null;
    final resolvedAppBar = appBar ?? _buildDefaultAppBar(context, hasDrawer);

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBody: extendBody,
      appBar: resolvedAppBar,
      drawer: drawer,
      drawerScrimColor: adaptiveDrawerScrim(isDark: colors.isDark),
      floatingActionButton: floatingActionButton,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ?header,
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: mode == PureNavigationMode.bottomBar
          ? AdaptiveNavigation(
              mode: mode,
              destinations: destinations,
              compactDestinations: compactDestinations,
              selectedId: selectedId,
              onDestinationSelected: onDestinationSelected,
              bottomBarHeight: bottomBarHeight,
            )
          : null,
    );
  }

  Widget _buildWide({
    required BuildContext context,
    required PureNavigationMode mode,
    required Color backgroundColor,
  }) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AdaptiveNavigation(
            mode: mode,
            destinations: destinations,
            selectedId: selectedId,
            onDestinationSelected: onDestinationSelected,
            sidebarWidth: sidebarWidth,
            railWidth: railWidth,
            tvWidth: tvWidth,
            footer: navigationFooter,
            brand: brand,
            logo: logo,
            onBrandTap: onAccountTap,
            showBrand: showBrand,
          ),
          Expanded(
            child: SafeArea(
              bottom: false,
              left: false,
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ?header,
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(BuildContext context, bool hasDrawer) {
    final colors = AdaptiveSurfaceColors.of(context);
    final allowMenu = showDrawerButton ?? hasDrawer;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: allowMenu && hasDrawer ? 0 : PureSpacing.lg,
      leading: allowMenu && hasDrawer
          ? Builder(
              builder: (context) {
                return IconButton(
                  tooltip: drawerOpenButtonTooltip,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded, size: 21),
                );
              },
            )
          : null,
      title: brand,
      actions: <Widget>[
        ...actions,
        const SizedBox(width: PureSpacing.sm),
      ],
    );
  }

  Widget _buildDrawer() {
    if (drawer != null) {
      return drawer!;
    }
    return PureNavigationDrawer(
      destinations: destinations,
      selectedId: selectedId,
      onDestinationSelected: onDestinationSelected,
      width: drawerWidth ?? AdaptiveShellSizes.drawerWidth,
      header: drawerHeader,
      footer: drawerFooter,
      accountName: accountName,
      accountSubtitle: accountSubtitle,
      onAccountTap: onAccountTap,
    );
  }
}
