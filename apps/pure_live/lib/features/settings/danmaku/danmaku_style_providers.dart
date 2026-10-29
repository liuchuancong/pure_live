import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The flying danmaku's look and motion (the reference's danmaku settings,
/// every knob of the flame layer's own config): the type — size, weight,
/// slant, spacing, face, colour, outline and shadow — the motion — speed,
/// the share of the picture messages cross, the margins and lane geometry
/// kept clear — how long a pinned message stays, the queue the layer drains,
/// and the caches it keeps while it draws.
typedef DanmakuStyle = ({
  double fontSize,
  int fontWeight,
  bool italic,
  double letterSpacing,
  double baseSpeed,
  double area,
  double topMargin,
  double bottomMargin,
  double opacity,
  bool showStroke,
  int textColor,
  int strokeColor,
  double strokeWidth,
  bool showShadow,
  int shadowColor,
  double shadowBlur,
  double shadowOffsetX,
  double shadowOffsetY,
  bool noEmoji,
  String? fontFamily,
  int maxVisibleCount,
  bool massMode,
  double trackHeight,
  double emojiSize,
  bool safeArea,
  double overlapSafeGap,
  int maxPendingCount,
  double maxPendingAge,
  double emitInterval,
  bool rasterize,
  int barragePoolMaxSize,
  int pictureCacheMaxSize,
  int textCacheMaxSize,
  int rasterCacheMb,
});

const DanmakuStyle _defaults = (
  fontSize: 16,
  fontWeight: 500,
  italic: false,
  letterSpacing: 0,
  baseSpeed: 120,
  area: 1.0,
  topMargin: 0,
  bottomMargin: 0.5,
  opacity: 1.0,
  showStroke: true,
  textColor: 0xFFFFFFFF,
  strokeColor: 0xFF000000,
  strokeWidth: 1.5,
  showShadow: false,
  shadowColor: 0xFF000000,
  shadowBlur: 0,
  shadowOffsetX: 1,
  shadowOffsetY: 1,
  noEmoji: false,
  fontFamily: null,
  maxVisibleCount: 48,
  massMode: false,
  trackHeight: 36,
  emojiSize: 24,
  safeArea: true,
  overlapSafeGap: 40,
  maxPendingCount: 120,
  maxPendingAge: 5,
  emitInterval: 0.1,
  rasterize: true,
  barragePoolMaxSize: 150,
  pictureCacheMaxSize: 200,
  textCacheMaxSize: 1000,
  rasterCacheMb: 24,
);

/// The colours the text, outline and shadow rows offer. The engine takes any
/// ARGB value; these are the ones the settings screen can still name out
/// loud, and the first entry is each face's engine default.
const List<int> kDanmakuColorChoices = [
  0xFFFFFFFF,
  0xFF000000,
  0xFFFF4D4F,
  0xFFFF8A3D,
  0xFFFFD666,
  0xFF52C41A,
  0xFF36CFC9,
  0xFF1677FF,
  0xFF9254DE,
  0xFFFF85C0,
];

/// Whether [value] is one the palette names.
bool isDanmakuPaletteColor(int value) => kDanmakuColorChoices.contains(value);

/// A stored colour from the palette; an unknown one (a backup from another
/// build) reads as [fallback].
int normalizeDanmakuColor(int? value, int fallback) => value != null && isDanmakuPaletteColor(value) ? value : fallback;

/// The words for a palette colour.
String danmakuColorLabel(Translations t, int value) => switch (value) {
  0xFFFFFFFF => t.settings.danmakuColorWhite,
  0xFF000000 => t.settings.danmakuColorBlack,
  0xFFFF4D4F => t.settings.danmakuColorRed,
  0xFFFF8A3D => t.settings.danmakuColorOrange,
  0xFFFFD666 => t.settings.danmakuColorYellow,
  0xFF52C41A => t.settings.danmakuColorGreen,
  0xFF36CFC9 => t.settings.danmakuColorCyan,
  0xFF1677FF => t.settings.danmakuColorBlue,
  0xFF9254DE => t.settings.danmakuColorPurple,
  _ => t.settings.danmakuColorPink,
};

/// The reference's mass-mode cap: `danmakuMassMode` raises the same-screen
/// limit to 1000 and asks the renderer for its realtime path.
const int kDanmakuMassModeMaxVisibleCount = 1000;

/// The reference's same-screen cap (its `danmakuMaxVisibleCount`): 10–120,
/// 48 by default; an out-of-range stored value (a TV backup's 0 for
/// "by device", say) reads as the default (its `resetOutOfRange`).
int normalizeDanmakuMaxVisibleCount(int? value) {
  if (value == null || value < DanmakuStyleRange.maxVisibleMin || value > DanmakuStyleRange.maxVisibleMax) {
    return DanmakuStyleRange.maxVisibleDefault;
  }
  return value;
}

/// The reference's nine weight stops, thin (100) through black (900).
const List<int> kDanmakuFontWeights = [100, 200, 300, 400, 500, 600, 700, 800, 900];

