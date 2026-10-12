import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What the douyin chat connection needs to join one broadcast.
@immutable
final class DouyinDanmakuArgs {
  /// Creates the arguments. [roomId] is this broadcast's numeric `room_id`
  /// (new every broadcast), [webRid] the room page id (the Referer), [userId]
  /// the 19-digit visitor id (`user_unique_id`). [cookie] is empty for an
  /// anonymous connect.
  const new({required this.webRid, required this.roomId, required this.userId, this.cookie = ''});

  /// The room page id, the handshake's Referer.
  final String webRid;

  /// This broadcast's `room_id`, the socket's `room_id` query.
  final String roomId;

  /// The visitor id (`user_unique_id`).
  final String userId;

  /// The request cookie, empty when anonymous.
  final String cookie;

  /// The handshake headers: UA, the cookie when there is one, Origin and the
  /// room's Referer.
  Map<String, String> get headers => {
    'user-agent': DouyinDanmakuProtocol.userAgent,
    if (cookie.trim().isNotEmpty) 'cookie': cookie,
    'origin': DouyinDanmakuProtocol.origin,
    'referer': '${DouyinDanmakuProtocol.origin}/$webRid',
  };
}

/// What one received Douyin frame asks for ([DouyinDanmakuProtocol.decode]):
/// the acknowledgement to send first, then the messages to report.
/// `envelopes` counts the messages the frame carried, of any method (a
/// heartbeat answer carries none).
typedef DouyinDanmakuFrame = ({Uint8List? ack, List<LiveMessage> messages, int envelopes});

/// Douyin's chat protocol (the codec of the reference `DouyinDanmaku`),
/// without I/O.
///
/// Both directions are protobuf `PushFrame`s (`logId 2, headersList 5,
/// payloadEncoding 6, payloadType 7, payload 8`). A server frame's payload,
/// gunzipped when its encoding says `gzip` or it starts with `1f 8b`, is a
/// `Response` (`messagesList 1, internalExt 5, needAck 9`) whose `Message`s
/// (`method 1, payload 2, msgId 3`) carry `WebcastChatMessage` and
/// `WebcastRoomUserSeqMessage` among many others.
///
/// Archived from the reference and mapped onto this tree's models: the
/// audience count is a [LiveAudienceUpdate], a colour is the int white, and a
/// message id is namespaced `douyin:`; gifts and other methods are not read.
abstract final class DouyinDanmakuProtocol {
  /// The two web IM edges, tried in this order.
  static const List<String> hosts = ['webcast100-ws-web-lq.douyin.com', 'webcast100-ws-web-hl.douyin.com'];

  /// Path of the push socket.
  static const String path = '/webcast/im/push/v2/';

  /// The site origin of the handshake.
  static const String origin = 'https://live.douyin.com';

  /// Desktop Chrome 134, the UA the handshake sends.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/134.0.0.0 Safari/537.36';

  /// Douyin's web app id.
  static const String aid = '6383';

  /// `version_code` of the connection.
  static const String versionCode = '180800';

  /// `webcast_sdk_version` of the connection.
  static const String sdkVersion = '1.0.15';

  /// Heartbeat period.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// Silence after which the socket is replaced.
  static const Duration inactivityTimeout = Duration(seconds: 45);

  static const int _maxEpochMilliseconds = 8640000000000000;

  /// The endpoints of [args]'s broadcast: every host with the same query. The
  /// cursor carries [now]; the [signature] (from `DouyinSign`) is a query value,
  /// so its `+` and `/` are percent-encoded.
  static List<Uri> endpoints(DouyinDanmakuArgs args, {required String signature, required DateTime now}) {
    final query = {
      'app_name': 'douyin_web',
      'version_code': versionCode,
      'webcast_sdk_version': sdkVersion,
      'update_version_code': sdkVersion,
      'compress': 'gzip',
      'cursor': 'h-1_t-${now.millisecondsSinceEpoch}_r-1_d-1_u-1',
      'host': origin,
      'aid': aid,
      'live_id': '1',
      'did_rule': '3',
      'debug': 'false',
      'maxCacheMessageNumber': '20',
      'endpoint': 'live_pc',
      'support_wrds': '1',
      'im_path': '/webcast/im/fetch/',
      'user_unique_id': args.userId,
      'device_platform': 'web',
      'cookie_enabled': 'true',
      'screen_width': '1920',
      'screen_height': '1080',
      'browser_language': 'zh-CN',
      'browser_platform': 'Win32',
      'browser_name': 'Mozilla',
      'browser_version': userAgent.substring('Mozilla/'.length),
      'browser_online': 'true',
      'tz_name': 'Asia/Shanghai',
      'identity': 'audience',
      'room_id': args.roomId,
      'need_persist_msg_count': '15',
      'heartbeatDuration': '0',
      'signature': signature,
    };
    return [for (final host in hosts) Uri(scheme: 'wss', host: host, path: path, queryParameters: query)];
  }

  /// The heartbeat frame, also sent once the socket opens: `PushFrame{payloadType: "hb"}`.
  static Uint8List heartbeat() => (ProtoWriter()..string(7, 'hb')).toBytes();

