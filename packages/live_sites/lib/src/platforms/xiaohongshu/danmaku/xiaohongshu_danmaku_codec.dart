import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// Pure RWP framing for public Xiaohongshu live rooms (the reference's
/// `XiaohongshuDanmakuProtocol`), without I/O. No account messaging,
/// outgoing comments, reactions, purchases or private-message decoding.
abstract final class XiaohongshuDanmakuCodec {
  /// The website's live push endpoint.
  static final Uri endpoint = Uri.parse('wss://apppush-rws.xiaohongshu.com/rwp');

  /// Handshake headers: the site's origin and the initializing browser's own
  /// user agent (the identity's, so the push service sees the visitor it
  /// acknowledged).
  static Map<String, String> handshakeHeaders(XiaohongshuPushIdentity identity) => {
    'origin': 'https://www.xiaohongshu.com',
    'user-agent': identity.userAgent,
  };

  /// The transport-level heartbeat text frame.
  static const String transportHeartbeat = '{"v":1,"t":0}';

  /// Largest envelope accepted (1 MiB of JSON text); a larger one is dropped.
  static const int maxEnvelopeLength = 1024 * 1024;

  /// Largest room push batch accepted; a longer one is not read.
  static const int maxBatchLength = 256;

  /// Largest base64 payload of one batch item accepted.
  static const int maxItemLength = 128 * 1024;

  /// Longest chat text shown.
  static const int maxTextLength = 8192;

  /// Longest nickname shown.
  static const int maxNickLength = 512;

  /// Most chat ids remembered for dedup.
  static const int maxSeenMessages = 512;

  /// Largest time a `DateTime` can hold, in milliseconds.
  static const int maxMillis = 8640000000000000;

  /// A transport control frame: operation [operation] with [body], matched to
  /// its answer by [id].
  static String control(String id, int operation, Map<String, Object?> body) => jsonEncode({
    'v': 1,
    't': 2,
    'm': id,
    'b': {
      'd': {'a': 1, 's': operation, 'b': body},
    },
  });

  /// The same guest handshake the public website sends. The identity is
  /// obtained from an acknowledged, isolated visitor session at runtime.
  static String handshake(String id, XiaohongshuPushIdentity identity) => control(id, 0, {
    'appId': 'xhs-pc',
    'authInfo': {'authType': 'generic', 'sid': identity.sid, 'uid': identity.uid, 'domain': 'red'},
    'deviceInfo': {
      'deviceId': identity.deviceId,
      'fingerprint': identity.fingerprint,
      'platform': 'browser',
      'os': 'web',
      'osVersion': '10.15',
      'deviceName': 'Chrome',
      'appVersion': '131.0.0.0',
      'userAgent': identity.userAgent,
    },
    'serviceTag': '',
    'bizInfos': [
      {'bizName': 'push', 'serializeType': 'json'},
    ],
    'roomInfo': [],
    'roomInfos': [],
    'tagInfo': [],
    'extInfo': {},
    'state': 1,
  });

  /// Registers only the room JSON service.
  static String register(String id) => control(id, 1, {
    'bizInfo': {'bizName': 'room', 'serializeType': 'json'},
    'register': true,
  });

  /// Subscribes to exactly one broadcast.
  static String join(String id, String roomId) => control(id, 8, {
    'info': {'bizName': 'room', 'roomId': roomId, 'roomType': 'LIVE'},
  });

  /// A viewing heartbeat, carrying no chat content.
  static String viewerHeart(String id, String roomId, String uid) => jsonEncode({
    'v': 1,
    't': 3,
    'm': id,
    'b': {
      'd': {
        'a': 0,
        'c': 'liveHeartBeat',
        'biz': 'room',
        'b': base64Encode(
          utf8.encode(
            jsonEncode({
              'roomId': roomId,
              'roomType': 'LIVE',
              'command': 1,
              'customData': jsonEncode({
                'type': 'viewer_heart',
                'priority': 0,
                'profile': {'nickname': '', 'avatar': '', 'user_id': uid, 'role': 0},
                'source': 'web_live',
                'desc': '',
              }),
            }),
          ),
        ),
        'e': <String, Object?>{},
        's': 'rrmp.o.l',
      },
    },
  });