/// Snaps a stored weight to the reference's 100-step stops within 100–900
/// (its `normalizeFontWeight`); anything unusable falls back to 500.
int normalizeDanmakuFontWeight(int? value) {
  final raw = (value ?? 500).clamp(100, 900);
  return (raw / 100).round() * 100;
}

/// The words for the weight stops, from thin to black.
String danmakuFontWeightLabel(Translations t, int weight) => switch (normalizeDanmakuFontWeight(weight)) {
  100 => t.settings.styleWeightThin,
  200 => t.settings.styleWeightExtraLight,
  300 => t.settings.styleWeightLight,
  400 => t.settings.styleWeightNormal,
  500 => t.settings.styleWeightMedium,
  600 => t.settings.styleWeightSemiBold,
  700 => t.settings.styleWeightBold,
  800 => t.settings.styleWeightExtraBold,
  _ => t.settings.styleWeightBlack,
};

/// The ranges the settings surface offers; the flame layer's own design
/// bounds, kept beside the controller so a slider and its consumer can
/// never disagree.
abstract final class DanmakuStyleRange {
  /// The type size's range, in pixels (the reference's `danmakuFontSize`:
  /// 10–30, default 16).
  static const double fontSizeMin = 10;
  static const double fontSizeMax = 30;

  /// The weight's range and granularity (the reference's
  /// `danmakuFontWeight`: 100–900 in 100 steps, default 500).
  static const int fontWeightMin = 100;
  static const int fontWeightMax = 900;
  static const int fontWeightDivisions = 8;

  /// The extra gap between glyphs, in pixels (the reference's
  /// `danmakuLetterSpacing`: -2–8, default 0; negative tightens the text).
  static const double letterSpacingMin = -2;
  static const double letterSpacingMax = 8;

  /// The speed's range, in pixels per second (the reference's
  /// `danmakuSpeed`: 20–400, default 120).
  static const double speedMin = 20;
  static const double speedMax = 400;

  /// The share of the picture's height the flying messages may use (the
  /// reference's `danmakuArea`: 0–1, default 1, 1% steps).
  static const double areaMin = 0;
  static const double areaMax = 1;

  /// The 1% granularity of the reference's area slider.
  static const int areaDivisions = 100;

  /// The opacity's range (the reference's `danmakuOpacity`: 0–1,
  /// default 1; its reader clamps out-of-range stored values too).
  static const double opacityMin = 0;
  static const double opacityMax = 1;

  /// The top margin's range, in pixels (the reference's `danmakuTopArea`:
  /// 0–300, default 0).
  static const double topMarginMin = 0;
  static const double topMarginMax = 300;

  /// The bottom margin's range, in pixels (the reference's
  /// `danmakuBottomArea`: 0–300, default 0.5 as `defaultDanmakuBottomArea`;
  /// the whole-pixel field rounds it to 0 until edited).
  static const double bottomMarginMin = 0;
  static const double bottomMarginMax = 300;

  /// The outline's width, in pixels (the reference's `danmakuFontBorder`:
  /// 0–4, default 1.5 as `defaultDanmakuFontBorder`).
  static const double strokeWidthMin = 0;
  static const double strokeWidthMax = 4;

  /// The same-screen cap (the reference's `danmakuMaxVisibleCount`):
  /// 10–120, 48 by default; the slider's 55 steps of two keep 48 on a stop.
  static const int maxVisibleMin = 10;
  static const int maxVisibleMax = 120;
  static const int maxVisibleDivisions = 55;
  static const int maxVisibleDefault = 48;

  /// The frame rate's range (the reference's `danmakuFps`: 30–240,
  /// default 60, one-frame steps).
  static const int fpsMin = 30;
  static const int fpsMax = 240;
  static const int fpsDefault = 60;
  static const int fpsDivisions = fpsMax - fpsMin;

  /// The shadow's blur radius (the engine's `shadowBlur`: 0–20, default 0 —
  /// the shadow is off until its switch turns it on).
  static const double shadowBlurMin = 0;
  static const double shadowBlurMax = 20;

  /// The shadow's offset from the glyph, in pixels (the engine's
  /// `shadowOffset`: -4–4 each way, default 1, 1).
  static const double shadowOffsetMin = -4;
  static const double shadowOffsetMax = 4;
  static const int shadowOffsetDivisions = 8;

  /// A lane's height in pixels (the engine's `trackHeight`: 18–88, default
  /// 36). Too short and glyphs clip, too tall and the picture loses rows.
  static const double trackHeightMin = 18;
  static const double trackHeightMax = 88;

  /// An emoji picture's edge in pixels (the engine's `emojiSize`: 14–64,
  /// default 24).
  static const double emojiSizeMin = 14;
  static const double emojiSizeMax = 64;

  /// The clearance a message's tail keeps from the next one (the engine's
  /// `overlapSafeGap`: 0–120, default 40).
  static const double overlapSafeGapMin = 0;
  static const double overlapSafeGapMax = 120;

