import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a Cupertino application shell from a [LanguageShellSpec] (§ surfaces).
///
/// Composed, not mapped — because `cupertino_ui` ships no navigation column. Its
/// two shell-shaped pieces are both unusable here: `cu.CupertinoTabScaffold`
/// binds a bottom bar of two to five destinations to a `cu.CupertinoTabView` per
/// tab, i.e. a body of its own, which is the opposite of the router-owned body
/// this contract carries; and `cu.CupertinoTabBar` is that same bottom bar on its
/// own — horizontal, full-width, index-controlled — which is why this package
/// already gives it to `navBar`. Neither takes a vertical column, so the rail is
/// assembled out of the library's own surface pieces: a
/// `cu.CupertinoListSection` (its grouped-surface background and hairline
/// separators) of `cu.CupertinoListTile` rows (leading glyph, title, inert when
/// given no `onTap`) — the same pieces iOS draws its sidebars out of.
///
/// The tinting is the library's, not the token's. The selected row takes the
/// accent: this fork's `CupertinoThemeData` has no `accentColor` at all, and its
/// accent role is `primaryColor` (mapped from the token in
/// `CupertinoThemeBuilder`), with `primaryContrastingColor` for what sits on the
/// fill. A live but unselected row uses `CupertinoColors.secondaryLabel`, a
/// disabled one `tertiaryLabel`, and the disabled row is refused by this builder —
/// its `onTap` is null — because the tile has no disabled state of its own.
///
/// [LanguageShellSpec.placement] is honoured on the rule the token shell uses, so
/// a narrow window switches form at the same width whichever language is active:
/// `rail` and an `adaptive` request with room for a pane compose the column,
/// `bottom` goes back through the adapter's `navBar` — the fork's own
/// `CupertinoTabBar`, with its guard for a bar it would assert on — and `none` or
/// a single destination hands the frame back to the page.
/// [LanguageShellSpec.trailing] has no slot in a library that has no rail, so
/// this builder pins it to the bottom of the column it composes; the bottom strip
/// has no such slot and drops it rather than inventing a place for it.
abstract final class CupertinoShellBuilder {
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
          // The strip is the fork's own bottom bar; its trailing content has
          // nowhere to go, so it is dropped here rather than faked as a row.
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
          child: ColoredBox(
            color: cu.CupertinoColors.systemGroupedBackground.resolveFrom(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cu.CupertinoListSection(
                  // The section paints the surface; the column behind it already
                  // is that surface, so the rows sit on it without a second fill.
                  backgroundColor: cu.CupertinoColors.transparent,
                  margin: EdgeInsets.zero,
                  children: [
                    for (final destination in spec.destinations)
                      _railTile(context, destination, destination.id == spec.selectedId, spec.onSelected),
                  ],
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

  /// One destination as the library's own row: accent when selected, inert when
  /// the caller says it cannot be taken.
  static Widget _railTile(
    BuildContext context,
    LiveShellDestination destination,
    bool selected,
    ValueChanged<String>? onSelected,
  ) {
    final accent = cu.CupertinoTheme.of(context);
    final enabled = destination.enabled;
    final tint = !enabled
        ? cu.CupertinoColors.tertiaryLabel.resolveFrom(context)
        : selected
        ? accent.primaryContrastingColor
        : cu.CupertinoColors.secondaryLabel.resolveFrom(context);
    final iconSize = LiveEnvironmentScope.maybeOf(context)?.geometry.iconSize ?? 18;

    return Semantics(
      selected: selected,
      child: cu.CupertinoListTile(
        leading: Icon(destination.icon, size: iconSize, color: tint),
        title: Text(
          destination.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        ),
        // A disabled destination keeps its row so the column does not shift when
        // it opens, and keeps no tap: the tile has no disabled state to ask for.
        onTap: enabled ? () => onSelected?.call(destination.id) : null,
        backgroundColor: selected ? accent.primaryColor : null,
      ),
    );
  }
}