  /// A bounded JSON envelope, or null. Malformed frames never escape into
  /// the session's callback and never contain diagnostic raw text.
  static Map<Object?, Object?>? envelope(Object? data) {
    if (data is! String || data.length > maxEnvelopeLength) return null;
    try {
      final value = jsonDecode(data);
      return value is Map ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// The acknowledgement code of a control answer ([frame] `t` 2 whose `m`
  /// matched the sent id): `b.a.c` as a JSON integer, or null when the
  /// answer is not one.
  static int? ackCode(Map<Object?, Object?> frame) {
    if (frame['t'] != 2) return null;
    final body = frame['b'];
    final ack = body is Map ? body['a'] : null;
    if (ack is! Map || ack['c'] is! int) return null;
    return ack['c']! as int;
  }

  /// Reads only room pushes for [roomId]. One corrupt item cannot hide the
  /// next message in a batch. Names are exactly those the server supplies;
  /// masked names and missing names are never reconstructed. Chat becomes a
  /// chat line; a `refresh` becomes one audience update per count it names
  /// (member_count online, uv cumulative) — heat and praise are never
  /// relabelled as viewers.
  static List<LiveMessage> messages(Map<Object?, Object?> frame, String roomId) {
    if (frame['t'] != 4) return const [];
    final body = frame['b'];
    final data = body is Map && body['d'] is Map ? body['d']! as Map<Object?, Object?> : const <Object?, Object?>{};
    final batch = data['b'];
    if (data['biz'] != 'room' || batch is! List || batch.length > maxBatchLength) return const [];
    final out = <LiveMessage>[];
    for (final item in batch) {
      final wrapped = item is Map ? item : const <Object?, Object?>{};
      final encoded = wrapped['d'];
      if (encoded is! String || encoded.length > maxItemLength) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(base64Decode(encoded)));
      } on FormatException {
        continue;
      }
      if (decoded is! Map) continue;
      if (_text(decoded['roomId']) != roomId || decoded['roomType'] != 'LIVE') continue;
      final raw = decoded['customData'];
      final Object? customDecoded;
      if (raw is String) {
        try {
          customDecoded = jsonDecode(raw);
        } on FormatException {
          continue;
        }
      } else {
        customDecoded = raw;
      }
      final custom = customDecoded is Map ? customDecoded : const <Object?, Object?>{};
      final id = _text(decoded['msgId']).isNotEmpty ? _text(decoded['msgId']) : _text(custom['commentId']);
      if (custom['type'] == 'text') {
        final text = custom['desc'] is String ? custom['desc']! as String : '';
        if (text.trim().isEmpty || text.length > maxTextLength) continue;
        final profile = custom['profile'] is Map
            ? custom['profile']! as Map<Object?, Object?>
            : const <Object?, Object?>{};
        final nick = profile['nickname'] is String ? profile['nickname']! as String : '';
        if (nick.length > maxNickLength) continue;
        final millis = _count(decoded['ts']);
        out.add(
          LiveMessage.normalized(
            sender: MessageSender.normalized(userId: _text(profile['user_id']), userName: nick),
            text: text,
            color: LiveMessageColor.white,
            messageId: id,
            sentAt: millis == null || millis > maxMillis
                ? null
                : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
            sourceRoomId: roomId,
          ),
        );
      } else if (custom['type'] == 'refresh') {
        final room = custom['room_data'] is Map
            ? custom['room_data']! as Map<Object?, Object?>
            : const <Object?, Object?>{};
        for (final metric in [
          (room['member_count'], LiveAudienceSignalKind.onlineViewers),
          (room['uv'], LiveAudienceSignalKind.totalViewers),
        ]) {
          final count = _count(metric.$1);
          if (count == null) continue;
          out.add(
            LiveMessage.normalized(
              type: LiveMessageType.audienceUpdate,
              color: LiveMessageColor.white,
              sourceRoomId: roomId,
              payload: LiveAudienceUpdate.of(kind: metric.$2, value: count),
            ),
          );
        }
      }
    }
    return List.unmodifiable(out);
  }

  static String _text(Object? value) => value is String
      ? value
      : value is int
      ? '$value'
      : '';

  static int? _count(Object? value) {
    final n = value is int
        ? value
        : value is String
        ? int.tryParse(value)
        : null;
    return n != null && n >= 0 && n <= 9007199254740991 ? n : null;
  }
}
