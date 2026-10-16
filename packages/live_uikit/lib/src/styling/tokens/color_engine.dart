import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Colour and scale maths ported from Ant Design v5's token derivation
/// (`@ant-design/colors` `generate`, the `default`/`dark` neutral palettes and
/// the `gen*MapToken` helpers). This is the arithmetic that turns a handful of
/// *seed* values into the full derived palette — the reason one brand colour
/// produces a complete, accessible ramp of backgrounds, borders, hovers, active
/// states and text without any hand-authored variants.
abstract final class ColorEngine {
  /// `getAlphaColor` — the base colour with its alpha replaced by [alpha].
  static Color alpha(Color base, double alpha) => base.withValues(alpha: alpha);

  /// `getSolidColor`: an HSV *value* shift (the light algorithm darkens, the
  /// dark one lightens) by [percent] out of 100 — mirroring how Ant's
  /// `FastColor.darken/lighten` adjust the value channel, not lightness.
  static Color solid(Color base, double percent, {required bool dark}) {
    final (h, s, v) = _toHsv(base);
    final value = (dark ? v + percent / 100 : v - percent / 100).clamp(0.0, 1.0);
    return _fromHsv(h, s, value);
  }

  /// The `@ant-design/colors` `generate` ramp, ported faithfully: ten colours
  /// where index 5 (the sixth) is the seed itself, 0..4 are lighter tints and
  /// 6..9 darker shades, each step nudging hue, saturation and value by Ant's
  /// published constants rather than a plain lightness interpolation. For a
  /// dark theme the same list is re-indexed the way `dark/colors.ts` does.
  static List<Color> palette(Color base, {bool dark = false}) {
    final (h, s, v) = _toHsv(base);
    final out = <Color>[];
    for (var i = _lightCount; i > 0; i--) {
      out.add(_fromHsv(_hue(h, i, true), _saturation(s, i, true), _value(v, i, true)));
    }
    out.add(base);
    for (var i = 1; i <= _darkCount; i++) {
      out.add(_fromHsv(_hue(h, i, false), _saturation(s, i, false), _value(v, i, false)));
    }
    if (!dark) {
      return out;
    }
    // Ant's dark palette order over the generated list (1-based → 0-based).
    return [out[0], out[1], out[2], out[3], out[6], out[5], out[4], out[6], out[5], out[4]];
  }

  static const double _hueStep = 2;
  static const double _saturationStep = 0.16;
  static const double _saturationStep2 = 0.05;
  static const double _brightnessStep1 = 0.05;
  static const double _brightnessStep2 = 0.15;
  static const int _lightCount = 5;
  static const int _darkCount = 4;

  static double _hue(double h, int i, bool light) {
    var hue = (h >= 60 && h <= 240)
        ? (light ? h - _hueStep * i : h + _hueStep * i)
        : (light ? h + _hueStep * i : h - _hueStep * i);
    if (hue < 0) {
      hue += 360;
    } else if (hue >= 360) {
      hue -= 360;
    }
    return hue;
  }

  static double _saturation(double s, int i, bool light) {
    var saturation = light
        ? s - _saturationStep * i
        : (i == _darkCount ? s + _saturationStep : s + _saturationStep2 * i);
    if (saturation > 1) {
      saturation = 1;
    }
    if (light && i == _lightCount && saturation > 0.1) {
      saturation = 0.1;
    }
    if (saturation < 0.06) {
      saturation = 0.06;
    }
    return saturation;
  }

  static double _value(double v, int i, bool light) {
    var value = light ? v + _brightnessStep1 * i : v - _brightnessStep2 * i;
    if (value > 1) {
      value = 1;
    }
    return value;
  }

  /// rgb (0..1) → (hue 0..360, saturation 0..1, value 0..1).
  static (double, double, double) _toHsv(Color c) {
    final r = c.r;
    final g = c.g;
    final b = c.b;
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final delta = maxV - minV;
    var hue = 0.0;
    if (delta != 0) {
      if (maxV == r) {
        hue = ((g - b) / delta) % 6;
      } else if (maxV == g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue *= 60;
      if (hue < 0) {
        hue += 360;
      }
    }
    final saturation = maxV == 0 ? 0.0 : delta / maxV;
    return (hue, saturation, maxV);
  }

  /// (hue 0..360, saturation 0..1, value 0..1) → rgb.
  static Color _fromHsv(double h, double s, double v) {
    final c = v * s;
    final hp = h / 60;
    final x = c * (1 - (hp % 2 - 1).abs());
    double r1;
    double g1;
    double b1;
    if (hp < 1) {
      r1 = c;
      g1 = x;
      b1 = 0;
    } else if (hp < 2) {
      r1 = x;
      g1 = c;
      b1 = 0;
    } else if (hp < 3) {
      r1 = 0;
      g1 = c;
      b1 = x;
    } else if (hp < 4) {
      r1 = 0;
      g1 = x;
      b1 = c;
    } else if (hp < 5) {
      r1 = x;
      g1 = 0;
      b1 = c;
    } else {
      r1 = c;
      g1 = 0;
      b1 = x;
    }
    final m = v - c;
    return Color.fromRGBO(_to255(r1 + m), _to255(g1 + m), _to255(b1 + m), 1);
  }

  static int _to255(double channel) {
    final value = (channel * 255).round();
    if (value < 0) {
      return 0;
    }
    if (value > 255) {
      return 255;
    }
    return value;
  }
}

/// The ten-step semantic slots Ant assigns to each colour ramp. Kept as a small
/// value object so `MapToken` exposes `colorPrimaryBg … colorPrimaryTextActive`
/// without repeating the indexing arithmetic per role.
class ColorRamp {
  /// A ramp from its ten colours (index 0 is the lightest tint, 5 the seed).
  const new(this.steps);

