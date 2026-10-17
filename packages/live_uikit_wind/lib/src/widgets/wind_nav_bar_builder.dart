import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind destination strip from a [LanguageNavBarSpec] (§9 NavBar).
///
/// Composed, not mapped: Wind has no navigation bar. The strip is the library's
/// own container doing a bar's job — a `WDiv` on its `bg-white dark:bg-gray-900`
/// elevated pair, closed by the `border-t border-gray-200 dark:border-gray-700`
/// hairline that is Tailwind's own separator — and each destination is the
/// library's own interactive part, a `WAnchor` over a `WDiv` column carrying
/// `WIcon` over `WText`, the destinations sharing the width the way `Expanded`
/// gives a flex share to a `flex-1` child.
///
/// The chosen destination takes the fork's `selected:` state on the glyph and the
/// label (`selected:text-primary-500`, the accent that reaches this subtree from
/// the token through `WindThemeBuilder` §8.1) while the rest rest in Wind's
/// `text-gray-500 dark:text-gray-400`; the pointer state takes its hover fill. The
/// states are passed to the styled `WDiv` as well as to the anchor for the reason
/// §9 records on the tab strip — a `hover:` class makes `WDiv` wrap itself in a
/// gestureless anchor, and it reads its state from the nearest provider.
///
/// [LanguageNavBarSpec.enabled] is the fork's inert state: `isDisabled` on every
/// anchor, so `disabled:opacity-50` paints and nothing reports. The bar's height
/// comes from the layout environment like the rest of the strip's geometry, but the icon size
/// does not: Wind's glyph step is a class token (`text-lg`), and interpolating
/// `text-[..]` per device is the runtime-into-cache pattern its widgets warn
/// against, so the strip keeps the library's own step.
abstract final class WindNavBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = geometry?.navBarHeight ?? 56;
    final select = spec.enabled ? spec.onChanged : null;

    return wind.WDiv(
      className: 'flex flex-col w-full bg-white dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700',
      children: [
        SizedBox(
          height: height,
          child: wind.WDiv(
            className: 'flex flex-row items-center w-full h-full',
            children: [
              for (var index = 0; index < spec.items.length; index++)
                Expanded(child: _cell(spec.items[index], index, index == spec.index, select)),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _cell(LiveNavBarItem item, int index, bool selected, ValueChanged<int>? select) {
    final states = selected ? _selectedStates : null;
    return wind.WAnchor(
      onTap: select == null ? null : () => select(index),
      isDisabled: select == null,
      states: states,
      child: wind.WDiv(
        className: _cellClasses,
        states: states,
        child: wind.WDiv(
          className: 'flex flex-col items-center gap-1 w-full',
          children: [
            wind.WIcon(item.icon, className: 'text-lg'),
            wind.WText(item.label, className: 'text-xs truncate w-full text-center'),
          ],
        ),
      ),
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _cellClasses =
      'flex flex-col items-center justify-center w-full h-full text-gray-500 dark:text-gray-400'
      ' transition-colors hover:bg-gray-50 dark:hover:bg-gray-800'
      ' selected:text-primary-500 disabled:opacity-50';
}