  /// The waiting queue's cap (the engine's `maxPendingCount`: 10–500,
  /// default 120).
  static const int maxPendingMin = 10;
  static const int maxPendingMax = 500;

  /// How long a message may wait for a lane before it is dropped (the
  /// engine's `maxPendingAge`: 1–15 s, default 5).
  static const double maxPendingAgeMin = 1;
  static const double maxPendingAgeMax = 15;

  /// The dispatch clock's tick (the engine's `emitInterval`: 0–1 s,
  /// default 0.1); mass mode bypasses it.
  static const double emitIntervalMin = 0;
  static const double emitIntervalMax = 1;

  /// The recycled message pool (the engine's `barragePoolMaxSize`: 16–600,
  /// default 150).
  static const int barragePoolMin = 16;
  static const int barragePoolMax = 600;

  /// The LRU picture cache (the engine's `pictureCacheMaxSize`: 16–800,
  /// default 200).
  static const int pictureCacheMin = 16;
  static const int pictureCacheMax = 800;

  /// The compiled text layout cache (the engine's `textCacheMaxSize`:
  /// 100–4000, default 1000).
  static const int textCacheMin = 100;
  static const int textCacheMax = 4000;

  /// The rasterized-message cache's budget in MB (the engine's
  /// `rasterCacheMaxBytes`, 4–128 MB, default 24).
  static const int rasterCacheMbMin = 4;
  static const int rasterCacheMbMax = 128;
}

/// Owns the danmaku style, persisted under `danmaku.style.*`; the player
/// surface rebuilds its barrage config on every change.
class DanmakuStyleController extends Notifier<DanmakuStyle> {
  @override
  DanmakuStyle build() {
    try {
      return (
        fontSize: _double('fontSize', _defaults.fontSize, DanmakuStyleRange.fontSizeMin, DanmakuStyleRange.fontSizeMax),
        fontWeight: normalizeDanmakuFontWeight(StoragePrefs.getInt('danmaku.style.fontWeight')),
        italic: _bool('italic', _defaults.italic),
        letterSpacing: _double(
          'letterSpacing',
          _defaults.letterSpacing,
          DanmakuStyleRange.letterSpacingMin,
          DanmakuStyleRange.letterSpacingMax,
        ),
        baseSpeed: _double('baseSpeed', _defaults.baseSpeed, DanmakuStyleRange.speedMin, DanmakuStyleRange.speedMax),
        area: _double('area', _defaults.area, DanmakuStyleRange.areaMin, DanmakuStyleRange.areaMax),
        topMargin: _double(
          'topMargin',
          _defaults.topMargin,
          DanmakuStyleRange.topMarginMin,
          DanmakuStyleRange.topMarginMax,
        ),
        bottomMargin: _double(
          'bottomMargin',
          _defaults.bottomMargin,
          DanmakuStyleRange.bottomMarginMin,
          DanmakuStyleRange.bottomMarginMax,
        ),
        opacity: _double('opacity', _defaults.opacity, DanmakuStyleRange.opacityMin, DanmakuStyleRange.opacityMax),
        showStroke: _bool('showStroke', _defaults.showStroke),
        textColor: normalizeDanmakuColor(StoragePrefs.getInt('danmaku.style.textColor'), _defaults.textColor),
        strokeColor: normalizeDanmakuColor(StoragePrefs.getInt('danmaku.style.strokeColor'), _defaults.strokeColor),
        strokeWidth: _double(
          'strokeWidth',
          _defaults.strokeWidth,
          DanmakuStyleRange.strokeWidthMin,
          DanmakuStyleRange.strokeWidthMax,
        ),
        showShadow: _bool('showShadow', _defaults.showShadow),
        shadowColor: normalizeDanmakuColor(StoragePrefs.getInt('danmaku.style.shadowColor'), _defaults.shadowColor),
        shadowBlur: _double(
          'shadowBlur',
          _defaults.shadowBlur,
          DanmakuStyleRange.shadowBlurMin,
          DanmakuStyleRange.shadowBlurMax,
        ),
        shadowOffsetX: _double(
          'shadowOffsetX',
          _defaults.shadowOffsetX,
          DanmakuStyleRange.shadowOffsetMin,
          DanmakuStyleRange.shadowOffsetMax,
        ),
        shadowOffsetY: _double(
          'shadowOffsetY',
          _defaults.shadowOffsetY,
          DanmakuStyleRange.shadowOffsetMin,
          DanmakuStyleRange.shadowOffsetMax,
        ),
        noEmoji: _bool('noEmoji', _defaults.noEmoji),
        fontFamily: _storedFontFamily(StoragePrefs.getString('danmaku.style.fontFamily')),
        maxVisibleCount: normalizeDanmakuMaxVisibleCount(StoragePrefs.getInt('danmaku.style.maxVisibleCount')),
        massMode: _bool('massMode', _defaults.massMode),
        trackHeight: _double(
          'trackHeight',
          _defaults.trackHeight,
          DanmakuStyleRange.trackHeightMin,
          DanmakuStyleRange.trackHeightMax,
        ),
        emojiSize: _double(
          'emojiSize',
          _defaults.emojiSize,
          DanmakuStyleRange.emojiSizeMin,
          DanmakuStyleRange.emojiSizeMax,
        ),
        safeArea: _bool('safeArea', _defaults.safeArea),
        overlapSafeGap: _double(
          'overlapSafeGap',
          _defaults.overlapSafeGap,
          DanmakuStyleRange.overlapSafeGapMin,
          DanmakuStyleRange.overlapSafeGapMax,
        ),
        maxPendingCount: _int(
          'maxPendingCount',
          _defaults.maxPendingCount,
          DanmakuStyleRange.maxPendingMin,
          DanmakuStyleRange.maxPendingMax,
        ),
        maxPendingAge: _double(
          'maxPendingAge',
          _defaults.maxPendingAge,
          DanmakuStyleRange.maxPendingAgeMin,
          DanmakuStyleRange.maxPendingAgeMax,
        ),
        emitInterval: _double(
          'emitInterval',
          _defaults.emitInterval,
          DanmakuStyleRange.emitIntervalMin,
          DanmakuStyleRange.emitIntervalMax,
        ),
        rasterize: _bool('rasterize', _defaults.rasterize),
        barragePoolMaxSize: _int(
          'barragePoolMaxSize',
          _defaults.barragePoolMaxSize,
          DanmakuStyleRange.barragePoolMin,
          DanmakuStyleRange.barragePoolMax,
        ),
        pictureCacheMaxSize: _int(
          'pictureCacheMaxSize',
          _defaults.pictureCacheMaxSize,
          DanmakuStyleRange.pictureCacheMin,
          DanmakuStyleRange.pictureCacheMax,
        ),
        textCacheMaxSize: _int(
          'textCacheMaxSize',
          _defaults.textCacheMaxSize,
          DanmakuStyleRange.textCacheMin,
          DanmakuStyleRange.textCacheMax,
        ),
        rasterCacheMb: _int(
          'rasterCacheMb',
          _defaults.rasterCacheMb,
          DanmakuStyleRange.rasterCacheMbMin,
          DanmakuStyleRange.rasterCacheMbMax,
        ),
      );
    } on Object {
      return _defaults;
    }
  }

