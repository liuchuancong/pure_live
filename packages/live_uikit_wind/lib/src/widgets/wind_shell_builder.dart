import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind application shell from a [LanguageShellSpec] (§ surfaces).
///
/// Composed, not mapped — `fluttersdk_wind` 1.8.4 is a styling library. It ships
/// styled parts (`WDiv`, `WCard`, `WButton`, `WAnchor`, `WText`, `WIcon`) and
/// Tailwind theme maps, and no navigation structure of any kind: nothing in it
/// binds a column of destinations to a body. So the rail is the same parts this
/// package's nav bar strip is made of, turned through a quarter turn — a `WDiv`
/// surface on its `bg-white dark:bg-gray-900` pair, closed by the `border-r
/// border-gray-200 dark:border-gray-700` hairline that is Tailwind's own
/// separator, of `WAnchor` cells over a `WDiv` column carrying `WIcon` over
/// `WText`.
///
/// The colour is the library's own map, not a token lookup: the accent reaches
/// this subtree flat — `WindThemeBuilder` expands the one token accent into every
/// `primary` shade (§8.1) — so `selected:text-primary-500` is the token accent
/// while `text-gray-500 dark:text-gray-400` rests, `hover:bg-gray-50
/// dark:hover:bg-gray-800` takes the pointer, and `selected:bg-gray-100
/// dark:selected:bg-gray-800` fills the chosen row. The fork's `selected:` state
/// is passed to the styled `WDiv` as well as to the anchor for the reason §9
/// records on the tab strip: a `hover:` class makes `WDiv` wrap itself in a
/// gestureless anchor and it reads its state from the nearest provider.
///
/// [LiveShellDestination.enabled] maps onto the library's inert state rather than
/// being refused locally: `isDisabled` on the anchor suppresses hover and focus,
/// swallows the gesture and activates `disabled:opacity-50` for the leaves below,
/// while the cell keeps its place in the column so nothing shifts when it opens.
/// The callback is also not built for a disabled destination, so the two agree.
///
/// The width and the form switch come from the layout environment on the rule the
/// token shell uses — `railWidth > 0` — so a narrow window changes shape at the
/// same width whichever language is active; the glyph step, by contrast, is one
/// of the library's own class tokens (`text-lg`), because interpolating
/// `text-[..]` per device is the runtime-into-cache pattern its widgets warn
/// against.
abstract final class WindShellBuilder {
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
          // The phone form goes back through the adapter's nav bar — the strip
          // this package already composes out of the same parts — rather than
          // drawing a second one here. That strip has no footer slot, so
          // [LanguageShellSpec.trailing] is dropped instead of invented as a row.
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

    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    return Row(
      children: [
        SizedBox(
          width: geometry?.railWidth ?? LiveSizing.railWidth,
          child: wind.WDiv(
            className:
                'flex flex-col w-full h-full bg-white dark:bg-gray-900 border-r border-gray-200 dark:border-gray-700',
            children: [
              for (final destination in spec.destinations)
                _cell(
                  destination,
                  selected: destination.id == spec.selectedId,
                  onSelected: spec.onSelected,
                ),
              if (spec.trailing case final Widget footer) ...[
                const Expanded(child: SizedBox.shrink()),
                Align(alignment: Alignment.bottomCenter, child: footer),
              ],
            ],
          ),
        ),
        Expanded(child: spec.child),
      ],
    );
  }

  /// The same rule the token shell uses, so both languages bend at one width.
  static bool _wantsRail(LiveShellPlacement placement, BuildContext context) => switch (placement) {
    LiveShellPlacement.rail => true,
    LiveShellPlacement.bottom || LiveShellPlacement.none => false,
    LiveShellPlacement.adaptive =>
      (LiveEnvironmentScope.maybeOf(context)?.geometry.railWidth ?? LiveSizing.railWidth) > 0,
  };

  /// One destination as the library's own interactive column cell.
  static Widget _cell(
    LiveShellDestination destination, {
    required bool selected,
    required ValueChanged<String>? onSelected,
  }) {
    final enabled = destination.enabled;
    final states = selected ? _selectedStates : null;
    return Semantics(
      selected: selected,
      child: wind.WAnchor(
        // A disabled destination is the fork's inert state, not a local refusal:
        // `isDisabled` paints `disabled:opacity-50` and ignores the gesture, and
        // the tap closure is not built for it either, so the look and its own label builder
        // cannot disagree.
        isDisabled: !enabled,
        onTap: enabled && onSelected != null ? () => onSelected(destination.id) : null,
        states: states,
        semanticLabel: destination.label,
        child: wind.WDiv(
          className: _cellClasses,
          states: states,
          child: wind.WDiv(
            className: 'flex flex-col items-center gap-1 w-full',
            children: [
              wind.WIcon(destination.icon, className: 'text-lg'),
              wind.WText(destination.label, className: 'text-xs truncate w-full text-center'),
            ],
          ),
        ),
      ),
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _cellClasses =
      'flex flex-col items-center justify-center w-full px-2 py-3'
      ' text-gray-500 dark:text-gray-400 transition-colors'
      ' hover:bg-gray-50 dark:hover:bg-gray-800'
      ' selected:text-primary-500 selected:bg-gray-100 dark:selected:bg-gray-800'
      ' disabled:opacity-50';
}
