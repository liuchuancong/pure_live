import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one LOOK chat frame held ([LookliveDanmakuCodec.decode]).
final class LookliveDanmakuFrame {
  /// Creates the result.
  const LookliveDanmakuFrame({
    this.messages = const [],
    this.replies = const [],
    this.opened = false,
    this.joined = false,
    this.refusal,
    this.kicked,
    this.dropped = false,
  });

  /// Nothing to act on.
  static const LookliveDanmakuFrame empty = LookliveDanmakuFrame();

  /// Chat, emoji and gifts, in order.
  final List<LiveMessage> messages;

  /// What to send back at once, in order: the echo of a socket.io heartbeat
  /// (`2::`) and the ack of a message that asked for one (`6:::<id>`).
  final List<String> replies;

  /// socket.io's connect packet (`1::`): the session is open, the client
  /// logs in to the chatroom now.
  final bool opened;

  /// The chatroom accepted the login (command 13-2 with `code` 200).
  final bool joined;

  /// The chatroom refused the login: its `code`; null otherwise.
  final int? refusal;

  /// The chatroom put this client out (command 13-3): the reason
  /// ([LookliveDanmakuCodec.kickReasons]); null otherwise.
  final int? kicked;

  /// The server ended the socket.io session (`0::`) or reported an error
  /// (`7:::`): the socket is to be replaced.
  final bool dropped;
}

/// The anonymous identity one connection logs in with, as the NIM SDK makes
/// it for a guest (`nimanon_` and 32 hex digits, a device id and an SDK
/// session of 32 hex digits each).
final class LookliveGuest {
  /// Creates the identity.
  const LookliveGuest({required this.account, required this.deviceId, required this.session});

  /// A new identity from [random] (the SDK's `guid()`: 32 lower-case hex
  /// digits).
  factory LookliveGuest.random(Random random) {
    String guid() => [for (var i = 0; i < 8; i++) random.nextInt(0x10000).toRadixString(16).padLeft(4, '0')].join();
    return LookliveGuest(account: 'nimanon_${guid()}', deviceId: guid(), session: guid());
  }

  /// The chatroom account (`nimanon_…`).
  final String account;

  /// The device id.
  final String deviceId;

  /// The SDK session.
  final String session;
}

/// The chat arguments of a room, which the room answer carries: the room
/// number, the room's Yunxin chatroom, and whether the room hides its
/// viewers' names.
@immutable
final class LookliveDanmakuArgs {
  /// Creates the arguments.
  const LookliveDanmakuArgs({required this.roomId, required this.chatroomId, this.anonymousMode = false});

  /// The room number (`liveRoomNo`): the chat servers are asked for it.
  final String roomId;

  /// The Yunxin chatroom of the room (`roomInfo.roomId`; not the room
  /// number).
  final String chatroomId;

  /// Whether the room hides its viewers' names (`anonymousMode`): LOOK's
  /// room page then shows a name's first character and `***`.
  final bool anonymousMode;

  @override
  bool operator ==(Object other) =>
      other is LookliveDanmakuArgs &&
      other.roomId == roomId &&
      other.chatroomId == chatroomId &&
      other.anonymousMode == anonymousMode;

  @override
  int get hashCode => Object.hash(roomId, chatroomId, anonymousMode);

  @override
  String toString() => 'LookliveDanmakuArgs($roomId, chatroom $chatroomId${anonymousMode ? ', anonymous' : ''})';
}

