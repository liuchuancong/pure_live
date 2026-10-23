import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/kugoulive/api/kugoulive_endpoints.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a danmaku connection needs to join a live room's chat: the room
/// number. The chat connection asks the website's scheduler for the socket
/// addresses and a login token of the room itself, so room entry hands over
/// nothing else.
final class KugouliveDanmakuArgs {
  /// Creates the arguments.
  const KugouliveDanmakuArgs({required this.roomId});

  /// The room number (3 to 11 digits).
  final String roomId;

  @override
  String toString() => 'KugouliveDanmakuArgs($roomId)';
}

/// What one Kugou Live chat frame held.
final class KugouliveDanmakuFrame {
  /// Creates the result.
  const KugouliveDanmakuFrame({
    this.messages = const [],
    this.joined = false,
    this.sessionId,
    this.refusal,
    this.heartbeat = false,
    this.ack,
  });

  /// Nothing to act on.
  static const KugouliveDanmakuFrame empty = KugouliveDanmakuFrame();

  /// Chat, audience updates and gifts, in order.
  final List<LiveMessage> messages;

  /// The acknowledgement to send (command 211), or null: the page answers
  /// every gift (601) whose envelope asks for one (`ack` 1); unanswered, the
  /// server sends it twice more, about 2 s apart.
  final Uint8List? ack;

  /// The server accepted the login (status 901 of type 1 with status 1).
  final bool joined;

  /// The session of an accepted login (`socsid`), sent again when the socket
  /// logs in anew (command 2201); null when the answer had none.
  final String? sessionId;

  /// The server refused the login (status 901 of type 1, another status),
  /// or null.
  final KugouliveChatRefusal? refusal;

  /// The server's answer to a heartbeat.
  final bool heartbeat;
}

/// A refused login: the status frame's `errorno` and `msg`.
final class KugouliveChatRefusal {
  /// Creates the refusal.
  const KugouliveChatRefusal(this.errorNo, [this.message = '']);

  /// `errorno`; [KugouliveDanmakuCodec.tokenRejected] (622) when the login
  /// token is not (or no longer) valid.
  final int errorNo;

  /// `msg`, or empty.
  final String message;

  /// Whether the token was refused: a new one is asked for.
  bool get tokenRejected => errorNo == KugouliveDanmakuCodec.tokenRejected;

  @override
  String toString() => '901 errorno $errorNo${message.isEmpty ? '' : ' $message'}';
}

/// The scheduler answered with a `code` other than 0 (a signature it does
/// not accept, a client it wants verified by a slider, …): the chat cannot
/// be joined.
final class KugouliveDispatchRefusal implements Exception {
  /// Creates the refusal.
  const KugouliveDispatchRefusal(this.code, [this.message = '']);

  /// The answer's `code`.
  final int code;

  /// The answer's `msg`, or empty.
  final String message;

  @override
  String toString() => 'dispatch: code $code${message.isEmpty ? '' : ' $message'}';
}

/// What the scheduler granted a room: its chat sockets and a login token.
final class KugouliveChatGrant {
  /// Creates the grant.
  const KugouliveChatGrant({required this.endpoints, required this.token, required this.age});

  /// The sockets (`protocol` + `addrs[].host`), in the answer's order.
  final List<Uri> endpoints;

  /// `soctoken`, the login's token.
  final String token;

  /// `age`: how long the website keeps the answer for a new visit (5
  /// minutes); a token this old is not used for a new socket.
  final Duration age;
}

/// Kugou Live's room chat, as the website's room page speaks it, without
/// I/O.
///
/// - The scheduler (`socket_scheduler/pc/binary/v2/address.jsonp`, signed
///   with the page's MD5 salt) gives three chat hosts and a token.
/// - Frames are binary: an 18-byte header (100, version 3, type 1, 12, the
///   command, the length, then zeros) and a protobuf `SocketProtocol.Message`
///   whose `content` is the command's message.
/// - Login is command 201 (`Login.LoginRequest`), 2201 on a reconnect; the
///   server answers with status frames (901, `ErrorResponse`): type 4, then
///   type 1 with status 1 and the session (`socsid`), or another status and
///   `errorno` (622: the token is refused).
/// - The heartbeat is the 4-byte frame `64 00 01 00` every 10 s; the server
///   answers `64 00 03 00`.
/// - A message is a `Content.ContentMessage` (`codec` 1) whose `content` is
///   the command's own protobuf (501 chat: `Chat.ChatResponse`), or JSON
///   (`codec` 0; 301005 the audience), gzipped (`compression` 1) or snappy
///   (2) when the envelope says so.
abstract final class KugouliveDanmakuCodec {
  /// The scheduler's path on the API host.
  static const String dispatchPath = '/socket_scheduler/pc/binary/v2/address.jsonp';

