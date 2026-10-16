import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS application shell from a [LanguageShellSpec] (§ surfaces).
///
/// What is mapped: [macos.SidebarItems] is the library's own navigation list — a
/// scrollable column whose rows it paints itself, the selected one with the
/// system-accent chip and white text — and [macos.SidebarItem] is the row
/// descriptor it consumes. The spec's destinations become those descriptors
/// one-for-one, so the accent decision, the row metrics, the icon tint and the
/// selection painting all stay the library's.
///
/// What is composed: the column *around* those rows, and the plumbing between a
/// row and the router. Neither `Sidebar` nor `SidebarItem` is a widget in
/// `macos_ui` 2.2.2: both are plain descriptor classes with no `build`. `Sidebar`
/// is read only by `MacosWindow` (`window.dart`), which turns its
/// `minWidth`/`maxWidth`/`isResizable`/`top`/`bottom` fields into a resizable
/// split around `sidebar.builder`; `SidebarItem` is read by `SidebarItems`, which
/// mounts a private row widget per descriptor. A shell that is not a window cannot
/// mount the first, so the shell draws the split itself: a fixed-width,
/// canvas-coloured column holding `SidebarItems` plus the trailing entry. The
/// consequences are stated plainly — this column is not drag-resizable and it has
/// no window-breakpoint auto-hide, because those are `MacosWindow` behaviours the
/// descriptor only asks for, and the window frame belongs to the language's
/// `scaffold` (`MacosScaffold`), not to the shell. The shell adds one sidebar
/// beside the page and nothing else: no `MacosWindow`, no `ToolBar`, no title bar.
///
/// [LanguageShellSpec.placement] is honoured with the same rule the shared token
/// shell uses — `rail` always, `bottom` never, `adaptive` whenever the environment
/// reports a rail width above zero — so the same app changes form at the same
/// window width whichever language is active. The rail's own *width* is not that
/// rule: it is this library's metric, floored at the width a sidebar row needs
/// ([MacosShellBuilder._minRailWidth]), because `_SidebarItem` sizes its row to a
/// fixed `134 + visualDensity.horizontal` and a token rail of 88 would crush it.
///
/// [LanguageShellSpec.trailing] has no slot here either: `SidebarItems` takes a
/// list of rows and nothing else (the descriptor's `bottom` slot is `MacosWindow`'s
/// code, unreachable from outside a window), so the shell pins it under the list
/// inside its own column. The `bottom` strip form has no footer at all, so that
/// form drops it — like the token shell and Material's rail.
///
/// [LiveShellDestination.enabled] has no counterpart in the library: `SidebarItem`
/// has no `disabled` field (unlike Material's `NavigationRailDestination`) and
/// `SidebarItems.onChanged` is required, so every row is tappable and the shell
/// refuses the tap itself — the same way the Fluent pane does — leaving a disabled
/// destination visible, tinted and inert rather than missing.
abstract final class MacosShellBuilder {
  /// The narrowest rail this shell will draw.
  ///
  /// `macos_ui`'s sidebar row is a `Container(width: 134.0 + visualDensity.horizontal)`
  /// inside a `ListView` padded 10 on every side, so anything under 154 makes the
  /// row shrink and its label ellipsis out of usefulness.
  static const double _minRailWidth = 154;

  /// Builds the shell for [spec].
  static Widget build(BuildContext context, LanguageShellSpec spec) {
    if (spec.placement == LiveShellPlacement.none || spec.destinations.length < 2) {
      // One destination is not a navigation choice, and a shell asked for none:
      // in both cases the frame is the page's own and the shell stands aside.
      return spec.child;
    }

    if (!_wantsRail(spec.placement, context)) {
      // The strip form is the library's own destination row, assembled by this
      // language's nav bar builder — the shell delegates rather than drawing a
      // second one, so the two forms cannot drift apart. `trailing` has no slot
      // in a strip and is dropped, as the contract documents.
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

    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final requested = geometry?.railWidth ?? LiveSizing.railWidth;
    final railWidth = requested < _minRailWidth ? _minRailWidth : requested;
    final selected = spec.destinations.indexWhere((destination) => destination.id == spec.selectedId);

    return Row(
      children: [
        SizedBox(
          width: railWidth,
          child: ColoredBox(
            // The library's own surface colour: `MacosWindow` paints the sidebar
            // over its vibrancy layer, which a shell has no business installing.
            color: macos.MacosTheme.of(context).canvasColor,
            child: Column(
              children: [
                // Expanded because the list scrolls: `SidebarItems` is a `ListView`,
                // and a sidebar that cannot scroll is not a macOS sidebar.
                Expanded(
                  child: macos.SidebarItems(
                    items: [
                      for (final destination in spec.destinations)
                        _destinationItem(theme: theme, destination: destination),
                    ],
                    // The pane has no "nothing selected": its constructor asserts
                    // `currentIndex >= 0` and its build asserts the index is inside
                    // the list, unlike Material's nullable rail index and Fluent's
                    // nullable `selected`. An id that matches nothing therefore
                    // selects the first row — a degenerate case (the router always
                    // reports an id it is showing), handled by complying with the
                    // library rather than crashing in it.
                    currentIndex: selected < 0 ? 0 : selected,
                    onChanged: (index) {
                      final destination = spec.destinations[index];
                      // Refused here: the row itself is always enabled because the
                      // library has no way to draw it otherwise.
                      if (destination.enabled) {
                        spec.onSelected?.call(destination.id);
                      }
                    },
                    cursor: SystemMouseCursors.click,
                  ),
                ),
                if (spec.trailing != null)
                  // Composed footer: `SidebarItems` ends with its last row, so the
                  // trailing entry is pinned below the list by this column, padded
                  // to the list's own 10-unit inset.
                  Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), child: spec.trailing),
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
    // The same predicate the shared token shell reads, so the form switch happens
    // at the same width in every language (§ surfaces).
    LiveShellPlacement.adaptive =>
      (LiveEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? LiveSizing.railWidth) > 0,
  };

  static macos.SidebarItem _destinationItem({required LiveTheme theme, required LiveShellDestination destination}) {
    // `label` is a Widget the library wraps in its own text style, and a `Text`
    // style merges into that inherited style, so only the disabled tint is set
    // here: the row keeps the library's size and weight for every other state.
    final tint = destination.enabled ? null : theme.colors.textDisabled;
    return macos.SidebarItem(
      leading: macos.MacosIcon(destination.icon),
      label: Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tint)),
    );
  }
}