  /// A stored number under `danmaku.style.<key>`, clamped.
  static double _double(String key, double fallback, double min, double max) =>
      (StoragePrefs.getDouble('danmaku.style.$key') ?? fallback).clamp(min, max);

  /// A stored whole number under `danmaku.style.<key>`, clamped.
  static int _int(String key, int fallback, int min, int max) =>
      (StoragePrefs.getInt('danmaku.style.$key') ?? fallback).clamp(min, max);

  /// A stored switch under `danmaku.style.<key>`.
  static bool _bool(String key, bool fallback) => StoragePrefs.getBool('danmaku.style.$key') ?? fallback;

  /// Moves the type size, writing through.
  Future<void> setFontSize(double value) =>
      _write(_next(fontSize: value.clamp(DanmakuStyleRange.fontSizeMin, DanmakuStyleRange.fontSizeMax)));

  /// Moves the weight to one of the reference's 100-step stops, writing
  /// through.
  Future<void> setFontWeight(int value) => _write(_next(fontWeight: normalizeDanmakuFontWeight(value)));

  /// Slants the type, writing through.
  Future<void> setItalic({required bool value}) => _write(_next(italic: value));

  /// Moves the extra gap between glyphs, in pixels (the reference's
  /// `danmakuLetterSpacing`: -2–8, default 0), writing through.
  Future<void> setLetterSpacing(double value) =>
      _write(_next(letterSpacing: value.clamp(DanmakuStyleRange.letterSpacingMin, DanmakuStyleRange.letterSpacingMax)));

  /// Moves the speed, writing through.
  Future<void> setBaseSpeed(double value) =>
      _write(_next(baseSpeed: value.clamp(DanmakuStyleRange.speedMin, DanmakuStyleRange.speedMax)));

  /// Moves the share of the screen messages may cross, writing through.
  Future<void> setArea(double value) =>
      _write(_next(area: value.clamp(DanmakuStyleRange.areaMin, DanmakuStyleRange.areaMax)));

  /// Moves the top margin the flying layer keeps free of messages (the
  /// reference's `danmakuTopArea`, in pixels), writing through.
  Future<void> setTopMargin(num value) =>
      _write(_next(topMargin: value.clamp(DanmakuStyleRange.topMarginMin, DanmakuStyleRange.topMarginMax).toDouble()));

  /// Moves the bottom margin the flying layer keeps free of messages (the
  /// reference's `danmakuBottomArea`, in pixels), writing through.
  Future<void> setBottomMargin(num value) => _write(
    _next(bottomMargin: value.clamp(DanmakuStyleRange.bottomMarginMin, DanmakuStyleRange.bottomMarginMax).toDouble()),
  );