/// LOOK's chat, without I/O: a NetEase Yunxin (网易云信) chatroom, joined
/// anonymously the way LOOK's website does it with the Yunxin web SDK 5.0.1.
///
/// - The room's chat servers come from the chat address API (`host:port`
///   each); the website sends no token for a guest.
/// - Every socket is socket.io 0.9: a GET of `/socket.io/1/?t=<ms>` answers
///   `<sid>:<heartbeat>:<close>:<transports>`, then the WebSocket opens at
///   `/socket.io/1/websocket/<sid>`. The server sends `1::` when the session
///   is open and `2::` every 25 s, which the client echoes; data travels in
///   message packets (`3:::<data>`).
/// - The data is the SDK's JSON: commands `{"SID", "CID", "SER", "Q"}`
///   (service, command, serial, typed parameters), answers `{"sid", "cid",
///   "ser", "code", "r"}`. Properties go by number (the SDK's
///   `serializeMap`).
/// - The client logs in anonymously to the chatroom (13-2) and sends the
///   link heartbeat (1-2) every 3 minutes. Chatroom messages come as
///   notifications (4-10) wrapping 13-7.
/// - A chat line is a text message (type 0) whose `custom` JSON has
///   `bizName` `iplay` and the sender in `content.user`.
abstract final class LookliveDanmakuCodec {
  /// LOOK's Yunxin app key: the website's public `online.appKey`.
  static const String appKey = '3a6a3e48f6854dfa4e4464f3bdaec3b4';

  /// The SDK's `info.sdkVersion` (web SDK 5.0.1).
  static const String sdkVersion = '47';

  /// The SDK's `info.protocolVersion`.
  static const int protocolVersion = 1;

  /// What the SDK reports as the system and browser (`platform.js`) on the
  /// desktop Chrome the handshake's user agent names; the server does not
  /// check them.
  static const String os = 'Windows 10 64-bit';

  /// See [os].
  static const String browser = 'Chrome 140.0.0.0';

  /// The chatroom name of a guest on LOOK's room page (`chatroomNick`).
  static const String guestNick = '匿名用户';

  /// The chatroom avatar of a guest (the SDK's default, one space).
  static const String guestAvatar = ' ';

  /// The watchdog's tick: the socket is replaced after 90 s of silence (the
  /// handshake's heartbeat timeout; the server sends `2::` every 25 s).
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// The heartbeat timer's period, one watchdog tick.
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// Ticks per link heartbeat: 6 × 30 s, the SDK's `heartbeatInterval` of
  /// 180 s.
  static const int ticksPerHeartbeat = 6;

  /// How long the login may take after the socket opened (the SDK waits
  /// 42 s; the answer came within 0.2 s).
  static const Duration joinTimeout = Duration(seconds: 10);

  /// The socket.io handshake's and the sockets' connect budget.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Chat server requests per connection: the website asks again once,
  /// 2 s after a failure.
  static const int addressAttempts = 2;

  /// See [addressAttempts].
  static const Duration addressRetryDelay = Duration(seconds: 2);

  /// Refused logins in a row that are retried (codes the SDK names as
  /// passing: [retriedRefusals]); the next one ends the connection.
  static const int maxRefusals = 3;

  /// Login refusals worth another socket: 408 timeout, 415 no chatroom
  /// server available, 500 server error, 503 busy (the SDK's error table).
  /// Any other code (403, 404 chatroom not found, 13002 chatroom closed, …)
  /// ends the connection.
  static const Set<int> retriedRefusals = {408, 415, 500, 503};

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// The SDK's kick reasons (`kickedReasons`): 1 the chatroom closed, 2 put
  /// out by the host or a manager, 3 the same account elsewhere, 4 silently
  /// (reconnect), 5 blacklisted.
  static const List<String> kickReasons = [
    '',
    'chatroomClosed',
    'managerKick',
    'samePlatformKick',
    'silentlyKick',
    'blacked',
  ];

  /// The kick the SDK answers by reconnecting (`silentlyKick`).
  static const int silentKick = 4;

  /// Handshake headers of the socket: the website's origin and the
  /// platform's user agent (LOOK's requests use `Mozilla/5.0`).
  static const Map<String, String> socketHeaders = {
    'origin': LookliveEndpoints.origin,
    'user-agent': LookliveEndpoints.userAgent,
  };

  /// The headers of the socket.io handshake GET: the origin, the room page
  /// as referer and the platform's user agent, as the website's XHR sends
  /// them.
  static Map<String, String> handshakeHeaders(String roomId) => {
    'origin': LookliveEndpoints.origin,
    'referer': LookliveEndpoints.link(roomId),
    'user-agent': LookliveEndpoints.userAgent,
  };

