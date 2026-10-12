import 'dart:async';
import 'dart:typed_data';

import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// One comment window of the comment server: its messages are read from
/// [uri], an answer that lasts until the window ends.
@immutable
final class NiconicoCommentWindow {
  /// Creates a window.
  const new({required this.from, required this.until, required this.uri});

  /// Window start.
  final DateTime from;

  /// Window end.
  final DateTime until;

  /// Where its messages are read (the path carries a token).
  final Uri uri;

  @override
  bool operator ==(Object other) =>
      other is NiconicoCommentWindow && other.from == from && other.until == until && other.uri == uri;

  @override
  int get hashCode => Object.hash(from, until, uri);

  /// The window's times only: its address carries a token.
  @override
  String toString() => 'NiconicoCommentWindow(${from.toUtc().toIso8601String()}–${until.toUtc().toIso8601String()})';
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
@immutable
final class NiconicoViewEntry {
  /// Creates an entry.
  const new(this.kind, {this.window, this.next});

  /// What it is.
  final NiconicoViewEntryKind kind;

  /// The window of a [NiconicoViewEntryKind.segment] or
  /// [NiconicoViewEntryKind.previous] entry; null when it is not usable (no
  /// times, or an address that is not the comment server).
  final NiconicoCommentWindow? window;

  /// The `at` of the next `view` request (seconds since the epoch), for a
  /// [NiconicoViewEntryKind.next] entry.
  final int? next;
}

/// Who may comment (`NicoliveState.comment_lock`), as the web player reads it:
/// everyone, nobody (`Locked`), or followers only (`Restricted` with a follow
/// restriction; `Restricted` without one is everyone).
@immutable
final class NiconicoCommentLock {
  const new _(this.isLocked, this.followersOnly);

  /// Followers only, once they have followed for [minimumFollow].
  const new followers(Duration minimumFollow) : isLocked = false, followersOnly = minimumFollow;

  /// Everyone may comment.
  static const NiconicoCommentLock none = NiconicoCommentLock._(false, null);

  /// Comments are locked.
  static const NiconicoCommentLock locked = NiconicoCommentLock._(true, null);

  /// Whether comments are locked.
  final bool isLocked;

  /// How long only followers must have followed to comment; null when not only
  /// followers may.
  final Duration? followersOnly;

  /// The notice for a change from [previous], or null when it is no change.
  String? noticeFrom(NiconicoCommentLock previous) {
    if (this == previous) return null;
    if (isLocked) return NiconicoDanmakuProtocol.commentLockedNotice;
    if (followersOnly case final minimum?) {
      final seconds = minimum.inSeconds;
      return seconds == 0
          ? '【コメント制限】フォロワーに限定されます'
          : '【コメント制限】${NiconicoDanmakuProtocol.followDuration(seconds)}フォローを継続したユーザーに限定されます';
    }
    return previous.isLocked
        ? NiconicoDanmakuProtocol.commentUnlockedNotice
        : NiconicoDanmakuProtocol.followersOnlyLiftedNotice;
  }

  @override
  bool operator ==(Object other) =>
      other is NiconicoCommentLock && other.isLocked == isLocked && other.followersOnly == followersOnly;

  @override
  int get hashCode => Object.hash(isLocked, followersOnly);

  @override
  String toString() => isLocked
      ? 'NiconicoCommentLock.locked'
      : followersOnly == null
      ? 'NiconicoCommentLock.none'
      : 'NiconicoCommentLock.followers(${followersOnly!.inSeconds} s)';
}

/// Reads the window messages of one connection, in order, into
/// [LiveMessage]s. It remembers who may comment, so that only changes of the
/// comment lock are reported, as the web player does; it starts from "everyone".
final class NiconicoMessageReader {
  /// Creates a reader.
  new();

  NiconicoCommentLock _commentLock = NiconicoCommentLock.none;
  bool _endedProgram = false;

  /// Who may comment, by the last comment lock read.
  NiconicoCommentLock get commentLock => _commentLock;

  /// Whether the last message read said that the program ended (`program_status`
  /// `Ended`).
  bool get endedProgram => _endedProgram;

  /// One window message (`ChunkedMessage`: 1 meta, then one of 2 message,
  /// 4 state, 5 signal) as a [LiveMessage], or null when it is none of the
  /// reported kinds. Throws [FormatException] when it is not protobuf.
  LiveMessage? read(List<int> bytes) {
    _endedProgram = false;
    final chunk = ProtoMessage.decode(bytes);
    final meta = chunk.message(1);
    return switch (NiconicoDanmakuProtocol._lastPayload(chunk)) {
      2 => NiconicoDanmakuProtocol._nicoliveMessage(chunk.message(2)!, meta),
      4 => _state(chunk.message(4)!, meta),
      _ => null,
    };
  }