  /// Derives a ramp from a [base] seed colour, honouring the [dark] algorithm.
  factory of(Color base, {bool dark = false}) => ColorRamp(ColorEngine.palette(base, dark: dark));

  /// The ten steps, lightest first.
  final List<Color> steps;

  /// `*Bg` — the lightest tint (level 1).
  Color get bg => steps[0];

  /// `*BgHover` (level 2).
  Color get bgHover => steps[1];

  /// `*Border` (level 3).
  Color get border => steps[2];

  /// `*BorderHover` (level 4).
  Color get borderHover => steps[3];

  /// `*Hover` (level 5).
  Color get hover => steps[4];

  /// The base colour itself (level 6).
  Color get base => steps[5];

  /// `*Active` (level 7).
  Color get active => steps[6];

  /// `*TextHover` (level 8).
  Color get textHover => steps[7];

  /// `*Text` (level 9).
  Color get text => steps[8];

  /// `*TextActive` (level 10).
  Color get textActive => steps[9];
}

/// `genFontSizes`: the ten-step modular type scale, base size index 1 and
/// `lineHeight = (size + 8) / size`, rounded to even pixels.
List<({double size, double lineHeight})> genFontSizes(double base) {
  final sizes = List.generate(10, (index) {
    final i = index - 1;
    final raw = base * math.exp(i / 5);
    final rounded = index > 1 ? raw.floorToDouble() : raw.ceilToDouble();
    return (rounded / 2).floorToDouble() * 2;
  });
  sizes[1] = base;
  return [for (final size in sizes) (size: size, lineHeight: (size + 8) / size)];
}

/// `genControlHeight`.
({double sm, double xs, double lg}) genControlHeight(double controlHeight) =>
    (sm: controlHeight * 0.75, xs: controlHeight * 0.5, lg: controlHeight * 1.25);

/// `genSizeMapToken`.
///
/// Ant's formula is written for a `sizeStep` of 4 or more; the compact density
/// algorithm steps it down twice, and `sizeStep - 3` then goes negative — a
/// negative padding, gap or minimum height reaches Flutter and throws
/// (`BoxConstraints has a negative minimum height`, `padding.isNonNegative`).
/// The ramp is clamped at zero here rather than at each call site: the scale is
/// the one place that knows these are distances.
DesignSizes genSizes(double sizeUnit, double sizeStep) {
  double step(int offset) => sizeUnit * (sizeStep + offset);
  return DesignSizes(
    xxl: step(8),
    xl: step(4),
    lg: step(2),
    md: step(1),
    ms: step(0),
    sm: math.max(0, step(-1)),
    xs: math.max(0, step(-2)),
    xxs: math.max(0, step(-3)),
  );
}

/// `genRadius` — the derived corner radii from a single base radius.
DesignRadii genRadii(double radiusBase) {
  var lg = radiusBase;
  var sm = radiusBase;
  var xs = radiusBase;
  var outer = radiusBase;
  if (radiusBase < 6 && radiusBase >= 5) {
    lg = radiusBase + 1;
  } else if (radiusBase < 16 && radiusBase >= 6) {
    lg = radiusBase + 2;
  } else if (radiusBase >= 16) {
    lg = 16;
  }
  if (radiusBase < 7 && radiusBase >= 5) {
    sm = 4;
  } else if (radiusBase < 8 && radiusBase >= 7) {
    sm = 5;
  } else if (radiusBase < 14 && radiusBase >= 8) {
    sm = 6;
  } else if (radiusBase < 16 && radiusBase >= 14) {
    sm = 7;
  } else if (radiusBase >= 16) {
    sm = 8;
  }
  if (radiusBase < 6 && radiusBase >= 2) {
    xs = 1;
  } else if (radiusBase >= 6) {
    xs = 2;
  }
  if (radiusBase > 4 && radiusBase < 8) {
    outer = 4;
  } else if (radiusBase >= 8) {
    outer = 6;
  }
  return DesignRadii(base: radiusBase, sm: sm, xs: xs, lg: lg, outer: outer);
}

/// The size scale (levels of spacing) derived from `sizeUnit`/`sizeStep`.
class DesignSizes {
  /// The scales.
  const new({
    required this.xxl,
    required this.xl,
    required this.lg,
    required this.md,
    required this.ms,
    required this.sm,
    required this.xs,
    required this.xxs,
  });

  /// The largest gap.
  final double xxl;

  /// XL gap.
  final double xl;

  /// Large gap.
  final double lg;

  /// Medium-large gap.
  final double md;

  /// Medium-small base.
  final double ms;

  /// Small gap.
  final double sm;

  /// Extra-small gap.
  final double xs;

  /// The smallest gap.
  final double xxs;
}

/// The corner-radius scale derived from one base radius.
class DesignRadii {
  /// The radii.
  const new({required this.base, required this.sm, required this.xs, required this.lg, required this.outer});

  /// The base control radius.
  final double base;

  /// The small radius.
  final double sm;

  /// The extra-small radius.
  final double xs;

  /// The large (card/dialog) radius.
  final double lg;

  /// The outer radius for nested surfaces.
  final double outer;
}
