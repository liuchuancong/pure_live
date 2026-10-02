import 'dart:convert';

import 'package:flutter/widgets.dart';

/// 应用内悬浮窗记住的位置与尺寸，横屏与竖屏各一套。
///
/// 存在一条 JSON 字符串设置里，而不是 8 个 Hive 字段：后者要在 5 个备份管线位置各写
/// 一遍，而这两套几何只有两个消费者——悬浮窗显示时读、拖动/缩放结束或隐藏时写。
///
/// 坐标是应用表面内的逻辑坐标；表面形状变化（旋转、应用窗口改变大小）时由组件按当前
/// 表面重新夹取，所以这里只负责存与取。
@immutable
class FloatWindowGeometry {
  const FloatWindowGeometry({this.landscape, this.portrait});

  const FloatWindowGeometry.empty() : landscape = null, portrait = null;

  final Rect? landscape;
  final Rect? portrait;

  /// 当前源方向对应的那一套。
  Rect? forPortrait(bool isPortrait) => isPortrait ? portrait : landscape;

  /// 写入某一方向的一套，另一套原样保留。
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
      // 手改过的备份不该让悬浮窗起不来：当作没有记录过。
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
