import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A compact bottom navigation bar for phones.
///
/// It is deliberately custom rather than Material's `NavigationBar` so the
/// selected state, icon weight, and 3px accent stay identical wherever the
/// bar mounts.
class PureBottomNavigation extends StatelessWidget {
  /// A bottom bar [height] tall listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.height = AdaptiveShellSizes.bottomNavHeight,
    this.showLabels = true,
    this.backgroundColor,
    super.key,
  });

  /// The destinations; more than five scroll horizontally.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// The bar's height.
  final double height;

  /// Whether labels are drawn under the glyphs.
  final bool showLabels;

  /// Overrides the bar's background.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = AdaptiveSurfaceColors.of(context);
    final scrollable = destinations.length > 5;

    final items = <Widget>[
      for (final PureNavDestination destination in destinations)
        if (scrollable)
          SizedBox(
            width: 78,
            child: PureBottomNavigationItem(
              destination: destination,
              selected: destination.id == selectedId,
              showLabel: showLabels,
              onTap: () => onDestinationSelected(destination),
            ),
          )
        else
          Expanded(
            child: PureBottomNavigationItem(
              destination: destination,
              selected: destination.id == selectedId,
              showLabel: showLabels,
              onTap: () => onDestinationSelected(destination),
            ),
          ),
    ];

    return Semantics(
      container: true,
      label: 'Bottom navigation',
      child: Material(
        color: backgroundColor ?? colors.surface,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: colors.isDark ? 0.18 : 0.025),
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: height,
              child: scrollable
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: PureSpacing.xs),
                      child: Row(children: items),
                    )
                  : Row(children: items),
            ),
          ),
        ),
      ),
    );
  }
}

/// One item inside [PureBottomNavigation].
class PureBottomNavigationItem extends StatelessWidget {
  /// Renders [destination] as one bottom-bar item.
  const new({required this.destination, required this.selected, required this.onTap, this.showLabel = true, super.key});

  /// The destination this item stands for.
  final PureNavDestination destination;

  /// Whether the item is the active destination.
  final bool selected;

  /// The activation handler.
  final VoidCallback onTap;

  /// Whether the label is drawn.
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final textStyle = PureTheme.of(context).text.caption;
    final color = !destination.enabled
        ? colors.textTertiary.withValues(alpha: 0.5)
        : selected
        ? colors.brand
        : colors.textSecondary;

    return Semantics(
      selected: selected,
      enabled: destination.enabled,
      button: true,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: destination.enabled ? onTap : null,
          hoverColor: colors.hover,
          splashColor: colors.brand.withValues(alpha: 0.08),
          highlightColor: colors.pressed,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              AnimatedContainer(
                duration: AdaptiveShellDurations.fast,
                curve: Curves.easeOutCubic,
                width: selected ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(color: colors.brand, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(height: 7),
              _BottomIcon(destination: destination, selected: selected, color: color, colors: colors),
              if (showLabel) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _BottomIcon extends StatelessWidget {
  const new({required this.destination, required this.selected, required this.color, required this.colors});

  final PureNavDestination destination;
  final bool selected;
  final Color color;
  final AdaptiveSurfaceColors colors;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(selected ? destination.selectedIcon : destination.icon, size: 22, color: color);

    if (destination.badgeCount == null) {
      return icon;
    }

    return SizedBox(
      width: 28,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(bottom: 0, left: 3, child: icon),
          Positioned(
            right: 0,
            top: -1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 13),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: colors.live,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.surface, width: 1.2),
              ),
              child: Text(
                destination.badgeCount! > 9 ? '9+' : '${destination.badgeCount}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700, height: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
