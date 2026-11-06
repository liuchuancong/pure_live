import 'package:flutter/material.dart' show Brightness, ColorScheme, LinearGradient, VerticalDirection;
import 'package:flutter/painting.dart' show Alignment, Color;

/// Colours of everything drawn over the picture: the control bars, their ink,
/// the scrims and dim states, the panes and chips that sit on a video that
/// can be any colour. Pages take their roles from here instead of literal
/// whites and blacks, so the look over the picture is decided in one place —
/// the app theme's light/dark pick never reaches the picture.
abstract final class OnVideoColors {
  /// Behind the picture (the stage, letterboxing, the floating window).
  static const Color ground = Color(0xFF000000);

  /// Text and icons of the controls.
  static const Color foreground = Color(0xFFFFFFFF);

  /// Secondary ink over the picture (a title, a caption).
  static const Color inkMuted = Color(0xE6FFFFFF);

  /// Tertiary ink over the picture (a count, a badge).
  static const Color inkSubtle = Color(0x99FFFFFF);

  /// The faintest ink still readable (a corner affordance).
  static const Color inkFaint = Color(0x80FFFFFF);

  /// Icons that must step back (an avatar ghost, a splitter handle).
  static const Color iconDim = Color(0x66FFFFFF);

  /// The hover fill of a control over the picture, and the hairline outline
  /// of a pane drawn over it — one strength for both, so hover and edge
  /// read as the same touch.
  static const Color inkHover = Color(0x24FFFFFF);

  /// The pressed fill of a control over the picture.
  static const Color inkPressed = Color(0x2EFFFFFF);

  /// The soft chip fill behind a mark on the picture.
  static const Color chipFill = Color(0x1FFFFFFF);

  /// Icons drawn on [chipFill].
  static const Color iconOnChip = Color(0xD9FFFFFF);

  /// The empty part of a level bar over the picture.
  static const Color track = Color(0x33FFFFFF);

  /// The strong end of the shade a bar hangs on.
  static const Color scrim = Color(0xB3000000);

  /// A shade stronger than [scrim] (a HUD plate, the bottom bar of the
  /// wide layout).
  static const Color scrimDeep = Color(0xCC000000);

  /// The glass backing of a multi-view pane over its picture.
  static const Color paneGlass = Color(0x99000000);

  /// The light dimming of a state over a moving picture.
  static const Color dimLight = Color(0x66000000);

  /// The dimming when the cover stands in for the picture entirely.
  static const Color coverDimHeavy = Color(0xE6000000);

  /// The faint veil over the ambient backdrop.
  static const Color veil = Color(0x26000000);

  /// No colour at all — the end every shade fades to.
  static const Color clear = Color(0x00000000);

  /// The frosted pill's dark fill under the control row; the video's own
  /// motion bleeds through the frost above it.
  static const Color panel = Color(0x59000000);

  /// The one red every player uses to say "this is live / this is being
  /// captured".
  static const Color signal = Color(0xFFFF3B5C);

  /// The gold a platform gift flies in.
  static const Color giftGold = Color(0xFFFFD166);

  /// The menu plate over the picture (nearly opaque, so the video never
  /// reads through a word list).
  static const Color menuPlate = Color(0xF2131519);

  /// The user's colour on the picture (a picked cell's frame): the light
  /// tone of the primary in a light app, the primary itself in a dark one.
  static Color accent(ColorScheme scheme) =>
      scheme.brightness == Brightness.light ? scheme.inversePrimary : scheme.primary;

  /// The shade a bar hangs along [edge] of the picture: [strong] at the
  /// edge, fading straight out into the picture (the reference shades with
  /// a mid stop; the app's bars fade in two, the look the room mocks fixed).
  static LinearGradient shade({required VerticalDirection edge, Color strong = scrim}) => LinearGradient(
    begin: edge == VerticalDirection.up ? Alignment.topCenter : Alignment.bottomCenter,
    end: edge == VerticalDirection.up ? Alignment.bottomCenter : Alignment.topCenter,
    colors: [strong, clear],
  );
}

/// Ink on a colour the app did not choose (a platform's super chat gold, a
/// viewer's danmaku colour): dark ink on light grounds, white on dark ones.
///
/// [darkInkOn] compares the WCAG ratios of both inks instead of splitting at
/// a luminance midpoint — a 0.55 split puts white on mid golds at under 2:1,
/// while the ratio comparison always picks the ink that actually reads.
abstract final class InkOnColor {
  /// Dark text.
  static const Color dark = Color(0xDD000000);

  /// Secondary dark text.
  static const Color darkMuted = Color(0x8A000000);

  /// Light text.
  static const Color light = Color(0xFFFFFFFF);

  /// Secondary light text.
  static const Color lightMuted = Color(0xCCFFFFFF);

  /// Opaque dark ink.
  static const Color ink = Color(0xFF18181A);

  /// Secondary dark ink.
  static const Color inkMuted = Color(0x9E18181A);

  /// Whether dark [ink] has the higher contrast on [background] (WCAG).
  static bool darkInkOn(Color background) {
    final luminance = background.withValues(alpha: 1).computeLuminance();
    final darkRatio = (luminance + 0.05) / (ink.computeLuminance() + 0.05);
    final lightRatio = 1.05 / (luminance + 0.05);
    return darkRatio >= lightRatio;
  }

  /// [ink] or [light], whichever reads better on [background].
  static Color contrastOn(Color background) => darkInkOn(background) ? ink : light;

  /// The secondary form of [contrastOn].
  static Color contrastMutedOn(Color background) => darkInkOn(background) ? inkMuted : lightMuted;
}
