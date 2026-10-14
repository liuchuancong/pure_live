import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_protobuf.dart';
import 'package:meta/meta.dart';

// The value wrappers spell their class name in their constructors; the `.new`
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One comment window of the comment server: its messages are read from
/// [uri], an answer that lasts until the window ends.
final class NiconicoCommentWindow {
  /// Creates a window.
  const NiconicoCommentWindow({required this.from, required this.until, required this.uri});

  /// Window start.
  final DateTime from;

  /// Window end.
  final DateTime until;

  /// Where its messages are read (the path carries a token).
  final Uri uri;

  @override
  String toString() => 'NiconicoCommentWindow(${from.toIso8601String()}–${until.toIso8601String()})';
}

/// What an entry of a `view` answer is (`ChunkedEntry`).
enum NiconicoViewEntryKind {
  /// A window under way or about to start: read it.
  segment,

  /// A finished window: history, not read.
  previous,

  /// Where older history and a state snapshot are: not read.
  backward,

  /// When to ask `view` again.
  next,

  /// Anything else.
  unknown,
}

/// One entry of a `view` answer.
final class NiconicoViewEntry {
  /// Creates an entry.
  const NiconicoViewEntry(this.kind, {this.window, this.next});

  /// What it is.
  final NiconicoViewEntryKind kind;

  /// The window of a [NiconicoViewEntryKind.segment] or
  /// [NiconicoViewEntryKind.previous] entry; null when it is not usable.
  final NiconicoCommentWindow? window;

  /// The `at` of the next `view` request (epoch seconds), for a
  /// [NiconicoViewEntryKind.next] entry.
  final int? next;
}

/// Who may comment (`NicoliveState.comment_lock`), as the web player reads it:
/// everyone, nobody ([NiconicoCommentLock.locked]), or followers only (a
/// [followersOnly] duration). Only a *change* is reported as a notice, so one
/// is remembered across a seat's messages.
@immutable
final class NiconicoCommentLock {
  const NiconicoCommentLock._(this.isLocked, this.followersOnly);

  /// Followers only, once they have followed for [minimumFollow].
  const NiconicoCommentLock.followers(Duration minimumFollow) : isLocked = false, followersOnly = minimumFollow;

  /// Everyone may comment.
  static const NiconicoCommentLock none = NiconicoCommentLock._(false, null);

  /// Comments are locked.
  static const NiconicoCommentLock locked = NiconicoCommentLock._(true, null);

  /// Whether comments are locked.
  final bool isLocked;

  /// How long only followers must have followed to comment; null when not only
  /// followers may.
  final Duration? followersOnly;

  @override
  bool operator ==(Object other) =>
      other is NiconicoCommentLock && other.isLocked == isLocked && other.followersOnly == followersOnly;

  @override
  int get hashCode => Object.hash(isLocked, followersOnly);
}

/// Reads the window messages of one connection, in order, into
/// [LiveMessage]s. It remembers who may comment, so only a change of the
/// comment lock is reported, and whether the last message said the program
/// ended ([endedProgram]); it starts from "everyone" (the web player's default
/// before its state snapshot, which is not read here). One reader serves one
/// seat; a re-seat starts a fresh one.
final class NiconicoMessageReader {
  NiconicoCommentLock _commentLock = NiconicoCommentLock.none;
  bool _endedProgram = false;

  /// Whether the last message read said the program ended (`program_status`
  /// `Ended`). A window that reports it ends its seat.
  bool get endedProgram => _endedProgram;

  /// One window message (`ChunkedMessage`: 1 meta, then one of 2 message,
  /// 4 state, 5 signal) as a [LiveMessage], or null when it is none of the
  /// reported kinds. Throws [FormatException] when it is not protobuf.
  LiveMessage? read(List<int> bytes) {
    _endedProgram = false;
    final chunk = NiconicoProtoMessage.decode(bytes);
    final meta = chunk.message(1);
    return switch (NiconicoDanmakuCodec.lastPayload(chunk)) {
      2 => NiconicoDanmakuCodec.nicoliveMessage(chunk.message(2)!, meta),
      4 => _state(chunk.message(4)!, meta),
      _ => null,
    };
  }

