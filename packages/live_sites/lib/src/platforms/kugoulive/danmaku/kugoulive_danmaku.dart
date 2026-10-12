import 'dart:convert';
import 'dart:io' show GZipCodec;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_parser.dart';
import 'package:meta/meta.dart';

/// What the kugoulive chat connection joins, named by the numeric room id.
@immutable
final class KugouLiveDanmakuArgs {
  /// Creates the arguments.
  const new(this.roomId);

  /// The room's number (the scheduler's `rid` and the login's room).
  final String roomId;
}

/// What the scheduler granted a room: its chat sockets and a login token.
@immutable
final class KugouLiveChatGrant {
  /// Creates the grant.
  new({required List<Uri> endpoints, required this.token, required this.age})
    : endpoints = List.unmodifiable(endpoints);

  /// The sockets (`protocol` + `addrs[].host`), in the answer's order.
  final List<Uri> endpoints;

  /// `soctoken`, the login's token.
  final String token;

  /// `age`: how long the website keeps the answer for a new visit; a token
  /// this old is not used for a new socket.
  final Duration age;
}

/// A refused login: the status frame's `errorno` and `msg`.
@immutable
final class KugouLiveChatRefusal {
  /// Creates the refusal.
  const new(this.errorNo, [this.message = '']);

  /// `errorno`; [KugouLiveDanmakuProtocol.tokenRejected] (622) when the login
  /// token is not (or no longer) valid.
  final int errorNo;

  /// `msg`, or empty.
  final String message;

  /// Whether the token was refused: a new one is asked for.
  bool get tokenRejected => errorNo == KugouLiveDanmakuProtocol.tokenRejected;

  @override
  String toString() => '901 errorno $errorNo${message.isEmpty ? '' : ' $message'}';
}

/// The scheduler answered with a `code` other than 0 (a signature it does not
/// accept, a client it wants verified, …): the chat cannot be joined.
final class KugouLiveDispatchRefusal implements Exception {
  /// Creates the refusal.
  const new(this.code, [this.message = '']);

  /// The answer's `code`.
  final int code;

  /// The answer's `msg`, or empty.
  final String message;

  @override
  String toString() => 'dispatch: code $code${message.isEmpty ? '' : ' $message'}';
}

/// What one Kugou Live chat frame held ([KugouLiveDanmakuProtocol.decode]).
@immutable
final class KugouLiveDanmakuFrame {
  /// Creates the result.
  const new({
    this.messages = const [],
    this.joined = false,
    this.sessionId,
    this.refusal,
    this.heartbeat = false,
    this.ack,
  });

  /// Chat, audience updates and gifts, in order.
  final List<LiveMessage> messages;

  /// The acknowledgement to send (command 211), or null: the page answers every
  /// gift (601) whose envelope asks for one (`ack` 1).
  final Uint8List? ack;

  /// The server accepted the login (status 901 of type 1 with status 1).
  final bool joined;

  /// The session of an accepted login (`socsid`).
  final String? sessionId;

  /// The server refused the login.
  final KugouLiveChatRefusal? refusal;

  /// The server's answer to a heartbeat.
  final bool heartbeat;
}

/// Kugou Live's (繁星, fanxing.kugou.com) room chat, as the website's room page
/// speaks it, without I/O.
///
/// - The scheduler (`socket_scheduler/pc/binary/v2/address.jsonp`, signed with
///   the page's MD5 salt) gives three chat hosts and a token.
/// - Frames are binary: an 18-byte header (100, version 3, type 1, 12, the
///   command, the length, then zeros) and a protobuf `SocketProtocol.Message`
///   whose `content` (field 7) is the command's message.
/// - Login is command 201, 2201 on a reconnect; the server answers with status
///   frames (901): type 1 with status 1 joins (with its `socsid`), another
///   status and `errorno` (622: the token is refused).
/// - The heartbeat is the 4-byte frame `64 00 01 00` every 10 s; the server
///   answers `64 00 03 00`.
/// - A message is a `Content.ContentMessage` (`codec` 1) whose `content` is the
///   command's own protobuf, or JSON (`codec` 0), gzipped (`compression` 1) or
///   snappy (2) when the envelope says so.
///
/// Archived from the reference and mapped onto this tree's models: a colour is
/// an int, the audience is a [LiveAudienceUpdate] (`visited` becoming
/// `watching`), a gift is a reduced [LiveGift] (no id, picture, receiver or
/// free), and a message carries no sender level, fan badge or PK-partner room.
abstract final class KugouLiveDanmakuProtocol {
  /// The scheduler's path on [KugouLiveParser.apiHost].
  static const String dispatchPath = '/socket_scheduler/pc/binary/v2/address.jsonp';

