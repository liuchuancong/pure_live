import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind list row from a [LanguageListRowSpec] (§9 ListRow).
///
/// Composed, not mapped: the fork has no list row, but it does have every part
/// one — the interactive `WAnchor` the library's own `WTabs`, `WSwitch` and
/// `WCheckbox` are built on, the `WDiv` container that carries the row's tone, and
/// `WText` for the two lines. So the row is anchored, flexed and toned in the
/// fork's vocabulary: `px-4 py-3` for its padding, `hover:bg-gray-100
/// dark:hover:bg-gray-800` for the pointer state, `gap-3` for the space between
/// the parts, and the library's `text-gray-500 dark:text-gray-400` step for the
/// secondary line.
///
/// [LanguageListRowSpec.selected] takes the two marks Wind gives a chosen row: a
/// fill one step above the hover fill, and an accent bar reserved on every row
/// (`border-l-2 border-transparent`) that only the chosen one recolours with
/// `selected:border-primary-500`. The accent has to be a mark rather than a wash:
/// `WindThemeBuilder` seeds Wind's `primary` scale flat (§8.1), so a
/// `bg-primary-*` fill is the full accent and dark text would sit on it unread.
///
/// [LanguageListRowSpec.divided] draws the hairline as the library's own 1px
/// surface rule; [LanguageListRowSpec.onLongPress] is a gesture the anchor takes
/// natively. [LanguageListRowSpec.focusNode] and `autofocus` have no slot — the
/// fork creates and tracks the node inside `WAnchor`, so they are recorded as
/// unexpressible exactly as §9 records them for the button.
abstract final class WindListRowBuilder {
  /// Builds the row for [spec].
  static Widget build(BuildContext context, LanguageListRowSpec spec) {
    final interactive = spec.onTap != null || spec.onLongPress != null;
    final states = spec.selected ? _selectedStates : null;

    final row = wind.WAnchor(
      onTap: interactive ? spec.onTap : null,
      onLongPress: interactive ? spec.onLongPress : null,
      isDisabled: !interactive,
      // No `semanticLabel`: the fork excludes the descendant subtree when one is
      // set, and a settings row carries a live trailing control — a switch, a
      // menu button — whose own semantics must survive. The merged title and
      // subtitle name the row instead (§14).
      states: states,
      child: wind.WDiv(
        className: _rowClasses,
        states: states,
        children: [
          ?spec.leading,
          Expanded(
            child: wind.WDiv(
              className: 'flex flex-col gap-0.5 w-full',
              children: [
                wind.WText(spec.title, className: 'text-sm text-gray-900 dark:text-gray-100 truncate'),
                if (spec.subtitle case final subtitle?)
                  wind.WText(subtitle, className: 'text-xs text-gray-500 dark:text-gray-400 truncate'),
              ],
            ),
          ),
          ?spec.trailing,
        ],
      ),
    );

    if (!spec.divided) {
      return row;
    }
    return wind.WDiv(
      className: 'flex flex-col w-full',
      children: [
        row,
        const wind.WDiv(className: 'w-full h-[1px] bg-gray-200 dark:bg-gray-700'),
      ],
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _rowClasses =
      'flex flex-row items-center gap-3 w-full px-4 py-3 border-l-2 border-transparent transition-colors'
      ' hover:bg-gray-50 dark:hover:bg-gray-800'
      ' selected:bg-gray-100 dark:selected:bg-gray-800 selected:border-primary-500'
      ' disabled:opacity-60';
}