  /// `NicoliveState`: not a oneof, but every recorded state carries one. The
  /// web player takes the first it knows in its order — 5 comment_lock, 4
  /// marquee, 9 program_status, 1 statistics. A field that is not protobuf
  /// counts as absent.
  LiveMessage? _state(NiconicoProtoMessage state, NiconicoProtoMessage? meta) {
    if (_readable(() => state.message(5)) case final lock?) {
      if (_readable(() => NiconicoDanmakuCodec.commentLockOf(lock)) case final next?) {
        final notice = NiconicoDanmakuCodec.commentLockNotice(next, _commentLock);
        _commentLock = next;
        if (notice != null) return NiconicoDanmakuCodec.notice(notice, meta);
      }
    }
    if (_readable(() => state.message(4)) case final marquee?) {
      if (_readable(() => NiconicoDanmakuCodec.operatorComment(marquee, meta)) case final notice?) return notice;
    }
    if (_readable(() => state.message(9)?.integer(1)) == 1) {
      _endedProgram = true;
      return NiconicoDanmakuCodec.programEnded(
        messageId: meta?.string(1)?.trim() ?? '',
        sentAt: NiconicoDanmakuCodec.time(meta?.message(2)),
      );
    }
    final viewers = _readable(() => state.message(1)?.integer(1));
    if (viewers == null || viewers < 0) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.audienceUpdate,
      payload: LiveAudienceUpdate(kind: LiveAudienceSignalKind.totalViewers, value: viewers),
      color: LiveMessageColor.white,
    );
  }

  /// What [read] gives, or null when it meets bytes that are not protobuf.
  static T? _readable<T>(T? Function() read) {
    try {
      return read();
    } on FormatException {
      return null;
    }
  }
}

/// niconico's comment server ("NDGR"), without I/O. The watching seat's
/// `messageServer.viewUri` names its `view` address; every answer is a
/// varint-length-delimited protobuf stream (`ChunkedEntry` for `view`,
/// `ChunkedMessage` for a window). Chats (`chat` field 1 and `overflowed_chat`
/// field 20) become chat messages; gifts (`gift` field 8) gift messages;
/// `statistics.viewers`, the operator's marquee comment, a change of who may
/// comment (`comment_lock`) and the program's end (`program_status`) become an
/// audience update and system notices. Ads, notifications, forwarded chats, the
/// other states and the signals are not reported.
abstract final class NiconicoDanmakuCodec {
  /// The notice of the program's end: the web player's line once it ended.
  static const String programEndedNotice = 'この番組は終了しました';

  /// The web player's comment-field line while comments are locked.
  static const String commentLockedNotice = '現在コメントできません';

  /// The lift of a comment lock (the web player only re-enables its field, so
  /// the sentence is ours).
  static const String commentUnlockedNotice = '评论锁定已解除';

  /// The web player's line when comments are no longer for followers only.
  static const String followersOnlyLiftedNotice = 'フォロワー限定コメントが解除されました';

  /// The most seconds a follow restriction is read as (about 136 years).
  static const int maxFollowSeconds = 1 << 32;

  /// A follow restriction of [seconds] (0 or more) as the web player writes it:
  /// whole days from a day on, else hours and minutes from an hour on, else
  /// minutes (`0分` under a minute).
  static String followDuration(int seconds) {
    if (seconds >= 86400) {
      final days = '${seconds ~/ 86400}日';
      return seconds % 86400 < 3600 ? days : '$daysと${seconds % 86400 ~/ 3600}時間';
    }
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final hours = '${seconds ~/ 3600}時間';
    return seconds % 3600 < 60 ? hours : '$hours${seconds % 3600 ~/ 60}分';
  }

  /// The `view` request of [view] for [at] (`now` or a `next` value).
  static Uri viewUrl(Uri view, String at) => view.replace(queryParameters: {...view.queryParameters, 'at': at});

  /// Whether [uri] may be read as the comment server: https on `nicovideo.jp`
  /// or a subdomain, without credentials, port or fragment.
  static bool isCommentServer(Uri uri) =>
      uri.isScheme('https') &&
      (uri.host == 'nicovideo.jp' || uri.host.endsWith('.nicovideo.jp')) &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasFragment;

  /// The largest comment-server message accepted.
  static const int maxMessageBytes = 1 << 20;

