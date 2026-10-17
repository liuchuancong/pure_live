import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A tiny marquee for an indeterminate value (null [PureProgress.value]).
class LinearIndeterminate extends StatelessWidget {
  /// An indeterminate bar.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return SizedBox.expand(
      child: LinearProgressIndicator(
        backgroundColor: Colors.transparent,
        color: theme.colors.primary,
        minHeight: theme.token.scale.sizes.xs,
      ),
    );
  }
}

/// The public progress bar: one widget, every theme and density. [build]
/// switches on `UiConfig.language` and constructs the library's real component
/// directly — fluent_2's `FluentProgressBar` under fluent, `MacosProgressBar` /
/// `MacosProgressCircle` under macOS, Cupertino's linear bar and spinning ring
/// under iOS, Material's `LinearProgressIndicator` — so what the user sees is
/// exactly what that library's own documentation shows. Switching
/// `UiConfig.language` re-skins every bar.
class PureProgress extends StatelessWidget {
  /// A progress bar at [value] (0..1).
  const new({required this.value, this.height = 8, this.showLabel = false, this.barColor, super.key});

  /// The completion fraction, or null for indeterminate.
  final double? value;

  /// The track thickness.
  final double height;

  /// Whether to show the trailing percentage.
  final bool showLabel;

  /// An optional fill colour override.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final fill = barColor ?? theme.colors.primary;
    final fraction = value?.clamp(0.0, 1.0);