  /// The acknowledgement of the frame [logId]: `PushFrame{logId, payloadType:
  /// "ack", payload: internalExt}`, every field written even when empty.
  static Uint8List ack(int logId, String internalExt) =>
      (ProtoWriter()
            ..integer(2, logId)
            ..string(7, 'ack')
            ..string(8, internalExt))
          .toBytes();

  /// Decodes one server [frame] for broadcast [roomId]. The frame, its payload
  /// and its `Response` are read as generated classes read them: when any part
  /// of them is unreadable, the frame yields nothing, not even the ack.
  /// Otherwise the ack comes when `needAck` asks for it, and each chat or
  /// audience message is decoded on its own (an unreadable one is lost).
  static DouyinDanmakuFrame decode(List<int> frame, {required String roomId}) {
    final ProtoMessage push;
    final ProtoMessage response;
    final List<ProtoMessage> envelopes;
    try {
      // The headers are read (and must be readable), then ignored.
      push = (ProtoMessage.decode(frame))..messages(5);
      final payload = push.bytes(8) ?? Uint8List(0);
      final gzipped =
          (push.string(6) ?? '').toLowerCase() == 'gzip' ||
          (payload.length >= 2 && payload[0] == 0x1F && payload[1] == 0x8B);
      response = ProtoMessage.decode(gzipped ? gzip.decode(payload) : payload);
      envelopes = response.messages(1);
      response.messages(7);
    } on FormatException {
      return (ack: null, messages: const [], envelopes: 0);
    }
    final messages = <LiveMessage>[];
    for (final envelope in envelopes) {
      try {
        final payload = envelope.bytes(2) ?? Uint8List(0);
        final message = switch (envelope.string(1)) {
          'WebcastChatMessage' => _chat(payload, envelope.integer(3) ?? 0, roomId),
          'WebcastRoomUserSeqMessage' => _online(payload),
          _ => null,
        };
        if (message != null) messages.add(message);
      } on FormatException {
        continue;
      }
    }
    return (
      ack: response.flag(9) ? ack(push.integer(2) ?? 0, response.string(5) ?? '') : null,
      messages: messages,
      envelopes: envelopes.length,
    );
  }

  /// `ChatMessage{common 1, user 2, content 3, eventTime 15}`, `Common{msgId 2,
  /// roomId 3, createTime 4}`, `User{id 1, nickName 3}`: another broadcast's chat
  /// is dropped (a room id of 0 or none is kept); the id is `common.msgId`, else
  /// the envelope's `msgId`. The time is `createTime`, else `eventTime`; above
  /// 10^11 is milliseconds, otherwise seconds, and 0 means none.
  static LiveMessage? _chat(Uint8List payload, int envelopeId, String roomId) {
    final chat = ProtoMessage.decode(payload);
    final common = chat.message(1);
    final user = chat.message(2);
    final chatRoomId = common == null ? '' : ProtoMessage.unsigned(common.integer(3) ?? 0);
    if (chatRoomId.isNotEmpty && chatRoomId != '0' && chatRoomId != roomId) return null;
    final commonId = common == null ? '' : ProtoMessage.unsigned(common.integer(2) ?? 0);
    final messageId = commonId.isNotEmpty && commonId != '0' ? commonId : (envelopeId == 0 ? '' : '$envelopeId');
    final createTime = common?.integer(4) ?? 0;
    final eventTime = chat.integer(15) ?? 0;
    DateTime? sentAt;
    if (createTime > 0) {
      final milliseconds = _milliseconds(createTime);
      if (milliseconds > _maxEpochMilliseconds) throw FormatException('douyin chat time out of range: $createTime');
      sentAt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } else if (eventTime > 0 && _milliseconds(eventTime) <= _maxEpochMilliseconds) {
      sentAt = DateTime.fromMillisecondsSinceEpoch(_milliseconds(eventTime));
    }
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: user?.string(3) ?? '',
      userId: ProtoMessage.unsigned(user?.integer(1) ?? 0),
      message: chat.string(3) ?? '',
      color: white,
      id: messageId.isEmpty ? null : 'douyin:$messageId',
      sentAt: sentAt,
    );
  }

  /// `RoomUserSeqMessage`: the concurrent audience is `total` (3), the exact
  /// number the display text rounds; without it, `onlineUserForAnchor` (10) when
  /// it has a digit.
  static LiveMessage? _online(Uint8List payload) {
    final message = ProtoMessage.decode(payload);
    final total = message.integer(3) ?? 0;
    final int value;
    if (total > 0) {
      value = total;
    } else {
      final text = message.string(10) ?? '';
      if (!text.contains(RegExp('[0-9]'))) return null;
      value = _audienceNumber(text);
    }
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      data: LiveAudienceUpdate(onlineViewers: value),
    );
  }

  /// A platform time: above 10^11 milliseconds, otherwise seconds.
  static int _milliseconds(int time) => time > 100000000000 ? time : time * 1000;

  /// A display audience text (`30.6万`) as a count.
  static int _audienceNumber(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return 0;
    final normalized = text.replaceAll(',', '').replaceAll('，', '');
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?').firstMatch(normalized);
    final number = double.tryParse(match?.group(1) ?? '') ?? 0;
    final multiplier = switch (match?.group(2)) {
      '亿' => 100000000,
      '万' || 'w' => 10000,
      '千' || 'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }

  /// White, the danmaku default.
  static const int white = 0xFFFFFF;
}