  /// socket.io's heartbeat packet, echoed as it arrives.
  static const String socketHeartbeat = '2::';

  /// The link heartbeat (service 1, command 2; serial 0 as the SDK sends
  /// it).
  static const String heartbeat = '3:::{"SID":1,"CID":2,"SER":0}';

  /// The largest chatroom id that stays exact as a JSON number in the
  /// website (2^53 − 1).
  static const int _maxChatroomId = 9007199254740991;

  /// Largest [DateTime], in milliseconds.
  static const int _maxEpochMillis = 8640000000000000;

  static final RegExp _chatroomId = RegExp(r'^[1-9][0-9]{0,15}$');
  static final RegExp _sessionId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _packet = RegExp(r'^([^:]+):([0-9]+)?(\+)?:([^:]+)?:?([\s\S]*)$');

  /// [args] trimmed if they name a chat: a room number and a chatroom id
  /// that the login can carry as a number; null otherwise.
  static LookliveDanmakuArgs? checked(LookliveDanmakuArgs args) {
    final roomId = args.roomId.trim();
    final chatroomId = args.chatroomId.trim();
    if (!LookliveEndpoints.isRoomNumber(roomId) ||
        !_chatroomId.hasMatch(chatroomId) ||
        int.parse(chatroomId) > _maxChatroomId) {
      return null;
    }
    return LookliveDanmakuArgs(roomId: roomId, chatroomId: chatroomId, anonymousMode: args.anonymousMode);
  }

  /// The socket of each chat server (`host:port`):
  /// `wss://<host>:<port>/socket.io/1/websocket/`, to which the handshake
  /// appends the session id. The SDK makes every address `https://` (its
  /// `secure` default) and tries them in order.
  static List<Uri> endpoints(List<String> addresses) => [
    for (final address in addresses) Uri.parse('wss://$address/socket.io/1/websocket/'),
  ];

  /// The socket.io handshake of [endpoint] at [now]: a GET of
  /// `https://<host>:<port>/socket.io/1/?t=<ms>` (`http` for a `ws`
  /// endpoint) with the website's origin, room [roomId]'s page as referer
  /// and the platform's user agent, as the website's XHR sends it.
  static Uri handshakeUrl(Uri endpoint, {required String roomId, required DateTime now}) => endpoint.replace(
    scheme: endpoint.isScheme('ws') ? 'http' : 'https',
    path: '/socket.io/1/',
    query: 't=${now.millisecondsSinceEpoch}',
  );

  /// The session id of a handshake answer
  /// (`<sid>:<heartbeat>:<close>:<transports>`). A status other than 200,
  /// an id that does not fit a URL path segment, or transports without
  /// `websocket` throw [FormatException].
  static String sessionOf(String text, {int status = 200}) {
    if (status != 200) throw FormatException('socket.io handshake: HTTP $status');
    final parts = text.trim().split(':');
    if (parts.length < 4 || !_sessionId.hasMatch(parts.first)) {
      throw FormatException('socket.io handshake: ${_snippet(text)}');
    }
    if (!parts[3].split(',').contains('websocket')) {
      throw FormatException('socket.io handshake: no websocket in ${_snippet(parts[3])}');
    }
    return parts.first;
  }

  /// The socket of [endpoint] for session [sessionId].
  static Uri socketUrl(Uri endpoint, String sessionId) => endpoint.replace(path: '${endpoint.path}$sessionId');