  /// The salt of the scheduler's signature (`$_fan_xing_$`).
  static const String signSalt = r'$_fan_xing_$';

  /// The page's `staticVersion`, sent as `_v`.
  static const String pageVersion = '7.0.0';

  /// `RoomSocket.socketPv`: the scheduler's `pv` and the login's `v`.
  static const int socketVersion = 20240801;

  /// `cid` of the scheduler and `clientid` of the login.
  static const int clientId = 100;

  /// `at` of a normal room.
  static const int roomType = 102;

  /// The login's `appid`.
  static const int appId = 1010;

  /// The login's `platid`: the web page.
  static const int platformId = 7;

  /// The login command.
  static const int loginCommand = 201;

  /// The login command of a socket that replaces a joined one.
  static const int reloginCommand = 2201;

  /// Status frames.
  static const int statusCommand = 901;

  /// Chat of the room.
  static const int chatCommand = 501;

  /// A gift in the room (`SENDGIFT`): reported and acknowledged.
  static const int giftCommand = 601;

  /// The page's image host, before a gift's picture path.
  static const String imageHost = 'https://s4fx.kgimg.com';

  /// The acknowledgement of a message (`ACKCMD`).
  static const int ackCommand = 211;

  /// Chat of the other room of a PK (`OTHERMESSAGE`): reported as chat
  /// marked with that room.
  static const int otherRoomChatCommand = 400305;

  /// The audience (`HEAT_NUM`, `actionId` `roomAuNumber`).
  static const int audienceCommand = 301005;

  /// The `errorno` of a refused token.
  static const int tokenRejected = 622;

  /// Heartbeat period (`BEAT_FREQUENCY`).
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How long the login may take before the socket is replaced.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// How long the website keeps a scheduler answer when the answer has no
  /// `age`.
  static const Duration defaultAge = Duration(minutes: 5);

  /// Silence after which the socket is replaced.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// Refused logins in a row after which the session gives up.
  static const int maxRefusals = 3;

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Largest decompressed message.
  static const int maxContentBytes = 4 * 1024 * 1024;

  /// The website's origin and the platform's desktop UA, as a browser sends
  /// them in the handshake.
  static const Map<String, String> socketHeaders = {
    'origin': KugouliveEndpoints.webOrigin,
    'user-agent': KugouliveEndpoints.userAgent,
  };

  static const int _magic = 100;
  static const int _version = 3;
  static const int _dataType = 1;
  static const int _heartbeatType = 0;
  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _token = RegExp(r'^[!-~]{1,1024}$');

  /// [roomId] trimmed when it is a room number, else null.
  static String? checkedRoom(String roomId) {
    final room = roomId.trim();
    return KugouliveEndpoints.roomId.hasMatch(room) ? room : null;
  }

  /// The scheduler's signature of [query]: the MD5 of the keys in order with
  /// their values, `k=v` joined by `&`, and the salt; its hex characters 8
  /// to 23.
  static String sign(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    final text = '${keys.map((key) => '$key=${query[key]}').join('&')}$signSalt';
    return crypto.md5.convert(utf8.encode(text)).toString().substring(8, 24);
  }

  /// The scheduler's address for room [roomId] at [now] (the page's
  /// parameters in its order, then `sign`).
  static Uri dispatchUrl(String roomId, {required DateTime now}) {
    final query = {
      '_p': '0',
      '_v': pageVersion,
      'pv': '$socketVersion',
      'rid': roomId,
      'clienttime': '${now.millisecondsSinceEpoch}',
      'cid': '$clientId',
      'at': '$roomType',
    };
    return Uri.https(KugouliveEndpoints.apiHost, dispatchPath, {...query, 'sign': sign(query)});
  }

  /// The headers of the scheduler's request: the API headers with the room
  /// page as Referer.
  static Map<String, String> dispatchHeaders(String roomId) => {
    ...KugouliveEndpoints.apiHeaders,
    'referer': KugouliveEndpoints.roomUrl(roomId),
  };

