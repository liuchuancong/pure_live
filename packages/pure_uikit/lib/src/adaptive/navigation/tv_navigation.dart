import 'package:flutter/material.dart';

import 'package:pure_uikit/src/adaptive/adaptive_shell_sizes.dart';
import 'package:pure_uikit/src/adaptive/adaptive_surface_tokens.dart';
import 'package:pure_uikit/src/adaptive/navigation/adaptive_brand_mark.dart';
import 'package:pure_uikit/src/adaptive/navigation/navigation_item.dart';
import 'package:pure_uikit/src/scales/spacing.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Focus-first navigation for 10-foot / TV experiences.
///
/// TV navigation uses larger hit targets and a strong keyboard focus ring.
/// Directional-pad traversal is provided by Flutter's focus system; pressing
/// select/enter activates the focused destination through [InkWell].
class PureTvNavigation extends StatelessWidget {
  /// A TV rail [width] wide listing [destinations].
  const new({
    required this.destinations,
    required this.selectedId,
    required this.onDestinationSelected,
    this.width = AdaptiveShellSizes.tvRailWidth,
    this.header,
    this.footer,
    this.brand,
    this.onBrandTap,
    this.showBrand = true,
    this.autofocus = true,
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

  /// The brand's tap handler.
  final VoidCallback? onBrandTap;

  /// Whether the brand header is shown.
  final bool showBrand;

  /// Whether the selected destination takes initial focus.
  final bool autofocus;

  /// Overrides the rail's background.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);

    final resolvedHeader =
        header ??
        (showBrand
            ? Padding(
                padding: const EdgeInsets.fromLTRB(PureSpacing.sm, PureSpacing.xl, PureSpacing.sm, PureSpacing.xl),
                child: Center(child: brand ?? AdaptiveBrandMark(onTap: onBrandTap, size: 36)),
              )
            : null);

    return Semantics(
      container: true,
      label: 'TV navigation',
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
                  padding: const EdgeInsets.symmetric(horizontal: PureSpacing.sm, vertical: PureSpacing.xs),
                  children: <Widget>[
                    for (int index = 0; index < destinations.length; index++) ...<Widget>[
                      if (destinations[index].startsGroup && index > 0)
                        Padding(
                          padding: const EdgeInsets.all(PureSpacing.sm),
                          child: Divider(height: 1, color: colors.border),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: PureSpacing.xs),
                        child: _TvNavigationItem(
                          destination: destinations[index],
                          selected: destinations[index].id == selectedId,
                          autofocus: autofocus && destinations[index].id == selectedId,
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

final class _TvNavigationItem extends StatefulWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final PureNavDestination destination;
  final bool selected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  State<_TvNavigationItem> createState() => _TvNavigationItemState();
}

final class _TvNavigationItemState extends State<_TvNavigationItem> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
    if (focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Scrollable.ensureVisible(
          context,
          duration: AdaptiveShellDurations.fast,
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdaptiveSurfaceColors.of(context);
    final textStyle = PureTheme.of(context).text;
    final enabled = widget.destination.enabled;

    final foreground = !enabled
        ? colors.textTertiary.withValues(alpha: 0.5)
        : widget.selected
        ? colors.brand
        : colors.textSecondary;

    return Semantics(
      selected: widget.selected,
      enabled: enabled,
      button: true,
      label: widget.destination.label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? widget.onTap : null,
          autofocus: widget.autofocus,
          onFocusChange: _handleFocusChange,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          splashColor: colors.brand.withValues(alpha: 0.12),
          highlightColor: colors.brand.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: AdaptiveShellDurations.fast,
            curve: Curves.easeOutCubic,
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.brandSubtle
                  : _focused
                  ? colors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _focused ? colors.brand : Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  widget.selected ? widget.destination.selectedIcon : widget.destination.icon,
                  size: 25,
                  color: foreground,
                ),
                const SizedBox(height: 5),
                Text(
                  widget.destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle.caption.copyWith(
                    color: foreground,
                    fontSize: 11.5,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
