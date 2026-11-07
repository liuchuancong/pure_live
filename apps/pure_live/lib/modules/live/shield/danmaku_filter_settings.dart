import 'package:flame_barrage/flame_barrage.dart' show EmojiAtlas;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart'
    show DanmakuTextShape, LiveMessage, LiveMessageQuery, danmakuMessageShape, danmakuShapeBlocked;
import 'package:live_storage/live_storage.dart';

/// The fuzzy half of the room danmaku filter: whether a line that closely
/// matches one shown moments ago is dropped, and the window/memory that
/// comparison uses (the reference's similar-danmaku filter). Persisted under
/// `danmaku.filter.*`; the room's danmaku pipeline rebuilds its controller
/// config from this on every change, and the controller owns the decision.
///
/// The three content blocks (D02.2 / the reference's 屏蔽页) ride along:
/// emoticon-only, over-long with its length, and the douyu
/// suspected-automation filter — the room's pipeline and the douyu site
/// read them here. The attribute blocks (the reference's 屏蔽页 c3) ride
/// with them: a grey line when the viewer asked for colour only, and the
/// sender-level floors.
typedef DanmakuFilterRules = ({
  bool similarityEnabled,
  int similarityThreshold,
  int similarityCacheSeconds,
  int similarityMaxCacheSize,
  bool blockEmoteOnly,
  bool blockLong,
  int blockLongLength,
  bool douyuSuspectedAutomated,
  bool coloredOnly,
  int minUserLevel,
  int minFansLevel,
});

const DanmakuFilterRules _defaults = (
  similarityEnabled: false,
  similarityThreshold: 85,
  similarityCacheSeconds: 3,
  similarityMaxCacheSize: 100,
  blockEmoteOnly: false,
  blockLong: false,
  blockLongLength: 30,
  douyuSuspectedAutomated: false,
  coloredOnly: false,
  minUserLevel: 0,
  minFansLevel: 0,
);

const String _similarityKey = 'danmaku.filter.similarity';
const String _thresholdKey = 'danmaku.filter.similarityThreshold';
const String _cacheSecondsKey = 'danmaku.filter.similarityCacheSeconds';
const String _maxCacheSizeKey = 'danmaku.filter.similarityMaxCacheSize';
const String _emoteOnlyKey = 'danmaku.filter.emoteOnly';
const String _blockLongKey = 'danmaku.filter.blockLong';
const String _blockLongLengthKey = 'danmaku.filter.blockLongLength';
const String _douyuSuspectedKey = 'danmaku.filter.douyuSuspected';
const String _coloredOnlyKey = 'danmaku.filter.coloredOnly';
const String _minUserLevelKey = 'danmaku.filter.minUserLevel';
const String _minFansLevelKey = 'danmaku.filter.minFansLevel';

/// The ranges the reference offers; the pane's sliders and the controller's
/// reads share them, so a stored value and its control cannot disagree.
abstract final class DanmakuFilterRange {
  /// Lowest similarity score that can be configured.
  static const int thresholdMin = 50;

  /// Highest similarity score.
  static const int thresholdMax = 100;

  /// Shortest cache window, in seconds.
  static const int cacheSecondsMin = 1;

  /// Longest cache window, in seconds.
  static const int cacheSecondsMax = 60;

  /// Smallest cache.
  static const int maxCacheSizeMin = 20;

  /// Largest cache.
  static const int maxCacheSizeMax = 1000;

  /// The cache slider's step (the reference's `stepSize: 10`).
  static const int maxCacheSizeStep = 10;

  /// Shortest over-long block: a line this short is never dropped.
  static const int blockLongLengthMin = 10;

  /// Longest over-long block.
  static const int blockLongLengthMax = 100;

  /// The over-long slider's step.
  static const int blockLongLengthStep = 5;

  /// Highest level a floor can name; the sliders run 0 (off) to this.
  static const int levelMax = 100;
}

