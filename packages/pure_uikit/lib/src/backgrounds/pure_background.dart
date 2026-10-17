import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/backgrounds/background_style.dart';
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// Paints a [PureBackgroundStyle] behind [child].
///
/// The widget renders the treatment it is given and reads exactly one
/// environment fact: `PureTheme.canBlur`, the resolved answer to "may a
/// backdrop filter be drawn at all" (`UiConfig.reduceTransparency` × the
/// host-reported hardware capability, folded once by `PureConfigProvider`).
/// Where that is false, the frosted and blurred treatments degrade to their
/// flat fill rather than paying for an effect the device or the user's
/// accessibility setting ruled out. Callers therefore pass a treatment, not a
/// platform check, and no page can forget the gate.
class PureBackground extends StatelessWidget {
  /// A background of [style] behind [child].
  const new({required this.style, this.child, this.clipRadius, this.animateImage = true, super.key});

  /// What to paint.
  final PureBackgroundStyle style;

  /// The content on top of the background.
  final Widget? child;

  /// The corner radius to clip to; null paints square corners.
  final BorderRadius? clipRadius;

  /// Whether an image background fades in once decoded, instead of popping
  /// in when the bytes arrive.
  final bool animateImage;

  /// A fully rounded clip at [radius], for cards and pills.
  static BorderRadius rounded([double radius = PureRadii.md]) => BorderRadius.circular(radius);

  @override
  Widget build(BuildContext context) {
    // Outside a PureConfigProvider nothing has resolved an affordance, so the
    // style is honoured as written.
    final canBlur = PureTheme.maybeOf(context)?.canBlur ?? true;
    final filled = switch (style) {
      PureSolidBackground(:final color) => ColoredBox(color: color, child: child),
      PureGradientBackground() => _gradient(child),
      PureImageBackground() => _image(context, child, canBlur),
      PureGlassBackground() => _glass(child, canBlur),
      PureRaisedBackground() => _raised(child),
    };
    final radius = clipRadius;
    return radius == null ? filled : ClipRRect(borderRadius: radius, child: filled);
  }

  Widget _gradient(Widget? child) {
    final gradient = style as PureGradientBackground;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient.colors,
          begin: gradient.begin,
          end: gradient.end,
          stops: gradient.stops.isEmpty ? null : gradient.stops,
        ),
      ),
      child: _scrimmed(gradient.scrim, gradient.scrimStrength, child),
    );
  }

  Widget _image(BuildContext context, Widget? child, bool canBlur) {
    final image = style as PureImageBackground;
    final picture = Image(image: image.image, fit: image.fit, width: double.infinity, height: double.infinity);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: animateImage
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey(image.image), child: picture),
                )
              : picture,
        ),
        if (image.blurSigma > 0 && canBlur) Positioned.fill(child: _BlurLayer(sigma: image.blurSigma)),
        if (image.scrim case final scrim?)
          Positioned.fill(
            child: ColoredBox(color: scrim.withValues(alpha: image.scrimStrength)),
          ),
        ?child,
      ],
    );
  }

  Widget _glass(Widget? child, bool canBlur) {
    final glass = style as PureGlassBackground;
    final border = glass.border;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: glass.color,
        border: border == null ? null : Border.all(color: border),
      ),
      child: child,
    );
    if (!canBlur) {
      // The verified degraded stand-in: the translucent fill and its border stay,
      // the backdrop filter goes. A surface the user excluded by accessibility
      // setting or the device cannot afford must still read as a surface.
      return surface;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: glass.sigma, sigmaY: glass.sigma, tileMode: TileMode.mirror),
        child: surface,
      ),
    );
  }

  Widget _raised(Widget? child) {
    final raised = style as PureRaisedBackground;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: raised.base,
        boxShadow: [
          BoxShadow(color: raised.dark, blurRadius: raised.depth * 2, offset: Offset(raised.depth, raised.depth)),
          BoxShadow(color: raised.light, blurRadius: raised.depth * 2, offset: Offset(-raised.depth, -raised.depth)),
        ],
      ),
      child: child,
    );
  }

  Widget _scrimmed(Color? scrim, double strength, Widget? child) {
    if (scrim == null || strength <= 0) {
      return child ?? const SizedBox.expand();
    }
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ColoredBox(color: scrim.withValues(alpha: strength)),
        ),
        ?child,
      ],
    );
  }
}

/// The blur layer used over an image background.
class _BlurLayer extends StatelessWidget {
  const new({required this.sigma});

  final double sigma;

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.mirror),
    child: const SizedBox.expand(),
  );
}