  /// Moves the opacity, writing through.
  Future<void> setOpacity(double value) =>
      _write(_next(opacity: value.clamp(DanmakuStyleRange.opacityMin, DanmakuStyleRange.opacityMax)));

  /// Flips the outline, writing through.
  Future<void> setShowStroke({required bool value}) => _write(_next(showStroke: value));

  /// Moves the glyphs' fill colour (the engine's `textColor`), writing
  /// through; the palette is the only source the row offers.
  Future<void> setTextColor(int value) => _write(_next(textColor: normalizeDanmakuColor(value, state.textColor)));

  /// Moves the outline's colour (the engine's `strokeColor`), writing
  /// through.
  Future<void> setStrokeColor(int value) => _write(_next(strokeColor: normalizeDanmakuColor(value, state.strokeColor)));

  /// Moves the outline's width, in pixels (the reference's
  /// `danmakuFontBorder`), writing through.
  Future<void> setStrokeWidth(num value) => _write(
    _next(strokeWidth: value.clamp(DanmakuStyleRange.strokeWidthMin, DanmakuStyleRange.strokeWidthMax).toDouble()),
  );

  /// Flips the glyph shadow (the engine's `showShadow`), writing through.
  Future<void> setShowShadow({required bool value}) => _write(_next(showShadow: value));

  /// Moves the shadow's colour, writing through.
  Future<void> setShadowColor(int value) => _write(_next(shadowColor: normalizeDanmakuColor(value, state.shadowColor)));

  /// Moves the shadow's blur, writing through.
  Future<void> setShadowBlur(double value) =>
      _write(_next(shadowBlur: value.clamp(DanmakuStyleRange.shadowBlurMin, DanmakuStyleRange.shadowBlurMax)));

  /// Moves the shadow's horizontal offset, writing through.
  Future<void> setShadowOffsetX(num value) => _write(
    _next(shadowOffsetX: value.clamp(DanmakuStyleRange.shadowOffsetMin, DanmakuStyleRange.shadowOffsetMax).toDouble()),
  );

  /// Moves the shadow's vertical offset, writing through.
  Future<void> setShadowOffsetY(num value) => _write(
    _next(shadowOffsetY: value.clamp(DanmakuStyleRange.shadowOffsetMin, DanmakuStyleRange.shadowOffsetMax).toDouble()),
  );

  /// Hides the emoji pictures in the flying layer (the reference's
  /// 纯文字模式); text still draws, the chat list is unaffected.
  Future<void> setNoEmoji({required bool value}) => _write(_next(noEmoji: value));

  /// Names the typeface the flying layer draws in; null follows the
  /// platform's own face.
  Future<void> setFontFamily(String? family) =>
      _write(_next(fontFamily: _storedFontFamily(family), clearFontFamily: true));

  /// Moves the same-screen cap (the reference's `danmakuMaxVisibleCount`),
  /// writing through; stored values outside 10–120 read back as 48.
  Future<void> setMaxVisibleCount(int value) =>
      _write(_next(maxVisibleCount: value.clamp(DanmakuStyleRange.maxVisibleMin, DanmakuStyleRange.maxVisibleMax)));

  /// Flips the reference's mass mode: realtime rendering and a 1000-message
  /// same-screen ceiling.
  Future<void> setMassMode({required bool value}) => _write(_next(massMode: value));

  /// Moves a lane's height, writing through.
  Future<void> setTrackHeight(double value) =>
      _write(_next(trackHeight: value.clamp(DanmakuStyleRange.trackHeightMin, DanmakuStyleRange.trackHeightMax)));

  /// Moves an emoji picture's edge, writing through.
  Future<void> setEmojiSize(double value) =>
      _write(_next(emojiSize: value.clamp(DanmakuStyleRange.emojiSizeMin, DanmakuStyleRange.emojiSizeMax)));

  /// Flips the safe-area inset the engine honours, writing through.
  Future<void> setSafeArea({required bool value}) => _write(_next(safeArea: value));

  /// Moves the clearance between a message and the next, writing through.
  Future<void> setOverlapSafeGap(double value) => _write(
    _next(overlapSafeGap: value.clamp(DanmakuStyleRange.overlapSafeGapMin, DanmakuStyleRange.overlapSafeGapMax)),
  );

  /// Moves the waiting queue's cap, writing through.
  Future<void> setMaxPendingCount(int value) =>
      _write(_next(maxPendingCount: value.clamp(DanmakuStyleRange.maxPendingMin, DanmakuStyleRange.maxPendingMax)));

  /// Moves how long a message may wait for a lane, in seconds, writing
  /// through.
  Future<void> setMaxPendingAge(double value) =>
      _write(_next(maxPendingAge: value.clamp(DanmakuStyleRange.maxPendingAgeMin, DanmakuStyleRange.maxPendingAgeMax)));

  /// Moves the dispatch clock's tick, in seconds, writing through.
  Future<void> setEmitInterval(double value) =>
      _write(_next(emitInterval: value.clamp(DanmakuStyleRange.emitIntervalMin, DanmakuStyleRange.emitIntervalMax)));

