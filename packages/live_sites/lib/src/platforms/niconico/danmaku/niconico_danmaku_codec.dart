import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_protobuf.dart';

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

/// niconico's comment server ("NDGR"), without I/O. The watching seat's
/// `messageServer.viewUri` names its `view` address; every answer is a
/// varint-length-delimited protobuf stream (`ChunkedEntry` for `view`,
/// `ChunkedMessage` for a window). Chats (`chat` field 1 and `overflowed_chat`
/// field 20) become [LiveMessage]s; the rest is not reported here.
abstract final class NiconicoDanmakuCodec {
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

  /// The messages of a whole answer [bytes], split at their varint length
  /// prefixes.
  static List<List<int>> split(List<int> bytes) => niconicoSplitDelimited(bytes);

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

  /// One window message (`ChunkedMessage`: 1 meta, then one of 2 message, 4
  /// state, 5 signal) as a [LiveMessage], or null when it is not a chat.
  /// Throws [FormatException] when it is not protobuf.
  static LiveMessage? message(List<int> bytes) {
    final chunk = NiconicoProtoMessage.decode(bytes);
    final meta = chunk.message(1);
    return switch (_lastOf(chunk, const {2, 4})) {
      2 => _nicoliveMessage(chunk.message(2)!, meta),
      _ => null,
    };
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

  // Helpers -------------------------------------------------------------------

  /// `NicoliveMessage`: its oneof's chat fields (1 chat, 20 overflowed_chat)
  /// become a chat; the rest is not reported.
  static LiveMessage? _nicoliveMessage(NiconicoProtoMessage data, NiconicoProtoMessage? meta) =>
      switch (data.lastOf(const {1, 20})) {
        final kind? => chat(data.message(kind)!, meta: meta),
        _ => null,
      };

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