  /// `NicoliveState`: the web player takes the first field it knows in its
  /// order: 5 comment_lock, 4 marquee, 9 program_status, 1 statistics. A field
  /// that is not protobuf counts as absent.
  LiveMessage? _state(ProtoMessage state, ProtoMessage? meta) {
    final lock = _readable(() => state.message(5));
    if (lock != null) {
      if (_readable(() => NiconicoDanmakuProtocol.commentLockOf(lock)) case final next?) {
        final notice = next.noticeFrom(_commentLock);
        _commentLock = next;
        if (notice != null) return NiconicoDanmakuProtocol._notice(notice, meta);
      }
    }
    final marquee = _readable(() => state.message(4));
    if (marquee != null) {
      if (_readable(() => NiconicoDanmakuProtocol._operatorComment(marquee, meta)) case final notice?) return notice;
    }
    if (_readable(() => state.message(9)?.integer(1)) == 1) {
      _endedProgram = true;
      return NiconicoDanmakuProtocol.programEnded(
        id: meta?.string(1)?.trim() ?? '',
        sentAt: NiconicoDanmakuProtocol.time(meta?.message(2)),
      );
    }
    // NicoliveState.statistics.viewers: the program's cumulative visitors.
    final viewers = _readable(() => state.message(1)?.integer(1));
    if (viewers == null || viewers < 0) return null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      data: LiveAudienceUpdate(watching: viewers),
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

/// Splits a varint-length-delimited protobuf stream (the comment server's
/// answers) into its messages as the bytes arrive.
final class NiconicoDelimitedReader {
  /// Creates a reader; a message over [maxLength] bytes is refused.
  new({this.maxLength = NiconicoDanmakuProtocol.maxMessageBytes});

  /// The largest message accepted.
  final int maxLength;

  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  /// Whether bytes of an unfinished message are waiting.
  bool get hasPending => _offset < _buffer.length;

  /// Adds [chunk] and returns the messages it completes, in order. Throws
  /// [FormatException] for a length prefix over ten bytes or a message over
  /// [maxLength]; the stream cannot be read further after that.
  List<Uint8List> add(List<int> chunk) {
    final rest = _buffer.length - _offset;
    final data = Uint8List(rest + chunk.length)
      ..setRange(0, rest, _buffer, _offset)
      ..setRange(rest, rest + chunk.length, chunk);
    final messages = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      var length = 0;
      var cursor = offset;
      var complete = false;
      for (var shift = 0; cursor < data.length; shift += 7) {
        if (shift >= 70) throw const FormatException('Length prefix longer than ten bytes');
        final byte = data[cursor++];
        length |= (byte & 0x7F) << shift;
        if (byte < 0x80) {
          complete = true;
          break;
        }
      }
      if (!complete) {
        if (cursor - offset >= 10) throw const FormatException('Length prefix longer than ten bytes');
        break;
      }
      if (length < 0 || length > maxLength) throw FormatException('Message of $length bytes');
      if (data.length - cursor < length) break;
      messages.add(Uint8List.sublistView(data, cursor, cursor + length));
      offset = cursor + length;
    }
    _buffer = data;
    _offset = offset;
    return messages;
  }

  /// Ends the stream: [FormatException] when a message was left unfinished.
  void close() {
    if (hasPending) throw const FormatException('Truncated message stream');
  }
}

/// niconico's comment server ("NDGR"), without I/O. The watching seat's
/// `messageServer` names its `view` address; every answer is a
/// varint-length-delimited protobuf stream (`dwango.nicolive.chat`):
///
/// - `view?at=now` answers at once with `next`; `view?at=<next>` streams the
///   history pointers (`backward`), the finished windows (`previous`), the
///   window under way (`segment`), then each next window as it is about to
///   start, and ends with `next`;
/// - a window's address streams its messages (`ChunkedMessage`) until it ends.
///
/// Chats (`chat`, `overflowed_chat`) become chat messages; `statistics.viewers`
/// (the program's cumulative visitors) an audience update; gifts, gift
/// messages; the operator's comments (`marquee`), changes of who may comment
/// (`comment_lock`) and the end of the program (`program_status`), system
/// notices. Ads, notifications, forwarded chats, other states and the signals
/// are not reported.
///
/// Archived from the reference and mapped onto this tree's models: a comment
/// colour is an int, a notice's `data` is the string `'system'`, the message id
/// field is `id`, a gift keeps only its name and one-item count with the point
/// as its price, and the cumulative visitor count is the room's `watching`.
abstract final class NiconicoDanmakuProtocol {
  /// The notice of the program's end (the web player's announcement).
  static const String programEndedNotice = 'この番組は終了しました';

