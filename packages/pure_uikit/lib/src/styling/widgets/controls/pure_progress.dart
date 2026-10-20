import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:forui/forui.dart' as forui;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:yaru/yaru.dart' as yaru;

/// A tiny marquee for an indeterminate value (null [PureProgress.value]).
class LinearIndeterminate extends StatelessWidget {
  /// An indeterminate bar.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return SizedBox.expand(child: PureProgress(value: null, height: theme.token.scale.sizes.xs));
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
  const new({required this.value, this.height, this.showLabel = false, this.barColor, super.key});

  /// The completion fraction, or null for indeterminate.
  final double? value;

  /// The track thickness, or null to keep whichever thickness the active
  /// library draws by default — macOS and iOS both set 4.5, neumorphic 14 and
  /// Yaru 4, so a single literal here flattened every one of them.
  final double? height;

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
      // animation, which is the contract, not a determinate bar at 0. The
      // groove is the scheme's own — a token fill colour painted over it reads
      // as a different material, not as the library's track.
      PureDesignLanguage.material => LinearProgressIndicator(value: value, minHeight: height, color: fill),
      // A known fraction is iOS's own linear bar; a null one is the spinning
      // ring, which is what iOS itself uses for work of unknown length — it
      // has no thickness or fill to carry, so `height` and `barColor` mean
      // nothing there.
      PureDesignLanguage.cupertino =>
        fraction == null
            ? cupertino.CupertinoActivityIndicator(color: barColor)
            : _labelled(
                theme,
                cupertino.CupertinoLinearActivityIndicator(
                  progress: fraction,
                  height: height ?? 4.5,
                  color: fill,
                ),
                fraction,
              ),
      // macOS answers the two states with two widgets of its own: the
      // determinate bar (a percentage, so the fraction is scaled) and the
      // `ProgressCircle` spinner, which takes only a radius. Its `trackColor`
      // is the filled portion and `backgroundColor` the groove, so only the
      // first is the contract's fill.
      PureDesignLanguage.macos =>
        fraction == null
            ? const macos.ProgressCircle()
            : macos.ProgressBar(value: (fraction * 100).clamp(0.0, 100.0), height: height ?? 4.5, trackColor: fill),
      // fluent_2's bar reads its colours from its own theme and has no colour
      // or thickness slot, so the spec's knobs ride in through the style
      // override; `value` is the same 0..1-or-null the contract carries. A null
      // thickness leaves the rail's colour to the library.
      PureDesignLanguage.fluent => f2.FluentProgressBar(
        value: fraction,
        style: f2.FluentProgressBarStyle(
          thickness: WidgetStatePropertyAll<double?>(height),
          indicatorColor: WidgetStatePropertyAll<Color?>(fill),
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
      PureDesignLanguage.forui => _forui(fraction),
      // glass_morphism_plus ships no indicator. Use Flutter's official Material
      // progress bar rather than a hand-built frosted groove.
      PureDesignLanguage.glass => _labelled(
        theme,
        LinearProgressIndicator(value: fraction, minHeight: height, color: fill),
        fraction,
      ),
      // The library's own linear bar: a recessed trough with an elevated dome
      // for the fill, themed from `NeuTheme`. A null `value` is the library's
      // own pulse, which repeats until the widget leaves the tree.
      PureDesignLanguage.neumorphic => _labelled(theme, _neumorphicBar(context, fraction), fraction),
      // fluttersdk_wind ships no progress bar. Fall back to Flutter's official
      // Material indicator.
      PureDesignLanguage.wind => _labelled(
        theme,
        LinearProgressIndicator(value: fraction, minHeight: height, color: fill),
        fraction,
      ),
      // Yaru's own bar: Ubuntu's progress is a thinner stroke on a track of its
      // own colour, and the library names the thickness `strokeWidth` where
      // Material names it `minHeight`. A null value is its indeterminate run.
      PureDesignLanguage.yaru => yaru.YaruLinearProgressIndicator(
        value: value,
        strokeWidth: height,
        trackStrokeWidth: height,
        color: fill,
      ),
    };
  }

  /// forui's two states, each with only the deltas the contract actually asks
  /// for — a null `height` leaves the library's own track constraints in place
  /// rather than replacing them with a loose box.
  Widget _forui(double? fraction) {
    if (fraction == null) {
      final thickness = height;
      if (thickness == null) {
        return const forui.FProgress();
      }
      return forui.FProgress(
        style: forui.FProgressStyleDelta.delta(constraints: BoxConstraints.tightFor(height: thickness)),
      );
    }
    return forui.FDeterminateProgress(
      value: fraction,
      style: forui.FDeterminateProgressStyleDelta.delta(
        constraints: height == null ? null : BoxConstraints.tightFor(height: height),
        fillDecoration: barColor == null ? null : forui.DecorationDelta.shapeDelta(color: barColor),
      ),
    );
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
      height: height ?? 14.0,
      progressColor: barColor ?? surface.accentColor,
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