/// Owns the fuzzy filter's rules: every edit moves the state first and then
/// writes through, so the pane answers at once and a closed store only
/// loses the persistence.
class DanmakuFilterController extends Notifier<DanmakuFilterRules> {
  @override
  DanmakuFilterRules build() {
    try {
      return (
        similarityEnabled: StoragePrefs.getBool(_similarityKey) ?? _defaults.similarityEnabled,
        similarityThreshold: _inRange(
          StoragePrefs.getInt(_thresholdKey),
          _defaults.similarityThreshold,
          DanmakuFilterRange.thresholdMin,
          DanmakuFilterRange.thresholdMax,
        ),
        similarityCacheSeconds: _inRange(
          StoragePrefs.getInt(_cacheSecondsKey),
          _defaults.similarityCacheSeconds,
          DanmakuFilterRange.cacheSecondsMin,
          DanmakuFilterRange.cacheSecondsMax,
        ),
        similarityMaxCacheSize: _inRange(
          StoragePrefs.getInt(_maxCacheSizeKey),
          _defaults.similarityMaxCacheSize,
          DanmakuFilterRange.maxCacheSizeMin,
          DanmakuFilterRange.maxCacheSizeMax,
        ),
        blockEmoteOnly: StoragePrefs.getBool(_emoteOnlyKey) ?? _defaults.blockEmoteOnly,
        blockLong: StoragePrefs.getBool(_blockLongKey) ?? _defaults.blockLong,
        blockLongLength: _inRange(
          StoragePrefs.getInt(_blockLongLengthKey),
          _defaults.blockLongLength,
          DanmakuFilterRange.blockLongLengthMin,
          DanmakuFilterRange.blockLongLengthMax,
        ),
        douyuSuspectedAutomated: StoragePrefs.getBool(_douyuSuspectedKey) ?? _defaults.douyuSuspectedAutomated,
        coloredOnly: StoragePrefs.getBool(_coloredOnlyKey) ?? _defaults.coloredOnly,
        minUserLevel: _inRange(
          StoragePrefs.getInt(_minUserLevelKey),
          _defaults.minUserLevel,
          0,
          DanmakuFilterRange.levelMax,
        ),
        minFansLevel: _inRange(
          StoragePrefs.getInt(_minFansLevelKey),
          _defaults.minFansLevel,
          0,
          DanmakuFilterRange.levelMax,
        ),
      );
    } on Object {
      return _defaults;
    }
  }

