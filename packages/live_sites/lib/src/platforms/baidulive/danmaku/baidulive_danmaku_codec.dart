import 'dart:convert';
import 'dart:io' show gzip;

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What the danmaku connection (M5.26, 30-3) needs of a live broadcast: the
/// message lists the room command 371 names.
///
/// Each list is an HLS-style playlist on
/// [BaiduliveEndpoints.messageListHost] whose segments are JSON message
/// batches: [chatList] carries chat, the online count and notices,
/// [reliableList] gifts and notices, [hostList] (404 when recorded) the
/// host's. The playlist URLs are signed (a `bce-auth-v1` authorization,
/// recorded valid 182.5 days, [expiresAt]); room entry hands them over
/// without a request, and a later connection after they expired needs a new
/// room command (the room detail).
@immutable
final class BaiduliveDanmakuArgs {
  /// Creates the arguments.
  const BaiduliveDanmakuArgs({
    required this.roomId,
    required this.chatList,
    this.reliableList,
    this.hostList,
    this.pullInterval = BaiduliveEndpoints.defaultPullInterval,
    this.expiresAt,
  });

  /// The room (one broadcast); messages naming another room are dropped.
  final String roomId;

  /// `chat_msg_hls_url` (else `video.msg_hls_url`, the same list).
  final Uri chatList;

  /// `reliable_msg_hls_url`, when given.
  final Uri? reliableList;

  /// `host_msg_hls_url`, when given.
  final Uri? hostList;

  /// `msg_hls_pull_internal_in_second`: the wait between two polls, 1–10 s
  /// ([BaiduliveEndpoints.defaultPullInterval] when missing).
  final Duration pullInterval;

  /// When the signature of [chatList] runs out (its `bce-auth-v1` time plus
  /// validity), or null when it does not say.
  final DateTime? expiresAt;

  /// Whether [expiresAt] has passed at [now].
  bool isExpiredAt(DateTime now) => switch (expiresAt) {
    final DateTime expiry => !now.isBefore(expiry),
    null => false,
  };

  @override
  bool operator ==(Object other) =>
      other is BaiduliveDanmakuArgs &&
      other.roomId == roomId &&
      other.chatList == chatList &&
      other.reliableList == reliableList &&
      other.hostList == hostList &&
      other.pullInterval == pullInterval &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(roomId, chatList, reliableList, hostList, pullInterval, expiresAt);

  /// The room only: the list URLs carry signatures.
  @override
  String toString() => 'BaiduliveDanmakuArgs($roomId)';
}

/// One answer of a message list ([BaiduliveDanmakuProtocol.playlist]).
final class BaidulivePlaylist {
  /// Creates the playlist.
  BaidulivePlaylist({required Iterable<Uri> segments, this.mediaSequence}) : segments = List.unmodifiable(segments);

  /// The segments, oldest first, resolved against the list's URL.
  final List<Uri> segments;

  /// `#EXT-X-MEDIA-SEQUENCE`, or null. Always 0 when recorded, so segments
  /// are told apart by [BaiduliveDanmakuProtocol.segmentKey] instead.
  final int? mediaSequence;
}

/// What one segment says ([BaiduliveDanmakuProtocol.segment]).
final class BaiduliveSegment {
  /// Creates the segment.
  BaiduliveSegment({Iterable<LiveMessage> messages = const [], this.ended = false})
    : messages = List.unmodifiable(messages);

  /// The messages, in order.
  final List<LiveMessage> messages;

  /// Whether it holds the room's "broadcast stopped" notice (102).
  final bool ended;
}

/// Baidu Live's chat (docs/D-弹幕/D01-平台弹幕协议/D01.27-百度直播弹幕/record.md),
/// without I/O.
///
/// The room command 371 names three message lists ([BaiduliveDanmakuArgs]):
/// HLS-style playlists on `liveshowstatic.baidu.com` that keep the last few
/// segments, each a JSON batch `{list: [{messages: [...]}]}`, gzipped (with
/// or without `Content-Encoding`). A message whose `type` is 0 holds its
/// payload in `content`, a JSON text whose `text` is JSON again (the web
/// page's `handleMessage`, pchome.live.fcb2dc0e.js). Read are the payload
/// types:
/// - 0, chat: the text by `message_type` as the page's `addChatItem` reads
///   it;
/// - 101, the online count `data.onlineusercnt` (the room command's
///   `online_users`);
/// - 102, the broadcast stopped (the page's `stopLive`);
/// - 107 with `service_type` 10024, a gift.
///
/// Everything else (107's other notices: `mix_room_close` names other rooms
/// of the recommendation mix that closed, likes, level-ups, pinned comments,
/// cards; 103, 104, 108) is not reported.
abstract final class BaiduliveDanmakuProtocol {
  /// Limit of one request.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Tries of the first chat list request.
  static const int startAttempts = 3;

  /// Wait between the tries of the first chat list request.
  static const Duration startRetryDelay = Duration(seconds: 2);

  /// Failed chat list requests in a row that are retried; the next one ends
  /// the connection.
  static const int maxFailures = 8;

