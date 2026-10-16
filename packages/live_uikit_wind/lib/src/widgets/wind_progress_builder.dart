import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind progress bar from a [LanguageProgressSpec] (§9 Progress).
///
/// Composed, not mapped: the fork ships no progress bar. Both halves are the
/// library's own container — a `WDiv` rail in its `bg-gray-200 dark:bg-gray-700`
/// neutral pair, a `WDiv` run in its `bg-primary-500` accent, closed by
/// `rounded-full` and `overflow-hidden` so the run is clipped to the rail's own
/// radius — with [LanguageProgressSpec.height] taken by a `SizedBox` and the
/// fraction by a `FractionallySizedBox`, which is exactly how `WDiv` renders its
/// own `w-1/2` token. A className is not interpolated with the fraction: the
/// library caches parsed class strings, and its widgets say that a runtime value
/// belongs in an inline prop, not in a `w-[..]` token.
///
/// [LanguageProgressSpec.barColor] is such a runtime value, so it arrives through
/// the fork's own `WDiv.backgroundColor` hook, which overrides the `bg-*` class
/// when given and leaves the accent alone when not.
///
/// An unknown completion cannot slide: `WSwitch` records that Wind has no
/// transform parser, so a moving indeterminate run is not something this library
/// can express at all. `animate-pulse` is — the library's documented
/// skeleton-work affordance — so `value: null` paints the full-width rail
/// breathing, and [LanguageProgressSpec.showLabel] is dropped with it because
/// there is no percentage of an unknown quantity to print.
abstract final class WindProgressBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final value = spec.value;
    final bar = wind.WDiv(
      className: 'w-full h-full rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700',
      child: value == null
          ? wind.WDiv(className: 'w-full h-full rounded-full animate-pulse', backgroundColor: spec.barColor)
          : FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: wind.WDiv(className: 'w-full h-full rounded-full bg-primary-500', backgroundColor: spec.barColor),
            ),
    );
    final track = SizedBox(height: spec.height, child: bar);

    final percent = value == null ? null : (value.clamp(0.0, 1.0) * 100).round();
    if (percent == null || !spec.showLabel) {
      return track;
    }
    return wind.WDiv(
      className: 'flex flex-row items-center gap-2 w-full',
      children: [
        Expanded(child: track),
        wind.WText('$percent%', className: 'text-xs text-gray-500 dark:text-gray-400 shrink-0'),
      ],
    );
  }
}
