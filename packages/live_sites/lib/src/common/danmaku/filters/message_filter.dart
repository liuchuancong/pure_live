// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/common/danmaku/filters/block_list.dart';
import 'package:live_sites/src/common/danmaku/filters/message_gate.dart';
import 'package:live_sites/src/common/danmaku/filters/repeated_filter.dart';
import 'package:live_sites/src/common/danmaku/filters/similarity_filter.dart';
import 'package:live_sites/src/common/danmaku/filters/text_shape.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// The filter settings of 3.x (danmaku settings and the block lists), with
/// its defaults: both optional filters are off; and the two blocks v4 added
/// (D02.2 c3), off too.
@immutable
final class DanmakuFilterSettings {
  /// Creates the settings.
  const DanmakuFilterSettings({
    this.collapseRepeated = false,
    this.repeatedWindowSeconds = 5,
    this.similarityEnabled = false,
    this.similarityThreshold = 85,
    this.similarityCacheSeconds = 3,
    this.similarityMaxCacheSize = 100,
    this.blockedUsers = const [],
    this.blockedKeywords = const [],
    this.blockEmoteOnly = false,
    this.blockLong = false,
    this.blockLongLength = 30,
  });

  /// Collapse repeated text (`collapseRepeatedDanmaku`).
  final bool collapseRepeated;

  /// Window of [collapseRepeated] in seconds, used clamped to 1–30
  /// (`repeatedDanmakuWindowSeconds`).
  final int repeatedWindowSeconds;

  /// Hide similar text (`enableDanmakuSimilarityFilter`).
  final bool similarityEnabled;

  /// Similarity score that hides a text (`danmakuSimilarityThreshold`).
  final int similarityThreshold;

  /// How long a shown text is compared with, in seconds
  /// (`danmakuSimilarityCacheDuration`).
  final int similarityCacheSeconds;

  /// Most texts compared with (`danmakuSimilarityMaxCacheSize`).
  final int similarityMaxCacheSize;

  /// Blocked viewer names as stored (`blockedDanmakuUsers`).
  final List<String> blockedUsers;

  /// Blocked words as stored (`shieldList`); `/…/` ones are patterns
  /// (D02.2).
  final List<String> blockedKeywords;

  /// Hide the messages that are nothing but emoticons
  /// (`blockEmoteOnlyDanmaku`, D02.2).
  final bool blockEmoteOnly;

  /// Hide the messages longer than [blockLongLength] (`blockLongDanmaku`,
  /// D02.2).
  final bool blockLong;

  /// The most characters [blockLong] lets through, used clamped to 10–100
  /// (`blockLongDanmakuLength`).
  final int blockLongLength;
}

/// What the filter did with a message ([DanmakuMessageFilter.judge]).
enum DanmakuVerdict {
  /// Shown.
  shown,

  /// Hidden by the duplicate gate (a repeated packet or an old message).
  duplicate,

  /// Hidden by the user's blocks: the block list, "屏蔽只有表情的弹幕" or
  /// "屏蔽超长弹幕" (the room counts these, D02.2 c4).
  blocked,

  /// Hidden as a repeat of a text just shown.
  repeated,

  /// Hidden as similar to a text just shown.
  similar,
}

