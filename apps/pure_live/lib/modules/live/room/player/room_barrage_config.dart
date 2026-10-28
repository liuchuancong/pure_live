import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/painting.dart' show Color, FontStyle, FontWeight, Offset;
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
    // The reference's 斜体: the engine's `fontStyle`.
    fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
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
    // The reference's 文字颜色/描边颜色: the fill and the outline's own ink.
    textColor: Color(style.textColor),
    strokeColor: Color(style.strokeColor),
    showStroke: style.showStroke,
    // The reference's 描边宽度 (danmakuFontBorder): the flame layout strokes
    // each glyph with this width when the outline is on.
    strokeWidth: style.strokeWidth,
    // The reference's 阴影: a cached paragraph shadow, no per-frame saveLayer.
    showShadow: style.showShadow,
    shadowColor: Color(style.shadowColor),
    shadowBlur: style.shadowBlur,
    shadowOffset: Offset(style.shadowOffsetX, style.shadowOffsetY),
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
    // The reference's 轨道高度/表情大小/重叠间距: the room surface draws them
    // as stored; a compact surface derives them from its scaled text.
    trackHeight: compact?.trackHeight ?? style.trackHeight,
    emojiSize: compact?.emojiSize ?? style.emojiSize,
    overlapSafeGap: compact?.overlapSafeGap ?? style.overlapSafeGap,
    // The reference's 安全区: a device screen insets its edges; a window
    // inside the app does not.
    safeArea: compact == null && style.safeArea,
    // The reference's 队列: how many messages wait for a lane, and how long
    // one may wait before the layer drops it. A compact surface keeps the
    // smaller queue that fits its window.
    maxPendingCount: compact == null ? style.maxPendingCount : CompactDanmakuMetrics.maxPendingCount,
    maxPendingAge: compact == null
        ? Duration(milliseconds: (style.maxPendingAge * 1000).round())
        : CompactDanmakuMetrics.maxPendingAge,
    // The reference's 发送间隔: the normal dispatch tick; mass mode bypasses
    // it.
    emitInterval: style.emitInterval,
    // The reference's 固定弹幕停留时长: how long a top- or bottom-pinned
    // message stays on a room surface (a compact surface keeps its own
    // shorter stay, which is what fits inside a small window).
    fixedDuration: compact == null
        ? (fixedDuration ?? const Duration(seconds: 4))
        : CompactDanmakuMetrics.fixedDuration,
    // The reference's 光栅化 and its caches: the room surface keeps the
    // stored sizes, the compact surface its smaller ones.
    rasterizeItems: style.rasterize,
    barragePoolMaxSize: compact == null ? style.barragePoolMaxSize : CompactDanmakuMetrics.barragePoolMaxSize,
    pictureCacheMaxSize: compact == null ? style.pictureCacheMaxSize : CompactDanmakuMetrics.pictureCacheMaxSize,
    textCacheMaxSize: compact == null ? style.textCacheMaxSize : CompactDanmakuMetrics.textCacheMaxSize,
    rasterCacheMaxBytes: style.rasterCacheMb * 1024 * 1024,
  );
}
