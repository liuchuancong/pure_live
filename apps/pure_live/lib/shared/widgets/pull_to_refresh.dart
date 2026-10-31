import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The house pull-to-refresh indicator: a spinner easing down from under the
/// surface's top edge as the drag grows, on the kit's surface with the accent
/// ink. The feeds and the music home share it, so one gesture looks the same
/// wherever it is offered.
Widget buildDsRefreshIndicator(BuildContext context, Widget child, IndicatorController controller) {
  final colors = DsTheme.colorsOf(context);
  final value = controller.value.clamp(0.0, 1.0);
  return Stack(
    children: [
      child,
      if (!controller.isIdle)
        Positioned(
          top: value * 48 - 44,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: value,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: DsBoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    shadows: [DsShadow.innerRing(colors.border)],
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(size: 18, color: colors.accent),
                    child: const DsSpinner(style: DsSpinnerStyle(size: 18)),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
