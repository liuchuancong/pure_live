import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_breakpoints.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/navigation/bottom_navigation.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/adaptive/navigation/rail_navigation.dart';
import 'package:pure_uikit/src/adaptive/navigation/sidebar_navigation.dart';
import 'package:pure_uikit/src/adaptive/navigation/tv_navigation.dart';

/// Navigation surfaces available to `AdaptiveScaffold`.
enum PureNavigationMode {
  /// Phone bottom bar.
  bottomBar,

  /// Tablet rail with icons and short labels.
  rail,

  /// Desktop sidebar with full labels.
  sidebar,

  /// Phone drawer, managed by the scaffold.
  drawer,

  /// Focus-first 10-foot navigation.
  tv,
}

/// Which navigation pattern a compact window should use.
enum PureCompactNavigationStyle {
  /// Persistent bottom bar, ideal for one-handed phone use.
  bottomBar,

  /// Drawer-only navigation, ideal for content-first phones.
  drawer,
}

/// Extensions over [PureNavigationMode].
extension PureNavigationModeX on PureNavigationMode {
  /// Whether this mode renders an inline navigation surface.
  bool get isInline => this != PureNavigationMode.drawer;

  /// Whether this mode is shown at the bottom of the scaffold.
  bool get isBottom => this == PureNavigationMode.bottomBar;
}

/// Renders the correct inline navigation surface for the current [mode].
///
/// `AdaptiveScaffold` uses this internally, but the widget can also be
/// composed by custom shells. Drawer mode returns an empty box; the scaffold
/// owns the drawer route and its scrim.
class AdaptiveNavigation extends StatelessWidget {
  /// Renders [mode] for [destinations].
  const new({
    required this.mode,
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.compactDestinations,
    this.sidebarWidth,
    this.railWidth,
    this.tvWidth,
    this.bottomBarHeight,
    this.header,
    this.footer,
    this.brand,
    this.logo,
    this.onBrandTap,
    this.showBrand = true,
    super.key,
  });

  /// The navigation mode to render.
  final PureNavigationMode mode;

  /// The full destination set.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// Optional alternate destination set for the compact bottom bar.
  final List<PureNavDestination>? compactDestinations;

  /// Overrides the sidebar's width.
  final double? sidebarWidth;

  /// Overrides the rail's width.
  final double? railWidth;

  /// Overrides the TV rail's width.
  final double? tvWidth;

  /// Overrides the bottom bar's height.
  final double? bottomBarHeight;

  /// Content above the destination list (rail/sidebar/TV).
  final Widget? header;

  /// Content pinned below the destination list.
  final Widget? footer;

  /// Full brand (mark + wordmark) used by the desktop sidebar.
  final Widget? brand;

  /// Logo-only mark used by the rail and TV navigation.
  final Widget? logo;

  /// The brand's tap handler.
  final VoidCallback? onBrandTap;

  /// Whether the brand header is shown.
  final bool showBrand;

  /// Resolves the best navigation mode for the current window.
  static PureNavigationMode resolveMode(
    BuildContext context, {
    PureNavigationMode? overrideMode,
    PureCompactNavigationStyle compactStyle = PureCompactNavigationStyle.bottomBar,
    bool isTelevision = false,
  }) {
    if (overrideMode != null) {
      return overrideMode;
    }
    if (isTelevision) {
      return PureNavigationMode.tv;
    }
    return switch (AdaptiveBreakpoints.of(context)) {
      AdaptiveBreakpoint.compact =>
        compactStyle == PureCompactNavigationStyle.drawer ? PureNavigationMode.drawer : PureNavigationMode.bottomBar,
      AdaptiveBreakpoint.medium => PureNavigationMode.rail,
      AdaptiveBreakpoint.expanded => PureNavigationMode.sidebar,
      AdaptiveBreakpoint.large => PureNavigationMode.sidebar,
    };
  }

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case PureNavigationMode.bottomBar:
        return PureBottomNavigation(
          destinations: _resolvedCompactDestinations,
          selectedId: selectedId,
          onDestinationSelected: onDestinationSelected,
          height: bottomBarHeight ?? AdaptiveShellSizes.bottomNavHeight,
        );
      case PureNavigationMode.rail:
        return PureNavigationRail(
          width: railWidth ?? AdaptiveShellSizes.railWidth,
          destinations: destinations,
          selectedId: selectedId,
          onDestinationSelected: onDestinationSelected,
          header: header,
          footer: footer,
          brand: logo,
          onBrandTap: onBrandTap,
          showBrand: showBrand,
        );
      case PureNavigationMode.sidebar:
        return DesktopNavigation(
          width: sidebarWidth ?? AdaptiveShellSizes.sidebarWidth,
          destinations: destinations,
          selectedId: selectedId,
          onDestinationSelected: onDestinationSelected,
          header: header,
          footer: footer,
          brand: brand,
          onBrandTap: onBrandTap,
          showBrand: showBrand,
        );
      case PureNavigationMode.tv:
        return PureTvNavigation(
          width: tvWidth ?? AdaptiveShellSizes.tvRailWidth,
          destinations: destinations,
          selectedId: selectedId,
          onDestinationSelected: onDestinationSelected,
          header: header,
          footer: footer,
          brand: logo,
          onBrandTap: onBrandTap,
          showBrand: showBrand,
        );
      case PureNavigationMode.drawer:
        return const SizedBox.shrink();
    }
  }

  List<PureNavDestination> get _resolvedCompactDestinations {
    if (compactDestinations != null) {
      return compactDestinations!;
    }
    final primary = destinations
        .where((destination) => destination.showInCompactBar)
        .toList(growable: false);
    if (primary.isEmpty) {
      return destinations.take(5).toList(growable: false);
    }
    return primary;
  }
}