/// Decides which chat messages of one room reach the screen and the list,
/// in 3.x's order (`DanmakuController._installCallbacks`):
///
/// 1. the duplicate gate ([DanmakuMessageGate]), always;
/// 2. the block list ([DanmakuBlockList]), always; then the emoticon-only
///    and the length blocks when enabled, for platform messages only
///    (D02.2);
/// 3. repeated-text collapsing ([RepeatedDanmakuFilter]) when enabled;
/// 4. the similarity filter ([DanmakuSimilarityFilter]) when enabled, for
///    platform messages only.
///
/// A platform gift goes through steps 1 and 2 only (D07.1: a gift repeats
/// on purpose, so neither collapsing nor similarity applies; a blocked word
/// in its text, `粉丝荧光棒 ×10`, blocks it). Local gifts and other message
/// types (audience figures, super chats) are not filtered.
final class DanmakuMessageFilter {
  /// Creates the filter with [settings]; [clock] times every step.
  DanmakuMessageFilter({DanmakuFilterSettings settings = const DanmakuFilterSettings(), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      similarity = DanmakuSimilarityFilter(clock: clock) {
    this.settings = settings;
  }

  final DateTime Function() _clock;

  /// Step 1.
  final DanmakuMessageGate gate = DanmakuMessageGate();

  /// Step 3.
  final RepeatedDanmakuFilter repeated = RepeatedDanmakuFilter();

  /// Step 4.
  final DanmakuSimilarityFilter similarity;

  late DanmakuBlockList _blockList;

  /// How step 2 reads a message's emoticons and length; the app's reads the
  /// platform's bundled emoticon lists too.
  DanmakuTextShaper shapeOf = danmakuMessageShape;

  /// The settings in use.
  DanmakuFilterSettings get settings => _settings;
  late DanmakuFilterSettings _settings;

  /// Applies new settings to the following messages, without reconnecting:
  /// the block list is rebuilt; the similarity filter takes the new values,
  /// or forgets its texts when it is off.
  set settings(DanmakuFilterSettings value) {
    _settings = value;
    _blockList = DanmakuBlockList.of(users: value.blockedUsers, keywords: value.blockedKeywords);
    if (!value.similarityEnabled) {
      similarity.clear();
      return;
    }
    similarity.updateConfig(
      similarityThreshold: value.similarityThreshold,
      cacheDuration: Duration(seconds: value.similarityCacheSeconds),
      maxCacheSize: value.similarityMaxCacheSize,
    );
  }

  /// Whether [message] should be shown.
  bool accepts(LiveMessage message) => judge(message) == DanmakuVerdict.shown;

  /// Whether [message] should be shown, and what hid it.
  DanmakuVerdict judge(LiveMessage message) {
    if (message.type == LiveMessageType.gift) return _judgeGift(message);
    if (message.type != LiveMessageType.chat) return DanmakuVerdict.shown;
    final now = _clock();
    if (!gate.accepts(message, now: now)) return DanmakuVerdict.duplicate;
    if (_blockList.blocks(message) || _blocksShape(message)) return DanmakuVerdict.blocked;
    final window = Duration(seconds: _settings.repeatedWindowSeconds.clamp(1, 30));
    if (!repeated.accepts(message, enabled: _settings.collapseRepeated, window: window, now: now)) {
      return DanmakuVerdict.repeated;
    }
    if (message.isLocal || !_settings.similarityEnabled || similarity.shouldDisplay(message.text)) {
      return DanmakuVerdict.shown;
    }
    return DanmakuVerdict.similar;
  }

  bool _blocksShape(LiveMessage message) {
    final settings = _settings;
    if (message.isLocal || !(settings.blockEmoteOnly || settings.blockLong)) return false;
    final shape = shapeOf(message);
    return (settings.blockEmoteOnly && shape.emoteOnly) ||
        (settings.blockLong && shape.length > settings.blockLongLength.clamp(10, 100));
  }

  /// Steps 1 and 2 for a platform gift (D07.1): the duplicate gate and the
  /// block list (D02.2's regexes too); the content blocks are for chat only.
  DanmakuVerdict _judgeGift(LiveMessage message) {
    if (message.isLocal) return DanmakuVerdict.shown;
    if (!gate.accepts(message, now: _clock())) return DanmakuVerdict.duplicate;
    return _blockList.blocks(message) ? DanmakuVerdict.blocked : DanmakuVerdict.shown;
  }

  /// Forgets everything seen (another room).
  void clear() {
    gate.clear();
    repeated.clear();
    similarity.clear();
  }
}