  /// Flips rasterized drawing: the engine paints a message once into a
  /// bitmap and blits it each frame (the low-end GPU answer).
  Future<void> setRasterize({required bool value}) => _write(_next(rasterize: value));

  /// Moves the recycled message pool's size, writing through.
  Future<void> setBarragePoolMaxSize(int value) => _write(
    _next(barragePoolMaxSize: value.clamp(DanmakuStyleRange.barragePoolMin, DanmakuStyleRange.barragePoolMax)),
  );

  /// Moves the picture cache's size, writing through.
  Future<void> setPictureCacheMaxSize(int value) => _write(
    _next(pictureCacheMaxSize: value.clamp(DanmakuStyleRange.pictureCacheMin, DanmakuStyleRange.pictureCacheMax)),
  );

  /// Moves the compiled text cache's size, writing through.
  Future<void> setTextCacheMaxSize(int value) =>
      _write(_next(textCacheMaxSize: value.clamp(DanmakuStyleRange.textCacheMin, DanmakuStyleRange.textCacheMax)));

  /// Moves the rasterized-message cache's budget, in MB, writing through.
  Future<void> setRasterCacheMb(int value) =>
      _write(_next(rasterCacheMb: value.clamp(DanmakuStyleRange.rasterCacheMbMin, DanmakuStyleRange.rasterCacheMbMax)));

  /// Restores the designed defaults.
  Future<void> reset() => _write(_defaults);

  /// The style with the named fields moved; everything else carries over
  /// from [state]. [clearFontFamily] lets the typeface row go back to the
  /// platform's own face, which a plain null cannot express.
  DanmakuStyle _next({
    double? fontSize,
    int? fontWeight,
    bool? italic,
    double? letterSpacing,
    double? baseSpeed,
    double? area,
    double? topMargin,
    double? bottomMargin,
    double? opacity,
    bool? showStroke,
    int? textColor,
    int? strokeColor,
    double? strokeWidth,
    bool? showShadow,
    int? shadowColor,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    bool? noEmoji,
    String? fontFamily,
    bool clearFontFamily = false,
    int? maxVisibleCount,
    bool? massMode,
    double? trackHeight,
    double? emojiSize,
    bool? safeArea,
    double? overlapSafeGap,
    int? maxPendingCount,
    double? maxPendingAge,
    double? emitInterval,
    bool? rasterize,
    int? barragePoolMaxSize,
    int? pictureCacheMaxSize,
    int? textCacheMaxSize,
    int? rasterCacheMb,
  }) => (
    fontSize: fontSize ?? state.fontSize,
    fontWeight: fontWeight ?? state.fontWeight,
    italic: italic ?? state.italic,
    letterSpacing: letterSpacing ?? state.letterSpacing,
    baseSpeed: baseSpeed ?? state.baseSpeed,
    area: area ?? state.area,
    topMargin: topMargin ?? state.topMargin,
    bottomMargin: bottomMargin ?? state.bottomMargin,
    opacity: opacity ?? state.opacity,
    showStroke: showStroke ?? state.showStroke,
    textColor: textColor ?? state.textColor,
    strokeColor: strokeColor ?? state.strokeColor,
    strokeWidth: strokeWidth ?? state.strokeWidth,
    showShadow: showShadow ?? state.showShadow,
    shadowColor: shadowColor ?? state.shadowColor,
    shadowBlur: shadowBlur ?? state.shadowBlur,
    shadowOffsetX: shadowOffsetX ?? state.shadowOffsetX,
    shadowOffsetY: shadowOffsetY ?? state.shadowOffsetY,
    noEmoji: noEmoji ?? state.noEmoji,
    fontFamily: clearFontFamily ? fontFamily : (fontFamily ?? state.fontFamily),
    maxVisibleCount: maxVisibleCount ?? state.maxVisibleCount,
    massMode: massMode ?? state.massMode,
    trackHeight: trackHeight ?? state.trackHeight,
    emojiSize: emojiSize ?? state.emojiSize,
    safeArea: safeArea ?? state.safeArea,
    overlapSafeGap: overlapSafeGap ?? state.overlapSafeGap,
    maxPendingCount: maxPendingCount ?? state.maxPendingCount,
    maxPendingAge: maxPendingAge ?? state.maxPendingAge,
    emitInterval: emitInterval ?? state.emitInterval,
    rasterize: rasterize ?? state.rasterize,
    barragePoolMaxSize: barragePoolMaxSize ?? state.barragePoolMaxSize,
    pictureCacheMaxSize: pictureCacheMaxSize ?? state.pictureCacheMaxSize,
    textCacheMaxSize: textCacheMaxSize ?? state.textCacheMaxSize,
    rasterCacheMb: rasterCacheMb ?? state.rasterCacheMb,
  );

