import 'package:flutter/material.dart';

/// The banner a paid line wears, in the platform's own colour when it has one.
///
/// Bilibili, Douyu, Huya, YouTube and 17Live each send the colours their site
/// gives a super chat, and a paid line is the one place in the room where the
/// platform is allowed to speak for itself. Reading them raw would put a site's
/// saturated gold under the column's own text, so the hue is held back toward
/// the surface it sits on: the money keeps the platform's family, the words
/// keep the contrast the theme chose.
({Color fill, Color edge})? paidBanner(String hex, Color surface) {
  final color = platformColor(hex);
  if (color == null) return null;
  return (fill: Color.lerp(color, surface, 0.78)!, edge: Color.lerp(color, surface, 0.55)!);
}

/// The same, as the two-colour banner a super chat's own card wears: [weight]
/// is how much of the platform shows, so a card can keep grading by the money
/// on the line while still wearing the platform's family. Null when the
/// platform sends no top colour, which is where the caller's theme fill stays;
/// without a tail colour the card keeps one hue.
Gradient? paidBannerGradient({
  required String top,
  required String bottom,
  required Color surface,
  double weight = 0.22,
}) {
  final first = platformColor(top);
  if (first == null) return null;
  final second = platformColor(bottom) ?? first;
  return LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [Color.lerp(first, surface, 1 - weight)!, Color.lerp(second, surface, 1 - weight)!],
  );
}

/// A platform's colour as it writes it: `#RRGGBB`, `#AARRGGBB`, or the same
/// without the `#`. Nothing else is a colour - a name, an `rgb()` call or a
/// truncated string falls back to the theme instead of painting the column
/// grey, because a paid line the platform cannot describe is not worth a
/// mis-read fill.
Color? platformColor(String value) {
  final hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  final code = int.tryParse(hex, radix: 16);
  if (code == null) return null;
  return hex.length == 8 ? Color(code) : Color(0xFF000000 | code);
}
