import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/douyin/api/douyin_endpoints.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_protobuf.dart';

/// What one received Douyin frame asks for: the acknowledgement to send
/// first, then the messages to report. `envelopes` counts the messages the
/// frame carried, of any method (a heartbeat answer carries none); `errors`
/// are the parts that could not be read — an unreadable frame has no ack and
/// no messages, an unreadable message only loses itself.
typedef DouyinDanmakuFrame = ({
  Uint8List? ack,
  List<LiveMessage> messages,
  int envelopes,
  List<FormatException> errors,
});

/// Douyin's danmaku protocol, without I/O.
///
/// Both directions are protobuf `PushFrame`s (`seqId 1, logId 2, service 3,
/// method 4, headersList 5, payloadEncoding 6, payloadType 7, payload 8`). A
/// server frame's payload, gunzipped when its encoding says `gzip` or it
/// starts with `1f 8b`, is a `Response` (`messagesList 1, internalExt 5,
/// needAck 9`) whose messages (`method 1, payload 2, msgId 3`) carry
/// `WebcastChatMessage` and `WebcastRoomUserSeqMessage` among many others;
/// gifts, emoji and moderation envelopes are not read.
abstract final class DouyinDanmakuProtocol {
  /// The two web IM edges, tried in this order.
  static const List<String> hosts = DouyinEndpoints.danmakuHosts;

  /// Path of the push socket.
  static const String path = DouyinEndpoints.danmakuPath;

  /// Heartbeat period (10 000 ms), also the join sent once the socket opens.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// Silence after which the socket is replaced.
  static const Duration inactivityTimeout = Duration(seconds: 45);

  /// Reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  /// How long the base backoff of a reconnect is (it grows from there).
  static const Duration reconnectBase = Duration(seconds: 1);

  /// The longest representable platform time in milliseconds.
  static const int _maxEpochMilliseconds = 8640000000000000;

  /// The endpoints of one broadcast: every host with the same query. The
  /// cursor carries [now]; the [signature] is a query value, so its `+` and
  /// `/` are percent-encoded.
  static List<Uri> endpoints({
    required String roomId,
    required String userId,
    required String signature,
    required DateTime now,
  }) => [
    for (final host in hosts)
      DouyinEndpoints.danmakuPush(
        host,
        roomId: roomId,
        userId: userId,
        signature: signature,
        cursor: now.millisecondsSinceEpoch,
      ),
  ];

  /// The handshake headers of a connection: UA, the cookie when there is
  /// one, Origin and the room's Referer.
  static Map<String, String> handshakeHeaders(String cookie, String webRid) => {
    'user-agent': DouyinEndpoints.userAgent,
    if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
    'origin': DouyinEndpoints.origin,
    'referer': '${DouyinEndpoints.origin}/${Uri.encodeComponent(webRid)}',
  };

  /// The heartbeat frame, also sent once the socket opens: `PushFrame` with
  /// only `payloadType: "hb"`.
  static Uint8List heartbeat() => (DouyinProtoWriter()..string(7, 'hb')).toBytes();

  /// The acknowledgement of the frame [logId]: `PushFrame{logId, payloadType:
  /// "ack", payload: internalExt}`, every field written even when empty.
  static Uint8List ack(int logId, String internalExt) =>
      (DouyinProtoWriter()
            ..integer(2, logId)
            ..string(7, 'ack')
            ..string(8, internalExt))
          .toBytes();

  /// Decodes one server [frame] of the broadcast [roomId].
  ///
  /// The frame, its payload and its `Response` are read as a generated
  /// protobuf class reads them: when any part of them is unreadable (headers
  /// and message envelopes included) the frame yields nothing, not even the
  /// acknowledgement. Otherwise the acknowledgement comes when `needAck` asks
  /// for it, and each chat or audience message is decoded on its own.
  static DouyinDanmakuFrame decode(List<int> frame, {required String roomId}) {
    final DouyinProtoMessage push;
    final DouyinProtoMessage response;
    final List<DouyinProtoMessage> envelopes;
    try {
      // The headers are read (and must be readable), then ignored.
      push = DouyinProtoMessage.decode(frame)..messages(5);
      final payload = push.bytes(8) ?? Uint8List(0);
      final gzipped =
          (push.string(6) ?? '').toLowerCase() == 'gzip' ||
          (payload.length >= 2 && payload[0] == 0x1F && payload[1] == 0x8B);
      response = DouyinProtoMessage.decode(gzipped ? gzip.decode(payload) : payload);
      envelopes = response.messages(1);
      response.messages(7);
    } on FormatException catch (error) {
      return (ack: null, messages: const <LiveMessage>[], envelopes: 0, errors: [error]);
    }
    final messages = <LiveMessage>[];
    final errors = <FormatException>[];
    for (final envelope in envelopes) {
      try {
        final payload = envelope.bytes(2) ?? Uint8List(0);
        final message = switch (envelope.string(1)) {
          'WebcastChatMessage' => chat(payload, envelope.integer(3) ?? 0, roomId),
          'WebcastRoomUserSeqMessage' => online(payload),
          _ => null,
        };
        if (message != null) messages.add(message);
      } on FormatException catch (error) {
        // One unreadable message loses only itself.
        errors.add(error);
      }
    }
    return (
      ack: response.flag(9) ? ack(push.integer(2) ?? 0, response.string(5) ?? '') : null,
      messages: messages,
      envelopes: envelopes.length,
      errors: errors,
    );
  }

