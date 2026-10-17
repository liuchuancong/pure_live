import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// Composed, not mapped. The fork does have `WTabs`, but it is a *tab view*: the
/// row is welded to a content panel (`panelBuilder` is required and the widget
/// renders the panel under the strip), it paints a `WText` per tab and nothing
/// else, so a caller who already has the body — which is every caller, since the
/// router owns it — gets an empty panel, and [LiveTab.icon] has nowhere to go. So
/// the strip here is made of the parts `WTabs` itself is made of: a `WAnchor` per
/// tab over a `WDiv`, the active one carrying the library's own `selected:`
/// tokens, on a rule-drawn list.
///
/// The accent does the selecting and the neutral greys do the resting: Wind's
/// `primary` scale reaches this subtree flat — `WindThemeBuilder` expands the one
/// token accent into every shade (§8.1) — so `text-primary-500` and
/// `border-primary-500` are the accent, and there is no tint step to invent. The
/// underline is reserved on every tab (`border-b-2 border-transparent`) so
/// choosing one moves nothing.
///
/// One fork detail is load-bearing: a `WDiv` whose className carries `hover:`
/// wraps *itself* in a gestureless `WAnchor`, and a `WDiv` reads its state from
/// the nearest provider, so `selected:` tokens only fire when the set is passed
/// to the styled `WDiv` as well as to the anchor — which is what `WTabs` does for
/// its own tabs. `disabled:` needs no double pass because the fork's inert state
/// does chain through a gestureless anchor.
///
/// [LanguageTabsSpec.spacing] belongs to the core's own laying-out; the strip uses the
/// library's own tab padding.
abstract final class WindTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return wind.WDiv(
      className: 'flex flex-row w-full border-b border-gray-200 dark:border-gray-700',
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          _tab(spec.tabs[index], index, index == spec.index, select),
      ],
    );
  }

  static Widget _tab(LiveTab tab, int index, bool selected, ValueChanged<int>? select) {
    final states = selected ? _selectedStates : null;
    return wind.WAnchor(
      onTap: select == null ? null : () => select(index),
      isDisabled: select == null,
      states: states,
      semanticLabel: tab.label,
      child: wind.WDiv(
        className: _tabClasses,
        states: states,
        child: wind.WDiv(
          className: 'flex flex-row items-center gap-2',
          children: [
            if (tab.icon case final icon?) wind.WIcon(icon, className: 'text-xs'),
            wind.WText(tab.label, className: 'truncate'),
          ],
        ),
      ),
    );
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _tabClasses =
      'px-4 py-2 text-sm border-b-2 border-transparent text-gray-600 dark:text-gray-400 transition-colors'
      ' hover:text-primary-500'
      ' selected:text-primary-500 selected:border-primary-500'
      ' disabled:opacity-50';
}