  Future<void> _write(DanmakuStyle next) async {
    state = next;
    final family = next.fontFamily;
    try {
      await StoragePrefs.setPrefs({
        'danmaku.style.fontSize': next.fontSize,
        'danmaku.style.fontWeight': next.fontWeight,
        'danmaku.style.italic': next.italic,
        'danmaku.style.letterSpacing': next.letterSpacing,
        'danmaku.style.baseSpeed': next.baseSpeed,
        'danmaku.style.area': next.area,
        'danmaku.style.topMargin': next.topMargin,
        'danmaku.style.bottomMargin': next.bottomMargin,
        'danmaku.style.opacity': next.opacity,
        'danmaku.style.showStroke': next.showStroke,
        'danmaku.style.textColor': next.textColor,
        'danmaku.style.strokeColor': next.strokeColor,
        'danmaku.style.strokeWidth': next.strokeWidth,
        'danmaku.style.showShadow': next.showShadow,
        'danmaku.style.shadowColor': next.shadowColor,
        'danmaku.style.shadowBlur': next.shadowBlur,
        'danmaku.style.shadowOffsetX': next.shadowOffsetX,
        'danmaku.style.shadowOffsetY': next.shadowOffsetY,
        'danmaku.style.noEmoji': next.noEmoji,
        'danmaku.style.maxVisibleCount': next.maxVisibleCount,
        'danmaku.style.massMode': next.massMode,
        'danmaku.style.trackHeight': next.trackHeight,
        'danmaku.style.emojiSize': next.emojiSize,
        'danmaku.style.safeArea': next.safeArea,
        'danmaku.style.overlapSafeGap': next.overlapSafeGap,
        'danmaku.style.maxPendingCount': next.maxPendingCount,
        'danmaku.style.maxPendingAge': next.maxPendingAge,
        'danmaku.style.emitInterval': next.emitInterval,
        'danmaku.style.rasterize': next.rasterize,
        'danmaku.style.barragePoolMaxSize': next.barragePoolMaxSize,
        'danmaku.style.pictureCacheMaxSize': next.pictureCacheMaxSize,
        'danmaku.style.textCacheMaxSize': next.textCacheMaxSize,
        'danmaku.style.rasterCacheMb': next.rasterCacheMb,
      });
      if (family == null) {
        await StoragePrefs.remove('danmaku.style.fontFamily');
      } else {
        await StoragePrefs.setString('danmaku.style.fontFamily', family);
      }
    } on Object {
      // The style is a preference; a closed store loses it.
    }
  }
}

/// The stored family, with the reference's `Default` sentinel (and an empty
/// write) folded into null, this app's "the platform's own face". A family
/// this build no longer offers — an old bundled or cloud face — falls back
/// the same way rather than leaving the picker on a value it cannot show.
String? _storedFontFamily(String? family) {
  final value = family?.trim();
  if (value == null || value.isEmpty || value == 'Default') return null;
  return normalizeFontFamilyId(value);
}

/// The flying danmaku's style.
final danmakuStyleProvider = NotifierProvider<DanmakuStyleController, DanmakuStyle>(DanmakuStyleController.new);

/// The flying layer's frame pacing: a manual rate, or the display's rate
/// capped by the general refresh-rate mode.
typedef DanmakuFrameRate = ({int fps, bool autoFps});

const DanmakuFrameRate _frameRateDefaults = (fps: DanmakuStyleRange.fpsDefault, autoFps: true);

/// The reference's `_boundedInt`: a stored rate outside 30–240 is clamped,
/// a missing one is the 60 FPS default.
int normalizeDanmakuFps(int? value) =>
    (value ?? DanmakuStyleRange.fpsDefault).clamp(DanmakuStyleRange.fpsMin, DanmakuStyleRange.fpsMax);

/// The reference's `resolvedDanmakuFps`: the manual rate when following the
/// display is off; otherwise the panel's highest rate capped at 60 FPS in
/// power saving and balanced, and left at the panel's rate in performance.
int resolveDanmakuFps({
  required bool autoFps,
  required int configured,
  required RefreshRateMode mode,
  double? currentHz,
  double? maxHz,
}) {
  if (!autoFps) return normalizeDanmakuFps(configured);
  final maximum = maxHz ?? 0;
  final current = currentHz ?? 0;
  final detected = maximum > 0 ? maximum : (current > 0 ? current : 60.0);
  final device = detected.round().clamp(DanmakuStyleRange.fpsMin, DanmakuStyleRange.fpsMax);
  return switch (mode) {
    RefreshRateMode.performance => device,
    RefreshRateMode.powerSaving || RefreshRateMode.balanced => device.clamp(DanmakuStyleRange.fpsMin, 60),
  };
}

/// Owns the danmaku frame rate, persisted under `danmaku.style.fps` and
/// `danmaku.style.autoFps`.
final class DanmakuFrameRateController extends Notifier<DanmakuFrameRate> {
  @override
  DanmakuFrameRate build() {
    try {
      return (
        fps: normalizeDanmakuFps(StoragePrefs.getInt('danmaku.style.fps')),
        autoFps: StoragePrefs.getBool('danmaku.style.autoFps') ?? _frameRateDefaults.autoFps,
      );
    } on Object {
      return _frameRateDefaults;
    }
  }