  /// The messages of a whole answer [bytes], split at their varint length
  /// prefixes.
  static List<List<int>> split(List<int> bytes) => niconicoSplitDelimited(bytes);

  /// The messages of a streamed answer [body], as they complete. Fails
  /// ([FormatException]) on a bad length prefix, a message over
  /// [maxLength], or when the answer ends inside a message.
  static Stream<Uint8List> delimited(Stream<List<int>> body, {int maxLength = maxMessageBytes}) async* {
    final reader = NiconicoDelimitedReader(maxLength: maxLength);
    await for (final chunk in body) {
      for (final message in reader.add(chunk)) {
        yield message;
      }
    }
    reader.close();
  }

  /// One `view` entry (`ChunkedEntry`: 1 segment, 2 backward, 3 previous,
  /// 4 next; the last length-delimited one wins). Throws [FormatException]
  /// when it is not protobuf.
  static NiconicoViewEntry viewEntry(List<int> bytes) {
    final entry = NiconicoProtoMessage.decode(bytes);
    final kind = _lastOf(entry, const {1, 2, 3, 4});
    return switch (kind) {
      1 => NiconicoViewEntry(NiconicoViewEntryKind.segment, window: _window(entry.message(1))),
      3 => NiconicoViewEntry(NiconicoViewEntryKind.previous, window: _window(entry.message(3))),
      2 => const NiconicoViewEntry(NiconicoViewEntryKind.backward),
      4 => NiconicoViewEntry(NiconicoViewEntryKind.next, next: _positive(entry.message(4)?.integer(1))),
      _ => const NiconicoViewEntry(NiconicoViewEntryKind.unknown),
    };
  }

  /// One window message (`ChunkedMessage`: 1 meta, then one of 2 message,
  /// 4 state, 5 signal) as a [LiveMessage], or null when it is none of the
  /// reported kinds; a comment lock as a change from "everyone". Throws
  /// [FormatException] when it is not protobuf. A connection reads a seat's
  /// messages with one [NiconicoMessageReader]; this stateless form is for a
  /// single message.
  static LiveMessage? message(List<int> bytes) => NiconicoMessageReader().read(bytes);

  /// The payload of a `ChunkedMessage`: 2 or 4 (a message, length-delimited)
  /// or 5 (a signal, a varint) — the last one wins. A signal (5) is not
  /// reported, but reading it as one keeps a `Flushed` chunk from being
  /// mistaken for a chat.
  static int? lastPayload(NiconicoProtoMessage chunk) {
    for (final field in chunk.fields.reversed) {
      if (field.number == 5 && field.wireType == niconicoProtoVarintType) return 5;
      if ((field.number == 2 || field.number == 4) && field.wireType == niconicoProtoLengthDelimitedType) {
        return field.number;
      }
    }
    return null;
  }

  /// The notice that the program ended ([programEndedNotice]), with the
  /// platform's [messageId] and [sentAt] when it has them.
  static LiveMessage programEnded({String messageId = '', DateTime? sentAt}) => notice(
    programEndedNotice,
    null,
    messageId: messageId,
    sentAt: sentAt,
  );

  /// A system notice of [text] with the window message's [meta] (id and time),
  /// its optional [userName] and [color].
  static LiveMessage notice(
    String text,
    NiconicoProtoMessage? meta, {
    String userName = '',
    LiveMessageColor? color,
    String messageId = '',
    DateTime? sentAt,
  }) => LiveMessage.normalized(
    type: LiveMessageType.notice,
    text: text,
    sender: MessageSender.normalized(userName: userName),
    payload: LiveNoticeKind.system,
    color: color ?? LiveMessageColor.white,
    messageId: messageId.isNotEmpty ? messageId : (meta?.string(1)?.trim() ?? ''),
    sentAt: sentAt ?? time(meta?.message(2)),
  );

  /// Who may comment by a `CommentLock` (1 status: 0 Unrestricted, 1 Locked,
  /// 2 Restricted; 2 follow_restriction {1 minimum_follow_duration {1
  /// seconds}}); null for a status this does not know (changes nothing). A
  /// follow duration below zero is zero; over [maxFollowSeconds], that.
  static NiconicoCommentLock? commentLockOf(NiconicoProtoMessage lock) {
    switch (lock.integer(1) ?? 0) {
      case 0:
        return NiconicoCommentLock.none;
      case 1:
        return NiconicoCommentLock.locked;
      case 2:
        final restriction = lock.message(2);
        if (restriction == null) return NiconicoCommentLock.none;
        final seconds = restriction.message(1)?.integer(1) ?? 0;
        return NiconicoCommentLock.followers(Duration(seconds: seconds.clamp(0, maxFollowSeconds)));
      default:
        return null;
    }
  }