  /// Flips the filter, writing the choice through.
  Future<void> setSimilarityEnabled({required bool value}) => _write((
    similarityEnabled: value,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the similarity threshold, writing through.
  Future<void> setSimilarityThreshold(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: value.clamp(DanmakuFilterRange.thresholdMin, DanmakuFilterRange.thresholdMax),
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the cache window, writing through.
  Future<void> setSimilarityCacheSeconds(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: value.clamp(DanmakuFilterRange.cacheSecondsMin, DanmakuFilterRange.cacheSecondsMax),
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the cache size, writing through.
  Future<void> setSimilarityMaxCacheSize(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: value.clamp(DanmakuFilterRange.maxCacheSizeMin, DanmakuFilterRange.maxCacheSizeMax),
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Hides (or shows) the lines that are nothing but emoticons.
  Future<void> setBlockEmoteOnly({required bool value}) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: value,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Hides (or shows) the lines longer than the rules' `blockLongLength`.
  Future<void> setBlockLong({required bool value}) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: value,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the length an over-long line must exceed to be hidden.
  Future<void> setBlockLongLength(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: value.clamp(DanmakuFilterRange.blockLongLengthMin, DanmakuFilterRange.blockLongLengthMax),
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Turns the douyu suspected-automation filter (its protocol drops those
  /// chats at the socket when the site's seam answers true).
  Future<void> setDouyuSuspectedAutomated({required bool value}) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: value,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Hides (or shows) the grey lines — a text colour with red, green and
  /// blue equal — while the viewer asked for colour only.
  Future<void> setColoredOnly({required bool value}) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: value,
    minUserLevel: state.minUserLevel,
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the user-level floor; zero disables it.
  Future<void> setMinUserLevel(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: value.clamp(0, DanmakuFilterRange.levelMax),
    minFansLevel: state.minFansLevel,
  ));

  /// Moves the fan-badge level floor; zero disables it.
  Future<void> setMinFansLevel(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: state.blockLongLength,
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
    coloredOnly: state.coloredOnly,
    minUserLevel: state.minUserLevel,
    minFansLevel: value.clamp(0, DanmakuFilterRange.levelMax),
  ));

  Future<void> _write(DanmakuFilterRules next) async {
    state = next;
    try {
      await StoragePrefs.setBool(_similarityKey, next.similarityEnabled);
      await StoragePrefs.setInt(_thresholdKey, next.similarityThreshold);
      await StoragePrefs.setInt(_cacheSecondsKey, next.similarityCacheSeconds);
      await StoragePrefs.setInt(_maxCacheSizeKey, next.similarityMaxCacheSize);
      await StoragePrefs.setBool(_emoteOnlyKey, next.blockEmoteOnly);
      await StoragePrefs.setBool(_blockLongKey, next.blockLong);
      await StoragePrefs.setInt(_blockLongLengthKey, next.blockLongLength);
      await StoragePrefs.setBool(_douyuSuspectedKey, next.douyuSuspectedAutomated);
      await StoragePrefs.setBool(_coloredOnlyKey, next.coloredOnly);
      await StoragePrefs.setInt(_minUserLevelKey, next.minUserLevel);
      await StoragePrefs.setInt(_minFansLevelKey, next.minFansLevel);
    } on Object {
      // The rules are a preference; a closed store loses them, nothing else.
    }
  }
}

int _inRange(int? value, int fallback, int min, int max) => value == null ? fallback : value.clamp(min, max);

/// The room danmaku's fuzzy filter rules.
final danmakuFilterProvider = NotifierProvider<DanmakuFilterController, DanmakuFilterRules>(
  DanmakuFilterController.new,
);

/// Whether [message] is one of the content blocks — nothing but emoticons,
/// or longer than the configured length — under [rules]. A line the viewer
/// sent themselves is never blocked.
bool danmakuShapeBlockedByRules(LiveMessage message, DanmakuFilterRules rules) => danmakuShapeBlocked(
  message,
  blockEmoteOnly: rules.blockEmoteOnly,
  blockLong: rules.blockLong,
  blockLongLength: rules.blockLongLength,
  shapeOf: _shapeAsDrawn,
);

/// Whether [message] is one of the attribute blocks under [rules]: a grey
/// line while the viewer asked for colour only, or a sender under one of
/// the level floors. A level the platform did not give is never under a
/// floor — unknown reads as no opinion, not as zero — and a line the viewer
/// sent themselves is never blocked.
bool danmakuAttributesBlockedByRules(LiveMessage message, DanmakuFilterRules rules) {
  if (message.isLocal) return false;
  if (rules.coloredOnly) {
    final color = message.effectiveColor;
    if (color.r == color.g && color.g == color.b) return true;
  }
  final sender = message.sender;
  if (sender == null) return false;
  return _underFloor(sender.userLevel, rules.minUserLevel) || _underFloor(sender.fanBadgeLevel, rules.minFansLevel);
}

bool _underFloor(String? display, int floor) {
  if (floor <= 0) return false;
  final level = display == null ? null : int.tryParse(display.trim());
  return level != null && level >= 0 && level < floor;
}

/// The message's shape read the way the chat draws it.
///
/// The flying layer's catalogue is the one table that knows `[笑哭]` is a
/// picture: Douyu and Huya send the code as the message's whole text and keep
/// the sheet themselves, so a filter that only reads [LiveMessage.emotes] —
/// the sites that name each emoticon — sees brackets and letters. Then
/// "屏蔽只有表情的弹幕" lets through exactly the screenful of faces it was
/// switched on for, and the length limit counts six characters for one
/// emoticon. The catalogue is the app's, so the reading is here rather than in
/// the package; a catalogue that has not loaded leaves the plain reading.
DanmakuTextShape _shapeAsDrawn(LiveMessage message) =>
    danmakuMessageShape(message, emoticonPattern: EmojiAtlas.instance.regex);
