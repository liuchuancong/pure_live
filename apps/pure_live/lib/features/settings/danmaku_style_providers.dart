import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/providers/display_refresh_rate_provider.dart'
    show RefreshRateMode, displayRefreshRateProvider;
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The flying danmaku's look and motion (the reference's danmaku settings,
/// the subset the flame layer draws by): type size, weight and spacing, speed, the
/// screen's share the messages may cross, the top and bottom margins kept
/// free of them, the pure-text answer, opacity, the outline, its width, the
/// typeface and how many messages may fly at once.
typedef DanmakuStyle = ({
  double fontSize,
  int fontWeight,
  double letterSpacing,
  double baseSpeed,
  double area,
  double topMargin,
  double bottomMargin,
  double opacity,
  bool showStroke,
  double strokeWidth,
  bool noEmoji,
  String? fontFamily,
  int maxVisibleCount,
  bool massMode,
});

const DanmakuStyle _defaults = (
  fontSize: 16,
  fontWeight: 500,
  letterSpacing: 0,
  baseSpeed: 120,
  area: 1.0,
  topMargin: 0,
  bottomMargin: 0.5,
  opacity: 1.0,
  showStroke: true,
  strokeWidth: 1.5,
  noEmoji: false,
  fontFamily: null,
  maxVisibleCount: 48,
  massMode: false,
);

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
}

/// Owns the danmaku style, persisted under `danmaku.style.*`; the player
/// surface rebuilds its barrage config on every change.
class DanmakuStyleController extends Notifier<DanmakuStyle> {
  @override
  DanmakuStyle build() {
    try {
      return (
        fontSize: (StoragePrefs.getDouble('danmaku.style.fontSize') ?? _defaults.fontSize).clamp(
          DanmakuStyleRange.fontSizeMin,
          DanmakuStyleRange.fontSizeMax,
        ),
        fontWeight: normalizeDanmakuFontWeight(StoragePrefs.getInt('danmaku.style.fontWeight')),
        letterSpacing: (StoragePrefs.getDouble('danmaku.style.letterSpacing') ?? _defaults.letterSpacing).clamp(
          DanmakuStyleRange.letterSpacingMin,
          DanmakuStyleRange.letterSpacingMax,
        ),
        baseSpeed: (StoragePrefs.getDouble('danmaku.style.baseSpeed') ?? _defaults.baseSpeed).clamp(
          DanmakuStyleRange.speedMin,
          DanmakuStyleRange.speedMax,
        ),
        area: (StoragePrefs.getDouble('danmaku.style.area') ?? _defaults.area).clamp(
          DanmakuStyleRange.areaMin,
          DanmakuStyleRange.areaMax,
        ),
        topMargin: (StoragePrefs.getDouble('danmaku.style.topMargin') ?? _defaults.topMargin).clamp(
          DanmakuStyleRange.topMarginMin,
          DanmakuStyleRange.topMarginMax,
        ),
        bottomMargin: (StoragePrefs.getDouble('danmaku.style.bottomMargin') ?? _defaults.bottomMargin).clamp(
          DanmakuStyleRange.bottomMarginMin,
          DanmakuStyleRange.bottomMarginMax,
        ),
        opacity: (StoragePrefs.getDouble('danmaku.style.opacity') ?? _defaults.opacity).clamp(
          DanmakuStyleRange.opacityMin,
          DanmakuStyleRange.opacityMax,
        ),
        showStroke: StoragePrefs.getBool('danmaku.style.showStroke') ?? _defaults.showStroke,
        strokeWidth: (StoragePrefs.getDouble('danmaku.style.strokeWidth') ?? _defaults.strokeWidth).clamp(
          DanmakuStyleRange.strokeWidthMin,
          DanmakuStyleRange.strokeWidthMax,
        ),
        noEmoji: StoragePrefs.getBool('danmaku.style.noEmoji') ?? _defaults.noEmoji,
        fontFamily: _storedFontFamily(StoragePrefs.getString('danmaku.style.fontFamily')),
        maxVisibleCount: normalizeDanmakuMaxVisibleCount(StoragePrefs.getInt('danmaku.style.maxVisibleCount')),
        massMode: StoragePrefs.getBool('danmaku.style.massMode') ?? _defaults.massMode,
      );
    } on Object {
      return _defaults;
    }
  }