  /// The notice of a change from [previous] to [next], or null when it is no
  /// change: the web player's own lines for followers-only and its lift, the
  /// comment field's line for a lock, and ours for a lock's lift.
  static String? commentLockNotice(NiconicoCommentLock next, NiconicoCommentLock previous) {
    if (next == previous) return null;
    if (next.isLocked) return commentLockedNotice;
    if (next.followersOnly case final minimum?) {
      final seconds = minimum.inSeconds;
      return seconds == 0
          ? '【コメント制限】フォロワーに限定されます'
          : '【コメント制限】${followDuration(seconds)}フォローを継続したユーザーに限定されます';
    }
    return previous.isLocked ? commentUnlockedNotice : followersOnlyLiftedNotice;
  }

  /// `Marquee` (1 display {1 operator_comment}): the operator's comment
  /// (`OperatorComment`: 1 content, 2 name, 3 modifier) as a notice, in its
  /// colour; null for a cleared marquee or an empty comment.
  static LiveMessage? operatorComment(NiconicoProtoMessage marquee, NiconicoProtoMessage? meta) {
    final comment = marquee.message(1)?.message(1);
    final text = comment?.string(1)?.trim() ?? '';
    if (comment == null || text.isEmpty) return null;
    return notice(text, meta, userName: comment.string(2)?.trim() ?? '', color: color(comment.message(3)));
  }

  /// A `Chat` (1 content, 2 name, 5 raw_user_id, 6 hashed_user_id, 7
  /// modifier), its id and time from the `ChunkedMessage` meta (1 id, 2 at):
  /// a chat message, or null when it has no text.
  static LiveMessage? chat(NiconicoProtoMessage message, {NiconicoProtoMessage? meta}) {
    final text = message.string(1)?.trim() ?? '';
    if (text.isEmpty) return null;
    final hashed = message.string(6)?.trim() ?? '';
    final raw = message.integer(5);
    return LiveMessage.normalized(
      text: text,
      sender: MessageSender.normalized(
        userId: hashed.isNotEmpty ? hashed : (raw == null ? '' : '$raw'),
        userName: message.string(2)?.trim() ?? '',
      ),
      color: color(message.message(7)),
      messageId: meta?.string(1)?.trim() ?? '',
      sentAt: time(meta?.message(2)),
    );
  }

  /// `NicoliveMessage`: one field of its oneof; 1 chat and 20 overflowed_chat
  /// are chats, 8 gift a gift, the rest not reported.
  static LiveMessage? nicoliveMessage(NiconicoProtoMessage data, NiconicoProtoMessage? meta) =>
      switch (data.lastOf(const {1, 7, 8, 9, 13, 17, 18, 19, 20, 22, 23, 24, 25, 26})) {
        final kind? when kind == 1 || kind == 20 => chat(data.message(kind)!, meta: meta),
        8 => gift(data.message(8)!, meta),
        _ => null,
      };

