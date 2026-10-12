import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What the Baidu Live chat needs to follow one broadcast: the message lists
/// the room command names. Each list is an HLS-style playlist on
/// [BaiduLiveDanmakuProtocol.messageListHost] whose segments are JSON message
/// batches: [chatList] carries chat, the online count and notices,
/// [reliableList] gifts and notices, [hostList] the host's. The playlist URLs
/// are signed (`bce-auth-v1`), room entry hands them over without a request,
/// and a later connection after they expired needs a new room command.
@immutable
final class BaiduLiveDanmakuArgs {
  /// A chat follow target.
  const new({
    required this.roomId,
    required this.chatList,
    this.reliableList,
    this.hostList,
    this.pullInterval = BaiduLiveDanmakuProtocol.defaultPullInterval,
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
  /// ([BaiduLiveDanmakuProtocol.defaultPullInterval] when missing).
  final Duration pullInterval;

  /// When the signature of [chatList] runs out, or null when it does not say.
  final DateTime? expiresAt;

  /// Whether [expiresAt] has passed at [now].
  bool isExpiredAt(DateTime now) => switch (expiresAt) {
    final DateTime expiry => !now.isBefore(expiry),
    null => false,
  };

  @override
  bool operator ==(Object other) =>
      other is BaiduLiveDanmakuArgs &&
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
  String toString() => 'BaiduLiveDanmakuArgs($roomId)';
}

/// One answer of a message list ([BaiduLiveDanmakuProtocol.playlist]).
@immutable
final class BaiduLivePlaylist {
  /// The playlist.
  new({required Iterable<Uri> segments, this.mediaSequence}) : segments = List.unmodifiable(segments);

  /// The segments, oldest first, resolved against the list's URL.
  final List<Uri> segments;

  /// `#EXT-X-MEDIA-SEQUENCE`, or null.
  final int? mediaSequence;
}

/// What one segment says ([BaiduLiveDanmakuProtocol.segment]).
@immutable
final class BaiduLiveSegment {
  /// The segment.
  new({Iterable<LiveMessage> messages = const [], this.ended = false}) : messages = List.unmodifiable(messages);

  /// The messages, in order.
  final List<LiveMessage> messages;

  /// Whether it holds the room's "broadcast stopped" notice (102).
  final bool ended;
}

/// Baidu Live's chat (the message-list protocol of the room page's
/// `handleMessage`), without I/O.
///
/// Read payload types are 0 (chat, the text by `message_type` as the page
/// reads it), 101 (the online count `data.onlineusercnt`), 102 (the broadcast
/// stopped) and 107 with `service_type` 10024 (a gift). Everything else (107's
/// other notices, likes, level-ups, cards, and 103, 104, 108) is not reported.
///
/// Archived from the reference and mapped onto this tree's models: the online
/// count is a [LiveAudienceUpdate.onlineViewers], a gift keeps only its name
/// and count (no `is_free`, picture or id here) and a chat colour is the white
/// default.
abstract final class BaiduLiveDanmakuProtocol {
  /// Limit of one request.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Tries of the first chat list request.
  static const int startAttempts = 3;

  /// Wait between the tries of the first chat list request.
  static const Duration startRetryDelay = Duration(seconds: 2);

  /// Failed chat list requests in a row that are retried; the next ends the
  /// connection.
  static const int maxFailures = 8;

  /// Polls a reliable or host list skips at most after failing.
  static const int maxSkippedPolls = 12;

  /// Tries of a segment that fails without an answer (or with 5xx).
  static const int segmentAttempts = 3;

  /// Segment keys remembered per list (a list shows three).
  static const int rememberedSegments = 256;

  /// The close detail of a broadcast that stopped (102).
  static const String endedDetail = 'Broadcast ended';

  /// The host every message list lives on.
  static const String messageListHost = 'liveshowstatic.baidu.com';

  /// The wait between two polls when the command gives none.
  static const Duration defaultPullInterval = Duration(seconds: 5);

  /// The website origin and the room page's URL.
  static const String webOrigin = 'https://live.baidu.com';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// The room page URL.
  static String roomUrl(String roomId) => '$webOrigin/m/room/$roomId';

  /// Request headers of room [roomId]: the website's (UA, Origin, the room
  /// page as Referer). The lists need none; the page sends them.
  static Map<String, String> headers(String roomId) => {
    'user-agent': _userAgent,
    'accept': 'application/json, text/plain, */*',
    'origin': webOrigin,
    'referer': roomUrl(roomId),
  };

  /// Wait after the [failures]-th failed chat list request in a row: 1, 2, 4,
  /// then 8 s.
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
  static BaiduLivePlaylist playlist(String text, Uri list) {
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
    return BaiduLivePlaylist(segments: segments, mediaSequence: sequence);
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
  static BaiduLiveSegment segment(List<int> bytes, {required String roomId}) {
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(Uint8List.fromList(inflate(bytes))));
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
            }
          case null:
            break;
        }
      }
    }
    return BaiduLiveSegment(messages: messages, ended: ended);
  }

  /// The online count as a message.
  static LiveMessage audience(int viewers) => LiveMessage(
    type: LiveMessageType.audienceUpdate,
    userName: '',
    message: '',
    data: LiveAudienceUpdate(onlineViewers: viewers),
  );

  /// A message and its payload: the page reads only `type` 0, whose `content`
  /// (JSON text or an object) holds `text` (JSON text or an object).
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
  /// reply's own words when `at_name` and the quoted words are given; trimmed,
  /// empty is dropped.
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
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _string(inner['name']).trim(),
      userId: _id(inner['uid']),
      message: text,
      id: _id(outer['msgid']),
      sentAt: _time(outer['create_time']),
      color: 0xFFFFFF,
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
  /// `gift_name`, `gift_count`). The text is `<name> ×<count>`; without a name
  /// there is no gift. This build keeps no `is_free`, picture or id.
  static LiveMessage? _gift(Map<String, Object?> outer, Map<String, Object?> inner, String roomId) {
    final data = _map(inner['data']);
    if (_id(data['service_type']) != '10024') return null;
    final service = _map(data['service_info']);
    if (!_forRoom(service['room_id'], roomId)) return null;
    final content = _map(_decoded(service['content']));
    final name = _string(content['gift_name']).trim();
    if (name.isEmpty) return null;
    final count = _int(content['gift_count']);
    final total = count != null && count > 0 ? count : 1;
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _string(service['user_name']).trim(),
      userId: _id(service['user_id']),
      message: '$name ×$total',
      id: _id(outer['msgid']),
      sentAt: _time(outer['create_time']),
      data: LiveGift(name: name, count: total),
    );
  }

  /// Whether a message's room id (missing, or naming [roomId]) is this room's.
  static bool _forRoom(Object? value, String roomId) {
    final id = _id(value);
    return id.isEmpty || id == roomId;
  }

  /// A message list of the room command: an http or https URL on
  /// [messageListHost] whose path ends in `.m3u8`; null otherwise. http
  /// becomes https, as the room page rewrites it to its own protocol; the
  /// signed query is kept as given.
  static Uri? messageList(Object? value) {
    final uri = Uri.tryParse(_string(value));
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    if (uri.host.toLowerCase() != messageListHost || uri.userInfo.isNotEmpty || uri.hasFragment) return null;
    if (!uri.path.endsWith('.m3u8')) return null;
    return uri.scheme == 'http' ? uri.replace(scheme: 'https') : uri;
  }

  /// When the signature of [list] runs out: its `authorization`
  /// (`bce-auth-v1/<key>/<UTC time>/<seconds>/<headers>/<signature>`) time
  /// plus its validity; null when the URL has no such signature.
  static DateTime? signatureExpiry(Uri list) {
    const name = 'authorization=';
    final field = list.query.split('&').where((f) => f.startsWith(name)).firstOrNull ?? '';
    // Recorded answers wrote the separators both plain and escaped.
    final parts = field
        .substring(field.isEmpty ? 0 : name.length)
        .replaceAll(RegExp('%2F', caseSensitive: false), '/')
        .replaceAll(RegExp('%3A', caseSensitive: false), ':')
        .split('/');
    if (parts.length < 4 || parts[0] != 'bce-auth-v1') return null;
    final time = parts[2];
    final signed = RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$').hasMatch(time) ? DateTime.tryParse(time) : null;
    final seconds = RegExp(r'^\d{1,10}$').hasMatch(parts[3]) ? int.parse(parts[3]) : null;
    // DateTime rolls a 13th month or a 45th day over; such a time is no time.
    if (signed == null || signed.toIso8601String().substring(0, 19) != time.substring(0, 19)) return null;
    return seconds == null || seconds == 0 ? null : signed.add(Duration(seconds: seconds));
  }

  /// The chat arguments of a live room command: the chat list
  /// (`chat_msg_hls_url`, else `video.msg_hls_url`), the reliable and host
  /// lists when valid ([messageList]), the poll interval
  /// (`msg_hls_pull_internal_in_second`, else the video's; 1–10 s) and when the
  /// chat list's signature runs out ([signatureExpiry]). Null without a valid
  /// chat list.
  static BaiduLiveDanmakuArgs? danmakuArgs(Map<String, Object?> command, String roomId) {
    final video = _map(command['video']);
    final chat = messageList(command['chat_msg_hls_url']) ?? messageList(video['msg_hls_url']);
    if (chat == null) return null;
    final seconds = _int(command['msg_hls_pull_internal_in_second'] ?? video['msg_hls_pull_internal_in_second']);
    return BaiduLiveDanmakuArgs(
      roomId: roomId,
      chatList: chat,
      reliableList: messageList(command['reliable_msg_hls_url']),
      hostList: messageList(command['host_msg_hls_url']),
      pullInterval: seconds != null && seconds > 0 ? Duration(seconds: seconds.clamp(1, 10)) : defaultPullInterval,
      expiresAt: signatureExpiry(chat),
    );
  }

  /// The largest time `DateTime` holds, in seconds either side of the epoch.
  static const int _maxSeconds = 8640000000000;

  /// `create_time` (Unix seconds, positive) in local time.
  static DateTime? _time(Object? value) {
    final seconds = _int(value);
    if (seconds == null || seconds <= 0 || seconds > _maxSeconds) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  /// A whole number: an integer, a whole finite double, or decimal digits (with
  /// a sign) as text; null otherwise (and beyond 64 bits).
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final double number when number.isFinite && number == number.truncateToDouble() && number.abs() < 9.2e18 =>
      number.toInt(),
    final String text when _digits.hasMatch(text.trim()) => int.tryParse(text.trim()),
    _ => null,
  };

  static final RegExp _digits = RegExp(r'^[+-]?\d+$');

  /// An id: text as it is (trimmed), a whole number as digits; empty otherwise.
  static String _id(Object? value) => switch (value) {
    final String text => text.trim(),
    final num number => '${_int(number) ?? ''}',
    _ => '',
  };

  static String _string(Object? value) => value is String ? value : '';

  static Map<String, Object?> _map(Object? value) => value is Map<String, Object?> ? value : const {};

  static List<Object?> _list(Object? value) => value is List<Object?> ? value : const [];
}
