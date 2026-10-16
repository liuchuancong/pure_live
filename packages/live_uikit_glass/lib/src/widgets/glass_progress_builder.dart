import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted progress bar from a [LanguageProgressSpec] (§9 Progress).
///
/// Composed, not mapped: the library has no indicator, so the groove is a
/// [glass.GlassContainer] at the spec's height — blur, tint, corner radius and
/// stroke inherited from [glass.GlassTheme] (§8) — and the fill is a solid one
/// inside it (`isBlurEnabled: false`: one backdrop filter per bar is the
/// library's own budget). The fill takes the primary colour, or
/// [LanguageProgressSpec.barColor] when the caller names one, at full opacity so
/// it reads as the lit part of the same sheet rather than a bar laid over it.
///
/// A null [LanguageProgressSpec.value] has no library widget to lean on either:
/// every spinner `glass_morphism_plus` paints is Material's own, so the
/// indeterminate case is the same frosted fill sliding end to end, driven by a
/// controller here and held at the leading edge when `UiConfig.animations` is off
/// (§13).
abstract final class GlassProgressBuilder {
  /// Builds the progress bar for [spec].
  static Widget build(BuildContext context, LanguageProgressSpec spec) {
    final theme = LiveTheme.of(context);
    final fraction = spec.value == null ? 1.0 : spec.value!.clamp(0.0, 1.0);

    final Widget bar = _Groove(spec: spec, fill: spec.barColor ?? theme.colors.primary, fraction: fraction);
    if (!spec.showLabel || spec.value == null) {
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

/// The frosted groove, holding either a determinate fill at the spec's fraction or
/// the sliding fill of an indeterminate value.
class _Groove extends StatelessWidget {
  const new({required this.spec, required this.fill, required this.fraction});

  final LanguageProgressSpec spec;
  final Color fill;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(spec.height);

    return SizedBox(
      height: spec.height,
      child: glass.GlassContainer(
        customBorderRadius: radius,
        child: spec.value == null
            ? _Marquee(fill: fill, radius: radius)
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

/// The indeterminate fill: a third of the groove travelling end to end on a loop.
///
/// The library paints no spinner of its own, so this is the travel drawn with the
/// same glass surfaces the determinate bar uses. It stops looping when
/// `UiConfig.animations` is off and rests at the leading edge, because a device
/// that cannot afford the motion should still show a bar (§13).
class _Marquee extends StatefulWidget {
  const new({required this.fill, required this.radius});

  final Color fill;
  final BorderRadius radius;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> with SingleTickerProviderStateMixin {
  static const double _share = 0.34;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read from the theme here rather than in `initState`, where an inherited
    // lookup is an error, and re-read on every dependency change so a config that
    // turns animations off mid-flight stops the loop instead of carrying on.
    if (LiveTheme.of(context).config.animations) {
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
    final animates = LiveTheme.of(context).config.animations;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite ? constraints.maxWidth * _share : 0.0;
          // -1 at the leading edge, +1 at the trailing one, so the block leaves
          // the groove exactly as it entered it.
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