  /// The notice while comments are locked (the web player's comment field).
  static const String commentLockedNotice = '現在コメントできません';

  /// The notice of a lock's lift (the web player only re-enables its field).
  static const String commentUnlockedNotice = '评论锁定已解除';

  /// The web player's line when comments are no longer for followers only.
  static const String followersOnlyLiftedNotice = 'フォロワー限定コメントが解除されました';

  /// The most seconds a follow restriction is read as (about 136 years).
  static const int maxFollowSeconds = 1 << 32;

  /// A follow restriction's duration of [seconds] as the web player writes it.
  static String followDuration(int seconds) {
    if (seconds >= 86400) {
      final days = '${seconds ~/ 86400}日';
      return seconds % 86400 < 3600 ? days : '$daysと${seconds % 86400 ~/ 3600}時間';
    }
    if (seconds < 3600) return '${seconds ~/ 60}分';
    final hours = '${seconds ~/ 3600}時間';
    return seconds % 3600 < 60 ? hours : '$hours${seconds % 3600 ~/ 60}分';
  }

  /// The web origin and the request headers the web player sends from it.
  static const String origin = 'https://live.nicovideo.jp';

  /// Request headers: a desktop UA, the site's referer and origin.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': '$origin/',
    'origin': origin,
  };

  /// How long the seat may take to name the comment server after its grant.
  static const Duration messageServerTimeout = Duration(seconds: 10);

  /// How often the seat is checked for the comment server meanwhile.
  static const Duration messageServerPoll = Duration(milliseconds: 100);

  /// Longest wait for the `view?at=now` answer, which comes at once.
  static const Duration firstViewTimeout = Duration(seconds: 10);

  /// Longest wait for the headers and between entries of a `view` answer.
  static const Duration viewTimeout = Duration(seconds: 60);

  /// Added to the time left of a window for the longest wait between its
  /// messages.
  static const Duration windowGrace = Duration(seconds: 20);

  /// The most time left a window is granted.
  static const Duration maxWindowLeft = Duration(seconds: 60);

  /// The longest wait for the headers and between the messages of a window
  /// ending at [until], asked at [now]: its time left (0–60 s) plus 20 s.
  static Duration windowTimeout(DateTime until, DateTime now) {
    final left = until.difference(now);
    return (left.isNegative ? Duration.zero : (left > maxWindowLeft ? maxWindowLeft : left)) + windowGrace;
  }

  /// Failures in a row that are retried; the next one ends the connection.
  static const int maxFailures = 8;

  /// The largest message accepted from the comment server.
  static const int maxMessageBytes = 1 << 20;

  /// Windows read at the same time at most (normally two or three).
  static const int maxOpenWindows = 8;

  /// Windows remembered as read, per seat.
  static const int rememberedWindows = 64;

  /// Wait after the [failures]-th failure in a row: 1, 2, 4, then 8 s.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// Whether [uri] may be requested as the comment server: https on
  /// `nicovideo.jp` or a subdomain, without credentials, port or fragment.
  static bool isCommentServer(Uri uri) =>
      uri.isScheme('https') &&
      (uri.host == 'nicovideo.jp' || uri.host.endsWith('.nicovideo.jp')) &&
      uri.userInfo.isEmpty &&
      !uri.hasPort &&
      !uri.hasFragment;

  /// The `view` request of [view] for [at] (`now` or a `next`).
  static Uri viewUrl(Uri view, String at) => view.replace(queryParameters: {...view.queryParameters, 'at': at});

  /// The messages of a streamed answer [body], as they complete. Fails
  /// ([FormatException]) on a bad length prefix or when the answer ends inside
  /// a message.
  static Stream<Uint8List> delimited(Stream<List<int>> body, {int maxLength = maxMessageBytes}) async* {
    final reader = NiconicoDelimitedReader(maxLength: maxLength);
    await for (final chunk in body) {
      for (final message in reader.add(chunk)) {
        yield message;
      }
    }
    reader.close();
  }

  /// The messages of a whole answer [bytes].
  static List<Uint8List> split(List<int> bytes, {int maxLength = maxMessageBytes}) {
    final reader = NiconicoDelimitedReader(maxLength: maxLength);
    final messages = reader.add(bytes);
    reader.close();
    return messages;
  }