  /// The anonymous chatroom login (service 13, command 2) with serial
  /// [serial] for [chatroomId] as [guest], as the SDK assembles it
  /// (`assembleLogin`, `assembleIMLogin`): type 1, the chatroom login
  /// (app key, account, device, chatroom, `appLogin`, the guest's name and
  /// avatar, session, `isAnonymous` 1) and the IM login (system, SDK
  /// version, `appLogin`, protocol version, device, app key, account,
  /// browser, session, an empty token). [again] is a login after a
  /// reconnect: the chatroom `appLogin` is 1 and the IM one 0 (0 and 1 the
  /// first time).
  static String login({
    required String chatroomId,
    required LookliveGuest guest,
    required int serial,
    bool again = false,
  }) {
    final chatroom = <String, Object>{
      '1': appKey,
      '2': guest.account,
      '3': guest.deviceId,
      '5': int.parse(chatroomId),
      '8': again ? 1 : 0,
      '20': guestNick,
      '21': guestAvatar,
      '26': guest.session,
      '38': 1,
    };
    final im = <String, Object>{
      '4': os,
      '6': sdkVersion,
      '8': again ? 0 : 1,
      '9': protocolVersion,
      '13': guest.deviceId,
      '18': appKey,
      '19': guest.account,
      '24': browser,
      '26': guest.session,
      '1000': '',
    };
    final command = {
      'SID': 13,
      'CID': 2,
      'SER': serial,
      'Q': [
        {'t': 'byte', 'v': 1},
        {'t': 'Property', 'v': chatroom},
        {'t': 'Property', 'v': im},
      ],
    };
    return '3:::${jsonEncode(command)}';
  }

  /// One frame (text, or UTF-8 bytes): one socket.io packet, or several
  /// framed as `\ufffd<length>\ufffd<packet>…` (socket.io 0.9's
  /// `decodePayload`).
  ///
  /// - `1::` opens the session; `2::` is echoed; `0::` and `7:::…` drop the
  ///   socket; a message packet with an id and no `+` is acked (`6:::<id>`).
  /// - A message's data is an SDK answer: the login's (13-2: joined, or its
  ///   refusal code), a kick (13-3), a chatroom message (13-7), or a
  ///   notification (4-10, 4-11) wrapping one in `r[1]`. Chat lines
  ///   ([chat]) are reported; with [anonymousMode] the names are masked as
  ///   the room page does.
  /// - Anything unreadable is skipped.
  static LookliveDanmakuFrame decode(Object? data, {bool anonymousMode = false}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return LookliveDanmakuFrame.empty;
    final messages = <LiveMessage>[];
    final replies = <String>[];
    var opened = false;
    var joined = false;
    var dropped = false;
    int? refusal;
    int? kicked;
    for (final packet in _payload(text)) {
      final match = _packet.firstMatch(packet);
      if (match == null || (match.group(4) ?? '').isNotEmpty) continue;
      switch (match.group(1)) {
        case '0' || '7':
          dropped = true;
        case '1':
          opened = true;
        case '2':
          replies.add(socketHeartbeat);
        case '3':
          if (match.group(2) case final id? when match.group(3) == null) replies.add('6:::$id');
          final answer = _answer(match.group(5) ?? '');
          if (answer == null) continue;
          switch ((answer.sid, answer.cid)) {
            case (13, 2):
              if (answer.code == 200) {
                joined = true;
              } else {
                refusal ??= answer.code ?? 0;
              }
            case (13, 3) when answer.code == 200:
              kicked ??= _int(answer.body.firstOrNull) ?? 0;
            case (13, 7) when answer.code == 200:
              if (chat(answer.body.firstOrNull, anonymousMode: anonymousMode) case final message?) {
                messages.add(message);
              }
              if (gift(answer.body.firstOrNull, anonymousMode: anonymousMode) case final message?) {
                messages.add(message);
              }
          }
      }
    }
    return LookliveDanmakuFrame(
      messages: messages,
      replies: replies,
      opened: opened,
      joined: joined,
      refusal: refusal,
      kicked: kicked,
      dropped: dropped,
    );
  }

  /// The packets of a frame: one, or those of a `\ufffd`-framed payload
  /// (lengths in UTF-16 units, as in JavaScript).
  static List<String> _payload(String text) {
    if (!text.startsWith('\ufffd')) return [text];
    final packets = <String>[];
    var index = 1;
    while (index < text.length) {
      final end = text.indexOf('\ufffd', index);
      if (end < 0) break;
      final length = int.tryParse(text.substring(index, end));
      if (length == null || length < 0 || end + 1 + length > text.length) break;
      packets.add(text.substring(end + 1, end + 1 + length));
      index = end + 1 + length + 1;
    }
    return packets;
  }

