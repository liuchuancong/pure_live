import 'package:desen_ui/desen_ui.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/widgets.dart';

/// How much a focused TV control grows (the reference's zoom, one notch
/// above rest but never enough to cover a neighbour).
const double kTvFocusScale = 1.05;

/// How much a control shrinks while the select key is held: a push, not a
/// second grow.
const double kTvPressScale = 0.97;

/// How long arriving at focus takes.
const Duration kTvFocusIn = Duration(milliseconds: 120);

/// The one motion curve every TV focus transition speaks.
const Curve kTvFocusCurve = Curves.easeOutCubic;

/// Arriving animates; leaving snaps, so a held arrow never leaves a trail
/// of half-grown items behind it.
Duration tvFocusDuration({required bool entered}) => entered ? kTvFocusIn : Duration.zero;

/// The one focus language every TV control speaks: a small grow, the
/// theme's focus color as a 2px ring, and — dark themes only — a soft glow.
/// On a light surface a blurred glow reads as a grey stain, so the light
/// theme keeps only the hard-edged ring. [radius] must match the control's
/// corners; [scale] drops to 1.0 for controls that fill their row, where
/// growing would push into the neighbours.
List<DpadEffect> tvFocusEffects(
  BuildContext context,
  BorderRadius radius, {
  double scale = kTvFocusScale,
  bool ring = true,
  bool glow = true,
}) {
  final colors = DsTheme.colorsOf(context);
  final light = DsTheme.of(context).brightness == Brightness.light;
  return [
    DpadScaleEffect(scale: scale, pressedScale: kTvPressScale, duration: kTvFocusIn),
    if (ring) DpadBorderEffect(color: colors.focus, width: 2, borderRadius: radius, duration: kTvFocusIn),
    if (glow && light)
      DpadGlowEffect(color: colors.focus, opacity: 1, blurRadius: 0, borderRadius: radius, duration: kTvFocusIn),
    if (glow && !light)
      DpadGlowEffect(color: colors.focus, opacity: 0.4, spreadRadius: 1.5, borderRadius: radius, duration: kTvFocusIn),
  ];
}