  /// `Gift` (1 item_id, 2 advertiser_user_id, 3 advertiser_name, 4 point,
  /// 5 message, 6 item_name, 7 contribution_rank): the shared `ニコ子 ×1` line,
  /// one item worth `point` niconico points (free at 0). Like the web player, a
  /// gift of negative points or without an item or a name is dropped.
  static LiveMessage? gift(NiconicoProtoMessage gift, NiconicoProtoMessage? meta) {
    final itemId = gift.string(1)?.trim() ?? '';
    final name = gift.string(6)?.trim() ?? '';
    final point = gift.integer(4) ?? 0;
    if ((itemId.isEmpty && name.isEmpty) || point < 0) return null;
    final giver = gift.string(3)?.trim() ?? '';
    final giverId = gift.integer(2);
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${name.isEmpty ? itemId : name} ×1',
      sender: MessageSender.normalized(
        userId: giverId != null && giverId > 0 ? '$giverId' : '',
        userName: giver,
      ),
      color: LiveMessageColor.white,
      payload: LiveGift(
        giftId: itemId,
        name: name,
        value: LiveGiftValue(
          unit: point == 0 ? LiveGiftUnit.free : LiveGiftUnit.point,
          unitPrice: point == 0 ? null : point.toDouble(),
          totalValue: point == 0 ? null : point.toDouble(),
        ),
      ),
      messageId: meta?.string(1)?.trim() ?? '',
      sentAt: time(meta?.message(2)),
    );
  }

  // Helpers -------------------------------------------------------------------

  /// `MessageSegment`: 1 from, 2 until, 3 uri — the window, or null when its
  /// times or address are not usable.
  static NiconicoCommentWindow? _window(NiconicoProtoMessage? segment) {
    final from = time(segment?.message(1));
    final until = time(segment?.message(2));
    final uri = Uri.tryParse(segment?.string(3)?.trim() ?? '');
    if (from == null || until == null || uri == null || !isCommentServer(uri)) return null;
    return NiconicoCommentWindow(from: from, until: until, uri: uri);
  }

  static int? _positive(int? value) => value != null && value > 0 ? value : null;

  /// The number of the last length-delimited field of [message] among [numbers]
  /// (a oneof: the last one wins), or null.
  static int? _lastOf(NiconicoProtoMessage message, Set<int> numbers) => message.lastOf(numbers);

  /// The largest `Timestamp.seconds` a `DateTime` holds.
  static const int _maxSeconds = 8640000000000;

  /// A `google.protobuf.Timestamp` (1 seconds, 2 nanos) as a `DateTime`; null
  /// without seconds, or out of range.
  static DateTime? time(NiconicoProtoMessage? timestamp) {
    final seconds = timestamp?.integer(1);
    final nanos = timestamp?.integer(2) ?? 0;
    if (seconds == null || seconds.abs() > _maxSeconds || nanos < 0 || nanos > 999999999) return null;
    return DateTime.fromMicrosecondsSinceEpoch(seconds * 1000000 + nanos ~/ 1000);
  }

  /// The colour of a `Chat.Modifier` (a oneof, the last one wins: 3 named_color,
  /// 4 full_color {1 r, 2 g, 3 b}); white without one or for an unknown name.
  static LiveMessageColor color(NiconicoProtoMessage? modifier) {
    if (modifier == null) return LiveMessageColor.white;
    final named = modifier.integer(3);
    if (named != null) return named >= 0 && named < namedColors.length ? namedColors[named] : LiveMessageColor.white;
    final rgb = modifier.message(4);
    if (rgb != null) {
      int channel(int number) => (rgb.integer(number) ?? 0).toSigned(32).clamp(0, 255);
      return LiveMessageColor(channel(1), channel(2), channel(3));
    }
    return LiveMessageColor.white;
  }

  /// The colours of `Chat.Modifier.ColorName`, by value: the ten basic colours
  /// and the ten premium ones, as niconico's comment commands draw them.
  static const List<LiveMessageColor> namedColors = [
    LiveMessageColor(255, 255, 255), // white
    LiveMessageColor(255, 0, 0), // red
    LiveMessageColor(255, 128, 128), // pink
    LiveMessageColor(255, 192, 0), // orange
    LiveMessageColor(255, 255, 0), // yellow
    LiveMessageColor(0, 255, 0), // green
    LiveMessageColor(0, 255, 255), // cyan
    LiveMessageColor(0, 0, 255), // blue
    LiveMessageColor(192, 0, 255), // purple
    LiveMessageColor(0, 0, 0), // black
    LiveMessageColor(204, 204, 153), // white2 (niconicowhite)
    LiveMessageColor(204, 0, 51), // red2 (truered)
    LiveMessageColor(255, 51, 204), // pink2
    LiveMessageColor(255, 102, 0), // orange2 (passionorange)
    LiveMessageColor(153, 153, 0), // yellow2 (madyellow)
    LiveMessageColor(0, 204, 102), // green2 (elementalgreen)
    LiveMessageColor(0, 204, 204), // cyan2
    LiveMessageColor(51, 153, 255), // blue2 (marineblue)
    LiveMessageColor(102, 51, 204), // purple2 (nobleviolet)
    LiveMessageColor(102, 102, 102), // black2
  ];
}