  /// Polls a reliable or host list skips at most after failing.
  static const int maxSkippedPolls = 12;

  /// Tries of a segment that fails without an answer (or with 5xx).
  static const int segmentAttempts = 3;

  /// Segment keys remembered per list (a list shows three).
  static const int rememberedSegments = 256;

  /// The close detail of a broadcast that stopped (102).
  static const String endedDetail = 'Broadcast ended';

  /// Request headers of room [roomId]: the website's (UA, Origin, the room
  /// page as Referer). The lists need none; the page sends them.
  static Map<String, String> headers(String roomId) => {
    'user-agent': BaiduliveEndpoints.userAgent,
    'accept': 'application/json, text/plain, */*',
    'origin': BaiduliveEndpoints.webOrigin,
    'referer': BaiduliveEndpoints.roomUrl(roomId),
  };

  /// Wait after the [failures]-th failed chat list request in a row: 1, 2,
  /// 4, then 8 s.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// Polls a reliable or host list skips after its [failures]-th failure in a
  /// row: 1, 2, 4, 8, then 12.
  static int skippedPolls(int failures) => (1 << (failures - 1).clamp(0, 4)).clamp(1, maxSkippedPolls);

  /// The key a segment is told apart by: its path (the name holds the list's
  /// id and a nanosecond time; the query is its signature).
  static String segmentKey(Uri segment) => segment.path;

