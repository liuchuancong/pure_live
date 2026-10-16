import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Glass application shell from a [LanguageShellSpec] (§ surfaces).
///
/// Composed, not mapped — `glass_morphism_plus` ships no navigation structure at
/// all. Its parts are surface pieces only (`GlassContainer`, `GlassTile`,
/// `GlassDivider`) plus the Material-bar-shaped `GlassAppBar`; there is no rail,
/// no sidebar, no tab scaffold to hang a router-owned body on. So the column is
/// assembled out of the same frosted pieces the nav bar and the tab bar already
/// compose themselves from: one full-height [glass.GlassContainer] as the track,
/// and a second, brighter [glass.GlassContainer] sheet behind the selected
/// destination — the idiom glassmorphism marks a selection with everywhere else in
/// this adapter. Every visible value comes from [glass.GlassTheme] (§8): the blur,
/// tint (`color`), opacity and corner radius (`borderRadius`) are the library's
/// inherited values, and the layout geometry falls back to the shared sizing scale
/// because a glass column has no metrics of its own.
///
/// Interaction goes through the core's [LiveBox]/[Style], not a tappable
/// [glass.GlassContainer]: the library's `onTap` installs its own transparent
/// `Material` wrapping an `InkWell` with a focus node of its own (§15, and the
/// reason every composed glass control in this package behaves the same way).
/// Underneath the host's ink surface that fights the dispatch system's focus
/// order, so the cell stays a [LiveBox] and the frosted sheets are purely paint.
///
/// `LiveShellPlacement` is honoured on the rule the token shell uses, so a
/// narrow window switches form at the same width whichever language is active:
/// `rail`, and an `adaptive` request with room for a pane, compose the column;
/// `bottom` hands the strip back through the adapter's `navBar` — this package's
/// own frosted bar — and `none` or a single destination gives the frame back to
/// the page. [LanguageShellSpec.trailing] is pinned to the foot of the composed
/// column; the bottom form has no such slot, so it is dropped there rather than
/// invented, exactly as the token shell states.
abstract final class GlassShellBuilder {
  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // the frame is the page's own, and the shell stands aside.
      return spec.child;
    }

    if (!_wantsRail(spec.placement, context)) {
      // The phone form. `GlassAppBar` is a Material bar, not a bottom strip, so
      // the strip goes back through the adapter's own nav bar; that form carries
      // no trailing slot, so `spec.trailing` is dropped here rather than faked as
      // a fifth tab — the same rule the token shell states.
      return Column(
        children: [
          Expanded(child: spec.child),
          LiveTheme.of(context).adapter.navBar(
            context,
            LanguageNavBarSpec(
              items: [
                for (final destination in spec.destinations)
                  LiveNavBarItem(label: destination.label, icon: destination.icon),
              ],
              index: spec.destinations.indexWhere((destination) => destination.id == spec.selectedId),
              // A disabled destination stays in the strip so the layout does not
              // shift, and the shell refuses it rather than reporting its id.
              onChanged: (index) {
                final destination = spec.destinations[index];
                if (destination.enabled) {
                  spec.onSelected?.call(destination.id);
                }
              },
            ),
          ),
        ],
      );
    }

    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    // The track and its cells share one radius, inset by the library's stroke so
    // the brighter sheet sits inside the frosted track rather than on its border.
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: geometry?.railWidth ?? LiveSizing.railWidth,
          // One frosted sheet for the whole column: the library's own surface,
          // blurring whatever the page paints behind the rail (§8).
          child: glass.GlassContainer(
            padding: EdgeInsets.all(theme.token.motion.lineWidth * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final destination in spec.destinations)
                  _RailCell(
                    destination: destination,
                    selected: destination.id == spec.selectedId,
                    iconSize: geometry?.iconSize ?? 18,
                    radius: radius,
                    onSelected: spec.onSelected,
                  ),
                if (spec.trailing case final Widget footer) ...[
                  const Spacer(),
                  Align(alignment: Alignment.bottomCenter, child: footer),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: spec.child),
      ],
    );
  }

  static bool _wantsRail(LiveShellPlacement placement, BuildContext context) => switch (placement) {
    LiveShellPlacement.rail => true,
    LiveShellPlacement.bottom || LiveShellPlacement.none => false,
    LiveShellPlacement.adaptive =>
      (LiveEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? LiveSizing.railWidth) > 0,
  };
}

/// One destination of the composed column: its glyph over its label, on a
/// brighter frosted sheet when the caller has selected it. A hover or press tints
/// the cell through the core's [LiveBox]; a disabled one keeps its row, dims, and
/// takes no tap, because a tappable [glass.GlassContainer] would bring its own
/// ink and focus node into the tree (§15).
class _RailCell extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.iconSize,
    required this.radius,
    this.onSelected,
  });

  final LiveShellDestination destination;
  final bool selected;
  final double iconSize;
  final BorderRadius radius;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final enabled = destination.enabled;
    final tint = !enabled
        ? theme.colors.textDisabled
        : selected
        ? theme.colors.primary
        : theme.colors.textSecondary;

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(destination.icon, size: iconSize, color: tint),
        SizedBox(height: sizes.xxs),
        Text(
          destination.label,
          style: theme.text.caption.copyWith(color: tint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Semantics(
      selected: selected,
      child: LiveBox(
        style: (state) => Style(
          borderRadius: radius,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: sizes.xs),
          background: enabled && (state == InteractionState.hovered || state == InteractionState.pressed)
              ? glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0))
              : null,
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        enabled: enabled,
        onTap: enabled ? () => onSelected?.call(destination.id) : null,
        child: selected
            ? glass.GlassContainer(
                customBorderRadius: radius,
                color: glassTheme.color,
                opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
                padding: EdgeInsets.symmetric(horizontal: sizes.sm, vertical: sizes.xs),
                child: label,
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: sizes.sm),
                child: label,
              ),
      ),
    );
  }
}
