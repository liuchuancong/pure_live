import 'package:flutter/widgets.dart';

/// The elevation ladder and the shadow geometry built from it.
///
/// Elevation is a semantic index (how far above the surface a thing
/// floats), not a pixel value: Material maps index 2 to a dp value and a
/// tint, Neumorphic maps it to a pair of light and dark shadows, and a
/// flat language maps everything to zero. The shadow lists here are the
/// shared default other languages reuse.
abstract final class LiveElevation {
  /// 0 — flush with the surface (page background, list rows).
  static const double level0 = 0;

  /// 1 — barely raised (cards at rest).
  static const double level1 = 1;

  /// 2 — raised (hovered cards, buttons on desktop).
  static const double level2 = 2;

  /// 4 — floating (menus, popovers).
  static const double level4 = 4;

  /// 8 — overlaying (dialogs, sheets).
  static const double level8 = 8;

  /// 16 — highest (TV focus fly-outs, drag previews).
  static const double level16 = 16;

  /// The ladder in ascending order, for previews and diagnostics.
  static const List<double> scale = [level0, level1, level2, level4, level8, level16];

  /// A soft shadow of [elevation] in [color], the shared default shape.
  ///
  /// Two layers — a tight direct shadow and a wide ambient one — because a
  /// single big BlurStyle reads as a grey halo on dark themes.
  static List<BoxShadow> shadow({required Color color, double elevation = level2}) {
    if (elevation <= 0) {
      return const [];
    }
    final alpha = color.a;
    return [
      BoxShadow(
        color: color.withValues(alpha: alpha * 0.6),
        blurRadius: elevation * 1.5,
        offset: Offset(0, elevation * 0.5),
      ),
      BoxShadow(
        color: color.withValues(alpha: alpha * 0.35),
        blurRadius: elevation * 4,
        offset: Offset(0, elevation * 1.5),
      ),
    ];
  }
}