  /// Moves the type size, writing through.
  Future<void> setFontSize(double value) => _write((
    fontSize: value.clamp(DanmakuStyleRange.fontSizeMin, DanmakuStyleRange.fontSizeMax),
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the weight to one of the reference's 100-step stops, writing
  /// through.
  Future<void> setFontWeight(int value) => _write((
    fontSize: state.fontSize,
    fontWeight: normalizeDanmakuFontWeight(value),
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the extra gap between glyphs, in pixels (the reference's
  /// `danmakuLetterSpacing`: -2–8, default 0), writing through.
  Future<void> setLetterSpacing(double value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: value.clamp(DanmakuStyleRange.letterSpacingMin, DanmakuStyleRange.letterSpacingMax),
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the speed, writing through.
  Future<void> setBaseSpeed(double value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: value.clamp(DanmakuStyleRange.speedMin, DanmakuStyleRange.speedMax),
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the share of the screen messages may cross, writing through.
  Future<void> setArea(double value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: value.clamp(DanmakuStyleRange.areaMin, DanmakuStyleRange.areaMax),
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the top margin the flying layer keeps free of messages (the
  /// reference's `danmakuTopArea`, in pixels), writing through.
  Future<void> setTopMargin(num value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: value.clamp(DanmakuStyleRange.topMarginMin, DanmakuStyleRange.topMarginMax).toDouble(),
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the bottom margin the flying layer keeps free of messages (the
  /// reference's `danmakuBottomArea`, in pixels), writing through.
  Future<void> setBottomMargin(num value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: value.clamp(DanmakuStyleRange.bottomMarginMin, DanmakuStyleRange.bottomMarginMax).toDouble(),
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the opacity, writing through.
  Future<void> setOpacity(double value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: value.clamp(DanmakuStyleRange.opacityMin, DanmakuStyleRange.opacityMax),
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Flips the outline, writing through.
  Future<void> setShowStroke({required bool value}) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: value,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the outline's width, in pixels (the reference's
  /// `danmakuFontBorder`), writing through.
  Future<void> setStrokeWidth(num value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: value.clamp(DanmakuStyleRange.strokeWidthMin, DanmakuStyleRange.strokeWidthMax).toDouble(),
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Hides the emoji pictures in the flying layer (the reference's
  /// 纯文字模式); text still draws, the chat list is unaffected.
  Future<void> setNoEmoji({required bool value}) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: value,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Names the typeface the flying layer draws in; null follows the
  /// platform's own face.
  Future<void> setFontFamily(String? family) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: _storedFontFamily(family),
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Moves the same-screen cap (the reference's `danmakuMaxVisibleCount`),
  /// writing through; stored values outside 10–120 read back as 48.
  Future<void> setMaxVisibleCount(int value) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: value.clamp(DanmakuStyleRange.maxVisibleMin, DanmakuStyleRange.maxVisibleMax),
    massMode: state.massMode,
  ));

  /// Flips the reference's mass mode: realtime rendering and a 1000-message
  /// same-screen ceiling.
  Future<void> setMassMode({required bool value}) => _write((
    fontSize: state.fontSize,
    fontWeight: state.fontWeight,
    letterSpacing: state.letterSpacing,
    baseSpeed: state.baseSpeed,
    area: state.area,
    topMargin: state.topMargin,
    bottomMargin: state.bottomMargin,
    opacity: state.opacity,
    strokeWidth: state.strokeWidth,
    showStroke: state.showStroke,
    noEmoji: state.noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: value,
  ));

  /// Applies a saved template's look (the reference's `DanmakuTemplate.apply`):
  /// area, margins, speed, size, weight, border, opacity, outline and the
  /// pure-text switch. Spacing, typeface, same-screen cap and mass mode are
  /// the viewer's own and stay put.
  Future<void> applyTemplate({
    required double area,
    required double topMargin,
    required double bottomMargin,
    required double baseSpeed,
    required double fontSize,
    required int fontWeight,
    required double strokeWidth,
    required double opacity,
    required bool showStroke,
    required bool noEmoji,
  }) => _write((
    fontSize: fontSize.clamp(DanmakuStyleRange.fontSizeMin, DanmakuStyleRange.fontSizeMax),
    fontWeight: normalizeDanmakuFontWeight(fontWeight),
    letterSpacing: state.letterSpacing,
    baseSpeed: baseSpeed.clamp(DanmakuStyleRange.speedMin, DanmakuStyleRange.speedMax),
    area: area.clamp(DanmakuStyleRange.areaMin, DanmakuStyleRange.areaMax),
    topMargin: topMargin.clamp(DanmakuStyleRange.topMarginMin, DanmakuStyleRange.topMarginMax),
    bottomMargin: bottomMargin.clamp(DanmakuStyleRange.bottomMarginMin, DanmakuStyleRange.bottomMarginMax),
    opacity: opacity.clamp(DanmakuStyleRange.opacityMin, DanmakuStyleRange.opacityMax),
    showStroke: showStroke,
    strokeWidth: strokeWidth.clamp(DanmakuStyleRange.strokeWidthMin, DanmakuStyleRange.strokeWidthMax),
    noEmoji: noEmoji,
    fontFamily: state.fontFamily,
    maxVisibleCount: state.maxVisibleCount,
    massMode: state.massMode,
  ));

  /// Restores the designed defaults.
  Future<void> reset() => _write(_defaults);

  Future<void> _write(DanmakuStyle next) async {
    state = next;
    try {
      await StoragePrefs.setDouble('danmaku.style.fontSize', next.fontSize);
      await StoragePrefs.setInt('danmaku.style.fontWeight', next.fontWeight);
      await StoragePrefs.setDouble('danmaku.style.letterSpacing', next.letterSpacing);
      await StoragePrefs.setDouble('danmaku.style.baseSpeed', next.baseSpeed);
      await StoragePrefs.setDouble('danmaku.style.area', next.area);
      await StoragePrefs.setDouble('danmaku.style.topMargin', next.topMargin);
      await StoragePrefs.setDouble('danmaku.style.bottomMargin', next.bottomMargin);
      await StoragePrefs.setDouble('danmaku.style.opacity', next.opacity);
      await StoragePrefs.setBool('danmaku.style.showStroke', next.showStroke);
      await StoragePrefs.setDouble('danmaku.style.strokeWidth', next.strokeWidth);
      await StoragePrefs.setBool('danmaku.style.noEmoji', next.noEmoji);
      await StoragePrefs.setInt('danmaku.style.maxVisibleCount', next.maxVisibleCount);
      await StoragePrefs.setBool('danmaku.style.massMode', next.massMode);
      final fontFamily = next.fontFamily;
      if (fontFamily == null) {
        await StoragePrefs.remove('danmaku.style.fontFamily');
      } else {
        await StoragePrefs.setString('danmaku.style.fontFamily', fontFamily);
      }
    } on Object {
      // The style is a preference; a closed store loses it.
    }
  }
}

/// The stored family, with the reference's `Default` sentinel (and an empty
/// write) folded into null, this app's "the platform's own face".
String? _storedFontFamily(String? family) {
  final value = family?.trim();
  return value == null || value.isEmpty || value == 'Default' ? null : value;
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

  /// Applies a saved template's frame pacing: its manual rate and whether the
  /// rate follows the display (the reference's template covers both).
  Future<void> applyTemplate({required int fps, required bool autoFps}) =>
      _write((fps: normalizeDanmakuFps(fps), autoFps: autoFps));

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