  /// `ChatMessage{common 1, user 2, content 3, eventTime 15}`, `Common{msgId
  /// 2, roomId 3, createTime 4}`, `User{id 1, nickName 3}`: another
  /// broadcast's chat is dropped (a room id of 0 or none is kept); the id is
  /// `common.msgId`, else the envelope's. The time is `createTime`, else
  /// `eventTime`; above 10^11 is milliseconds, otherwise seconds, and 0 means
  /// none. Ids are unsigned (a uint64 read into a signed `int`).
  static LiveMessage? chat(Uint8List payload, int envelopeId, String roomId) {
    final message = DouyinProtoMessage.decode(payload);
    final common = message.message(1);
    final user = message.message(2);
    final chatRoomId = common == null ? '' : DouyinProtoMessage.unsigned(common.integer(3) ?? 0);
    if (chatRoomId.isNotEmpty && chatRoomId != '0' && chatRoomId != roomId) return null;
    final commonId = common == null ? '' : DouyinProtoMessage.unsigned(common.integer(2) ?? 0);
    final messageId = commonId.isNotEmpty && commonId != '0' ? commonId : (envelopeId == 0 ? '' : '$envelopeId');
    final createTime = common?.integer(4) ?? 0;
    final eventTime = message.integer(15) ?? 0;
    DateTime? sentAt;
    if (createTime > 0) {
      final milliseconds = _milliseconds(createTime);
      if (milliseconds > _maxEpochMilliseconds) {
        throw FormatException('Douyin chat time out of range: $createTime');
      }
      sentAt = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    } else if (eventTime > 0 && _milliseconds(eventTime) <= _maxEpochMilliseconds) {
      // A fallback out of range leaves the chat without a time.
      sentAt = DateTime.fromMillisecondsSinceEpoch(_milliseconds(eventTime), isUtc: true);
    }
    return LiveMessage.normalized(
      text: message.string(3) ?? '',
      sender: MessageSender.normalized(
        userId: DouyinProtoMessage.unsigned(user?.integer(1) ?? 0),
        userName: user?.string(3) ?? '',
      ),
      color: LiveMessageColor.white,
      messageId: messageId.isEmpty ? '' : 'douyin:$messageId',
      sentAt: sentAt,
    );
  }

  /// A platform time: above 10^11 milliseconds, otherwise seconds.
  static int _milliseconds(int time) => time > 100000000000 ? time : time * 1000;

  /// `RoomUserSeqMessage`: the concurrent audience is `total` (3), the exact
  /// number the display text rounds; without it, `onlineUserForAnchor` (10,
  /// `30.6万`) when it carries a digit. `totalUser` (7) is cumulative.
  static LiveMessage? online(Uint8List payload) {
    final message = DouyinProtoMessage.decode(payload);
    final total = message.integer(3) ?? 0;
    final int value;
    if (total > 0) {
      value = total;
    } else {
      final text = message.string(10) ?? '';
      if (!text.contains(RegExp('[0-9]'))) return null;
      value = parseAudienceNumber(text);
    }
    return LiveMessage.normalized(
      type: LiveMessageType.audienceUpdate,
      color: LiveMessageColor.white,
      payload: LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: value),
    );
  }

  /// The envelope method names the protocol reads (a test hook for the
  /// dispatch table).
  static const List<String> handledMethods = ['WebcastChatMessage', 'WebcastRoomUserSeqMessage'];

  /// A `Response` as a PushFrame, gzipped when [gzipPayload] asks for it: the
  /// frame-building helper of the protocol's own tests.
  static Uint8List responseBytes(
    List<Uint8List> envelopes, {
    bool needAck = false,
    String internalExt = '',
    bool gzipPayload = false,
    int logId = 0,
  }) {
    final writer = DouyinProtoWriter();
    for (final envelope in envelopes) {
      writer.bytes(1, envelope);
    }
    if (internalExt.isNotEmpty) writer.string(5, internalExt);
    if (needAck) writer.integer(9, 1);
    final payload = writer.toBytes();
    return (DouyinProtoWriter()
          ..integer(2, logId)
          ..string(6, gzipPayload ? 'gzip' : '')
          ..bytes(8, gzipPayload ? _gzip(payload) : payload))
        .toBytes();
  }

  /// An envelope (`method 1, payload 2, msgId 3`).
  static Uint8List envelopeBytes(String method, Uint8List payload, {int msgId = 0}) =>
      (DouyinProtoWriter()
            ..string(1, method)
            ..bytes(2, payload)
            ..integer(3, msgId))
          .toBytes();

  static Uint8List _gzip(List<int> bytes) => Uint8List.fromList(gzip.encode(bytes));

  /// The text of a chat's UTF-8 payload, for tests and diagnostics.
  static String decodeText(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
}
