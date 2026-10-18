import 'package:flutter/material.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/adaptive_brand_mark.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';


/// A compact, icon-over-label navigation rail for tablets and medium windows.
///
/// The rail keeps the navigation persistent without stealing content width.
class PureNavigationRail extends StatelessWidget {
  /// A rail [width] wide listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.width = AdaptiveShellSizes.railWidth,
    this.header,
    this.footer,
    this.brand,
    this.onBrandTap,
    this.showBrand = true,
    this.backgroundColor,
    super.key,
  });

  /// The destinations, top to bottom.
  final List<PureNavDestination> destinations;

  /// The selected destination's id.
  final String selectedId;

  /// Called with the tapped destination.
  final ValueChanged<PureNavDestination> onDestinationSelected;

  /// The rail's width.
  final double width;

  /// Replaces the default brand header.
  final Widget? header;

  /// Optional content pinned below the destination list.
  final Widget? footer;

  /// The brand mark shown at the rail's head.
  final Widget? brand;

  /// The brand's tap handler (usually "go home").
  final VoidCallback? onBrandTap;

  /// Whether the brand header is shown.
  final bool showBrand;

  /// Overrides the rail's background.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);

    final resolvedHeader =
        header ??
        (showBrand
            ? Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.lg, PureSpacing.sm, PureSpacing.lg),
                child: Center(
                  child: brand ?? AdaptiveBrandMark(onTap: onBrandTap, size: 32),
                ),
              )
            : null);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.sidebar,
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          right: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?resolvedHeader,
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.xs, vertical: PureSpacing.xs),
                  children: <Widget>[
                    for (int index = 0; index < destinations.length; index++) ...<Widget>[
                      if (destinations[index].startsGroup && index > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: PureSpacing.sm,
                            vertical: PureSpacing.xs,
                          ),
                          child: Divider(height: 1, color: colors.border),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: PureNavigationTile(
                          destination: destinations[index],
                          selected: destinations[index].id == selectedId,
                          onTap: () => onDestinationSelected(destinations[index]),
                          layout: PureNavigationTileLayout.vertical,
                          showSelectedBar: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PureSpacing.sm),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