  /// The grant of a scheduler [answer]. A `code` other than 0 throws
  /// [KugouliveDispatchRefusal]; a failed status or an answer that cannot be
  /// read throws its failure.
  ///
  /// Each `addrs[].host` becomes `protocol` + host (`ws://` without a
  /// protocol, as the page does); hosts that do not make a `ws`/`wss` URL
  /// are skipped. A token is printable ASCII without spaces.
  static KugouliveChatGrant grant(String answer, {int status = 200}) {
    const what = 'dispatch';
    if (KugouliveJson.statusError(status, what) case final error?) throw error;
    final Object? root;
    try {
      root = jsonDecode(answer);
    } on FormatException {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: not JSON');
    }
    if (root is! Map) throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: not an object');
    final code = KugouliveJson.integer(root['code']);
    if (code != 0) throw KugouliveDispatchRefusal(code ?? -1, KugouliveJson.text(root['msg']));
    final data = root['data'];
    if (data is! Map) throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: no data');
    final protocol = KugouliveJson.text(data['protocol']).isEmpty ? 'ws://' : KugouliveJson.text(data['protocol']);
    final endpoints = <Uri>[];
    for (final address in data['addrs'] is List ? data['addrs'] as List : const []) {
      final host = address is Map && address['host'] is String ? address['host'] as String : '';
      final uri = host.isEmpty ? null : Uri.tryParse('$protocol$host');
      if (uri != null &&
          (uri.scheme == 'wss' || uri.scheme == 'ws') &&
          uri.host.isNotEmpty &&
          !endpoints.contains(uri)) {
        endpoints.add(uri);
      }
    }
    final token = KugouliveJson.text(data['soctoken']);
    if (endpoints.isEmpty || !_token.hasMatch(token)) {
      throw const KugouliveFailure(KugouliveFailureKind.apiChanged, '$what: no chat address or token');
    }
    final age = KugouliveJson.integer(data['age']);
    return KugouliveChatGrant(
      endpoints: endpoints,
      token: token,
      age: age != null && age > 0 ? Duration(milliseconds: age) : defaultAge,
    );
  }

