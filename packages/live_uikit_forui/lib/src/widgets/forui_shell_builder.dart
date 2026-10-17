import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI application shell from a [LanguageShellSpec] (§ surfaces).
///
/// `FSidebar` is the library's own structural navigation column, and it is
/// usable on its own: its only ancestor requirement is the `FTheme` scope this
/// adapter already installs — an `FSidebarItem` resolves its style through
/// `FSidebarData` to the theme's `sidebarStyle` when no `FSidebarGroup` wraps it,
/// and the sidebar paints
/// nothing but its own header/content/footer strip. It does *not* carry a body
/// area — the router-owned page stays outside it — so the shell composes the
/// `Row[sidebar, Expanded(child)]` itself, exactly as Material composes its
/// `NavigationRail`. The library's default width (256, a constraint inside
/// `FSidebarStyle`) is kept rather than the token's rail metric: the form rules
/// are the contract's, and the column's own look is the language's.
///
/// [LiveShellDestination.enabled] has no slot on `FSidebarItem` — the widget
/// models a `selected` state but never a disabled one — so a disabled
/// destination is refused here the way the Fluent pane has to refuse it: the
/// item keeps its place in the column, inert, with its label still readable.
///
/// [LiveShellPlacement] is honoured the same way every language honours it:
/// `bottom` goes back through the adapter's `navBar` (the library's own
/// `FBottomNavigationBar`), and `adaptive` reads the same window geometry the
/// token shell reads, so a narrow window switches form at the same width
/// whichever language is active. [LanguageShellSpec.trailing] has a real slot
/// in the sidebar — its sticky footer — and the bottom strip has none, so that
/// form drops it rather than inventing a place for it.
abstract final class ForuiShellBuilder {
  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // the frame is the page's own and the shell stands aside.
      return spec.child;
    }

    if (!_wantsRail(spec.placement, context)) {
      // The bottom strip is the navBar control's, delegated rather than
      // re-drawn here; its spec takes no trailing, so the slot is dropped.
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

    return Row(
      children: [
        forui.FSidebar(
          // The sticky footer is the library's own name for this contract's
          // trailing slot.
          footer: spec.trailing,
          children: [
            for (final destination in spec.destinations)
              forui.FSidebarItem(
                icon: Icon(destination.icon),
                label: Text(destination.label),
                selected: destination.id == spec.selectedId,
                // A disabled destination — or a shell with no callback at all —
                // gets a null onPress, which is how the library spells "inert";
                // it has no dimmed disabled state of its own to map onto.
                onPress: destination.enabled && spec.onSelected != null
                    ? () => spec.onSelected!(destination.id)
                    : null,
              ),
          ],
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