  /// One `view` entry (`ChunkedEntry`: 1 segment, 2 backward, 3 previous,
  /// 4 next; the last one wins). Throws [FormatException] when it is not
  /// protobuf.
  static NiconicoViewEntry viewEntry(List<int> bytes) {
    final entry = ProtoMessage.decode(bytes);
    final kind = _lastMessage(entry, const {1, 2, 3, 4});
    return switch (kind) {
      1 => NiconicoViewEntry(NiconicoViewEntryKind.segment, window: _window(entry.message(1))),
      3 => NiconicoViewEntry(NiconicoViewEntryKind.previous, window: _window(entry.message(3))),
      2 => const NiconicoViewEntry(NiconicoViewEntryKind.backward),
      4 => NiconicoViewEntry(NiconicoViewEntryKind.next, next: _positive(entry.message(4)?.integer(1))),
      _ => const NiconicoViewEntry(NiconicoViewEntryKind.unknown),
    };
  }

  /// `MessageSegment`: 1 from, 2 until, 3 uri.
  static NiconicoCommentWindow? _window(ProtoMessage? segment) {
    final from = time(segment?.message(1));
    final until = time(segment?.message(2));
    final uri = Uri.tryParse(segment?.string(3)?.trim() ?? '');
    if (from == null || until == null || uri == null || !isCommentServer(uri)) return null;
    return NiconicoCommentWindow(from: from, until: until, uri: uri);
  }

  static int? _positive(int? value) => value != null && value > 0 ? value : null;

  /// The number of the last length-delimited field of [message] among
  /// [numbers] (a oneof: the last one wins), or null.
  static int? _lastMessage(ProtoMessage message, Set<int> numbers) {
    for (final field in message.fields.reversed) {
      if (field.wireType == ProtoMessage.lengthDelimitedType && numbers.contains(field.number)) return field.number;
    }
    return null;
  }

  /// The largest `Timestamp.seconds` a `DateTime` holds.
  static const int _maxSeconds = 8640000000000;

  /// A `google.protobuf.Timestamp` (1 seconds, 2 nanos) as a local `DateTime`;
  /// null without seconds, or out of range.
  static DateTime? time(ProtoMessage? timestamp) {
    final seconds = timestamp?.integer(1);
    final nanos = timestamp?.integer(2) ?? 0;
    if (seconds == null || seconds.abs() > _maxSeconds || nanos < 0 || nanos > 999999999) return null;
    return DateTime.fromMicrosecondsSinceEpoch(seconds * 1000000 + nanos ~/ 1000);
  }

  /// One window message (`ChunkedMessage`: 1 meta, then one of 2 message,
  /// 4 state, 5 signal) as a [LiveMessage], or null when it is none of the
  /// reported kinds. Throws [FormatException] when it is not protobuf.
  static LiveMessage? message(List<int> bytes) => NiconicoMessageReader().read(bytes);

  /// The payload of a `ChunkedMessage`: 2 or 4 (messages), 5 (a varint).
  static int? _lastPayload(ProtoMessage chunk) {
    for (final field in chunk.fields.reversed) {
      if (field.number == 5 && field.wireType == ProtoMessage.varintType) return 5;
      if ((field.number == 2 || field.number == 4) && field.wireType == ProtoMessage.lengthDelimitedType) {
        return field.number;
      }
    }
    return null;
  }

  /// A system notice of [text], with the window message's id and time.
  static LiveMessage _notice(String text, ProtoMessage? meta, {String userName = '', int? color}) => LiveMessage(
    type: LiveMessageType.notice,
    data: 'system',
    userName: userName,
    message: text,
    id: meta?.string(1)?.trim(),
    sentAt: time(meta?.message(2)),
    color: color ?? defaultColor,
  );

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  /// The notice that the program ended, with the platform's [id] and [sentAt].
  static LiveMessage programEnded({String id = '', DateTime? sentAt}) => LiveMessage(
    type: LiveMessageType.notice,
    data: 'system',
    userName: '',
    message: programEndedNotice,
    id: id.isEmpty ? null : id,
    sentAt: sentAt,
  );

