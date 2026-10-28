import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/painting.dart' show FontWeight;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/modules/live/room/player/compact_danmaku_metrics.dart';

/// The flame engine's config for one room surface, translated from the
/// stored [DanmakuStyle]. The room page and the small surfaces (the PiP
/// window, the floating player) share this one mapping, so every danmaku
/// setting bites everywhere the flying layer draws; a small surface adds
/// [compact], the width-derived or pinned scaling from
/// [CompactDanmakuMetrics].
BarrageConfig roomBarrageConfig(
  DanmakuStyle style,
  int fps, {
  String? family,
  double? area,
  Duration? fixedDuration,
  CompactDanmakuMetrics? compact,
}) {
  final scale = compact?.scale ?? 1.0;
  return BarrageConfig(
    fontSize: compact?.fontSize ?? style.fontSize,
    // The reference's 字体粗细: 100–900, the flame layout's own default
    // being w500.
    fontWeight: FontWeight(style.fontWeight),
    // The reference's 文字间距 (danmakuLetterSpacing): pixels of extra space
    // between glyphs, negative to tighten; the compact factor scales it
    // with the text.
    letterSpacing: style.letterSpacing * scale,
    baseSpeed: compact?.baseSpeed ?? style.baseSpeed,
    area: area ?? style.area,
    // The reference's 顶部留白: pixels kept message-free at the top edge
    // before the area's share is measured.
    topAreaDistance: style.topMargin,
    // The reference's 底部留白: pixels kept message-free at the bottom edge,
    // so subtitles stay readable.
    bottomAreaDistance: style.bottomMargin,
    opacity: style.opacity,
    showStroke: style.showStroke,
    // The reference's 描边宽度 (danmakuFontBorder): the flame layout strokes
    // each glyph with this width when the outline is on.
    strokeWidth: style.strokeWidth,
    // The reference's 纯文字模式: the flame layout skips the emoji pictures
    // and keeps the words.
    noEmojiMode: style.noEmoji,
    fontFamily: family ?? style.fontFamily,
    // The reference's 海量模式: realtime dispatch and a fixed 1000-message
    // ceiling; otherwise the chosen 10–120 cap.
    realtimeMode: style.massMode,
    maxVisibleCount: style.massMode ? kDanmakuMassModeMaxVisibleCount : style.maxVisibleCount,
    // The reference's 弹幕帧率: the manual rate, or the display policy's cap
    // (60 FPS in power saving/balanced).
    fps: fps,
    // The room surface keeps the engine defaults; the compact surface's
    // lane geometry and pool sizes come from CompactDanmakuMetrics.
    trackHeight: compact?.trackHeight ?? 36,
    emojiSize: compact?.emojiSize ?? 24,
    overlapSafeGap: compact?.overlapSafeGap ?? 40,
    safeArea: compact == null,
    maxPendingCount: compact == null ? 120 : CompactDanmakuMetrics.maxPendingCount,
    maxPendingAge: compact == null ? const Duration(seconds: 5) : CompactDanmakuMetrics.maxPendingAge,
    // The reference's 固定弹幕停留时长: how long a top- or bottom-pinned
    // message stays on a room surface (a compact surface keeps its own
    // shorter stay, which is what fits inside a small window).
    fixedDuration: compact == null ? (fixedDuration ?? const Duration(seconds: 4)) : CompactDanmakuMetrics.fixedDuration,
    barragePoolMaxSize: compact == null ? 150 : CompactDanmakuMetrics.barragePoolMaxSize,
    pictureCacheMaxSize: compact == null ? 200 : CompactDanmakuMetrics.pictureCacheMaxSize,
    textCacheMaxSize: compact == null ? 1000 : CompactDanmakuMetrics.textCacheMaxSize,
  );
}