    return switch (theme.config.language) {
      // A null value stays null: the fork renders its own indeterminate
      // animation, which is the contract, not a determinate bar at 0.
      PureDesignLanguage.material => LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: fill,
        backgroundColor: theme.colors.fillSecondary,
      ),
      // A known fraction is iOS's own linear bar; a null one is the spinning
      // ring, which is what iOS itself uses for work of unknown length — it
      // has no thickness or fill to carry, so `height` and `barColor` mean
      // nothing there.
      PureDesignLanguage.cupertino => fraction == null
          ? cupertino.CupertinoActivityIndicator(color: barColor)
          : _labelled(theme, cupertino.CupertinoLinearActivityIndicator(progress: fraction, height: height, color: fill), fraction),
      // macOS answers the two states with two widgets of its own: the
      // determinate bar (a percentage, so the fraction is scaled) and the
      // `ProgressCircle` spinner, which takes only a radius.
      PureDesignLanguage.macos => fraction == null
          ? const macos.ProgressCircle()
          : macos.ProgressBar(
              value: (fraction * 100).clamp(0.0, 100.0),
              height: height,
              trackColor: fill,
              backgroundColor: theme.colors.fillSecondary,
            ),
      // fluent_2's bar reads its colours from its own theme and has no colour
      // or thickness slot, so the spec's knobs ride in through the style
      // override; `value` is the same 0..1-or-null the contract carries.
      PureDesignLanguage.fluent => f2.FluentProgressBar(
        value: fraction,
        style: f2.FluentProgressBarStyle(
          thickness: WidgetStatePropertyAll<double?>(height),
          indicatorColor: WidgetStatePropertyAll<Color?>(fill),
          railColor: WidgetStatePropertyAll<Color?>(theme.colors.fillSecondary),
        ),
      ),
      // The library splits the two states the contract expresses with a null
      // `value` into two widgets, so both are mapped rather than approximated:
      // a fraction is `FDeterminateProgress` and null is `FProgress`, the
      // library's own indeterminate animation. `height` rides the style's
      // track constraints and `barColor` the fill's decoration — both through
      // forui's style delta, which replaces only the field named. The
      // indicator paints a bar and nothing else, so `showLabel` is the one
      // field of this control the library cannot express and is dropped rather
      // than overlaid with a hand-built percentage.
      PureDesignLanguage.forui => fraction == null
          ? forui.FProgress(
              style: forui.FProgressStyleDelta.delta(constraints: BoxConstraints.tightFor(height: height)),
            )
          : forui.FDeterminateProgress(
              value: fraction,
              style: forui.FDeterminateProgressStyleDelta.delta(
                constraints: BoxConstraints.tightFor(height: height),
                fillDecoration: barColor == null ? null : forui.DecorationDelta.shapeDelta(color: barColor),
              ),
            ),
      // Hand-rolled glass-style composition: glass_morphism_plus has no
      // indicator, so the groove is a frosted [glass.GlassContainer] at the
      // spec's height and the fill a solid one inside it, and an unknown
      // completion is the same frosted fill sliding end to end (the library's
      // every spinner is Material's own), stopping when `UiConfig.animations`
      // is off.
      PureDesignLanguage.glass => _GlassProgress(value: value, height: height, showLabel: showLabel, barColor: barColor),
      // The library's own linear bar: a recessed trough with an elevated dome
      // for the fill, themed from `NeuTheme`. A null `value` is the library's
      // own pulse, which repeats until the widget leaves the tree.
      PureDesignLanguage.neumorphic => _labelled(theme, _neumorphicBar(context, fraction), fraction),
      // Hand-rolled wind-style composition: the fork ships no progress bar, so
      // both halves are the library's own container — a `WDiv` rail in its
      // neutral pair and a `WDiv` run in its accent, closed by `rounded-full`,
      // with the fraction on a `FractionallySizedBox` (exactly how `WDiv`
      // renders its own `w-1/2` token). A className is never interpolated with
      // the fraction; `barColor` arrives through `WDiv.backgroundColor`, the
      // fork's own runtime override. An unknown completion cannot slide — Wind
      // has no transform parser — so it breathes with the library's documented
      // `animate-pulse` skeleton affordance, and `showLabel` is dropped with
      // it because there is no percentage of an unknown quantity to print.
      PureDesignLanguage.wind => _WindProgress(value: value, height: height, showLabel: showLabel, barColor: barColor),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different bar.
      PureDesignLanguage.material || PureDesignLanguage.yaru => LinearProgressIndicator(
        value: value,
        minHeight: height,
        color: fill,
        backgroundColor: theme.colors.fillSecondary,
      ),
    };
  }

  /// The library's own linear bar: a recessed trough ([neu.NeuShape.pressed])
  /// with an elevated dome ([neu.NeuShape.convex]) for the fill at the theme's
  /// accent, over the base colour trough. A null `value` is the library's own
  /// pulse, which repeats until the widget leaves the tree; the contract asks
  /// no timer of the language, so nothing here disposes it.
  Widget _neumorphicBar(BuildContext context, double? fraction) {
    final surface = neu.NeuTheme.of(context);
    return neu.NeuProgressBar(
      value: fraction,
      height: height,
      progressColor: barColor ?? surface.accentColor,
      trackColor: surface.baseColor,
    );
  }

  /// The bar, plus the trailing percentage where [showLabel] asks for one and
  /// the fraction is known — a spinner has no percentage to name.
  Widget _labelled(PureTheme theme, Widget bar, double? fraction) {
    if (!showLabel || fraction == null) {
      return bar;
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text('${(fraction * 100).round()}%', style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}

/// The glass progress bar: a hand-rolled glassmorphism composition — the
/// library has no indicator, so the groove is a frosted [glass.GlassContainer]
/// and the fill a solid one inside it (`isBlurEnabled: false`: one backdrop
/// filter per bar is the library's own budget). An unknown completion is the
/// same frosted fill sliding end to end — the library paints no spinner of its
/// own — driven by a controller here and held at the leading edge when
/// `UiConfig.animations` is off.
class _GlassProgress extends StatelessWidget {
  const new({required this.value, required this.height, required this.showLabel, required this.barColor});

  final double? value;
  final double height;
  final bool showLabel;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final fraction = value == null ? 1.0 : value!.clamp(0.0, 1.0);

    final Widget bar = _GlassGroove(value: value, height: height, fill: barColor ?? theme.colors.primary, fraction: fraction);
    if (!showLabel || value == null) {
      return bar;
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text('${(fraction * 100).round()}%', style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}

/// The frosted groove, holding either a determinate fill at the fraction or the
/// sliding fill of an indeterminate value.
class _GlassGroove extends StatelessWidget {
  const new({required this.value, required this.height, required this.fill, required this.fraction});

  final double? value;
  final double height;
  final Color fill;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);

    return SizedBox(
      height: height,
      child: glass.GlassContainer(
        customBorderRadius: radius,
        child: value == null
            ? _GlassMarquee(fill: fill, radius: radius)
            : LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.centerLeft,
                  child: glass.GlassContainer(
                    width: constraints.maxWidth * fraction,
                    customBorderRadius: radius,
                    color: fill,
                    opacity: 1,
                    isBlurEnabled: false,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The indeterminate fill: a third of the groove travelling end to end on a
/// loop. It stops looping when `UiConfig.animations` is off and rests at the
/// leading edge, because a device that cannot afford the motion should still
/// show a bar.
class _GlassMarquee extends StatefulWidget {
  const new({required this.fill, required this.radius});

  final Color fill;
  final BorderRadius radius;

  @override
  State<_GlassMarquee> createState() => _GlassMarqueeState();
}

class _GlassMarqueeState extends State<_GlassMarquee> with SingleTickerProviderStateMixin {
  static const double _share = 0.34;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read from the theme here rather than in `initState`, where an inherited
    // lookup is an error, and re-read on every dependency change so a config
    // that turns animations off mid-flight stops the loop instead of carrying
    // on.
    if (PureTheme.of(context).config.animations) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animates = PureTheme.of(context).config.animations;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth * _share : 0.0;
          // -1 at the leading edge, +1 at the trailing one, so the block
          // leaves the groove exactly as it entered it.
          final travelled = animates ? _controller.value * 2 - 1 : -1.0;
          return Align(
            alignment: Alignment(travelled, 0),
            child: glass.GlassContainer(
              width: width,
              customBorderRadius: widget.radius,
              color: widget.fill,
              opacity: 1,
              isBlurEnabled: false,
            ),
          );
        },
      ),
    );
  }
}

/// The wind progress bar: a hand-rolled wind-style composition — the fork ships
/// no progress bar, so the rail and the run are `WDiv` surfaces in the
/// library's own utility tokens (see the `PureSlider` wind branch for why a
/// runtime value never enters a className).
class _WindProgress extends StatelessWidget {
  const new({required this.value, required this.height, required this.showLabel, required this.barColor});

  final double? value;
  final double height;
  final bool showLabel;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final bar = wind.WDiv(
      className: 'w-full h-full rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700',
      child: value == null
          ? wind.WDiv(className: 'w-full h-full rounded-full animate-pulse', backgroundColor: barColor)
          : FractionallySizedBox(
              widthFactor: value!.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: wind.WDiv(className: 'w-full h-full rounded-full bg-primary-500', backgroundColor: barColor),
            ),
    );
    final track = SizedBox(height: height, child: bar);

    final percent = value == null ? null : (value!.clamp(0.0, 1.0) * 100).round();
    if (percent == null || !showLabel) {
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