  /// A frame of [command] carrying [content]: the 18-byte header, then the
  /// envelope `SocketProtocol.Message{content}`.
  static Uint8List frame(int command, List<int> content) {
    final message = (KugouliveProtoWriter()..bytes(7, content)).toBytes();
    final header = ByteData(18)
      ..setUint8(0, _magic)
      ..setInt16(1, _version)
      ..setUint8(3, _dataType)
      ..setInt16(4, 12)
      ..setInt32(6, command)
      ..setInt32(10, message.length);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(message))
        .toBytes();
  }

  /// The anonymous login of room [roomId]: `Login.LoginRequest` with the
  /// fields the page sets, in field order: command, room, `kugouid` 0, an
  /// empty `token`, [appId], [platformId], the device, [socketVersion],
  /// `referer` 0, [clientId], the scheduler's [token], the page's session
  /// [sid], the last session [sessionId] (empty before the first join),
  /// `screen` 0 and `dfid` `-`. [again] is the login of a socket that
  /// replaces a joined one (2201).
  static Uint8List login({
    required String roomId,
    required String token,
    required String sid,
    required String deviceNo,
    String sessionId = '',
    bool again = false,
  }) {
    final command = again ? reloginCommand : loginCommand;
    final request = KugouliveProtoWriter()
      ..integer(1, command)
      ..integer(2, int.parse(roomId))
      ..integer(3, 0)
      ..string(4, '')
      ..integer(6, appId)
      ..integer(7, platformId)
      ..string(10, deviceNo)
      ..integer(12, socketVersion)
      ..integer(13, 0)
      ..integer(14, clientId)
      ..string(15, token)
      ..string(18, sid)
      ..string(23, sessionId)
      ..integer(29, 0)
      ..string(38, '-');
    return frame(command, request.toBytes());
  }

  /// The heartbeat (`encodeSocketBeat`): 100, version 1, type 0.
  static Uint8List heartbeat() => Uint8List.fromList(const [_magic, 0, 1, _heartbeatType]);

  /// The acknowledgement of a message of room [roomId] (for a gift whose
  /// envelope has `ack` 1): `Ack.AckRequest` with the command 211, the room,
  /// `kugouId` 0 (no login), the envelope's `offset` and `msgId` and its
  /// `rpt`, every field written.
  static Uint8List ack({required String roomId, required String offset, required String msgId, int repeat = 0}) =>
      frame(
        ackCommand,
        (KugouliveProtoWriter()
              ..integer(1, ackCommand)
              ..integer(2, int.parse(roomId))
              ..integer(3, 0)
              ..string(4, offset)
              ..string(5, msgId)
              ..integer(6, repeat))
            .toBytes(),
      );

  /// A uuid as the page's `generateUUID` writes it (version 4 form), for the
  /// login's session and device.
  static String uuid(Random random) {
    const hex = '0123456789abcdef';
    final text = StringBuffer();
    for (final char in 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.split('')) {
      text.write(switch (char) {
        'x' => hex[random.nextInt(16)],
        'y' => hex[(random.nextInt(16) & 3) | 8],
        _ => char,
      });
    }
    return text.toString();
  }

  /// One server frame for room [roomId].
  ///
  /// - A frame of type 0 is the heartbeat's answer.
  /// - Status (901): type 1 with status 1 joins (with its `socsid`); type 1
  ///   with another status is a refusal; other types (4 comes first) say
  ///   nothing.
  /// - Chat (501) and the PK partner room's chat (400305) as [chat]; the
  ///   audience (301005) as [audience].
  /// - A gift (601) as [gift]; one whose envelope asks for it is
  ///   acknowledged as well.
  /// - Anything else, text frames, frames that cannot be read (a short
  ///   header, bad protobuf, JSON or compression) give nothing.
  static KugouliveDanmakuFrame decode(Object? data, {required String roomId}) {
    if (data is! List<int>) return KugouliveDanmakuFrame.empty;
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    if (bytes.length >= 4 && bytes[3] == _heartbeatType) return const KugouliveDanmakuFrame(heartbeat: true);
    final (int, Map<String, Object?>?) read;
    try {
      read = _packet(bytes);
    } on FormatException {
      return KugouliveDanmakuFrame.empty;
    }
    final (command, packet) = read;
    if (packet == null) return KugouliveDanmakuFrame.empty;
    switch (command) {
      case statusCommand:
        if (KugouliveJson.integer(packet['type']) != 1) return KugouliveDanmakuFrame.empty;
        if (KugouliveJson.integer(packet['status']) == 1) {
          final session = KugouliveJson.text(packet['socsid']);
          return KugouliveDanmakuFrame(joined: true, sessionId: session.isEmpty ? null : session);
        }
        return KugouliveDanmakuFrame(
          refusal: KugouliveChatRefusal(
            KugouliveJson.integer(packet['errorno']) ?? 0,
            KugouliveJson.text(packet['msg']),
          ),
        );
      case chatCommand || otherRoomChatCommand:
        final message = chat(packet, roomId: roomId, otherRoom: command == otherRoomChatCommand);
        return KugouliveDanmakuFrame(messages: [?message]);
      case audienceCommand:
        return KugouliveDanmakuFrame(messages: audience(packet, roomId: roomId));
      case giftCommand:
        return KugouliveDanmakuFrame(
          messages: [?gift(packet, roomId: roomId)],
          ack: KugouliveJson.integer(packet['ack']) == 1
              ? ack(
                  roomId: roomId,
                  offset: KugouliveJson.text(packet['offset']),
                  msgId: KugouliveJson.text(packet['msgId']),
                  repeat: KugouliveJson.integer(packet['rpt']) ?? 0,
                )
              : null,
        );
    }
    return KugouliveDanmakuFrame.empty;
  }

  /// The command of [frame] and its message: a status frame's
  /// `ErrorResponse`, a message's `ContentMessage` (with a chat's
  /// `ChatResponse` as `content`, its `ext` and `sinfo`), or the JSON of a
  /// `codec` 0 envelope. Null for what is not read.
  static (int, Map<String, Object?>?) _packet(Uint8List frame) {
    if (frame.length < 10) throw const FormatException('Kugou chat frame too short');
    final view = ByteData.sublistView(frame);
    final start = 6 + view.getInt16(4);
    if (start < 10 || start > frame.length) throw const FormatException('Kugou chat header out of range');
    final command = view.getInt32(6);
    final envelope = KugouliveProtoMessage.decode(Uint8List.sublistView(frame, start));
    final content = _uncompress(envelope.bytes(7) ?? Uint8List(0), envelope.integer(5) ?? 0);
    Map<String, Object?>? packet;
    if ((envelope.integer(6) ?? 0) == 1) {
      packet = command == statusCommand
          ? _status(KugouliveProtoMessage.decode(content))
          : _content(KugouliveProtoMessage.decode(content), command);
    } else {
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(content));
      } on FormatException {
        return (command, null);
      }
      packet = json is Map ? json.cast<String, Object?>() : null;
    }
    // The page puts the envelope's ack fields on the message.
    return (
      command,
      packet == null
          ? null
          : {
              ...packet,
              'ack': envelope.integer(2) ?? 0,
              'rpt': envelope.integer(3) ?? 0,
              'msgId': envelope.string(4) ?? '',
              'offset': envelope.string(1) ?? '',
            },
    );
  }

  /// `SocketProtocol.ErrorResponse{cmd 1, type 2, seq 3, status 4, errorno
  /// 5, msg 6, socsid 7}`.
  static Map<String, Object?> _status(KugouliveProtoMessage status) => {
    'type': status.integer(2) ?? 0,
    'status': status.integer(4) ?? 0,
    'errorno': status.integer(5) ?? 0,
    'msg': status.string(6) ?? '',
    'socsid': status.string(7) ?? '',
  };

  /// `Content.ContentMessage{cmd 1, content 2, roomid 3, receiverid 4,
  /// senderid 6, senderkugouid 7, time 11, ext 14, sinfo 15, codec 16,
  /// source 18 {roomid 1, tags 2}}`; the `content` of a chat whose `codec`
  /// is 1 read as `Chat.ChatResponse`, its `ext` for the fan badge and the
  /// text's colour, and its `sinfo` (`ck` 5, `ckid` 8). Other messages keep
  /// only the envelope.
  static Map<String, Object?> _content(KugouliveProtoMessage message, int command) {
    final packet = <String, Object?>{
      'roomid': message.integer(3) ?? 0,
      'receiverid': message.integer(4) ?? 0,
      'senderid': message.integer(6) ?? 0,
      'senderkugouid': message.integer(7) ?? 0,
      'time': message.integer(11) ?? 0,
    };
    if (command == giftCommand && (message.integer(16) ?? 0) == 1) {
      return {...packet, 'content': _giftContent(KugouliveProtoMessage.decode(message.bytes(2) ?? Uint8List(0)))};
    }
    if ((command != chatCommand && command != otherRoomChatCommand) || (message.integer(16) ?? 0) != 1) {
      return packet;
    }
    final chat = KugouliveProtoMessage.decode(message.bytes(2) ?? Uint8List(0));
    final ext = KugouliveProtoMessage.decode(message.bytes(14) ?? Uint8List(0));
    final intimacy = ext.message(39);
    final userGuard = ext.message(8);
    final littleGuard = ext.message(9);
    final sinfo = message.message(15);
    final source = message.message(18);
    return {
      ...packet,
      'content': _chatResponse(chat),
      'ext': {
        if (intimacy != null)
          'intimacyVo': {
            'level': intimacy.integer(1) ?? 0,
            'nameplate': intimacy.string(2) ?? '',
            'type': intimacy.integer(3) ?? 0,
            'lightUp': intimacy.integer(5) ?? 0,
          },
        if (userGuard != null) 'userGuard': {'g': userGuard.string(1) ?? ''},
        if (littleGuard != null) 'littleGuard': {'l': littleGuard.integer(1) ?? 0},
      },
      if (sinfo != null) 'sinfo': {'ck': sinfo.integer(5) ?? 0, 'ckid': sinfo.string(8) ?? ''},
      if (source != null) 'source': {'roomid': source.integer(1) ?? 0, 'tags': source.integer(2) ?? 0},
    };
  }

  /// The fields of `GiftEffectSocketMsg.Content` that a gift line reads.
  static Map<String, Object?> _giftContent(KugouliveProtoMessage gift) => {
    'giftid': gift.integer(2) ?? 0,
    'giftname': gift.string(3) ?? '',
    'num': gift.integer(4) ?? 0,
    'price': gift.integer(5) ?? 0,
    'image': gift.string(8) ?? '',
    'roomid': gift.integer(12) ?? 0,
    'senderid': gift.integer(13) ?? 0,
    'sendername': gift.string(15) ?? '',
    'senderrichlevel': gift.integer(17) ?? 0,
    'receiverid': gift.integer(18) ?? 0,
    'receivername': gift.string(19) ?? '',
    'comboId': gift.string(26) ?? '',
    'comboIdV2': gift.string(28) ?? '',
    'comboSumV2': gift.integer(29) ?? 0,
    'mysticStatus': gift.integer(38) ?? 0,
    'comboGiftSum': gift.integer(75) ?? 0,
    'senderrichlevelV2': gift.integer(78) ?? 0,
  };

  /// `Chat.ChatResponse{chatmsg 1, senderid 2, senderkugouid 3, sendername
  /// 4, senderrichlevel 5, receiverid 6, receivername 8, seq 13,
  /// senderrichlevelV2 25}`.
  static Map<String, Object?> _chatResponse(KugouliveProtoMessage chat) => {
    'chatmsg': chat.string(1) ?? '',
    'senderid': chat.integer(2) ?? 0,
    'senderkugouid': chat.integer(3) ?? 0,
    'sendername': chat.string(4) ?? '',
    'senderrichlevel': chat.integer(5) ?? 0,
    'receiverid': chat.integer(6) ?? 0,
    'receivername': chat.string(8) ?? '',
    'seq': chat.integer(13) ?? 0,
    'senderrichlevelV2': chat.integer(25) ?? 0,
  };

  /// A chat message (or the PK partner room's) of room [roomId] as chat, or
  /// null when the page would not show it in the public chat:
  ///
  /// - the message goes to someone (`receiverid` of the envelope not 0: a
  ///   private message), comes from a negative sender or is marked
  ///   `privateType` 1;
  /// - it names another room (`roomid` not 0 and not [roomId]);
  /// - [otherRoom] without `source.tags & 1` or without the partner's
  ///   `source.roomid`; such a chat carries that room as the message's
  ///   source room;
  /// - it has no text left.
  ///
  /// The text is `chatmsg` and the name `sendername`, without the separators
  /// and direction marks U+2027 to U+202E the page takes out, trimmed. The
  /// user id is the envelope's `senderid` (the chat's without one), for a
  /// mystery guest (`sinfo.ck` 1) the alias id `sinfo.ckid`. The level is
  /// the wealth level `senderrichlevelV2`, else `senderrichlevel`; the fan
  /// badge is `ext.intimacyVo`'s `nameplate` and `level` when the page shows
  /// it (level above 0, `type` 1 to 4, `lightUp` 1). The id is the
  /// envelope's `msgId`, else `<sender>:<seq>`; the time is the envelope's
  /// `time` (seconds, milliseconds above 10^11). The colour is the page's
  /// for the text.
  static LiveMessage? chat(Map<String, Object?> packet, {required String roomId, bool otherRoom = false}) {
    if ((KugouliveJson.integer(packet['receiverid']) ?? 0) != 0 ||
        (KugouliveJson.integer(packet['senderid']) ?? 0) < 0) {
      return null;
    }
    final content = packet['content'];
    if (content is! Map || KugouliveJson.integer(content['privateType']) == 1) return null;
    final room = KugouliveJson.integer(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != roomId) return null;
    var sourceRoom = '';
    if (otherRoom) {
      final source = packet['source'];
      final partner = source is Map ? KugouliveJson.integer(source['roomid']) ?? 0 : 0;
      final tags = source is Map ? KugouliveJson.integer(source['tags']) ?? 0 : 0;
      if (tags & 1 == 0 || partner <= 0 || '$partner' == roomId) return null;
      sourceRoom = '$partner';
    }
    final text = _clean(content['chatmsg']);
    if (text.isEmpty) return null;
    final sender = _id(packet['senderid']) ?? _id(content['senderid']);
    final sinfo = packet['sinfo'];
    final mystery = sinfo is Map && KugouliveJson.integer(sinfo['ck']) == 1;
    final alias = mystery ? KugouliveJson.text(sinfo['ckid']) : null;
    final level = _positive(content['senderrichlevelV2']) ?? _positive(content['senderrichlevel']);
    final ext = _extension(packet['ext']);
    final badge = _badge(ext);
    final messageId = KugouliveJson.text(packet['msgId']);
    final seq = KugouliveJson.integer(content['seq']) ?? 0;
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: alias ?? sender ?? '',
        userName: _clean(content['sendername']),
        userLevel: level == null ? '' : '$level',
        fanBadgeName: badge?.name ?? '',
        fanBadgeLevel: badge == null ? '' : '${badge.level}',
      ),
      text: text,
      color: textColor(ext, mystery: mystery),
      messageId: messageId.isNotEmpty
          ? messageId
          : sender != null && seq > 0
          ? '$sender:$seq'
          : '',
      sentAt: _time(packet['time']),
      sourceRoomId: sourceRoom,
    );
  }

  /// A gift (601, `SENDGIFT`) of room [roomId] as a gift message, or null
  /// when it is not one: no gift id, or the gift names another room.
  ///
  /// - `giftid`, `giftname`, `num`; the price in star coins (written as the
  ///   platform's paid currency, v2 has no star-coin unit), `price × num`
  ///   for all of them; a price of 0 is free;
  /// - the combo key `comboIdV2`, else `comboId` unless it is `0`; the
  ///   combo's gifts so far `comboGiftSum`;
  /// - the icon `image` on the image host (an `http:` address made `https`);
  ///   the receiver `receivername`;
  /// - the sender is `sendername`, `senderid` and the wealth level; the id
  ///   is the envelope's `msgId` (the same on the server's repeats); the
  ///   time its `time`.
  ///
  /// Read from the content of a protobuf envelope (`codec` 1) or of a JSON
  /// one, which uses the same names.
  static LiveMessage? gift(Map<String, Object?> packet, {required String roomId}) {
    final content = packet['content'];
    if (content is! Map) return null;
    for (final room in [KugouliveJson.integer(content['roomid']) ?? 0, KugouliveJson.integer(packet['roomid']) ?? 0]) {
      if (room != 0 && '$room' != roomId) return null;
    }
    final id = _id(content['giftid']);
    if (id == null) return null;
    final count = max(1, KugouliveJson.integer(content['num']) ?? 1);
    final price = KugouliveJson.integer(content['price']) ?? 0;
    final comboV2 = KugouliveJson.text(content['comboIdV2']).trim();
    final combo = KugouliveJson.text(content['comboId']).trim();
    final comboSum = KugouliveJson.integer(content['comboGiftSum']) ?? 0;
    final level = _positive(content['senderrichlevelV2']) ?? _positive(content['senderrichlevel']);
    final gift = LiveGift.of(
      giftId: id,
      name: _clean(content['giftname']),
      count: count,
      value: LiveGiftValue.of(
        unit: price == 0 ? LiveGiftUnit.free : LiveGiftUnit.starCoin,
        unitPrice: price < 0 ? null : price.toDouble(),
        totalValue: price < 0 ? null : (price * count).toDouble(),
      ),
      combo: LiveGiftCombo.of(
        comboKey: comboV2.isNotEmpty && comboV2 != '0'
            ? comboV2
            : combo.isNotEmpty && combo != '0'
            ? combo
            : '',
        comboTotal: comboSum > 0 ? comboSum : null,
      ),
      recipientName: _clean(content['receivername']),
      iconUrl: _image(KugouliveJson.text(content['image']))?.toString(),
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(
        userId: _id(content['senderid']) ?? _id(packet['senderid']) ?? '',
        userName: _clean(content['sendername']),
        userLevel: level == null ? '' : '$level',
      ),
      text: '${gift.name} ×${gift.count}',
      messageId: KugouliveJson.text(packet['msgId']),
      sentAt: _time(packet['time']),
      payload: gift,
    );
  }

  /// A gift picture's address: a path on the image host, or an `http(s)`
  /// address as `https`; null for anything else.
  static Uri? _image(String path) {
    final text = path.trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text.startsWith('/') && !text.startsWith('//') ? '$imageHost$text' : text);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    return uri.replace(scheme: 'https');
  }

  /// The audience of room [roomId] (`HEAT_NUM` with `actionId`
  /// `roomAuNumber`, about every minute): `count`, the viewers now, and
  /// `visited`, the viewers of this broadcast so far. `hot`, the page's
  /// 热度, is not reported.
  static List<LiveMessage> audience(Map<String, Object?> packet, {required String roomId}) {
    final content = packet['content'];
    if (content is! Map || content['actionId'] != 'roomAuNumber') return const [];
    final room = KugouliveJson.integer(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != roomId) return const [];
    final data = content['data'];
    if (data is! Map) return const [];
    return [
      for (final (key, kind) in const [
        ('count', LiveAudienceSignalKind.onlineViewers),
        ('visited', LiveAudienceSignalKind.totalViewers),
      ])
        if (KugouliveJson.count(data[key]) case final value?)
          LiveMessage.normalized(
            type: LiveMessageType.audienceUpdate,
            payload: LiveAudienceUpdate.of(kind: kind, value: value),
          ),
    ];
  }

  /// The orange of a chat text the page highlights (`#ff9900`).
  static const LiveMessageColor highlightColor = LiveMessageColor(0xff, 0x99, 0x00);

  /// The gold of a mystery guest's chat text (`#CC9900`).
  static const LiveMessageColor mysteryColor = LiveMessageColor(0xcc, 0x99, 0x00);

  /// The colour the page gives a chat text, with the fan-club switch on:
  ///
  /// - [highlightColor] when the fan-club level (`intimacyVo.level`) is
  ///   above 7, or the sender is a little guard (`littleGuard.l`) or a guard
  ///   (`userGuard.g`), read with JavaScript's truthiness;
  /// - [mysteryColor], over that, for a mystery guest;
  /// - white otherwise, and whenever the message has no `ext`.
  static LiveMessageColor textColor(Map<Object?, Object?>? ext, {required bool mystery}) {
    if (ext == null) return LiveMessageColor.white;
    if (mystery) return mysteryColor;
    final intimacy = ext['intimacyVo'];
    final littleGuard = ext['littleGuard'];
    final userGuard = ext['userGuard'];
    if ((intimacy is Map && _jsNumber(intimacy['level']) > 7) ||
        (littleGuard is Map && _jsTruthy(littleGuard['l'])) ||
        (userGuard is Map && _jsTruthy(userGuard['g']))) {
      return highlightColor;
    }
    return LiveMessageColor.white;
  }

  /// JavaScript's truthiness of a JSON value.
  static bool _jsTruthy(Object? value) => switch (value) {
    null => false,
    final bool flag => flag,
    final num number => number != 0 && !number.isNaN,
    final String text => text.isNotEmpty,
    _ => true,
  };

  /// A JSON value as JavaScript's `>` compares it with a number.
  static double _jsNumber(Object? value) => switch (value) {
    null => 0,
    final num number => number.toDouble(),
    final bool flag => flag ? 1 : 0,
    final String text when text.trim().isEmpty => 0,
    final String text => double.tryParse(text.trim()) ?? double.nan,
    _ => double.nan,
  };

  /// The message's `ext` as the page reads it: a map, or the URL-encoded
  /// JSON of a JSON message. Null when it is missing or cannot be read.
  static Map<Object?, Object?>? _extension(Object? ext) {
    var value = ext;
    if (value is String) {
      if (value.isEmpty) return null;
      // decodeComponent throws on a bad escape.
      if (_badEscape.hasMatch(value)) return null;
      try {
        value = jsonDecode(Uri.decodeComponent(value));
      } on FormatException {
        return null;
      }
    }
    return value is Map<Object?, Object?> ? value : null;
  }

  /// The fan badge the page shows: `intimacyVo` of the message's [ext].
  static ({String name, int level})? _badge(Map<Object?, Object?>? ext) {
    final intimacy = ext?['intimacyVo'];
    if (intimacy is! Map) return null;
    final level = KugouliveJson.integer(intimacy['level']) ?? 0;
    final type = KugouliveJson.integer(intimacy['type']) ?? 0;
    final name = _clean(intimacy['nameplate']);
    if (level <= 0 || type < 1 || type > 4 || KugouliveJson.integer(intimacy['lightUp']) != 1 || name.isEmpty) {
      return null;
    }
    return (name: name, level: level);
  }

  static final RegExp _badEscape = RegExp('%(?![0-9A-Fa-f]{2})');
  static final RegExp _marks = RegExp(r'[\u2027-\u202E]');

  static String _clean(Object? value) => KugouliveJson.text(value).replaceAll(_marks, '').trim();

  static String? _id(Object? value) => switch (KugouliveJson.integer(value)) {
    final int id when id > 0 => '$id',
    _ => null,
  };

  static int? _positive(Object? value) => switch (KugouliveJson.integer(value)) {
    final int number when number > 0 => number,
    _ => null,
  };

  static DateTime? _time(Object? value) {
    final time = KugouliveJson.integer(value) ?? 0;
    if (time <= 0) return null;
    final milliseconds = time > 100000000000 ? time : time * 1000;
    return milliseconds > _maxEpochMilliseconds ? null : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// [content] as the envelope's `compression` says: 1 gzip, 2 snappy, else
  /// as it is. At most [maxContentBytes].
  static Uint8List _uncompress(Uint8List content, int compression) {
    switch (compression) {
      case 1:
        final sink = _BoundedSink(maxContentBytes);
        try {
          GZipCodec().decoder.startChunkedConversion(sink)
            ..add(content)
            ..close();
        } on FormatException {
          rethrow;
        } on Object catch (error) {
          throw FormatException('Kugou chat gzip: $error');
        }
        return sink.bytes.takeBytes();
      case 2:
        return snappy(content);
    }
    return content;
  }

  /// A raw snappy block (the page's snappyjs `uncompressToBuffer`): the
  /// length as a varint, then literals and copies. At most
  /// [maxContentBytes]; anything malformed is a [FormatException].
  static Uint8List snappy(Uint8List input) {
    var position = 0;
    var length = 0;
    for (var shift = 0; ; shift += 7) {
      if (shift > 28 || position >= input.length) throw const FormatException('Snappy length');
      final byte = input[position++];
      length |= (byte & 0x7F) << shift;
      if (byte < 0x80) break;
    }
    if (length > maxContentBytes) throw const FormatException('Snappy block too large');
    final output = Uint8List(length);
    var written = 0;
    int take(int count) {
      if (position + count > input.length) throw const FormatException('Snappy block truncated');
      var value = 0;
      for (var i = 0; i < count; i++) {
        value |= input[position + i] << (8 * i);
      }
      position += count;
      return value;
    }

    while (position < input.length) {
      final tag = input[position++];
      final int size;
      if (tag & 3 == 0) {
        final short = (tag >> 2) + 1;
        size = short > 60 ? take(short - 60) + 1 : short;
        if (position + size > input.length || written + size > length) {
          throw const FormatException('Snappy literal out of range');
        }
        output.setRange(written, written + size, input, position);
        position += size;
        written += size;
        continue;
      }
      final int offset;
      switch (tag & 3) {
        case 1:
          size = 4 + ((tag >> 2) & 7);
          offset = ((tag >> 5) << 8) | take(1);
        case 2:
          size = (tag >> 2) + 1;
          offset = take(2);
        default:
          size = (tag >> 2) + 1;
          offset = take(4);
      }
      if (offset == 0 || offset > written || written + size > length) {
        throw const FormatException('Snappy copy out of range');
      }
      for (var i = 0; i < size; i++) {
        output[written] = output[written - offset];
        written++;
      }
    }
    if (written != length) throw const FormatException('Snappy length mismatch');
    return output;
  }
}

final class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this.limit);

  final int limit;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) {
      throw FormatException('Kugou chat message exceeds $limit bytes');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
