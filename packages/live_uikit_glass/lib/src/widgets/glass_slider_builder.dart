import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted slider from a [LanguageSliderSpec] (§9 Slider).
///
/// Composed, not mapped: `glass_morphism_plus` ships no slider, so the three
/// pieces are the library's own surfaces — a hairline-thin [glass.GlassContainer]
/// rail taking its blur, tint, radius and stroke from [glass.GlassTheme] (§8), a
/// solid one for the filled part of the track, and a circular one for the handle.
/// The rail keeps the backdrop filter and the two pieces drawn over it skip
/// theirs (`isBlurEnabled: false` is the library's own budget knob), which is what
/// keeps a drag from blurring the page three times over. Geometry and colour come
/// from the slider component token, since the library has neither for a control it
/// does not carry.
///
/// A slider is dragged rather than tapped, so its gesture layer is the widgets
/// library's own [GestureDetector] instead of the core's [LiveBox]: a [Focus]
/// routes [LanguageSliderSpec.focusNode] and steps the value by a twentieth of the
/// range on the arrow keys, and [Semantics] reports the number rather than the
/// geometry.
abstract final class GlassSliderBuilder {
  /// Builds the slider for [spec].
  static Widget build(BuildContext context, LanguageSliderSpec spec) {
    final theme = LiveTheme.of(context);
    final st = theme.slider;
    final glassTheme = glass.GlassTheme.of(context);
    final interactive = spec.enabled && spec.onChanged != null;
    final range = spec.max - spec.min;
    final fraction = range == 0 ? 0.0 : ((spec.value - spec.min) / range).clamp(0.0, 1.0);

    return Focus(
      focusNode: spec.focusNode,
      canRequestFocus: interactive,
      onKeyEvent: (node, event) => _onKey(spec, event, interactive, range),
      child: Semantics(
        slider: true,
        enabled: interactive,
        value: spec.value.toStringAsFixed(2),
        child: Opacity(
          opacity: spec.enabled ? 1 : st.disabledOpacity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final trackWidth = (width - st.handleSize).clamp(0.0, width);
              final center = st.handleSize / 2 + fraction * trackWidth;
              final railTop = (st.handleSize - st.railHeight) / 2;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: interactive
                    ? (d) => _report(spec, d.localPosition.dx, width, st.handleSize)
                    : null,
                onTapDown: interactive ? (d) => _report(spec, d.localPosition.dx, width, st.handleSize) : null,
                child: SizedBox(
                  height: st.handleSize,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: railTop,
                        height: st.railHeight,
                        child: glass.GlassContainer(customBorderRadius: BorderRadius.circular(st.railHeight)),
                      ),
                      Positioned(
                        left: 0,
                        width: center,
                        top: railTop,
                        height: st.railHeight,
                        child: glass.GlassContainer(
                          customBorderRadius: BorderRadius.circular(st.railHeight),
                          color: st.trackColor,
                          opacity: 1,
                          isBlurEnabled: false,
                          // The library's stroke is what separates the filled
                          // part of a glass track from the rail behind it.
                          borderWidth: glassTheme.borderWidth,
                        ),
                      ),
                      Positioned(
                        left: (center - st.handleSize / 2).clamp(0.0, width - st.handleSize),
                        top: 0,
                        child: glass.GlassContainer(
                          width: st.handleSize,
                          height: st.handleSize,
                          shape: BoxShape.circle,
                          color: st.handleColor,
                          opacity: 1,
                          isBlurEnabled: false,
                          borderColor: st.handleBorderColor,
                          boxShadow: theme.token.motion.boxShadowTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Reports the value under a pointer at [dx] across a [width]-wide track whose
  /// knob travels the [handleSize] its own diameter (§9).
  static void _report(LanguageSliderSpec spec, double dx, double width, double handleSize) {
    final trackWidth = (width - handleSize).clamp(0.0, width);
    final fraction = (trackWidth <= 0 ? 0.0 : (dx - handleSize / 2) / trackWidth).clamp(0.0, 1.0);
    final range = spec.max - spec.min;
    spec.onChanged?.call((spec.min + fraction * range).clamp(spec.min, spec.max));
  }

  static KeyEventResult _onKey(LanguageSliderSpec spec, KeyEvent event, bool interactive, double range) {
    if (!interactive) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowDown) {
        spec.onChanged?.call((spec.value - range / 20).clamp(spec.min, spec.max));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp) {
        spec.onChanged?.call((spec.value + range / 20).clamp(spec.min, spec.max));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
