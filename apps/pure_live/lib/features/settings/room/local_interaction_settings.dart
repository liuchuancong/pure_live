import 'dart:async' show Timer, unawaited;
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/features/settings/room/local_growth.dart';

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

/// Which local gifts show their effect over the picture (the reference's
/// `localInteraction.giftEffectLevel`).
enum LocalGiftEffectLevel {
  /// Every gift.
  all('all'),

  /// Only gifts from [kLocalGiftBigPrice] up.
  bigOnly('bigOnly'),

  /// None; gifts still join the chat and the history.
  off('off');

  LocalGiftEffectLevel(this.id);

  /// The stored value.
  final String id;

  /// The level stored as [id]; [all] for anything else (the reference's
  /// normalisation).
  static LocalGiftEffectLevel parse(String? id) => switch (id) {
    'bigOnly' => bigOnly,
    'off' => off,
    _ => all,
  };

  /// Whether a gift costing [price] shows its effect.
  bool shows(int price) => switch (this) {
    all => true,
    bigOnly => price >= kLocalGiftBigPrice,
    off => false,
  };
}

/// A gift from [kLocalGiftBigPrice] up is the reference's "big" tier.
const int kLocalGiftBigPrice = 1000;

/// The most phrases the reference keeps.
const int kLocalPhraseLimit = 20;

/// The longest phrase, counted as the local composer counts.
const int kLocalPhraseLength = 40;

/// Why a phrase cannot be saved.
enum LocalPhraseProblem {
  /// Nothing but whitespace.
  empty,

  /// Another phrase already says it.
  duplicate,

  /// [kLocalPhraseLimit] are saved already.
  full,
}

/// A local danmaku sent in a room, kept for replay when the room is entered
/// again.
final class LocalReplayChat {
  /// Creates the entry.
  const LocalReplayChat({required this.at, required this.text});

  /// When it was sent.
  final DateTime at;

  /// What was said.
  final String text;
}

/// How far back a room replay looks.
const Duration kLocalReplayWindow = Duration(hours: 24);

/// The most lines one replay puts back.
const int kLocalReplayCount = 20;

/// The room-chat log's cap; older rooms leave first.
const int kLocalRoomChatLimit = 200;

/// How long the room-chat log is kept; a replay only reads 24 hours.
const Duration kLocalRoomChatRetention = Duration(days: 3);

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

/// The whole local-interaction choice: identity, what shows, the gift effect
/// level, the phrase chips, replay, growth, the economy, the history and the
/// look.
final class LocalInteractionState {
  /// Creates the state.
  const LocalInteractionState({
    required this.enabled,
    required this.userName,
    required this.title,
    required this.showAsDanmaku,
    required this.showPlatformBadge,
    required this.showLevelBadge,
    required this.enableGiftEffects,
    required this.giftEffectLevel,
    required this.previewPlatform,
    required this.replayOnEnter,
    required this.phrases,
    required this.growthEnabled,
    required this.growthDay,
    required this.coins,
    required this.experience,
    required this.history,
    required this.style,
  });

  /// Whether the local panel is offered.
  final bool enabled;
  final String userName;
  final String title;
  final bool showAsDanmaku;
  final bool showPlatformBadge;
  final bool showLevelBadge;

  /// The 3.x switch's stored value; kept in step with [giftEffectLevel].
  final bool enableGiftEffects;

  /// Which gifts show their effect.
  final LocalGiftEffectLevel giftEffectLevel;
  final String previewPlatform;

  /// Whether entering a room puts its local danmaku from the last day back.
  final bool replayOnEnter;

  /// The quick phrases above the room composer, in the user's order.
  final List<String> phrases;

  /// Whether watching, check-in and local danmaku earn coins and experience.
  final bool growthEnabled;

  /// What growth gave today.
  final LocalGrowthDay growthDay;
  final int coins;
  final int experience;
  final List<String> history;
  final LocalDanmakuStyle style;