  /// The website's origin, for the handshake and the scheduler's Referer.
  static const String origin = 'https://fanxing.kugou.com';

  /// The salt of the scheduler's signature.
  static const String signSalt = r'$_fan_xing_$';

  /// The page's `staticVersion` (`liveInitData.version`), sent as `_v`.
  static const String pageVersion = '7.0.0';

  /// `RoomSocket.socketPv`: the scheduler's `pv` and the login's `v`.
  static const int socketVersion = 20240801;

  /// `cid` of the scheduler and `clientid` of the login.
  static const int clientId = 100;

  /// `at` of a normal room.
  static const int roomType = 102;

  /// The login's `appid` (the page's fallback without a login cookie).
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

  /// A gift in the room.
  static const int giftCommand = 601;

  /// The page's image host, before a gift's picture path.
  static const String imageHost = 'https://s4fx.kgimg.com';

  /// The acknowledgement of a message.
  static const int ackCommand = 211;

  /// Chat of the other room of a PK.
  static const int otherRoomChatCommand = 400305;

  /// The audience (`HEAT_NUM`, `actionId` `roomAuNumber`).
  static const int audienceCommand = 301005;

  /// The `errorno` of a refused token.
  static const int tokenRejected = 622;

  /// Heartbeat period.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How long the login may take before the next host is tried.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// How long the website keeps a scheduler answer when it has no `age`.
  static const Duration defaultAge = Duration(minutes: 5);

  /// Refused logins in a row after which the connection gives up.
  static const int maxRefusals = 3;

  /// Largest decompressed message.
  static const int maxContentBytes = 4 * 1024 * 1024;

  /// The handshake headers: the website's origin and the platform's UA.
  static Map<String, String> get socketHeaders => {
    'origin': origin,
    'user-agent': KugouLiveParser.apiHeaders['user-agent']!,
  };

  static const int _magic = 100;
  static const int _version = 3;
  static const int _dataType = 1;
  static const int _heartbeatType = 0;
  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{2,10}$');
  static final RegExp _token = RegExp(r'^[!-~]{1,1024}$');

  /// [roomId] trimmed when it is a room number, else null.
  static String? checkedRoom(String roomId) {
    final room = roomId.trim();
    return _roomId.hasMatch(room) ? room : null;
  }

  /// The scheduler's signature of [query]: the MD5 of the keys in order with
  /// their values, `k=v` joined by `&`, and [signSalt]; its hex characters 8–23.
  static String sign(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    final text = '${keys.map((key) => '$key=${query[key]}').join('&')}$signSalt';
    return md5.convert(utf8.encode(text)).toString().substring(8, 24);
  }

