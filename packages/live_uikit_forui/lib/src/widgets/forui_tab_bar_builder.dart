import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';

/// Builds a ForUI tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// `FTabs` is the library's tab widget and it is mapped, with one honest cost: every
/// `FTabEntry` carries a content panel, because the library's tabs are a *tab view*.
/// This contract's tabs are a strip — the caller's router owns the body in every
/// language — so each entry gets an empty box and the strip arrives with the library's
/// small content gap under it. That is what buys the library's own indicator, label
/// weight and focus ring; composing the bar out of `FTappable`s instead would have
/// re-drawn those decisions by hand.
///
/// The selection is lifted ([forui.FTabControl.lifted]): the spec's index is what the
/// strip shows and a tap only reports the index. `FTabs` moves its indicator when the
/// index it was handed actually changes, which keeps the strip controlled and undoes a
/// refused tap by itself. A disabled strip therefore keeps its look and reports nothing —
/// forui has no disabled state for tabs, and the observable behaviour the spec asks for
/// is the one the lifted control gives (§9).
///
/// Two things are handled rather than mapped: [LanguageTabsSpec.spacing] has no slot,
/// because the library pads its own strip, and the controller cannot show "nothing
/// selected", so an out-of-range [LanguageTabsSpec.index] is clamped into the tabs that
/// exist. An empty list returns nothing at all, because `FTabs` asserts on it.
abstract final class ForuiTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final count = spec.tabs.length;
    if (count == 0) {
      return const SizedBox.shrink();
    }
    final select = spec.enabled ? spec.onChanged : null;

    return forui.FTabs(
      // The library keeps one tab controller for the widget's lifetime and does not
      // resize it when the tab count changes, so a changed count remounts the strip
      // instead of leaving it pointed at the old length.
      key: ValueKey('forui-tabs-$count'),
      control: forui.FTabControl.lifted(
        index: spec.index.clamp(0, count - 1),
        onChange: (index) => select?.call(index),
      ),
      children: [for (final tab in spec.tabs) forui.FTabEntry(label: _label(tab), child: const SizedBox.shrink())],
    );
  }

  static Widget _label(LiveTab tab) => switch (tab.icon) {
    final IconData glyph => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(glyph),
        Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    ),
    null => Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
  };
}