  /// An SDK answer as its service, command, code and response list; a
  /// notification (4-10, 4-11) as the command it wraps (`r[1]
  /// .headerPacket`) with its `body` (the SDK's `parseResponse`).
  static ({int sid, int cid, int? code, List<Object?> body})? _answer(String data) {
    final Object? json;
    try {
      json = jsonDecode(data);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final sid = _int(json['sid']);
    final cid = _int(json['cid']);
    final r = json['r'];
    if (sid == null || cid == null) return null;
    final code = _int(json['code']);
    if (sid == 4 && (cid == 10 || cid == 11)) {
      final wrapped = r is List && r.length > 1 ? r[1] : null;
      if (wrapped is! Map) return null;
      final header = wrapped['headerPacket'];
      final body = wrapped['body'];
      if (header is! Map || body is! List) return null;
      final innerSid = _int(header['sid']);
      final innerCid = _int(header['cid']);
      if (innerSid == null || innerCid == null) return null;
      return (sid: innerSid, cid: innerCid, code: code, body: body);
    }
    return (sid: sid, cid: cid, code: code, body: r is List ? r : const []);
  }

  /// `custom.type` of a gift ([gift]).
  static const int giftType = 102;

  /// A chatroom message (its numbered properties) as white chat, or null
  /// when it is not a chat line the website shows:
  ///
  /// - a text message (`2` is 0) with text (`3`, the SDK's `attach`;
  ///   trimmed) and a `custom` (`4`) JSON object whose `bizName` is `iplay`
  ///   (a short-keyed custom, `sp` 1, is expanded as LOOK's `parseIM` does),
  ///   not held back for a risk level (`content.commonCtrl.riskLevelKey`,
  ///   never granted to a guest) and with a sender (`content.user`): the
  ///   text;
  /// - or LOOK's emoji message (a custom message, `2` is 100, from
  ///   `musiclive_server`, `custom.type` 2601): the emoji's name in
  ///   brackets (`content.emoji`, a JSON text with `name`), as the room page
  ///   writes it next to the image.
  ///
  /// The sender is `content.user`: the name `nickname` (else `nickName`),
  /// masked to its first character and `***` with [anonymousMode], the id
  /// `userId` (else the message's `from`, `21`), the level `liveLevel` and
  /// the fan club's `fanClubLevel` and `fanClubName` (else those of
  /// `fanClubInfo`). The message id is `idClient` (`1`), the time `time`
  /// (`20`, milliseconds).
  static LiveMessage? chat(Object? message, {bool anonymousMode = false}) {
    if (message is! Map) return null;
    final type = _int(message['2']);
    final custom = _custom(message['4']);
    if (custom == null) return null;
    final String text;
    switch (type) {
      case 0:
        text = _text(message['3']);
        if (text.isEmpty || custom['bizName'] != 'iplay') return null;
      case 100 when message['21'] == 'musiclive_server' && _int(custom['type']) == 2601:
        final content = custom['content'];
        final emoji = content is Map ? _custom(content['emoji']) : null;
        final name = emoji == null ? '' : _text(emoji['name']);
        if (name.isEmpty) return null;
        text = '[$name]';
      default:
        return null;
    }
    final content = custom['content'];
    if (content is! Map) return null;
    final control = content['commonCtrl'];
    if (control is Map && _held(control['riskLevelKey'])) return null;
    final user = content['user'];
    if (user is! Map) return null;
    final time = _int(message['20']);
    return LiveMessage.normalized(
      sender: _sender(message, user, anonymousMode: anonymousMode, fansFallback: true),
      text: text,
      color: LiveMessageColor.white,
      messageId: _text(message['1']),
      sentAt: time != null && time > 0 && time <= _maxEpochMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
    );
  }

  /// A gift: a custom message (`2` is 100) whose `custom.type` is
  /// [giftType] with a gift id (`content.giftId`), as a
  /// [LiveMessageType.gift] message with a [LiveGift]; null otherwise.
  ///
  /// - [LiveGift.giftId] `giftId`, [LiveGift.name] `giftName`,
  ///   [LiveGift.count] `number`, [LiveGift.iconUrl] `giftIconUrl` (made
  ///   https);
  /// - [LiveGiftValue.unitPrice] `giftWorth` and
  ///   [LiveGiftValue.totalValue] `giftWorth × number` (LOOK's gift worth
  ///   is its paid currency, written as gold here; `giftValue` and
  ///   `giftCharmRankScore` are the broadcaster's charm points, not read);
  /// - [LiveGift.recipientName] `receiver.nickName` when the gift names
  ///   one;
  /// - the sender, id and time as [chat]'s.
  static LiveMessage? gift(Object? message, {bool anonymousMode = false}) {
    if (message is! Map || _int(message['2']) != 100) return null;
    final custom = _custom(message['4']);
    if (custom == null || _int(custom['type']) != giftType) return null;
    final content = custom['content'];
    if (content is! Map) return null;
    final id = _int(content['giftId']);
    if (id == null || id <= 0) return null;
    final count = _int(content['number']) ?? 1;
    final worth = _int(content['giftWorth']);
    final icon = Uri.tryParse(_text(content['giftIconUrl']));
    final receiver = content['receiver'];
    final user = content['user'] is Map ? content['user'] as Map : const <Object?, Object?>{};
    final time = _int(message['20']);
    final gift = LiveGift(
      giftId: '$id',
      name: _text(content['giftName']),
      iconUrl: icon != null && icon.host.isNotEmpty && (icon.isScheme('http') || icon.isScheme('https'))
          ? '${icon.replace(scheme: 'https')}'
          : null,
      count: count,
      value: LiveGiftValue(
        unit: LiveGiftUnit.note,
        unitPrice: worth != null && worth >= 0 ? worth.toDouble() : null,
        totalValue: worth != null && worth >= 0 ? (worth * max(count, 1)).toDouble() : null,
      ),
      recipientName: receiver is Map ? _text(receiver['nickName']) : '',
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: _sender(message, user, anonymousMode: anonymousMode, fansFallback: false),
      text: '${gift.name} ×${gift.count}',
      color: LiveMessageColor.white,
      messageId: _text(message['1']),
      sentAt: time != null && time > 0 && time <= _maxEpochMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
      payload: gift,
    );
  }

  /// The sender of a message: the name `nickname` (else `nickName`), masked
  /// with [anonymousMode], the id `userId` (else the message's `from`,
  /// `21`), the level `liveLevel` and the fan club's level and name. With
  /// [fansFallback] the fan club falls back to the message's `fanClubInfo`
  /// when the user carries none (the chat line's reading; a gift line reads
  /// the user alone).
  static MessageSender _sender(
    Map<Object?, Object?> message,
    Map<Object?, Object?> user, {
    required bool anonymousMode,
    required bool fansFallback,
  }) {
    var name = _text(user['nickname']);
    if (name.isEmpty) name = _text(user['nickName']);
    if (anonymousMode && name.isNotEmpty) name = '${String.fromCharCode(name.runes.first)}***';
    var userId = _text(user['userId']);
    if (userId.isEmpty) userId = _text(message['21']);
    var fansLevel = _level(user['fanClubLevel']);
    var fansName = _text(user['fanClubName']);
    if (fansFallback) {
      final fanClub = switch (user['fanClubInfo']) {
        final Map<Object?, Object?> info => info,
        _ => const <Object?, Object?>{},
      };
      if (fansLevel.isEmpty) fansLevel = _level(fanClub['fanClubLevel']);
      if (fansName.isEmpty) fansName = _text(fanClub['fanClubName']);
    }
    return MessageSender.normalized(
      userId: userId,
      userName: name,
      userLevel: _level(user['liveLevel']),
      fanBadgeLevel: fansLevel,
      fanBadgeName: fansName,
    );
  }

  /// Whether a message is held back for a risk level the viewer lacks
  /// (LOOK's `onmsgs`: a truthy `riskLevelKey` not in the viewer's
  /// `riskLevel`, which is empty for a guest).
  static bool _held(Object? key) => switch (key) {
    null || false || '' => false,
    final num number => number != 0,
    _ => true,
  };

  /// A `custom` JSON text as an object, expanded when short-keyed (`sp`
  /// 1); null when it is not an object.
  static Map<Object?, Object?>? _custom(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(value);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    return json['sp'] == 1 ? _expandMap(json, _shortKeys) : json;
  }

  /// LOOK's short keys (`encodeIM`'s table, app chunk module `NomM`):
  /// each short key to its name and, for an object, its own table. The URL
  /// fields' host completion is left out: no image is read.
  static const Map<String, (String, Map<String, Object>?)> _shortKeys = {
    'c': (
      'content',
      {
        'ir': ('isRoomManager', null),
        'md': ('msgDisplayInfo', {'f': ('fontInfoId', null), 'b': ('bubbleInfoId', null)}),
        'u': (
          'user',
          {
            'a': ('avatarUrl', null),
            'fa': ('fanClubAnchorId', null),
            'fcl': ('fanClubLevel', null),
            'fcn': ('fanClubName', null),
            'fcp': ('fanClubPrivilege', null),
            'fct': ('fanClubType', null),
            'fcnp': (
              'fanClubNameplate',
              {
                'fa': ('fanClubAnchorId', null),
                'fcl': ('fanClubLevel', null),
                'fcp': ('fanClubPrivilege', null),
                'fct': ('fanClubType', null),
              },
            ),
            'g': ('gender', null),
            'l': ('liveLevel', null),
            'n': ('nickname', null),
            'i': ('userId', null),
            'ni': ('nobleInfo', {'l': ('nobleLevel', null)}),
            'nu': ('numen', {'i': ('numenId', null), 's': ('status', null)}),
            'h': (
              'headFrameInfo',
              {'b': ('bigImgUrl', null), 'c': ('configId', null), 'e': ('endTime', null), 's': ('smallImgUrl', null)},
            ),
            'ut': (
              'userTitle',
              {
                'o': ('isOn', null),
                'c': ('configId', null),
                'e': ('endTime', null),
                'r': ('resourceUrl', null),
                'v': ('visibleType', null),
              },
            ),
            'uut': (
              'unionUserTitle',
              {'t': ('titleType', null), 'e': ('expireTime', null), 's': ('styleText', null), 'u': ('unionId', null)},
            ),
          },
        ),
        'uhc': (
          'userHonorsConfig',
          {
            'i': ('id', null),
            'a': ('appearanceType', null),
            'b': ('backgroundUrl', null),
            'bm': ('bigMedalUrl', null),
            'm': ('medalUrl', null),
            'n': ('name', null),
          },
        ),
        'a': ('attachments', null),
      },
    ),
  };

  /// [value] with its keys renamed by [table] (LOOK's `parseIM`): a key not
  /// in the table keeps its name, and so do the keys below it.
  static Object? _expand(Object? value, Map<String, Object>? table) => switch (value) {
    final List<Object?> list => [for (final item in list) _expand(item, table)],
    final Map<Object?, Object?> map => _expandMap(map, table),
    _ => value,
  };

  static Map<Object?, Object?> _expandMap(Map<Object?, Object?> value, Map<String, Object>? table) =>
      <Object?, Object?>{
        for (final MapEntry(:key, value: item) in value.entries)
          if (table?[key] case (final String name, final Map<String, Object>? below))
            name: _expand(item, below)
          else
            key: _expand(item, null),
      };

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };

  /// A positive level as text, else ''.
  static String _level(Object? value) => switch (_int(value)) {
    final int level when level > 0 => '$level',
    _ => '',
  };

  static String _snippet(String text) {
    final trimmed = text.trim();
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}…';
  }
}
