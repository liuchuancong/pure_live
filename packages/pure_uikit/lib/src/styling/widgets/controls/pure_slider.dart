import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The public slider: one widget, every theme and density. It carries only
/// semantics (`value`, `min`, `max`, `onChanged`, `enabled`); its appearance
/// comes straight from the active design language's own widget library. [build]
/// switches on `UiConfig.language` and constructs the library's real component
/// directly — fluent_2's `FluentSlider` under fluent, `MacosSlider` under macOS,
/// `CupertinoSlider` under iOS, Material's `Slider` — so what the user sees is
/// exactly what that library's own documentation shows. Switching
/// `UiConfig.language` re-skins every slider.
class PureSlider extends StatelessWidget {
  /// A slider.
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.enabled = true,
    this.focusNode,
    super.key,
  });

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables it.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = enabled ? onChanged : null;
    final clamped = value.clamp(min, max);
    final span = max - min;
    // The value normalised into the 0..1 track the fractional libraries measure
    // (forui lifts a track percentage, glass and wind compute the thumb's run
    // themselves), clamped so a value outside its own bounds still draws inside
    // the rail.
    final fraction = span <= 0 ? 0.0 : ((clamped - min) / span).clamp(0.0, 1.0);

    return switch (theme.config.language) {
      PureDesignLanguage.fluent => f2.FluentSlider(
        value: clamped,
        min: min,
        max: max,
        onChanged: select,
        focusNode: focusNode,
      ),
      // `MacosSlider.onChanged` is a required, non-nullable callback, so a dead
      // slider has no representation in the library: it is drawn from the
      // library's own inert rail and published thumb colour instead of a
      // closure that would leave a live-looking control.
      PureDesignLanguage.macos => select == null
          ? _inertMacosSlider(context, clamped)
          : macos.MacosSlider(value: clamped, min: min, max: max, onChanged: onChanged!),
      // The Cupertino slider takes no focus node; a null callback is its inert
      // state.
      PureDesignLanguage.cupertino => cupertino.CupertinoSlider(
        value: clamped,
        min: min,
        max: max,
        onChanged: select,
      ),
      // forui's slider is lifted and measures a track percentage rather than
      // the spec's units, so the fraction goes in and what the thumb reports is
      // denormalised back; the library's value bubble is switched off because
      // it would announce "40%" for a value the caller reads as 40 of 0..100.
      // The field owns its focus internally, so [focusNode] is not mapped.
      PureDesignLanguage.forui => forui.FSlider(
        control: forui.FSliderControl.liftedContinuous(
          value: forui.FSliderValue(max: fraction),
          onChange: (next) => select?.call(min + next.max * span),
        ),
        enabled: select != null,
        tooltipControls: const forui.FSliderTooltipControls.disabled(),
      ),
      // Hand-rolled glass-style composition: glass_morphism_plus ships no
      // slider, so the rail, the filled run and the handle are the library's
      // own surfaces — a hairline frosted [glass.GlassContainer] rail, a solid
      // one for the fill, a circular one for the handle, each themed from its
      // [glass.GlassTheme] and measured against the slider component token.
      // Only the rail keeps a backdrop filter (`isBlurEnabled: false` on the
      // parts drawn over it is the library's own budget knob); the drag and
      // tap sit on a widgets-layer [GestureDetector] and the focus node on a
      // [Focus] that steps a twentieth of the range on the arrow keys.
      PureDesignLanguage.glass => _GlassSlider(
        value: clamped,
        min: min,
        max: max,
        enabled: enabled,
        onChanged: onChanged,
        focusNode: focusNode,
      ),
      PureDesignLanguage.neumorphic => neu.NeuSlider(value: clamped, min: min, max: max, onChanged: select),
      // Hand-rolled wind-style composition: fluttersdk_wind ships no slider, so
      // the rail and the thumb are the library's own surfaces — `WDiv` over
      // `WDiv`, tinted with its own colour tokens — and the fill width and
      // thumb offset are computed from a measured rail and applied with
      // `Positioned` (a runtime value never goes into a className, which the
      // library caches). The drag sits on a widgets-layer [GestureDetector]
      // over the parts, and a tap positions the value the same way; the fork
      // keeps focus inside `WAnchor`, so [focusNode] has no slot here.
      PureDesignLanguage.wind => _WindSlider(
        value: clamped,
        min: min,
        max: max,
        enabled: enabled,
        onChanged: onChanged,
      ),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different slider.
      PureDesignLanguage.material || PureDesignLanguage.yaru => Slider(
        value: clamped,
        min: min,
        max: max,
        onChanged: select,
        focusNode: focusNode,
      ),
    };
  }

  /// The dead slider the macOS branch draws: [macos.ProgressBar]'s rail with
  /// the library's own thumb colour parked at the value's fraction under an
  /// [IgnorePointer]. Same rail-and-thumb reading as the live control, nothing
  /// to drag.
  Widget _inertMacosSlider(BuildContext context, double value) {
    final theme = PureTheme.of(context);
    const thumbSize = 12.0;
    final span = max - min;
    final fraction = span <= 0 ? 0.0 : ((value - min) / span).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Semantics(
        slider: true,
        value: value.toStringAsFixed(2),
        child: SizedBox(
          height: 20,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The rail needs a width to divide; an unbounded parent gets a
              // sane track rather than an infinite one.
              var width = constraints.maxWidth;
              if (!constraints.hasBoundedWidth) {
                width = 200;
              }
              final travel = width - thumbSize;
              return SizedBox(
                width: width,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: thumbSize / 2),
                      child: macos.ProgressBar(
                        value: fraction * 100,
                        height: 4,
                        trackColor: theme.colors.primary,
                        backgroundColor: theme.colors.fillSecondary,
                      ),
                    ),
                    Positioned(
                      left: (travel * fraction).clamp(0.0, travel),
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: macos.MacosDynamicColor.resolve(macos.MacosColors.sliderThumbColor, context),
                          border: Border.all(color: theme.colors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The glass slider: a hand-rolled glassmorphism composition — the library
/// ships no slider, so the three pieces are its own surfaces (see the
/// [PureSlider] glass branch). Geometry and colour come from the slider
/// component token, since the library has neither for a control it does not
/// carry.
class _GlassSlider extends StatelessWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    required this.focusNode,
  });

  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final st = theme.slider;
    final glassTheme = glass.GlassTheme.of(context);
    final interactive = enabled && onChanged != null;
    final range = max - min;
    final fraction = range == 0 ? 0.0 : ((value - min) / range).clamp(0.0, 1.0);

    return Focus(
      focusNode: focusNode,
      canRequestFocus: interactive,
      onKeyEvent: (node, event) => _onKey(event),
      child: Semantics(
        slider: true,
        enabled: interactive,
        value: value.toStringAsFixed(2),
        child: Opacity(
          opacity: enabled ? 1 : st.disabledOpacity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final trackWidth = (width - st.handleSize).clamp(0.0, width);
              final center = st.handleSize / 2 + fraction * trackWidth;
              final railTop = (st.handleSize - st.railHeight) / 2;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: interactive
                    ? (d) => _report(d.localPosition.dx, width, st.handleSize)
                    : null,
                onTapDown: interactive ? (d) => _report(d.localPosition.dx, width, st.handleSize) : null,
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

  /// Reports the value under a pointer at [dx] across a [width]-wide track
  /// whose knob travels the [handleSize] its own diameter.
  void _report(double dx, double width, double handleSize) {
    final trackWidth = (width - handleSize).clamp(0.0, width);
    final fraction = (trackWidth <= 0 ? 0.0 : (dx - handleSize / 2) / trackWidth).clamp(0.0, 1.0);
    onChanged?.call((min + fraction * (max - min)).clamp(min, max));
  }

  /// The arrow keys step a twentieth of the range, the way a focused slider
  /// answers the keyboard.
  KeyEventResult _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !enabled || onChanged == null) {
      return KeyEventResult.ignored;
    }
    final range = max - min;
    final down = event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (down) {
      onChanged?.call((value - range / 20).clamp(min, max));
      return KeyEventResult.handled;
    }
    if (up) {
      onChanged?.call((value + range / 20).clamp(min, max));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// The wind slider: a hand-rolled wind-style composition — the library ships no
/// slider, so the rail, the filled run and the thumb are `WDiv` surfaces in the
/// library's own utility tokens (see the [PureSlider] wind branch). The
/// className strings are constants so the library's parser cache sees stable
/// keys; only the geometry is computed, and the fork's `disabled:` prefix
/// carries the inert look.
class _WindSlider extends StatelessWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  /// The thumb's side, and the height the rail is centred inside.
  static const double thumbSide = 16;

  /// The rail's thickness — Wind's own `h-1` step at the 4pt base unit.
  static const double trackHeight = 4;

  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    // One verdict decides both the callback and the state the fork paints
    // from, so a Wind rail can never look live while it is dead.
    final interactive = enabled && onChanged != null;
    final states = interactive ? null : const {'disabled'};
    final range = max - min;
    final ratio = range <= 0 ? 0.0 : ((value - min) / range).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth : MediaQuery.sizeOf(context).width;
          // The thumb rides the last [thumbSide] of the rail, so the fill ends
          // at its centre and neither part leaves the box at either stop.
          final travel = width > thumbSide ? width - thumbSide : 0.0;
          final thumbLeft = travel * ratio;
          final filled = (thumbLeft + thumbSide / 2).clamp(0.0, width);
          void report(double x) {
            if (!interactive) {
              return;
            }
            final at = x.clamp(0.0, width);
            onChanged!(min + (width == 0 ? 0 : at / width) * range);
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

  static const String _trackClasses = 'w-full h-1 rounded-full bg-gray-200 dark:bg-gray-700 disabled:opacity-50';

  static const String _fillClasses = 'w-full h-1 rounded-full bg-primary-500 disabled:opacity-50';

  static const String _thumbClasses =
      'size-4 rounded-full bg-white border border-gray-300 dark:border-gray-600 shadow disabled:opacity-50';
}
