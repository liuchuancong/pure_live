import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart' show LiveMessage, danmakuShapeBlocked;
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
/// read them here.
typedef DanmakuFilterRules = ({
  bool similarityEnabled,
  int similarityThreshold,
  int similarityCacheSeconds,
  int similarityMaxCacheSize,
  bool blockEmoteOnly,
  bool blockLong,
  int blockLongLength,
  bool douyuSuspectedAutomated,
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
);

const String _similarityKey = 'danmaku.filter.similarity';
const String _thresholdKey = 'danmaku.filter.similarityThreshold';
const String _cacheSecondsKey = 'danmaku.filter.similarityCacheSeconds';
const String _maxCacheSizeKey = 'danmaku.filter.similarityMaxCacheSize';
const String _emoteOnlyKey = 'danmaku.filter.emoteOnly';
const String _blockLongKey = 'danmaku.filter.blockLong';
const String _blockLongLengthKey = 'danmaku.filter.blockLongLength';
const String _douyuSuspectedKey = 'danmaku.filter.douyuSuspected';

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
  ));

  /// Moves the length an over-long line must exceed to be hidden.
  Future<void> setBlockLongLength(int value) => _write((
    similarityEnabled: state.similarityEnabled,
    similarityThreshold: state.similarityThreshold,
    similarityCacheSeconds: state.similarityCacheSeconds,
    similarityMaxCacheSize: state.similarityMaxCacheSize,
    blockEmoteOnly: state.blockEmoteOnly,
    blockLong: state.blockLong,
    blockLongLength: value.clamp(
      DanmakuFilterRange.blockLongLengthMin,
      DanmakuFilterRange.blockLongLengthMax,
    ),
    douyuSuspectedAutomated: state.douyuSuspectedAutomated,
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
    } on Object {
      // The rules are a preference; a closed store loses them, nothing else.
    }
  }
}

int _inRange(int? value, int fallback, int min, int max) =>
    value == null ? fallback : value.clamp(min, max);

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
);