  /// A copy with the given fields replaced.
  LocalInteractionState copyWith({
    bool? enabled,
    String? userName,
    String? title,
    bool? showAsDanmaku,
    bool? showPlatformBadge,
    bool? showLevelBadge,
    bool? enableGiftEffects,
    LocalGiftEffectLevel? giftEffectLevel,
    String? previewPlatform,
    bool? replayOnEnter,
    List<String>? phrases,
    bool? growthEnabled,
    LocalGrowthDay? growthDay,
    int? coins,
    int? experience,
    List<String>? history,
    LocalDanmakuStyle? style,
  }) => LocalInteractionState(
    enabled: enabled ?? this.enabled,
    userName: userName ?? this.userName,
    title: title ?? this.title,
    showAsDanmaku: showAsDanmaku ?? this.showAsDanmaku,
    showPlatformBadge: showPlatformBadge ?? this.showPlatformBadge,
    showLevelBadge: showLevelBadge ?? this.showLevelBadge,
    enableGiftEffects: enableGiftEffects ?? this.enableGiftEffects,
    giftEffectLevel: giftEffectLevel ?? this.giftEffectLevel,
    previewPlatform: previewPlatform ?? this.previewPlatform,
    replayOnEnter: replayOnEnter ?? this.replayOnEnter,
    phrases: phrases ?? this.phrases,
    growthEnabled: growthEnabled ?? this.growthEnabled,
    growthDay: growthDay ?? this.growthDay,
    coins: coins ?? this.coins,
    experience: experience ?? this.experience,
    history: history ?? this.history,
    style: style ?? this.style,
  );
}

/// The reference's defaults.
LocalInteractionState _defaults() => LocalInteractionState(
  enabled: true,
  userName: 'Pure Live',
  title: 'listener',
  showAsDanmaku: true,
  showPlatformBadge: true,
  showLevelBadge: true,
  enableGiftEffects: true,
  giftEffectLevel: LocalGiftEffectLevel.all,
  previewPlatform: 'bilibili',
  replayOnEnter: true,
  phrases: const [],
  growthEnabled: true,
  growthDay: LocalGrowthDay.today(),
  coins: 1000,
  experience: 0,
  history: const [],
  style: _defaultStyle,
);

/// The history's cap; older lines leave first.
const int kLocalHistoryLimit = 100;

/// Owns every `localInteraction.*` key and the economy/history mutations the
/// room panel makes.
final class LocalInteractionController extends Notifier<LocalInteractionState> {
  Timer? _watchTimer;

  /// Minutes of this room's play not yet counted into a watch step.
  Duration _watchPending = Duration.zero;

  /// The local day [_watchPending] belongs to.
  String _watchDay = '';

