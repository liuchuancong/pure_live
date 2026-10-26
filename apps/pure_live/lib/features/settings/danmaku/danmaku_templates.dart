import 'dart:convert';

import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_style_providers.dart';

/// The saved look's storage key (the reference's `savedDanmakuTemplate`).
const String kSavedDanmakuTemplateKey = 'danmaku.style.template';

/// A danmaku look the viewer saved with one tap (the reference's
/// `DanmakuTemplate` / 3.x `DanmakuViewingTemplate`, schema 2): the area, the
/// margins, speed, size, weight, border, opacity, outline, pure-text switch
/// and frame pacing. Letter spacing, typeface, same-screen cap and mass mode
/// are not part of the template, as in the reference.
final class DanmakuTemplate {
  /// Creates a template.
  const DanmakuTemplate({
    required this.area,
    required this.speed,
    required this.fontSize,
    required this.fontBorder,
    required this.opacity,
    this.top = 0,
    this.bottom = 0,
    this.fontWeight = 500,
    this.stroke = true,
    this.noEmojiMode = false,
    this.fps = 60,
    this.autoFps = true,
  });

  /// The live look, as the save action reads it.
  factory DanmakuTemplate.of(DanmakuStyle style, DanmakuFrameRate frameRate) => DanmakuTemplate(
    area: style.area,
    top: style.topMargin,
    bottom: style.bottomMargin,
    speed: style.baseSpeed,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    fontBorder: style.strokeWidth,
    opacity: style.opacity,
    stroke: style.showStroke,
    noEmojiMode: style.noEmoji,
    fps: frameRate.fps,
    autoFps: frameRate.autoFps,
  );

  /// The schema written into [encode].
  static const int schemaVersion = 2;

  /// Display area, 0 to 1.
  final double area;

  /// Pixels kept free above.
  final double top;

  /// Pixels kept free below.
  final double bottom;

  /// Speed, in pixels per second.
  final double speed;

  /// Font size, in pixels.
  final double fontSize;

  /// Font weight, 100 to 900.
  final int fontWeight;

  /// Border width, in pixels.
  final double fontBorder;

  /// Opacity, 0 to 1.
  final double opacity;

  /// Whether the outline is on.
  final bool stroke;

  /// Whether emoticon pictures are hidden.
  final bool noEmojiMode;

  /// Manual frame rate.
  final int fps;

  /// Whether the frame rate follows the display.
  final bool autoFps;

  /// The reference's saved form: a schema-2 JSON object.
  String encode() => jsonEncode({
    'version': schemaVersion,
    'noEmojiMode': noEmojiMode,
    'area': area,
    'top': top,
    'bottom': bottom,
    'speed': speed,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'fontBorder': fontBorder,
    'opacity': opacity,
    'stroke': stroke,
    'fps': fps,
    'autoFps': autoFps,
  });

  /// Reads a saved template; null when it is damaged or a value is out of
  /// range (nothing is applied then). Missing optional fields take
  /// [fallback]'s, as in the reference.
  static DanmakuTemplate? tryDecode(String raw, DanmakuTemplate fallback) {
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, Object?>) return null;
      double number(String name, double min, double max) {
        final field = value[name];
        if (field is! num || !field.isFinite || field < min || field > max) throw FormatException(name);
        return field.toDouble();
      }

      bool flag(String name, {required bool otherwise}) {
        if (!value.containsKey(name)) return otherwise;
        final field = value[name];
        if (field is! bool) throw FormatException(name);
        return field;
      }

      int whole(String name, int otherwise, int min, int max) {
        if (!value.containsKey(name)) return otherwise;
        final field = value[name];
        if (field is! num || field != field.roundToDouble() || field < min || field > max) {
          throw FormatException(name);
        }
        return field.toInt();
      }

      return DanmakuTemplate(
        noEmojiMode: flag('noEmojiMode', otherwise: fallback.noEmojiMode),
        area: number('area', 0, 1),
        top: number('top', 0, 300),
        bottom: number('bottom', 0, 300),
        speed: number('speed', 20, 400),
        fontSize: number('fontSize', 10, 30),
        fontWeight: whole('fontWeight', fallback.fontWeight, 100, 900),
        fontBorder: number('fontBorder', 0, 4),
        opacity: number('opacity', 0, 1),
        stroke: flag('stroke', otherwise: fallback.stroke),
        fps: whole('fps', fallback.fps, 30, 240),
        autoFps: flag('autoFps', otherwise: fallback.autoFps),
      );
    } on FormatException {
      return null;
    }
  }
}

/// The stored template JSON, or null when nothing usable was saved.
String? readSavedDanmakuTemplate() {
  try {
    final raw = StoragePrefs.getString(kSavedDanmakuTemplateKey)?.trim();
    return raw == null || raw.isEmpty ? null : raw;
  } on Object {
    return null;
  }
}

/// Saves [raw] as the viewer's template; a closed store loses it, nothing else.
Future<void> writeSavedDanmakuTemplate(String raw) async {
  try {
    await StoragePrefs.setString(kSavedDanmakuTemplateKey, raw);
  } on Object {
    // A preference; a closed store loses it.
  }
}

/// Writes [template] into the live look, as one style update plus one pacing
/// update, so the flying layer rebuilds at most twice.
Future<void> applyDanmakuTemplate(
  DanmakuTemplate template, {
  required DanmakuStyleController style,
  required DanmakuFrameRateController frameRate,
}) async {
  await style.applyTemplate(
    area: template.area,
    topMargin: template.top,
    bottomMargin: template.bottom,
    baseSpeed: template.speed,
    fontSize: template.fontSize,
    fontWeight: template.fontWeight,
    strokeWidth: template.fontBorder,
    opacity: template.opacity,
    showStroke: template.stroke,
    noEmoji: template.noEmojiMode,
  );
  await frameRate.applyTemplate(fps: template.fps, autoFps: template.autoFps);
}
