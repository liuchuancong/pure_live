import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind slider from a [LanguageSliderSpec] (§9 Slider).
///
/// Composed, not mapped: `fluttersdk_wind` ships no slider at all. The rail and
/// the thumb are therefore the library's own surfaces — `WDiv` over `WDiv` —
/// tinted with its own colour tokens (`bg-primary-500` for the filled run, the
/// `bg-gray-200 dark:bg-gray-700` pair for the unfilled one, `rounded-full`,
/// `border` and `shadow` from `WindThemeData`'s radius/border/shadow maps), the
/// same rail-plus-thumb shape `WSwitch` documents for its own thumb.
///
/// Two jobs fall outside the fork, and both fall to the widgets layer rather
/// than to a Material part:
///
/// * **The fraction.** `w-*` and `basis-*` are compile-time class tokens and the
///   library warns against interpolating a runtime value into a className
///   because it bloats its parser cache, so the fill width and the thumb offset
///   are computed from a measured rail and applied with `Positioned`. The
///   measurement uses `MediaQuery`'s width when the incoming main axis
///   is unbounded, which is the width `WDiv`'s own grid layout takes.
/// * **The drag.** `WAnchor` is the library's only interaction widget and it
///   offers tap, long-press and double-tap, so the drag sits on a
///   `GestureDetector` over the parts; a tap positions the value the same way,
///   which is what a pointer user expects of a rail.
///
/// [LanguageSliderSpec.focusNode] has no slot here for the reason §9 already
/// records for the button — the fork keeps focus inside `WAnchor` — so it is
/// reported as unexpressible rather than answered with a second node.
abstract final class WindSliderBuilder {
  /// The thumb's side, and the height the rail is centred inside.
  static const double thumbSide = 16;

  /// The rail's thickness — Wind's own `h-1` step at the 4pt base unit.
  static const double trackHeight = 4;

  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) {
    // One verdict decides both the callback and the state the fork paints from,
    // so a Wind rail can never look live while it is dead (§2.3) — the same rule
    // the switch and the checkbox builders follow.
    final interactive = spec.enabled && spec.onChanged != null;
    final states = interactive ? null : _disabledStates;
    final ratio = _ratio(spec);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
          // The thumb rides the last `thumbSide` of the rail, so the fill ends at
          // its centre and neither part leaves the box at either stop.
          final travel = width > thumbSide ? width - thumbSide : 0.0;
          final thumbLeft = travel * ratio;
          final filled = (thumbLeft + thumbSide / 2).clamp(0.0, width);
          void report(double x) {
            if (!interactive) {
              return;
            }
            final at = x.clamp(0.0, width);
            spec.onChanged!(spec.min + (width == 0 ? 0 : at / width) * (spec.max - spec.min));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: interactive ? (details) => report(details.localPosition.dx) : null,
            onHorizontalDragUpdate: interactive ? (details) => report(details.localPosition.dx) : null,
            child: SizedBox(
              width: width,
              height: thumbSide,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (thumbSide - trackHeight) / 2,
                    child: wind.WDiv(className: _trackClasses, states: states),
                  ),
                  Positioned(
                    left: 0,
                    width: filled,
                    top: (thumbSide - trackHeight) / 2,
                    child: wind.WDiv(className: _fillClasses, states: states),
                  ),
                  Positioned(
                    left: thumbLeft,
                    top: 0,
                    child: wind.WDiv(className: _thumbClasses, states: states),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static const Set<String> _disabledStates = <String>{'disabled'};

  static const String _trackClasses = 'w-full h-1 rounded-full bg-gray-200 dark:bg-gray-700 disabled:opacity-50';

  static const String _fillClasses = 'w-full h-1 rounded-full bg-primary-500 disabled:opacity-50';

  static const String _thumbClasses =
      'size-4 rounded-full bg-white border border-gray-300 dark:border-gray-600 shadow disabled:opacity-50';

  /// The completion fraction, clamped so a spec whose value sits outside its own
  /// bounds still draws inside the rail.
  static double _ratio(LanguageSliderSpec spec) {
    final range = spec.max - spec.min;
    if (range <= 0) {
      return 0;
    }
    return ((spec.value - spec.min) / range).clamp(0.0, 1.0);
  }
}
