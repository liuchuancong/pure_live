import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind segmented control from a [LanguageSegmentedSpec] (§9 Segmented).
///
/// Composed, not mapped: the fork has no segmented track. Its own answer to "one
/// choice out of a row" is a row of `WButton`s plus the `selected:` state prefix
/// — the very mechanism `WTabs` uses to mark its active tab — so the track is
/// assembled here from those: one button per segment, and the chosen one carries
/// `selected:bg-primary-500 selected:text-white` through the library's state
/// pipeline (`WButton.states` → `WindAnchorStateProvider` → `WindParser`).
///
/// The fill rather than an underline is what separates a segment from a tab in
/// this library, and it also settles the tint question: `WindThemeBuilder` seeds
/// Wind's `primary` scale as one flat accent (§8.1), so a `bg-primary-100` tint
/// would paint solid accent behind dark text. Wind's neutral pair carries the
/// hover, the accent carries the choice.
///
/// [LanguageSegmentedSpec.expand] gives every segment an equal share by wrapping
/// each button in `Expanded` with `w-full` on it: `flex-1` is a `WDiv`/`WText`
/// feature and `WButton` reads only its own width classes, never a flex share. A
/// group with nothing to report is the fork's own inert state — `disabled: true`
/// with no `onTap` — so `disabled:opacity-50` activates and the segments stop
/// answering.
abstract final class WindSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final select = spec.enabled ? spec.onChanged : null;
    return wind.WDiv(
      className: spec.expand ? 'flex flex-row items-center gap-1 w-full' : 'flex flex-row items-center gap-1',
      children: [for (var index = 0; index < spec.labels.length; index++) _segment(spec, index, select)],
    );
  }

  static Widget _segment(LanguageSegmentedSpec spec, int index, ValueChanged<int>? select) {
    final inert = select == null;
    final label = spec.labels[index];
    final button = wind.WButton(
      onTap: inert ? null : () => select(index),
      disabled: inert,
      states: index == spec.index ? _selectedStates : null,
      semanticLabel: label,
      className: spec.expand ? '$_segmentClasses w-full' : _segmentClasses,
      child: wind.WText(label, className: 'text-center truncate'),
    );
    return spec.expand ? Expanded(child: button) : button;
  }

  static const Set<String> _selectedStates = <String>{'selected'};

  static const String _segmentClasses =
      'px-4 py-2 rounded-lg text-sm text-gray-600 dark:text-gray-300 transition-colors'
      ' hover:bg-gray-100 dark:hover:bg-gray-800'
      ' selected:bg-primary-500 selected:text-white'
      ' disabled:opacity-50';
}