  /// A playlist answered from [list]: `#EXTM3U` first, then every line that
  /// is neither empty nor a tag is a segment, resolved against [list]; one on
  /// another host or scheme is skipped. Throws [FormatException] when the text
  /// is not a playlist.
  static BaidulivePlaylist playlist(String text, Uri list) {
    final lines = const LineSplitter().convert(text).map((line) => line.trim()).where((line) => line.isNotEmpty);
    if (lines.firstOrNull != '#EXTM3U') throw const FormatException('Baidu Live message list is not a playlist');
    int? sequence;
    final segments = <Uri>[];
    for (final line in lines) {
      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        sequence = _int(line.substring('#EXT-X-MEDIA-SEQUENCE:'.length));
      }
      if (line.startsWith('#')) continue;
      final Uri segment;
      try {
        segment = list.resolve(line);
      } on FormatException {
        continue;
      }
      if (segment.scheme == list.scheme && segment.host == list.host && segment.userInfo.isEmpty) {
        segments.add(segment);
      }
    }
    return BaidulivePlaylist(segments: segments, mediaSequence: sequence);
  }

  /// [bytes] inflated while they start with the gzip magic (at most twice):
  /// segments are gzipped, sometimes without `Content-Encoding` (then the
  /// transport leaves them as they are). Throws [FormatException] on a broken
  /// gzip stream.
  static List<int> inflate(List<int> bytes) {
    var body = bytes;
    for (var depth = 0; depth < 2 && body.length >= 2 && body[0] == 0x1f && body[1] == 0x8b; depth++) {
      body = gzip.decode(body);
    }
    return body;
  }

  /// The messages of one segment (its body as served) for room [roomId], in
  /// order. Throws [FormatException] when it is not a JSON object; a message
  /// that cannot be read is skipped.
  static BaiduliveSegment segment(List<int> bytes, {required String roomId}) {
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(inflate(bytes)));
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Baidu Live segment: $error');
    }
    if (root is! Map<String, Object?>) throw const FormatException('Baidu Live segment is not an object');
    final messages = <LiveMessage>[];
    var ended = false;
    for (final item in _list(root['list'])) {
      for (final message in _list(_map(item)['messages'])) {
        switch (_payload(message)) {
          case (final Map<String, Object?> outer, final Map<String, Object?> inner):
            switch (_int(inner['type'])) {
              case 0:
                if (_chat(outer, inner, roomId) case final chat?) messages.add(chat);
              case 101:
                if (_online(inner, roomId) case final online?) messages.add(online);
              case 102:
                if (_forRoom(inner['room_id'] ?? _map(inner['data'])['room_id'], roomId)) ended = true;
              case 107:
                if (_gift(outer, inner, roomId) case final gift?) messages.add(gift);
              default:
                break;
            }
          case null:
            break;
        }
      }
    }
    return BaiduliveSegment(messages: messages, ended: ended);
  }

  /// The online count as a message.
  static LiveMessage audience(int viewers) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    color: LiveMessageColor.white,
    payload: LiveAudienceUpdate.of(kind: LiveAudienceSignalKind.onlineViewers, value: viewers),
  );

  /// A message and its payload: the page reads only `type` 0, whose
  /// `content` (JSON text or an object) holds `text` (JSON text or an
  /// object).
  static (Map<String, Object?>, Map<String, Object?>)? _payload(Object? message) {
    final outer = _map(message);
    if (_int(outer['type']) != 0) return null;
    final text = _map(_decoded(outer['content']))['text'];
    final inner = _decoded(text);
    return inner is Map<String, Object?> ? (outer, inner) : null;
  }

  static Object? _decoded(Object? value) {
    if (value is! String) return value;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  /// A chat line (the page's `addChatItem`): the text by `message_type`
  /// ("0" `content`, else `message_body.txt.word`; "3" the link's title; "1",
  /// "2", "4" images and cards and "5" voice have none; others `content`), a
  /// reply's own words (`message_body.txt.word` when `at_name` and the quoted
  /// words are given); trimmed, empty is dropped.
  static LiveMessage? _chat(Map<String, Object?> outer, Map<String, Object?> inner, String roomId) {
    if (!_forRoom(inner['room_id'], roomId)) return null;
    final body = _map(inner['message_body']);
    final words = _string(_map(body['txt'])['word']);
    final content = _string(inner['content']);
    var text = switch (_id(inner['message_type'])) {
      '0' => content.isNotEmpty ? content : words,
      '1' || '2' || '4' || '5' => '',
      '3' => _string(_map(body['link'])['title']),
      _ => content,
    };
    final quoted = _string(_map(_map(inner['at_message_body'])['txt'])['word']);
    if (_string(inner['at_name']).isNotEmpty && _int(inner['at_message_type']) == 0 && quoted.isNotEmpty) {
      if (words.isNotEmpty) text = words;
    }
    text = text.trim();
    if (text.isEmpty) return null;
    return LiveMessage.normalized(
      text: text,
      sender: MessageSender.normalized(userId: _id(inner['uid']), userName: _string(inner['name']).trim()),
      messageId: _id(outer['msgid']),
      sentAt: _time(outer['create_time']),
      color: LiveMessageColor.white,
    );
  }

  /// The online count of a 101 (`data.onlineusercnt`, a whole number of zero
  /// or more).
  static LiveMessage? _online(Map<String, Object?> inner, String roomId) {
    if (!_forRoom(inner['room_id'], roomId)) return null;
    final count = _int(_map(inner['data'])['onlineusercnt']);
    return count != null && count >= 0 ? audience(count) : null;
  }

  /// A gift of a 107/10024: `service_info` names the sender (`user_name`,
  /// `user_id`) and holds the gift in `content` (JSON text or an object:
  /// `gift_name`, `gift_count`, `gift_id`, `is_free`, `gift_url`). The text
  /// is `<name> ×<count>`; without a name there is no gift. The unit of
  /// `total_value` is not known, so a gift carries no price: a free one
  /// [LiveGiftUnit.free], a paid one [LiveGiftUnit.other] without a number.
  static LiveMessage? _gift(Map<String, Object?> outer, Map<String, Object?> inner, String roomId) {
    final data = _map(inner['data']);
    if (_id(data['service_type']) != '10024') return null;
    final service = _map(data['service_info']);
    if (!_forRoom(service['room_id'], roomId)) return null;
    final content = _map(_decoded(service['content']));
    final name = _string(content['gift_name']).trim();
    if (name.isEmpty) return null;
    final count = _int(content['gift_count']);
    final icon = Uri.tryParse(_string(content['gift_url']).trim());
    final free = _int(content['is_free']) == 1;
    final gift = LiveGift(
      giftId: _id(content['gift_id']),
      name: name,
      iconUrl: icon != null && icon.scheme == 'https' && icon.host.isNotEmpty ? '$icon' : null,
      count: count != null && count > 0 ? count : 1,
      value: LiveGiftValue(unit: free ? LiveGiftUnit.free : LiveGiftUnit.other),
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${gift.name} ×${gift.count}',
      sender: MessageSender.normalized(userId: _id(service['user_id']), userName: _string(service['user_name']).trim()),
      messageId: _id(outer['msgid']),
      sentAt: _time(outer['create_time']),
      color: LiveMessageColor.white,
      payload: gift,
    );
  }

  /// Whether a message's room id (missing, or naming [roomId]) is this room's.
  static bool _forRoom(Object? value, String roomId) {
    final id = _id(value);
    return id.isEmpty || id == roomId;
  }

  /// The largest time `DateTime` holds, in seconds either side of the epoch.
  static const int _maxSeconds = 8640000000000;

  /// `create_time` (Unix seconds, positive) in local time.
  static DateTime? _time(Object? value) {
    final seconds = _int(value);
    if (seconds == null || seconds <= 0 || seconds > _maxSeconds) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  /// A whole number: an integer, a whole finite double, or decimal digits
  /// (with a sign) as text; null otherwise (and beyond 64 bits).
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final double number when number.isFinite && number == number.truncateToDouble() && number.abs() < 9.2e18 =>
      number.toInt(),
    final String text when _digits.hasMatch(text.trim()) => int.tryParse(text.trim()),
    _ => null,
  };

  static final RegExp _digits = RegExp(r'^[+-]?\d+$');

  /// An id: text as it is (trimmed), a whole number as digits; empty
  /// otherwise.
  static String _id(Object? value) => switch (value) {
    final String text => text.trim(),
    final num number => '${_int(number) ?? ''}',
    _ => '',
  };

  static String _string(Object? value) => value is String ? value : '';

  static Map<String, Object?> _map(Object? value) => value is Map<String, Object?> ? value : const {};

  static List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];
}
