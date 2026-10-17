import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI application shell from a [LanguageShellSpec] (§ surfaces).
///
/// `mu.NavigationRail` is the library's own structural navigation: a destination
/// is an icon over a label, the selection is painted with the Material 3
/// indicator pill, and a destination can be `disabled` — the one shell library
/// that models it, so this builder maps [LiveShellDestination.enabled] onto it
/// instead of refusing the tap the way the Fluent pane has to. The rail is only
/// the strip: Material composes it beside the body, so the shell draws that
/// `Row` itself and leaves the page frame to the language's `scaffold`.
///
/// [LanguageShellSpec.placement] is honoured rather than folded: a `bottom`
/// request goes back through the adapter's `navBar` — the fork's own
/// `NavigationBar`, with its guard for a bar too short to satisfy its assert —
/// and an `adaptive` one reads the same window geometry the rest of the layout
/// reads, so a narrow window switches form at the same width whichever language is
/// active.
/// [LanguageShellSpec.trailing] has a real slot in the rail and is pinned to its
/// bottom; the bottom strip has none, so that form drops it.
abstract final class MaterialShellBuilder {
  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // the frame is the page's own and the shell stands aside.
      return spec.child;
    }

    if (!_wantsRail(spec.placement, context)) {
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

    final selected = spec.destinations.indexWhere((destination) => destination.id == spec.selectedId);
    return Row(
      children: [
        mu.NavigationRail(
          // Out of range is "nothing selected": the rail asserts a null index
          // rather than an index into a list it has not been given.
          selectedIndex: selected < 0 ? null : selected,
          labelType: mu.NavigationRailLabelType.all,
          onDestinationSelected: (index) {
            final destination = spec.destinations[index];
            if (destination.enabled) {
              spec.onSelected?.call(destination.id);
            }
          },
          destinations: [
            for (final destination in spec.destinations)
              mu.NavigationRailDestination(
                icon: Icon(destination.icon),
                label: Text(destination.label),
                disabled: !destination.enabled,
              ),
          ],
          trailing: spec.trailing,
          trailingAtBottom: spec.trailing != null,
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
