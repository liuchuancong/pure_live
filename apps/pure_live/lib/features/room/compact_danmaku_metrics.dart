import 'dart:math' as math;

import 'package:pure_live/features/settings/pip_danmaku_scale_provider.dart' show resolvePipDanmakuScale;

/// The compact (picture-in-picture) danmaku geometry, following the
/// reference's `CompactDanmakuMetrics`: one width-derived or pinned factor
/// scales the size and the travel speed together, so a message crosses a
/// small window much as it crosses the room.
final class CompactDanmakuMetrics {
  const CompactDanmakuMetrics._({
    required this.scale,
    required this.fontSize,
    required this.baseSpeed,
    required this.trackHeight,
    required this.emojiSize,
    required this.overlapSafeGap,
  });

  /// Resolves the compact geometry from the main look and the window width.
  factory CompactDanmakuMetrics.resolve({
    required double width,
    required bool auto,
    required double pinnedScale,
    required double configuredFontSize,
    required double configuredSpeed,
  }) {
    final scale = resolvePipDanmakuScale(width: width, auto: auto, pinned: pinnedScale);
    final fontSize = configuredFontSize * scale;
    // flame_barrage allocates tracks with at least fontSize + 10 but paints
    // their offsets with the configured trackHeight; supplying that same
    // minimum keeps allocation and rendering geometry identical.
    final trackHeight = math.max(fontSize * 1.8, fontSize + 10).clamp(18.0, 88.0);
    return CompactDanmakuMetrics._(
      scale: scale,
      fontSize: fontSize,
      baseSpeed: configuredSpeed * scale,
      trackHeight: trackHeight,
      emojiSize: (fontSize * 1.35).clamp(14.0, 64.0),
      overlapSafeGap: (fontSize * 1.5).clamp(16.0, 80.0),
    );
  }

  /// The factor applied to the main look.
  final double scale;

  /// The scaled font size in pixels.
  final double fontSize;

  /// The scaled travel speed in pixels per second.
  final double baseSpeed;

  /// The lane height the engine allocates and paints with.
  final double trackHeight;

  /// The emoji picture size.
  final double emojiSize;

  /// The clearance between a message's tail and the next one.
  final double overlapSafeGap;

  /// The compact surface's smaller caches (the reference's pool sizes);
  /// kept here so the renderer and any preview share one contract.
  static const int barragePoolMaxSize = 32;
  static const int pictureCacheMaxSize = 48;
  static const int textCacheMaxSize = 160;
  static const int maxPendingCount = 36;
  static const Duration maxPendingAge = Duration(seconds: 3);
  static const Duration fixedDuration = Duration(seconds: 4);
}