  @override
  LocalInteractionState build() {
    final defaults = _defaults();
    try {
      final legacyEffects = _bool('localInteraction.enableGiftEffects') ?? defaults.enableGiftEffects;
      return LocalInteractionState(
        enabled: _bool('localInteraction.enabled') ?? defaults.enabled,
        userName: _string('localInteraction.userName') ?? defaults.userName,
        title: _string('localInteraction.title') ?? defaults.title,
        showAsDanmaku: _bool('localInteraction.showAsDanmaku') ?? defaults.showAsDanmaku,
        showPlatformBadge: _bool('localInteraction.showPlatformBadge') ?? defaults.showPlatformBadge,
        showLevelBadge: _bool('localInteraction.showLevelBadge') ?? defaults.showLevelBadge,
        enableGiftEffects: legacyEffects,
        // The 3.x switch decides first: off reads as off; otherwise the
        // stored level stands (all when absent or unknown).
        giftEffectLevel: legacyEffects
            ? LocalGiftEffectLevel.parse(_string('localInteraction.giftEffectLevel'))
            : LocalGiftEffectLevel.off,
        previewPlatform: _string('localInteraction.previewPlatform') ?? defaults.previewPlatform,
        replayOnEnter: _bool('localInteraction.replayOnEnter') ?? defaults.replayOnEnter,
        phrases: _cleanPhrases(_strings('localInteraction.phrases') ?? defaults.phrases),
        growthEnabled: _bool('localInteraction.growthEnabled') ?? defaults.growthEnabled,
        growthDay: LocalGrowthDay.read(_string('localInteraction.growthDay')),
        coins: _int('localInteraction.coins') ?? defaults.coins,
        experience: _int('localInteraction.experience') ?? defaults.experience,
        history: _strings('localInteraction.history') ?? defaults.history,
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
      return defaults;
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

  /// Today's counters (a stored day from before today reads as empty).
  LocalGrowthDay get todayGrowth => LocalGrowthDay.read(state.growthDay.encode());

  /// Enables or disables the local panel.
  Future<void> setEnabled({required bool value}) async {
    if (!value) stopWatch();
    state = state.copyWith(enabled: value);
    await _write('localInteraction.enabled', value);
  }

  /// Renames the local user.
  Future<void> setUserName(String value) async {
    final name = value.trim().isEmpty ? _defaults().userName : value.trim();
    state = state.copyWith(userName: name);
    await _write('localInteraction.userName', name);
  }

  /// Changes the local title.
  Future<void> setTitle(String value) async {
    final title = value.trim().isEmpty ? _defaults().title : value.trim();
    state = state.copyWith(title: title);
    await _write('localInteraction.title', title);
  }

  /// Flips one of the four "what shows" switches.
  Future<void> setFlag(String key, {required bool value}) async {
    state = switch (key) {
      'showAsDanmaku' => state.copyWith(showAsDanmaku: value),
      'showPlatformBadge' => state.copyWith(showPlatformBadge: value),
      'showLevelBadge' => state.copyWith(showLevelBadge: value),
      _ => state.copyWith(enableGiftEffects: value),
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

  /// Chooses which gifts show their effect; keeps the 3.x switch in step
  /// (off is off, the other levels on), as the reference stores both.
  Future<void> setGiftEffectLevel(LocalGiftEffectLevel level) async {
    final effects = level != LocalGiftEffectLevel.off;
    state = state.copyWith(giftEffectLevel: level, enableGiftEffects: effects);
    await _write('localInteraction.giftEffectLevel', level.id);
    await _write('localInteraction.enableGiftEffects', effects);
  }

  /// Chooses the platform the preview wears.
  Future<void> setPreviewPlatform(String id) async {
    state = state.copyWith(previewPlatform: id);
    await _write('localInteraction.previewPlatform', id);
  }

  /// Turns replaying a room's last-day local danmaku on entry on or off.
  Future<void> setReplayOnEnter({required bool value}) async {
    state = state.copyWith(replayOnEnter: value);
    await _write('localInteraction.replayOnEnter', value);
  }

  /// Writes the coin balance (the settings page may grant coins).
  Future<void> setCoins(int value) async {
    final coins = value < 0 ? 0 : value;
    state = state.copyWith(coins: coins);
    await _write('localInteraction.coins', coins);
  }

  /// Writes the experience (one level per 100).
  Future<void> setExperience(int value) async {
    final experience = value < 0 ? 0 : value;
    state = state.copyWith(experience: experience);
    await _write('localInteraction.experience', experience);
  }

  // ---- phrases (D08.2) ----

  /// [text] as a phrase is saved: trimmed, at most [kLocalPhraseLength].
  static String cleanPhrase(String text) {
    final trimmed = text.trim();
    return trimmed.runes.take(kLocalPhraseLength).map(String.fromCharCode).join();
  }

  static List<String> _cleanPhrases(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (cleanPhrase(value) case final phrase when phrase.isNotEmpty && seen.add(phrase)) phrase,
    ].take(kLocalPhraseLimit).toList(growable: false);
  }

  /// Whether another phrase can be added.
  bool get phrasesFull => state.phrases.length >= kLocalPhraseLimit;

  /// Why [text] cannot be a phrase (in place of [replacing]), or null when
  /// it can.
  LocalPhraseProblem? phraseProblem(String text, {int? replacing}) {
    final phrase = cleanPhrase(text);
    if (phrase.isEmpty) return LocalPhraseProblem.empty;
    final at = state.phrases.indexOf(phrase);
    if (at >= 0 && at != replacing) return LocalPhraseProblem.duplicate;
    if (replacing == null && phrasesFull) return LocalPhraseProblem.full;
    return null;
  }

  /// Appends [text] as the last phrase; false when [phraseProblem] says why
  /// not.
  Future<bool> addPhrase(String text) async {
    if (phraseProblem(text) != null) return false;
    final next = [...state.phrases, cleanPhrase(text)];
    state = state.copyWith(phrases: next);
    await _writePhrases(next);
    return true;
  }

  /// Replaces the phrase at [index]; false when [phraseProblem] says why not.
  Future<bool> editPhrase(int index, String text) async {
    if (index < 0 || index >= state.phrases.length || phraseProblem(text, replacing: index) != null) {
      return false;
    }
    final next = [...state.phrases]..[index] = cleanPhrase(text);
    state = state.copyWith(phrases: next);
    await _writePhrases(next);
    return true;
  }

  /// Removes the phrase at [index] and answers it (for an undo), or null.
  Future<String?> removePhrase(int index) async {
    if (index < 0 || index >= state.phrases.length) return null;
    final next = [...state.phrases];
    final removed = next.removeAt(index);
    state = state.copyWith(phrases: next);
    await _writePhrases(next);
    return removed;
  }

  /// Puts [text] back at [index] unless it is there already.
  Future<void> restorePhrase(int index, String text) async {
    final phrase = cleanPhrase(text);
    if (phrase.isEmpty || state.phrases.contains(phrase)) return;
    final next = [...state.phrases]..insert(index.clamp(0, state.phrases.length), phrase);
    state = state.copyWith(phrases: next);
    await _writePhrases(next);
  }

  /// Moves the phrase at [from] to [to].
  Future<void> movePhrase(int from, int to) async {
    if (from < 0 || from >= state.phrases.length) return;
    final next = [...state.phrases];
    final moved = next.removeAt(from);
    next.insert(to.clamp(0, next.length), moved);
    state = state.copyWith(phrases: next);
    await _writePhrases(next);
  }

  // ---- growth (D08.3) ----

  /// Turns local growth on or off; stopping settles the watch timer.
  Future<void> setGrowthEnabled({required bool value}) async {
    if (!value) stopWatch();
    state = state.copyWith(growthEnabled: value);
    await _write('localInteraction.growthEnabled', value);
  }

  /// Starts counting this room's play: checks in the first room of the day
  /// and awards a watch step every [LocalGrowthRules.watchStep].
  void startWatch() {
    if (!state.enabled || !state.growthEnabled) return;
    _watchDay = LocalGrowthDay.dayOf(DateTime.now());
    _checkIn();
    _watchTimer ??= Timer.periodic(const Duration(minutes: 1), (_) => _watchTick());
  }

  /// Stops counting play (the room closed, the app went away, growth was
  /// turned off); today's watched time up to the last step is kept.
  void stopWatch() {
    _watchTimer?.cancel();
    _watchTimer = null;
    final today = LocalGrowthDay.dayOf(DateTime.now());
    final pending = today == _watchDay ? _watchPending : Duration.zero;
    _watchPending = Duration.zero;
    if (pending <= Duration.zero) return;
    final growth = todayGrowth;
    unawaited(_write('localInteraction.growthDay', growth.copyWith(watched: growth.watched + pending).encode()));
  }

  void _watchTick() {
    if (!state.enabled || !state.growthEnabled) {
      stopWatch();
      return;
    }
    final day = LocalGrowthDay.dayOf(DateTime.now());
    if (day != _watchDay) {
      _watchDay = day;
      _watchPending = Duration.zero;
    }
    _watchPending += const Duration(minutes: 1);
    if (_watchPending < LocalGrowthRules.watchStep) return;
    final growth = todayGrowth;
    final remaining = LocalGrowthRules.watchDailyExperience - growth.watchExperience;
    if (remaining <= 0) {
      _watchPending = Duration.zero;
      return;
    }
    final steps = math.min(
      _watchPending.inMinutes ~/ LocalGrowthRules.watchStep.inMinutes,
      remaining ~/ LocalGrowthRules.watchExperience,
    );
    if (steps <= 0) return;
    _watchPending -= LocalGrowthRules.watchStep * steps;
    unawaited(
      _grow(
        growth.copyWith(
          watched: growth.watched + LocalGrowthRules.watchStep * steps,
          watchExperience: growth.watchExperience + steps * LocalGrowthRules.watchExperience,
        ),
        experience: steps * LocalGrowthRules.watchExperience,
        coins: steps * LocalGrowthRules.watchCoins,
      ),
    );
  }

  void _checkIn() {
    final growth = todayGrowth;
    if (growth.checkedIn) return;
    unawaited(
      _grow(
        growth.copyWith(checkedIn: true),
        experience: LocalGrowthRules.checkInExperience,
        coins: LocalGrowthRules.checkInCoins,
      ),
    );
  }

  /// A local danmaku was sent: earn [LocalGrowthRules.chatExperience] until
  /// the day's cap.
  Future<void> rewardChat() async {
    if (!state.enabled || !state.growthEnabled) return;
    final growth = todayGrowth;
    if (growth.chatExperience >= LocalGrowthRules.chatDailyExperience) return;
    await _grow(
      growth.copyWith(chatExperience: growth.chatExperience + LocalGrowthRules.chatExperience),
      experience: LocalGrowthRules.chatExperience,
      coins: 0,
    );
  }

  Future<void> _grow(LocalGrowthDay growth, {required int experience, required int coins}) async {
    state = state.copyWith(
      growthDay: growth,
      experience: state.experience + experience,
      coins: state.coins + coins,
    );
    await _write('localInteraction.growthDay', growth.encode());
    if (experience != 0) await _write('localInteraction.experience', state.experience);
    if (coins != 0) await _write('localInteraction.coins', state.coins);
  }

  // ---- per-room chat log (D08.1 c6) ----

  /// Records a local danmaku said in a room for [kLocalReplayWindow].
  Future<void> recordRoomChat(String platform, String roomId, String text) async {
    final line = cleanPhrase(text);
    if (line.isEmpty) return;
    final now = DateTime.now();
    final entries = _readRoomChats().where((entry) => now.difference(entry.at) <= kLocalRoomChatRetention).toList()
      ..add(_RoomChatEntry(at: now, platform: platform, roomId: roomId, text: line));
    final kept = entries.length > kLocalRoomChatLimit
        ? entries.sublist(entries.length - kLocalRoomChatLimit)
        : entries;
    await _write('localInteraction.roomChats', jsonEncode([for (final entry in kept) entry.toJson()]));
  }

  /// The local danmaku sent in this room during [kLocalReplayWindow], oldest
  /// first, at most [kLocalReplayCount].
  List<LocalReplayChat> replayChatsFor(String platform, String roomId, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final recent = [
      for (final entry in _readRoomChats())
        if (entry.platform == platform &&
            entry.roomId == roomId &&
            at.difference(entry.at) <= kLocalReplayWindow &&
            !entry.at.isAfter(at))
          entry,
    ]..sort((a, b) => a.at.compareTo(b.at));
    return [
      for (final entry in recent.length > kLocalReplayCount
          ? recent.sublist(recent.length - kLocalReplayCount)
          : recent)
        LocalReplayChat(at: entry.at, text: entry.text),
    ];
  }

  List<_RoomChatEntry> _readRoomChats() {
    final raw = _string('localInteraction.roomChats');
    if (raw == null || raw.isEmpty) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! List) return [];
    final entries = <_RoomChatEntry>[];
    for (final item in decoded) {
      final entry = _RoomChatEntry.tryParse(item);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  // ---- history and economy ----

  /// Replaces one style field and marks the look custom.
  Future<void> setStyle(LocalDanmakuStyle style) async {
    final next = (preset: 'custom', color: style.color, fontSize: style.fontSize, speed: style.speed, fontWeight: style.fontWeight, showStroke: style.showStroke, strokeWidth: style.strokeWidth, placement: style.placement, fontFamily: style.fontFamily, italic: style.italic, opacity: style.opacity, letterSpacing: style.letterSpacing, strokeColor: style.strokeColor, showShadow: style.showShadow, shadowColor: style.shadowColor, shadowBlur: style.shadowBlur, shadowOffset: style.shadowOffset, fixedDurationMs: style.fixedDurationMs);
    state = state.copyWith(style: next);
    await _writeStyle(next);
  }

  /// Applies a quick look whole.
  Future<void> applyPreset(LocalDanmakuPreset preset) async {
    final next = preset.apply(state.style);
    state = state.copyWith(style: next);
    await _writeStyle(next);
    await _write('localInteraction.danmakuPreset', preset.id);
  }

  /// Appends one history line, keeping the newest [kLocalHistoryLimit].
  Future<void> addHistory(String line) async {
    final history = [...state.history, line];
    final trimmed = history.length > kLocalHistoryLimit ? history.sublist(history.length - kLocalHistoryLimit) : history;
    state = state.copyWith(history: trimmed);
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
    state = state.copyWith(coins: state.coins - gift.price, experience: state.experience + gift.price);
    await _write('localInteraction.coins', state.coins);
    await _write('localInteraction.experience', state.experience);
    await addHistory('${_stamp()} ${gift.emoji} ${gift.name} -${gift.price}');
    return true;
  }

  /// Clears the history, coins and experience behind the page's confirm.
  Future<void> clearHistoryAndEconomy() async {
    state = state.copyWith(
      coins: _defaults().coins,
      experience: 0,
      history: const [],
      growthDay: LocalGrowthDay.today(),
    );
    _watchPending = Duration.zero;
    try {
      await StoragePrefs.setStringList('localInteraction.history', const []);
      await StoragePrefs.setInt('localInteraction.coins', _defaults().coins);
      await StoragePrefs.setInt('localInteraction.experience', 0);
      await StoragePrefs.setString('localInteraction.growthDay', state.growthDay.encode());
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Clears only the history, keeping coins and experience.
  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
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

  Future<void> _writePhrases(List<String> phrases) async {
    try {
      await StoragePrefs.setStringList('localInteraction.phrases', phrases);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  Future<void> _write(String key, Object value) async {
    try {
      if (value is bool) await StoragePrefs.setBool(key, value);
      if (value is int) await StoragePrefs.setInt(key, value);
      if (value is double) await StoragePrefs.setDouble(key, value);
      if (value is String) await StoragePrefs.setString(key, value);
      if (value is List<String>) await StoragePrefs.setStringList(key, value);
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  static String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}';
  }
}

/// One stored room-chat line (the replay source).
final class _RoomChatEntry {
  const _RoomChatEntry({required this.at, required this.platform, required this.roomId, required this.text});

  final DateTime at;
  final String platform;
  final String roomId;
  final String text;

  static _RoomChatEntry? tryParse(Object? item) {
    if (item is! Map) return null;
    final at = item['at'];
    final platform = item['platform'];
    final roomId = item['roomId'];
    final text = item['text'];
    if (at is! num || platform is! String || roomId is! String || text is! String || text.isEmpty) return null;
    return _RoomChatEntry(
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      platform: platform,
      roomId: roomId,
      text: text,
    );
  }

  Map<String, Object> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'platform': platform,
    'roomId': roomId,
    'text': text,
  };
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