  /// Moves the manual rate; it applies once following the display is off.
  Future<void> setFps(int value) => _write((fps: normalizeDanmakuFps(value), autoFps: state.autoFps));

  /// Flips between the display policy and the manual rate.
  Future<void> setAutoFps({required bool value}) => _write((fps: state.fps, autoFps: value));

  /// Restores the reference's defaults: follow the display at 60 FPS.
  Future<void> reset() => _write(_frameRateDefaults);

  Future<void> _write(DanmakuFrameRate next) async {
    state = next;
    try {
      await StoragePrefs.setInt('danmaku.style.fps', next.fps);
      await StoragePrefs.setBool('danmaku.style.autoFps', next.autoFps);
    } on Object {
      // The rate is a preference; a closed store loses it.
    }
  }
}

/// The danmaku frame rate the flying layer uses.
final danmakuFrameRateProvider = NotifierProvider<DanmakuFrameRateController, DanmakuFrameRate>(
  DanmakuFrameRateController.new,
);

/// The rate sent to the flame renderer, recomputed when the panel's rate or
/// the general refresh-rate mode changes.
final danmakuEffectiveFpsProvider = Provider<int>((ref) {
  final rate = ref.watch(danmakuFrameRateProvider);
  final display = ref.watch(displayRefreshRateProvider);
  return resolveDanmakuFps(
    autoFps: rate.autoFps,
    configured: rate.fps,
    mode: display.mode,
    currentHz: display.snapshot?.currentHz,
    maxHz: display.snapshot?.maxHz,
  );
});

/// Whether a tap on a flying danmaku opens its actions (the reference's
/// `enableDanmakuTapInteraction`, on by default).
final class DanmakuTapInteractionController extends Notifier<bool> {
  static const String _key = 'danmaku.interaction.tap';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_key) ?? true;
    } on Object {
      return true;
    }
  }

  /// Turns the tap's actions on or off, writing through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_key, value);
    } on Object {
      // The interaction is a preference; a closed store loses it.
    }
  }

  /// Restores the reference's default: a tap opens the actions.
  Future<void> reset() => set(value: true);
}

/// Whether tapping a flying danmaku opens its actions.
final danmakuTapInteractionProvider = NotifierProvider<DanmakuTapInteractionController, bool>(
  DanmakuTapInteractionController.new,
);

/// Whether long-pressing a flying danmaku opens its actions (the reference's
/// `enableDanmakuLongPressInteraction`, on by default).
final class DanmakuLongPressInteractionController extends Notifier<bool> {
  static const String _key = 'danmaku.interaction.longPress';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(_key) ?? true;
    } on Object {
      return true;
    }
  }

  /// Turns the long-press actions on or off, writing through.
  Future<void> set({required bool value}) async {
    state = value;
    try {
      await StoragePrefs.setBool(_key, value);
    } on Object {
      // The interaction is a preference; a closed store loses it.
    }
  }

  /// Restores the reference's default: a long press opens the actions.
  Future<void> reset() => set(value: true);
}

/// Whether long-pressing a flying danmaku opens its actions.
final danmakuLongPressInteractionProvider = NotifierProvider<DanmakuLongPressInteractionController, bool>(
  DanmakuLongPressInteractionController.new,
);

/// What the platform's flying messages do while the video is paused (the
/// reference's `danmakuPausedBehavior`): [pause] stands them with it (the
/// default, as 3.x's main picture), [fly] lets them fly on and new ones
/// come in. Stored under the reference's own words.
enum DanmakuPausedBehavior {
  pause,
  fly;

  /// The reference's stored value for this choice.
  String get stored => this == fly ? 'continue' : 'pause';

  /// The reference's `allowed` set: any other value reads as the default.
  static DanmakuPausedBehavior fromStored(String? value) => value == 'continue' ? fly : pause;
}

/// Owns the paused-video behaviour of the flying layer, persisted under
/// `danmaku.pausedBehavior` (the reference's `danmakuPausedBehavior`).
final class DanmakuPausedBehaviorController extends Notifier<DanmakuPausedBehavior> {
  static const String _key = 'danmaku.pausedBehavior';

  @override
  DanmakuPausedBehavior build() {
    try {
      return DanmakuPausedBehavior.fromStored(StoragePrefs.getString(_key));
    } on Object {
      return DanmakuPausedBehavior.pause;
    }
  }

  /// Moves the choice, writing through; a live room applies it at once.
  Future<void> set(DanmakuPausedBehavior value) async {
    state = value;
    try {
      await StoragePrefs.setString(_key, value.stored);
    } on Object {
      // The behaviour is a preference; a closed store loses it.
    }
  }

  /// Restores the reference's default: the messages stand with the video.
  Future<void> reset() => set(DanmakuPausedBehavior.pause);
}

/// What the flying danmaku do while the video is paused.
final danmakuPausedBehaviorProvider = NotifierProvider<DanmakuPausedBehaviorController, DanmakuPausedBehavior>(
  DanmakuPausedBehaviorController.new,
);
