import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic application shell from a [LanguageShellSpec] (§ surfaces).
///
/// **Composed, not mapped** — for the same reason `navBar` and `tabBar` are: the
/// library's one navigation widget, `neu.NeuBottomNav`, cannot be this surface. It
/// asserts at least two items, takes a non-null `ValueChanged<int>` where the
/// contract's disabled destination is an inert row, hard-wraps itself in a
/// `SafeArea` plus an outer margin as a floating pill, and reaches for
/// `HapticFeedback` on every change. It is also horizontal by construction: this
/// package needs a *column* when a window has room for a rail, and the library has
/// no rail, sidebar or `NavigationView` at all.
///
/// So the pane is built from the library's own faces, the way the nav bar's slab
/// is, turned vertical: one full-height `neu.NeuContainer` on its default flat
/// face at [neu.NeuThemeData.depth] is the track, and it carries one cell per
/// destination — the chosen one sunk into [neu.NeuShape.pressed] with its glyph
/// and label in [neu.NeuThemeData.accentColor], the others left flat at zero
/// depth. Radius is read off the theme and inset for the cells exactly as
/// `NeumorphicNavBarBuilder` does, so the dishes nest inside the plane instead of
/// cutting it.
///
/// Three faces, three readings — the distinction this package keeps in every one
/// of them: `tabBar` **domes** the chosen cell (`convex`, raised out of the plane)
/// and floats free of any bar; `navBar` is a docked horizontal slab whose chosen
/// cell presses *into* it; the shell here is that same pressed reading drawn as a
/// **vertical column** beside the page. A Neumorphic page can therefore tell its
/// tabs from its bar from its shell by touch, without a single Material widget in
/// the subtree.
///
/// [LanguageShellSpec.placement] follows the rule the token shell uses, so the two
/// forms switch at the same width whichever language is active: `rail` and an
/// `adaptive` request with room for a pane compose the column at
/// `LiveEnvironmentScope`'s rail width (falling back to [LiveSizing.railWidth]),
/// `bottom` hands the strip back through the adapter's `navBar` — this package's
/// own slab — and `none` or a single destination gives the frame back to the page.
/// [LanguageShellSpec.trailing] has a slot in the column the composed pane
/// provides for itself, pinned under a `Spacer`; the bottom strip's library bar has
/// no such slot, so this builder drops it rather than inventing a place for it.
/// A disabled destination keeps its cell so the column does not shift when it
/// opens, and is refused here — the `NeuContainer` has no disabled state to ask
/// for — exactly as the token shell refuses it.
abstract final class NeumorphicShellBuilder {
  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // the frame is the page's own and the shell stands aside.
      return spec.child;
    }

    final adapter = LiveTheme.of(context).adapter;
    if (!_wantsRail(spec.placement, context)) {
      // The strip form is the language's own docked slab, so it comes back through
      // `navBar` rather than being drawn twice. That bar has no end-of-navigation
      // slot — `NeuBottomNav` is a floating pill and the composed cells fill the
      // width equally — so `trailing` is dropped here, as the contract allows,
      // instead of being smuggled in as another destination.
      return Column(
        children: [
          Expanded(child: spec.child),
          adapter.navBar(
            context,
            LanguageNavBarSpec(
              items: [
                for (final destination in spec.destinations)
                  LiveNavBarItem(label: destination.label, icon: destination.icon),
              ],
              index: spec.destinations.indexWhere((destination) => destination.id == spec.selectedId),
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

    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    return Row(
      children: [
        SizedBox(
          width: geometry?.railWidth ?? LiveSizing.railWidth,
          child: _Rail(
            destinations: spec.destinations,
            selectedId: spec.selectedId,
            iconSize: geometry?.iconSize ?? 18,
            trailing: spec.trailing,
            onSelected: (id) => spec.onSelected?.call(id),
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

/// The composed column: the theme's flat plane, and one sunk cell per destination.
class _Rail extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedId,
    required this.iconSize,
    required this.onSelected,
    this.trailing,
  });

  final List<LiveShellDestination> destinations;
  final String? selectedId;
  final double iconSize;
  final ValueChanged<String> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final inset = theme.token.scale.sizes.xs;
    final barRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(barRadius.topLeft.x <= inset ? 0.0 : barRadius.topLeft.x - inset);

    return neu.NeuContainer(
      borderRadius: barRadius,
      baseColor: surface.baseColor,
      depth: surface.depth,
      distance: surface.distance,
      padding: EdgeInsets.symmetric(horizontal: inset, vertical: inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final destination in destinations) ...[
            _Cell(
              destination: destination,
              selected: destination.id == selectedId,
              enabled: destination.enabled,
              iconSize: iconSize,
              onTap: destination.enabled ? () => onSelected(destination.id) : null,
              radius: cellRadius,
              surface: surface,
              theme: theme,
            ),
            SizedBox(height: inset),
          ],
          if (trailing case final Widget footer) ...[
            const Spacer(),
            Align(alignment: Alignment.bottomCenter, child: footer),
          ],
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const new({
    required this.destination,
    required this.selected,
    required this.enabled,
    required this.iconSize,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final LiveShellDestination destination;
  final bool selected;
  final bool enabled;
  final double iconSize;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final LiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color tint;
    if (!enabled) {
      tint = theme.colors.textDisabled;
    } else if (selected) {
      tint = surface.accentColor;
    } else {
      tint = theme.colors.textSecondary;
    }

    return Semantics(
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: neu.NeuContainer(
          shape: selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
          borderRadius: radius,
          baseColor: surface.baseColor,
          depth: selected ? surface.depth : 0.0,
          distance: selected ? surface.distance : 0.0,
          padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.xs, vertical: theme.token.scale.sizes.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, color: tint, size: iconSize),
              SizedBox(height: theme.token.scale.sizes.xxs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.text.caption.copyWith(
                  color: tint,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
