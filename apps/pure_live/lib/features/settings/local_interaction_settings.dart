import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The local danmaku look (the reference's `localInteraction.danmaku*` keys):
/// the flying message's colour, size, speed, weight, outline, placement,
/// face, italic, opacity, spacing, shadow and fixed-message duration.
typedef LocalDanmakuStyle = ({
  String preset,
  int color,
  double fontSize,
  double speed,
  int fontWeight,
  bool showStroke,
  double strokeWidth,
  String placement,
  String fontFamily,
  bool italic,
  double opacity,
  double letterSpacing,
  int strokeColor,
  bool showShadow,
  int shadowColor,
  double shadowBlur,
  double shadowOffset,
  int fixedDurationMs,
});

/// The fixed-message placements the reference offers.
abstract final class LocalDanmakuPlacement {
  /// Scrolling danmaku.
  static const String scroll = 'scroll';

  /// A message pinned to the top.
  static const String top = 'top';

  /// A message pinned to the bottom.
  static const String bottom = 'bottom';

  /// Every placement, in the settings order.
  static const List<String> values = [scroll, top, bottom];
}

/// One quick look the reference ships; applying it writes every style field.
final class LocalDanmakuPreset {
  /// Creates a preset.
  const LocalDanmakuPreset({
    required this.id,
    required this.color,
    required this.fontSize,
    required this.speed,
    required this.fontWeight,
    required this.showStroke,
    required this.strokeWidth,
    this.placement = LocalDanmakuPlacement.scroll,
    this.fontFamily = 'system',
    this.italic = false,
    this.opacity = 1,
    this.letterSpacing = 0,
    this.strokeColor = 0xFF000000,
    this.showShadow = false,
    this.shadowColor = 0xFF000000,
    this.shadowBlur = 2,
    this.shadowOffset = 1,
    this.fixedDurationMs = 4000,
  });

  /// The stored id.
  final String id;
  final int color;
  final double fontSize;
  final double speed;
  final int fontWeight;
  final bool showStroke;
  final double strokeWidth;
  final String placement;
  final String fontFamily;
  final bool italic;
  final double opacity;
  final double letterSpacing;
  final int strokeColor;
  final bool showShadow;
  final int shadowColor;
  final double shadowBlur;
  final double shadowOffset;
  final int fixedDurationMs;

  /// Replaces every style field of [state].
  LocalDanmakuStyle apply(LocalDanmakuStyle state) => (
    preset: id,
    color: color,
    fontSize: fontSize,
    speed: speed,
    fontWeight: fontWeight,
    showStroke: showStroke,
    strokeWidth: strokeWidth,
    placement: placement,
    fontFamily: fontFamily,
    italic: italic,
    opacity: opacity,
    letterSpacing: letterSpacing,
    strokeColor: strokeColor,
    showShadow: showShadow,
    shadowColor: shadowColor,
    shadowBlur: shadowBlur,
    shadowOffset: shadowOffset,
    fixedDurationMs: fixedDurationMs,
  );
}

/// The reference's six looks, values copied from its controller.
const List<LocalDanmakuPreset> kLocalDanmakuPresets = [
  LocalDanmakuPreset(
    id: 'clean',
    color: 0xFFFFFFFF,
    fontSize: 19,
    speed: 130,
    fontWeight: 600,
    showStroke: true,
    strokeWidth: 1.5,
  ),
  LocalDanmakuPreset(
    id: 'highlight',
    color: 0xFFFFE45C,
    fontSize: 22,
    speed: 145,
    fontWeight: 800,
    showStroke: true,
    strokeWidth: 2,
    letterSpacing: 0.4,
  ),
  LocalDanmakuPreset(
    id: 'neon',
    color: 0xFFFF69D4,
    fontSize: 21,
    speed: 120,
    fontWeight: 700,
    showStroke: true,
    strokeWidth: 2.5,
    showShadow: true,
    shadowColor: 0xFFFF2DC6,
    shadowBlur: 4,
    shadowOffset: 0,
  ),
  LocalDanmakuPreset(
    id: 'minimal',
    color: 0xFF72E6FF,
    fontSize: 17,
    speed: 105,
    fontWeight: 500,
    showStroke: false,
    strokeWidth: 0,
    opacity: 0.86,
  ),
  LocalDanmakuPreset(
    id: 'caption',
    color: 0xFFFFFFFF,
    fontSize: 20,
    speed: 120,
    fontWeight: 700,
    showStroke: true,
    strokeWidth: 2.5,
    placement: LocalDanmakuPlacement.bottom,
    fixedDurationMs: 5200,
  ),
  LocalDanmakuPreset(
    id: 'cyber',
    color: 0xFF58F5FF,
    fontSize: 20,
    speed: 150,
    fontWeight: 700,
    showStroke: true,
    strokeWidth: 1.5,
    fontFamily: 'mono',
    letterSpacing: 1.1,
    strokeColor: 0xFF11243A,
    showShadow: true,
    shadowColor: 0xFF00C8FF,
    shadowBlur: 3,
  ),
];

/// A local gift the panel offers.
typedef LocalGift = ({String id, String name, String emoji, int price});

/// The generic gift shelf, priced like the reference's common packs.
const List<LocalGift> kLocalGifts = [
  (id: 'lollipop', name: '棒棒糖', emoji: '🍭', price: 100),
  (id: 'heart', name: '小心心', emoji: '💗', price: 500),
  (id: 'rocket', name: '火箭', emoji: '🚀', price: 5000),
  (id: 'crown', name: '王冠', emoji: '👑', price: 2000),
  (id: 'star', name: '星星', emoji: '⭐', price: 300),
  (id: 'cake', name: '蛋糕', emoji: '🎂', price: 800),
];

/// The clean look the reference starts from.
const LocalDanmakuStyle _defaultStyle = (
  preset: 'clean',
  color: 0xFFFFFFFF,
  fontSize: 19,
  speed: 130,
  fontWeight: 600,
  showStroke: true,
  strokeWidth: 1.5,
  placement: LocalDanmakuPlacement.scroll,
  fontFamily: 'system',
  italic: false,
  opacity: 1,
  letterSpacing: 0,
  strokeColor: 0xFF000000,
  showShadow: false,
  shadowColor: 0xFF000000,
  shadowBlur: 2,
  shadowOffset: 1,
  fixedDurationMs: 4000,
);

/// The whole local-interaction choice: identity, what shows, economy, the
/// history and the look.
typedef LocalInteractionState = ({
  bool enabled,
  String userName,
  String title,
  bool showAsDanmaku,
  bool showPlatformBadge,
  bool showLevelBadge,
  bool enableGiftEffects,
  String previewPlatform,
  int coins,
  int experience,
  List<String> history,
  LocalDanmakuStyle style,
});

/// The reference's defaults.
const LocalInteractionState _defaults = (
  enabled: true,
  userName: 'Pure Live',
  title: 'listener',
  showAsDanmaku: true,
  showPlatformBadge: true,
  showLevelBadge: true,
  enableGiftEffects: true,
  previewPlatform: 'bilibili',
  coins: 1000,
  experience: 0,
  history: [],
  style: _defaultStyle,
);

/// The history's cap; older lines leave first.
const int kLocalHistoryLimit = 100;

/// Owns every `localInteraction.*` key and the economy/history mutations the
/// room panel makes.
final class LocalInteractionController extends Notifier<LocalInteractionState> {
  @override
  LocalInteractionState build() {
    try {
      return (
        enabled: _bool('localInteraction.enabled') ?? _defaults.enabled,
        userName: _string('localInteraction.userName') ?? _defaults.userName,
        title: _string('localInteraction.title') ?? _defaults.title,
        showAsDanmaku: _bool('localInteraction.showAsDanmaku') ?? _defaults.showAsDanmaku,
        showPlatformBadge: _bool('localInteraction.showPlatformBadge') ?? _defaults.showPlatformBadge,
        showLevelBadge: _bool('localInteraction.showLevelBadge') ?? _defaults.showLevelBadge,
        enableGiftEffects: _bool('localInteraction.enableGiftEffects') ?? _defaults.enableGiftEffects,
        previewPlatform: _string('localInteraction.previewPlatform') ?? _defaults.previewPlatform,
        coins: _int('localInteraction.coins') ?? _defaults.coins,
        experience: _int('localInteraction.experience') ?? _defaults.experience,
        history: _strings('localInteraction.history') ?? _defaults.history,
        style: (
          preset: _string('localInteraction.danmakuPreset') ?? _defaultStyle.preset,
          color: _int('localInteraction.danmakuColor') ?? _defaultStyle.color,
          fontSize: _double('localInteraction.danmakuFontSize') ?? _defaultStyle.fontSize,
          speed: _double('localInteraction.danmakuSpeed') ?? _defaultStyle.speed,
          fontWeight: _int('localInteraction.danmakuFontWeight') ?? _defaultStyle.fontWeight,
          showStroke: _bool('localInteraction.danmakuShowStroke') ?? _defaultStyle.showStroke,
          strokeWidth: _double('localInteraction.danmakuStrokeWidth') ?? _defaultStyle.strokeWidth,
          placement: _string('localInteraction.danmakuPlacement') ?? _defaultStyle.placement,
          fontFamily: _string('localInteraction.danmakuFontFamily') ?? _defaultStyle.fontFamily,
          italic: _bool('localInteraction.danmakuItalic') ?? _defaultStyle.italic,
          opacity: _double('localInteraction.danmakuOpacity') ?? _defaultStyle.opacity,
          letterSpacing: _double('localInteraction.danmakuLetterSpacing') ?? _defaultStyle.letterSpacing,
          strokeColor: _int('localInteraction.danmakuStrokeColor') ?? _defaultStyle.strokeColor,
          showShadow: _bool('localInteraction.danmakuShowShadow') ?? _defaultStyle.showShadow,
          shadowColor: _int('localInteraction.danmakuShadowColor') ?? _defaultStyle.shadowColor,
          shadowBlur: _double('localInteraction.danmakuShadowBlur') ?? _defaultStyle.shadowBlur,
          shadowOffset: _double('localInteraction.danmakuShadowOffset') ?? _defaultStyle.shadowOffset,
          fixedDurationMs: _int('localInteraction.danmakuFixedDurationMs') ?? _defaultStyle.fixedDurationMs,
        ),
      );
    } on Object {
      return _defaults;
    }
  }

  static bool? _bool(String key) {
    try {
      return StoragePrefs.getBool(key);
    } on Object {
      return null;
    }
  }

  static String? _string(String key) {
    try {
      return StoragePrefs.getString(key);
    } on Object {
      return null;
    }
  }

  static int? _int(String key) {
    try {
      return StoragePrefs.getInt(key);
    } on Object {
      return null;
    }
  }

  static double? _double(String key) {
    try {
      return StoragePrefs.getDouble(key);
    } on Object {
      return null;
    }
  }

  static List<String>? _strings(String key) {
    try {
      return StoragePrefs.getStringList(key);
    } on Object {
      return null;
    }
  }

  /// The level the experience earns (one level per 100 points).
  int get level => state.experience ~/ 100 + 1;

  /// Enables or disables the local panel.
  Future<void> setEnabled({required bool value}) => _writeState((enabled: value, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style), 'localInteraction.enabled', value);

  /// Renames the local user.
  Future<void> setUserName(String value) => _writeState((enabled: state.enabled, userName: value.trim().isEmpty ? _defaults.userName : value.trim(), title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style), 'localInteraction.userName', value.trim().isEmpty ? _defaults.userName : value.trim());

  /// Changes the local title.
  Future<void> setTitle(String value) => _writeState((enabled: state.enabled, userName: state.userName, title: value.trim().isEmpty ? _defaults.title : value.trim(), showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style), 'localInteraction.title', value.trim().isEmpty ? _defaults.title : value.trim());

  /// Flips one of the four "what shows" switches.
  Future<void> setFlag(String key, {required bool value}) async {
    state = switch (key) {
      'showAsDanmaku' => (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: value, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style),
      'showPlatformBadge' => (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: value, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style),
      'showLevelBadge' => (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: value, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style),
      _ => (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: value, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: state.style),
    };
    await _write(
      switch (key) {
        'showAsDanmaku' => 'localInteraction.showAsDanmaku',
        'showPlatformBadge' => 'localInteraction.showPlatformBadge',
        'showLevelBadge' => 'localInteraction.showLevelBadge',
        _ => 'localInteraction.enableGiftEffects',
      },
      value,
    );
  }

  /// Chooses the platform the preview wears.
  Future<void> setPreviewPlatform(String id) async {
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: id, coins: state.coins, experience: state.experience, history: state.history, style: state.style);
    await _write('localInteraction.previewPlatform', id);
  }

  /// Writes the coin balance (the settings page may grant coins).
  Future<void> setCoins(int value) async {
    final coins = value < 0 ? 0 : value;
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: coins, experience: state.experience, history: state.history, style: state.style);
    await _write('localInteraction.coins', coins);
  }

  /// Writes the experience (one level per 100).
  Future<void> setExperience(int value) async {
    final experience = value < 0 ? 0 : value;
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: experience, history: state.history, style: state.style);
    await _write('localInteraction.experience', experience);
  }

  /// Replaces one style field and marks the look custom.
  Future<void> setStyle(LocalDanmakuStyle style) async {
    final next = (preset: 'custom', color: style.color, fontSize: style.fontSize, speed: style.speed, fontWeight: style.fontWeight, showStroke: style.showStroke, strokeWidth: style.strokeWidth, placement: style.placement, fontFamily: style.fontFamily, italic: style.italic, opacity: style.opacity, letterSpacing: style.letterSpacing, strokeColor: style.strokeColor, showShadow: style.showShadow, shadowColor: style.shadowColor, shadowBlur: style.shadowBlur, shadowOffset: style.shadowOffset, fixedDurationMs: style.fixedDurationMs);
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: next);
    await _writeStyle(next);
  }

  /// Applies a quick look whole.
  Future<void> applyPreset(LocalDanmakuPreset preset) async {
    final next = preset.apply(state.style);
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: state.history, style: next);
    await _writeStyle(next);
    await _write('localInteraction.danmakuPreset', preset.id);
  }

  /// Appends one history line, keeping the newest [kLocalHistoryLimit].
  Future<void> addHistory(String line) async {
    final history = [...state.history, line];
    final trimmed = history.length > kLocalHistoryLimit ? history.sublist(history.length - kLocalHistoryLimit) : history;
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: trimmed, style: state.style);
    try {
      await StoragePrefs.setStringList('localInteraction.history', trimmed);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Spends a gift: answers false when the coins do not cover it. A success
  /// deducts the price, adds the price as experience and logs the line.
  Future<bool> sendGift(LocalGift gift, {String? roomName}) async {
    if (!state.enabled || state.coins < gift.price) return false;
    final exp = state.experience + gift.price;
    final coins = state.coins - gift.price;
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: coins, experience: exp, history: state.history, style: state.style);
    await _write('localInteraction.coins', coins);
    await _write('localInteraction.experience', exp);
    await addHistory('${_stamp()} ${gift.emoji} ${gift.name} -${gift.price}');
    return true;
  }

  /// Clears the history, coins and experience behind the page's confirm.
  Future<void> clearHistoryAndEconomy() async {
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: _defaults.coins, experience: 0, history: const [], style: state.style);
    try {
      await StoragePrefs.setStringList('localInteraction.history', const []);
      await StoragePrefs.setInt('localInteraction.coins', _defaults.coins);
      await StoragePrefs.setInt('localInteraction.experience', 0);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Clears only the history, keeping coins and experience.
  Future<void> clearHistory() async {
    state = (enabled: state.enabled, userName: state.userName, title: state.title, showAsDanmaku: state.showAsDanmaku, showPlatformBadge: state.showPlatformBadge, showLevelBadge: state.showLevelBadge, enableGiftEffects: state.enableGiftEffects, previewPlatform: state.previewPlatform, coins: state.coins, experience: state.experience, history: const [], style: state.style);
    try {
      await StoragePrefs.setStringList('localInteraction.history', const []);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _writeStyle(LocalDanmakuStyle style) async {
    await _write('localInteraction.danmakuColor', style.color);
    await _write('localInteraction.danmakuFontSize', style.fontSize);
    await _write('localInteraction.danmakuSpeed', style.speed);
    await _write('localInteraction.danmakuFontWeight', style.fontWeight);
    await _write('localInteraction.danmakuShowStroke', style.showStroke);
    await _write('localInteraction.danmakuStrokeWidth', style.strokeWidth);
    await _write('localInteraction.danmakuPlacement', style.placement);
    await _write('localInteraction.danmakuFontFamily', style.fontFamily);
    await _write('localInteraction.danmakuItalic', style.italic);
    await _write('localInteraction.danmakuOpacity', style.opacity);
    await _write('localInteraction.danmakuLetterSpacing', style.letterSpacing);
    await _write('localInteraction.danmakuStrokeColor', style.strokeColor);
    await _write('localInteraction.danmakuShowShadow', style.showShadow);
    await _write('localInteraction.danmakuShadowColor', style.shadowColor);
    await _write('localInteraction.danmakuShadowBlur', style.shadowBlur);
    await _write('localInteraction.danmakuShadowOffset', style.shadowOffset);
    await _write('localInteraction.danmakuFixedDurationMs', style.fixedDurationMs);
    await _write('localInteraction.danmakuPreset', style.preset);
  }

  Future<void> _write(String key, Object value) async {
    try {
      if (value is bool) await StoragePrefs.setBool(key, value);
      if (value is int) await StoragePrefs.setInt(key, value);
      if (value is double) await StoragePrefs.setDouble(key, value);
      if (value is String) await StoragePrefs.setString(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _writeState(LocalInteractionState next, String key, Object value) async {
    state = next;
    await _write(key, value);
  }

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }
}

/// The local-interaction state.
final localInteractionProvider = NotifierProvider<LocalInteractionController, LocalInteractionState>(
  LocalInteractionController.new,
);

/// The palette the text/stroke/shadow colour rows offer.
const List<int> kLocalDanmakuColors = [
  0xFFFFFFFF,
  0xFFFFE45C,
  0xFF72E6FF,
  0xFFFF69D4,
  0xFF58F5FF,
  0xFF9DFF8A,
  0xFFFF9F5C,
  0xFF000000,
];
