import 'package:flutter/material.dart';
import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/adaptive_brand_mark.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';


/// A persistent, labelled navigation sidebar for desktop and large displays.
///
/// This is the full navigation surface: product mark at the top, grouped
/// destinations, and an optional footer for account or utility actions.
class DesktopNavigation extends StatelessWidget {
  /// A sidebar [width] wide listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.width = AdaptiveShellSizes.sidebarWidth,
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

  /// The sidebar's width.
  final double width;

  /// Replaces the default brand header.
  final Widget? header;

  /// Optional content pinned below the destination list.
  final Widget? footer;

  /// The brand lockup; a plain mark when [showBrand] with no [brand] given.
  final Widget? brand;

  /// The brand's tap handler (usually "go home").
  final VoidCallback? onBrandTap;

  /// Whether the brand header is shown.
  final bool showBrand;

  /// Overrides the sidebar's background.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);

    final resolvedHeader =
        header ??
        (showBrand
            ? Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.xl, PureSpacing.xl, PureSpacing.lg, PureSpacing.xl),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: brand ?? AdaptiveBrandMark(onTap: onBrandTap),
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
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md, vertical: PureSpacing.xs),
                  children: <Widget>[
                    for (int index = 0; index < destinations.length; index++) ...<Widget>[
                      if (destinations[index].startsGroup && index > 0)
                        Padding(
                          padding: const EdgeInsets.all(PureSpacing.sm),
                          child: Divider(height: 1, color: colors.border),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: PureNavigationTile(
                          destination: destinations[index],
                          selected: destinations[index].id == selectedId,
                          onTap: () => onDestinationSelected(destinations[index]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.all(PureSpacing.md),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