  /// The scheduler's address for room [roomId] at [now].
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
    return Uri.https(KugouLiveParser.apiHost, dispatchPath, {...query, 'sign': sign(query)});
  }

  /// The scheduler's headers for [roomId]: the API headers with the room page
  /// as Referer.
  static Map<String, String> dispatchHeaders(String roomId) => {
    ...KugouLiveParser.apiHeaders,
    'referer': '$origin/$roomId',
  };

  /// The grant of a scheduler [body]: three chat sockets and a token. A `code`
  /// other than 0 throws [KugouLiveDispatchRefusal]; a failed status or an
  /// unreadable answer throws its `SiteError`.
  static KugouLiveChatGrant grant(String body, {int status = 200}) {
    final root = KugouLiveParser.decode(body, status: status, what: 'dispatch');
    final code = SiteCounts.integer(root['code']);
    if (code != 0) throw KugouLiveDispatchRefusal(code ?? -1, _text(root['msg']));
    final data = root['data'];
    if (data is! Map) throw const SiteApiChangedError('kugoulive dispatch: no data');
    final protocol = _text(data['protocol']).isEmpty ? 'ws://' : _text(data['protocol']);
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
    final token = _text(data['soctoken']);
    if (endpoints.isEmpty || !_token.hasMatch(token)) {
      throw const SiteApiChangedError('kugoulive dispatch: no chat address or token');
    }
    final age = SiteCounts.integer(data['age']);
    return KugouLiveChatGrant(
      endpoints: endpoints,
      token: token,
      age: age != null && age > 0 ? Duration(milliseconds: age) : defaultAge,
    );
  }

  /// A frame of [command] carrying [content]: the 18-byte header, then the
  /// envelope `SocketProtocol.Message{content: 7}`.
  static Uint8List frame(int command, List<int> content) {
    final message = (ProtoWriter()..bytes(7, content)).toBytes();
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

  /// The anonymous login of room [roomId] (`Login.LoginRequest`), in field
  /// order. [again] is the login of a socket that replaces a joined one (2201).
  static Uint8List login({
    required String roomId,
    required String token,
    required String sid,
    required String deviceNo,
    String sessionId = '',
    bool again = false,
  }) {
    final command = again ? reloginCommand : loginCommand;
    final request = ProtoWriter()
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

  /// The heartbeat: 100, version 1, type 0.
  static Uint8List heartbeat() => Uint8List.fromList(const [_magic, 0, 1, _heartbeatType]);

  /// The acknowledgement of a gift's message (`Ack.AckRequest`, command 211).
  static Uint8List ack({required String roomId, required String offset, required String msgId, int repeat = 0}) =>
      frame(
        ackCommand,
        (ProtoWriter()
              ..integer(1, ackCommand)
              ..integer(2, int.parse(roomId))
              ..integer(3, 0)
              ..string(4, offset)
              ..string(5, msgId)
              ..integer(6, repeat))
            .toBytes(),
      );

  /// A uuid as the page's `generateUUID` writes it, for the login's session and
  /// device.
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

  /// One server frame for room [roomId]: a heartbeat answer, a status frame
  /// (join, refusal), chat, the audience or a gift (and its acknowledgement).
  static KugouLiveDanmakuFrame decode(Object? data, {required String roomId}) {
    if (data is! List<int>) return const KugouLiveDanmakuFrame();
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    if (bytes.length >= 4 && bytes[3] == _heartbeatType) return const KugouLiveDanmakuFrame(heartbeat: true);
    final (int, Map<String, Object?>?) read;
    try {
      read = _packet(bytes);
    } on FormatException {
      return const KugouLiveDanmakuFrame();
    }
    final (command, packet) = read;
    if (packet == null) return const KugouLiveDanmakuFrame();
    switch (command) {
      case statusCommand:
        if (SiteCounts.integer(packet['type']) != 1) return const KugouLiveDanmakuFrame();
        if (SiteCounts.integer(packet['status']) == 1) {
          final session = _text(packet['socsid']);
          return KugouLiveDanmakuFrame(joined: true, sessionId: session.isEmpty ? null : session);
        }
        return KugouLiveDanmakuFrame(
          refusal: KugouLiveChatRefusal(SiteCounts.integer(packet['errorno']) ?? 0, _text(packet['msg'])),
        );
      case chatCommand || otherRoomChatCommand:
        final message = chat(packet, roomId: roomId, otherRoom: command == otherRoomChatCommand);
        return KugouLiveDanmakuFrame(messages: [?message]);
      case audienceCommand:
        return KugouLiveDanmakuFrame(messages: audience(packet, roomId: roomId));
      case giftCommand:
        return KugouLiveDanmakuFrame(
          messages: [?gift(packet, roomId: roomId)],
          ack: SiteCounts.integer(packet['ack']) == 1
              ? ack(
                  roomId: roomId,
                  offset: _text(packet['offset']),
                  msgId: _text(packet['msgId']),
                  repeat: SiteCounts.integer(packet['rpt']) ?? 0,
                )
              : null,
        );
    }
    return const KugouLiveDanmakuFrame();
  }

  static (int, Map<String, Object?>?) _packet(Uint8List frame) {
    if (frame.length < 10) throw const FormatException('Kugou chat frame too short');
    final view = ByteData.sublistView(frame);
    final start = 6 + view.getInt16(4);
    if (start < 10 || start > frame.length) throw const FormatException('Kugou chat header out of range');
    final command = view.getInt32(6);
    final envelope = ProtoMessage.decode(Uint8List.sublistView(frame, start));
    final content = _uncompress(envelope.bytes(7) ?? Uint8List(0), envelope.integer(5) ?? 0);
    final Map<String, Object?>? packet;
    if ((envelope.integer(6) ?? 0) == 1) {
      packet = command == statusCommand
          ? _status(ProtoMessage.decode(content))
          : _content(ProtoMessage.decode(content), command);
    } else {
      final Object? json;
      try {
        json = jsonDecode(utf8.decode(content));
      } on FormatException {
        return (command, null);
      }
      packet = json is Map ? json.cast<String, Object?>() : null;
    }
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

  static Map<String, Object?> _status(ProtoMessage status) => {
    'type': status.integer(2) ?? 0,
    'status': status.integer(4) ?? 0,
    'errorno': status.integer(5) ?? 0,
    'msg': status.string(6) ?? '',
    'socsid': status.string(7) ?? '',
  };

  static Map<String, Object?> _content(ProtoMessage message, int command) {
    final packet = <String, Object?>{
      'roomid': message.integer(3) ?? 0,
      'receiverid': message.integer(4) ?? 0,
      'senderid': message.integer(6) ?? 0,
      'senderkugouid': message.integer(7) ?? 0,
      'time': message.integer(11) ?? 0,
    };
    if (command == giftCommand && (message.integer(16) ?? 0) == 1) {
      return {...packet, 'content': _giftContent(ProtoMessage.decode(message.bytes(2) ?? Uint8List(0)))};
    }
    if ((command != chatCommand && command != otherRoomChatCommand) || (message.integer(16) ?? 0) != 1) {
      return packet;
    }
    final chat = ProtoMessage.decode(message.bytes(2) ?? Uint8List(0));
    final ext = ProtoMessage.decode(message.bytes(14) ?? Uint8List(0));
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

  static Map<String, Object?> _giftContent(ProtoMessage gift) => {
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

  static Map<String, Object?> _chatResponse(ProtoMessage chat) => {
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

  /// A chat message of room [roomId] as chat, or null when the page would not
  /// show it (private, another room, no text, or the PK partner's chat without
  /// a shown tag). The colour is [textColor]; the sender level, fan badge and
  /// PK-partner room have no field here.
  static LiveMessage? chat(Map<String, Object?> packet, {required String roomId, bool otherRoom = false}) {
    if ((SiteCounts.integer(packet['receiverid']) ?? 0) != 0 || (SiteCounts.integer(packet['senderid']) ?? 0) < 0) {
      return null;
    }
    final content = packet['content'];
    if (content is! Map || SiteCounts.integer(content['privateType']) == 1) return null;
    final room = SiteCounts.integer(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != roomId) return null;
    if (otherRoom) {
      final source = packet['source'];
      final partner = source is Map ? SiteCounts.integer(source['roomid']) ?? 0 : 0;
      final tags = source is Map ? SiteCounts.integer(source['tags']) ?? 0 : 0;
      if (tags & 1 == 0 || partner <= 0 || '$partner' == roomId) return null;
    }
    final text = _clean(content['chatmsg']);
    if (text.isEmpty) return null;
    final sender = _id(packet['senderid']) ?? _id(content['senderid']);
    final sinfo = packet['sinfo'];
    final mystery = sinfo is Map && SiteCounts.integer(sinfo['ck']) == 1;
    final alias = mystery ? _text(sinfo['ckid']) : null;
    final ext = _extension(packet['ext']);
    final messageId = _text(packet['msgId']);
    final seq = SiteCounts.integer(content['seq']) ?? 0;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _clean(content['sendername']),
      userId: alias ?? sender ?? '',
      message: text,
      color: textColor(ext, mystery: mystery),
      id: messageId.isNotEmpty
          ? messageId
          : sender != null && seq > 0
          ? '$sender:$seq'
          : '',
      sentAt: _time(packet['time']),
    );
  }

  /// A gift (601) of room [roomId] as a [LiveMessageType.gift] message, or null
  /// when it has no gift id or names another room. The picture, receiver, free
  /// mark and gift id have no field here; the combo key becomes [LiveGift.combo].
  static LiveMessage? gift(Map<String, Object?> packet, {required String roomId}) {
    final content = packet['content'];
    if (content is! Map) return null;
    for (final room in [SiteCounts.integer(content['roomid']) ?? 0, SiteCounts.integer(packet['roomid']) ?? 0]) {
      if (room != 0 && '$room' != roomId) return null;
    }
    final name = _clean(content['giftname']);
    final id = _id(content['giftid']);
    if (id == null) return null;
    final count = max(1, SiteCounts.integer(content['num']) ?? 1);
    final price = SiteCounts.integer(content['price']) ?? 0;
    final comboV2 = _text(content['comboIdV2']).trim();
    final combo = _text(content['comboId']).trim();
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _clean(content['sendername']),
      userId: _id(content['senderid']) ?? _id(packet['senderid']) ?? '',
      message: '${name.isEmpty ? '礼物 $id' : name} ×$count',
      color: white,
      id: _text(packet['msgId']),
      sentAt: _time(packet['time']),
      data: LiveGift(
        name: name.isEmpty ? '礼物 $id' : name,
        count: count,
        unitPrice: price < 0 ? 0 : price,
        totalValue: price < 0 ? 0 : price * count,
        combo: comboV2.isNotEmpty && comboV2 != '0'
            ? comboV2
            : combo.isNotEmpty && combo != '0'
            ? combo
            : null,
      ),
    );
  }

  /// The audience of room [roomId]: `count` the viewers now, `visited` the
  /// viewers so far (as [LiveAudienceUpdate.watching]).
  static List<LiveMessage> audience(Map<String, Object?> packet, {required String roomId}) {
    final content = packet['content'];
    if (content is! Map || content['actionId'] != 'roomAuNumber') return const [];
    final room = SiteCounts.integer(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != roomId) return const [];
    final data = content['data'];
    if (data is! Map) return const [];
    return [
      if (_count(data['count']) case final value?)
        LiveMessage(
          type: LiveMessageType.audienceUpdate,
          userName: '',
          message: '',
          data: LiveAudienceUpdate(onlineViewers: value),
        ),
      if (_count(data['visited']) case final value?)
        LiveMessage(
          type: LiveMessageType.audienceUpdate,
          userName: '',
          message: '',
          data: LiveAudienceUpdate(watching: value),
        ),
    ];
  }

  /// The orange of a chat text the page highlights.
  static const int highlightColor = 0xFF9900;

  /// The gold of a mystery guest's chat text.
  static const int mysteryColor = 0xCC9900;

  /// White, the danmaku default.
  static const int white = 0xFFFFFF;

  /// The colour the page gives a chat text, as an int: [highlightColor] for a
  /// high fan-club level or a guard, [mysteryColor] for a mystery guest over
  /// that, [white] otherwise (and without an `ext`).
  static int textColor(Map<Object?, Object?>? ext, {required bool mystery}) {
    if (ext == null) return white;
    if (mystery) return mysteryColor;
    final intimacy = ext['intimacyVo'];
    final littleGuard = ext['littleGuard'];
    final userGuard = ext['userGuard'];
    if ((intimacy is Map && _jsNumber(intimacy['level']) > 7) ||
        (littleGuard is Map && _jsTruthy(littleGuard['l'])) ||
        (userGuard is Map && _jsTruthy(userGuard['g']))) {
      return highlightColor;
    }
    return white;
  }

  static bool _jsTruthy(Object? value) => switch (value) {
    null => false,
    final bool flag => flag,
    final num number => number != 0 && !number.isNaN,
    final String text => text.isNotEmpty,
    _ => true,
  };

  static double _jsNumber(Object? value) => switch (value) {
    null => 0,
    final num number => number.toDouble(),
    final bool flag => flag ? 1 : 0,
    final String text when text.trim().isEmpty => 0,
    final String text => double.tryParse(text.trim()) ?? double.nan,
    _ => double.nan,
  };

  /// The message's `ext` as the page reads it: a map, or the URL-encoded JSON
  /// of a JSON message.
  static Map<Object?, Object?>? _extension(Object? ext) {
    var value = ext;
    if (value is String) {
      if (value.isEmpty) return null;
      if (_badEscape.hasMatch(value)) return null;
      try {
        value = jsonDecode(Uri.decodeComponent(value));
      } on FormatException {
        return null;
      }
    }
    return value is Map<Object?, Object?> ? value : null;
  }

  static final RegExp _badEscape = RegExp('%(?![0-9A-Fa-f]{2})');
  static final RegExp _marks = RegExp('[${String.fromCharCode(0x2027)}-${String.fromCharCode(0x202E)}]');

  static String _clean(Object? value) => _text(value).replaceAll(_marks, '').trim();

  static String _text(Object? value) => switch (value) {
    final String text => text,
    final int number => '$number',
    _ => '',
  };

  static String? _id(Object? value) => switch (SiteCounts.integer(value)) {
    final int id when id > 0 => '$id',
    _ => null,
  };

  static int? _count(Object? value) {
    final direct = SiteCounts.integer(value);
    if (direct != null) return direct >= 0 ? direct : null;
    final text = _text(value).replaceAll(',', '');
    if (text.isEmpty) return null;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    final number = match == null ? null : double.tryParse(match.group(0)!);
    if (number == null) return null;
    final scale = text.contains('万')
        ? 10000
        : text.contains('亿')
        ? 100000000
        : 1;
    return (number * scale).round();
  }

  static DateTime? _time(Object? value) {
    final time = SiteCounts.integer(value) ?? 0;
    if (time <= 0) return null;
    final milliseconds = time > 100000000000 ? time : time * 1000;
    return milliseconds > _maxEpochMilliseconds ? null : DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }

  /// [content] as the envelope's `compression` says: 1 gzip, 2 snappy, else as
  /// it is. At most [maxContentBytes].
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

  /// A raw snappy block (the page's snappyjs `uncompressToBuffer`).
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
  new(this.limit);

  final int limit;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) throw FormatException('Kugou chat message exceeds $limit bytes');
    bytes.add(chunk);
  }

  @override
  void close() {}
}