  /// Who may comment by a `CommentLock` (1 status: 0 Unrestricted, 1 Locked,
  /// 2 Restricted; 2 follow_restriction {1 minimum_follow_duration {1
  /// seconds}}); null for an unknown status. A follow duration below zero is
  /// zero; over [maxFollowSeconds], that.
  static NiconicoCommentLock? commentLockOf(ProtoMessage lock) {
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

  /// `Marquee` (1 display {1 operator_comment}): the operator's comment
  /// (1 content, 2 name, 3 modifier) as a notice in its colour; null for a
  /// cleared marquee or an empty comment.
  static LiveMessage? _operatorComment(ProtoMessage marquee, ProtoMessage? meta) {
    final comment = marquee.message(1)?.message(1);
    final text = comment?.string(1)?.trim() ?? '';
    if (comment == null || text.isEmpty) return null;
    return _notice(text, meta, userName: comment.string(2)?.trim() ?? '', color: color(comment.message(3)));
  }

  /// `NicoliveMessage`: one field of its oneof; 1 chat and 20 overflowed_chat
  /// are chats, 8 gift a gift, the rest not reported.
  static LiveMessage? _nicoliveMessage(ProtoMessage data, ProtoMessage? meta) =>
      switch (_lastMessage(data, const {1, 7, 8, 9, 13, 17, 18, 19, 20, 22, 23, 24, 25, 26})) {
        final kind? when kind == 1 || kind == 20 => _chat(data.message(kind)!, meta),
        8 => _gift(data.message(8)!, meta),
        _ => null,
      };

  /// `Gift`: 1 item_id, 2 advertiser_user_id, 3 advertiser_name, 4 point,
  /// 5 message, 6 item_name, 7 contribution_rank. The text is `<name> ×1`. A
  /// gift of negative points or without an item is dropped. The point is kept
  /// as the gift price; the item id, giver rank and gift message have no field
  /// in this tree's [LiveGift].
  static LiveMessage? _gift(ProtoMessage gift, ProtoMessage? meta) {
    final itemId = gift.string(1)?.trim() ?? '';
    final name = gift.string(6)?.trim() ?? '';
    final point = gift.integer(4) ?? 0;
    if ((itemId.isEmpty && name.isEmpty) || point < 0) return null;
    final giver = gift.string(3)?.trim() ?? '';
    final giverId = gift.integer(2);
    final shown = name.isEmpty ? itemId : name;
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: giver,
      userId: giverId != null && giverId > 0 ? '$giverId' : '',
      message: '$shown ×1',
      id: meta?.string(1)?.trim(),
      sentAt: time(meta?.message(2)),
      data: LiveGift(name: shown, count: 1, unitPrice: point, totalValue: point),
      color: defaultColor,
    );
  }

  /// `Chat`: 1 content, 2 name, 5 raw_user_id, 6 hashed_user_id, 7 modifier;
  /// the id and time are the meta's (1 id, 2 at).
  static LiveMessage? _chat(ProtoMessage chat, ProtoMessage? meta) {
    final text = chat.string(1)?.trim() ?? '';
    if (text.isEmpty) return null;
    final hashed = chat.string(6)?.trim() ?? '';
    final raw = chat.integer(5);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: chat.string(2)?.trim() ?? '',
      userId: hashed.isNotEmpty ? hashed : (raw == null ? '' : '$raw'),
      message: text,
      id: meta?.string(1)?.trim(),
      sentAt: time(meta?.message(2)),
      color: color(chat.message(7)),
    );
  }

  /// The colours of `Chat.Modifier.ColorName`, by value (the ten basic and the
  /// ten premium names), as niconico's comment commands draw them.
  static const List<int> namedColors = [
    0xFFFFFF, // white
    0xFF0000, // red
    0xFF8080, // pink
    0xFFC000, // orange
    0xFFFF00, // yellow
    0x00FF00, // green
    0x00FFFF, // cyan
    0x0000FF, // blue
    0xC000FF, // purple
    0x000000, // black
    0xCCCC99, // white2 (niconicowhite)
    0xCC0033, // red2 (truered)
    0xFF33CC, // pink2
    0xFF6600, // orange2 (passionorange)
    0x999900, // yellow2 (madyellow)
    0x00CC66, // green2 (elementalgreen)
    0x00CCCC, // cyan2
    0x3399FF, // blue2 (marineblue)
    0x6633CC, // purple2 (nobleviolet)
    0x666666, // black2
  ];

  /// The colour of a `Chat.Modifier` (a oneof, the last one wins: 3
  /// named_color, 4 full_color {1 r, 2 g, 3 b}); white without one, or for an
  /// unknown name. Channels are clamped to 0–255.
  static int color(ProtoMessage? modifier) {
    if (modifier == null) return defaultColor;
    for (final field in modifier.fields.reversed) {
      if (field.number == 3 && field.wireType == ProtoMessage.varintType) {
        final value = field.value as int;
        return value >= 0 && value < namedColors.length ? namedColors[value] : defaultColor;
      }
      if (field.number == 4 && field.wireType == ProtoMessage.lengthDelimitedType) {
        final rgb = modifier.message(4)!;
        int channel(int number) => (rgb.integer(number) ?? 0).toSigned(32).clamp(0, 255);
        return (channel(1) << 16) | (channel(2) << 8) | channel(3);
      }
    }
    return defaultColor;
  }
}
