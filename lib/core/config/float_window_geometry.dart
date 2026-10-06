import 'dart:convert';

import 'package:flutter/widgets.dart';

@immutable
class FloatWindowGeometry {
  const FloatWindowGeometry({this.landscape, this.portrait});

  const FloatWindowGeometry.empty() : landscape = null, portrait = null;

  final Rect? landscape;
  final Rect? portrait;

  Rect? forPortrait(bool isPortrait) => isPortrait ? portrait : landscape;

  /// Whether the surface the small window floats in is taller than it is wide.
  ///
  /// The window is remembered per surface orientation: a phone held upright and
  /// the same phone turned sideways have different room on screen, and a size
  /// that suits one of them is wrong in the other. A size that is unknown or
  /// degenerate counts as landscape, which is where the anchor places a window
  /// that has no memory yet.
  static bool isPortraitSurface(Size size) {
    if (!size.isFinite || size.isEmpty) return false;
    return size.height > size.width;
  }

  FloatWindowGeometry withRect({required bool isPortrait, required Rect rect}) {
    return isPortrait
        ? FloatWindowGeometry(landscape: landscape, portrait: rect)
        : FloatWindowGeometry(landscape: rect, portrait: portrait);
  }

  String encode() {
    final map = <String, dynamic>{};
    final left = landscape;
    final right = portrait;
    if (left != null) map['landscape'] = _encodeRect(left);
    if (right != null) map['portrait'] = _encodeRect(right);
    return jsonEncode(map);
  }

  static FloatWindowGeometry decode(String raw) {
    if (raw.trim().isEmpty) return const FloatWindowGeometry.empty();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const FloatWindowGeometry.empty();
      return FloatWindowGeometry(
        landscape: _decodeRect(decoded['landscape']),
        portrait: _decodeRect(decoded['portrait']),
      );
    } catch (_) {
      return const FloatWindowGeometry.empty();
    }
  }

  static List<double> _encodeRect(Rect rect) => <double>[rect.left, rect.top, rect.width, rect.height];

  static Rect? _decodeRect(Object? raw) {
    if (raw is! List || raw.length != 4) return null;
    final values = <double>[];
    for (final entry in raw) {
      if (entry is! num || !entry.isFinite) return null;
      values.add(entry.toDouble());
    }
    final rect = Rect.fromLTWH(values[0], values[1], values[2], values[3]);
    if (!rect.isFinite || rect.isEmpty) return null;
    return rect;
  }
}
