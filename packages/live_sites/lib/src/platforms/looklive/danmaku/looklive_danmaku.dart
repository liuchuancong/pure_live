import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What one LOOK chat frame held ([LookLiveDanmakuProtocol.decode]).
@immutable
final class LookLiveDanmakuFrame {
  /// Creates the result.
  const new({
    this.messages = const [],
    this.replies = const [],
    this.opened = false,
    this.joined = false,
    this.refusal,
    this.kicked,
    this.dropped = false,
  });

  /// Chat, in order.
  final List<LiveMessage> messages;

  /// What to send back at once: the echo of a socket.io heartbeat (`2::`) and
  /// the ack of a message that asked for one (`6:::<id>`).
  final List<String> replies;

  /// socket.io's connect packet (`1::`): the session is open, log in now.
  final bool opened;

  /// The chatroom accepted the login (command 13-2 with `code` 200).
  final bool joined;

  /// The chatroom refused the login: its `code`; null otherwise.
  final int? refusal;

  /// The chatroom put this client out (command 13-3): the reason; null
  /// otherwise.
  final int? kicked;

  /// The server ended the socket.io session (`0::`) or reported an error
  /// (`7:::`): the socket is to be replaced.
  final bool dropped;
}

/// The anonymous identity one connection logs in with, as the Yunxin SDK makes
/// it for a guest (`nimanon_` and 32 hex digits, a device id and an SDK session
/// of 32 hex digits each).
@immutable
final class LookLiveGuest {
  /// Creates the identity.
  const new({required this.account, required this.deviceId, required this.session});

  /// A new identity from [random] (the SDK's `guid()`: 32 lower-case hex
  /// digits).
  factory random(Random random) {
    String guid() => [for (var i = 0; i < 8; i++) random.nextInt(0x10000).toRadixString(16).padLeft(4, '0')].join();
    return LookLiveGuest(account: 'nimanon_${guid()}', deviceId: guid(), session: guid());
  }

  /// The chatroom account (`nimanon_…`).
  final String account;

  /// The device id.
  final String deviceId;

  /// The SDK session.
  final String session;
}

/// What the LOOK chat connection needs: the room and its Yunxin chatroom id
/// (both from the room's chat-server request) and whether to mask names.
@immutable
final class LookLiveDanmakuArgs {
  /// A chat join target.
  const new({required this.roomId, required this.chatroomId, this.anonymousMode = false});

  /// The room number.
  final String roomId;

  /// The chatroom id, carried as a JSON number in the login.
  final String chatroomId;

  /// Whether to mask sender names as the room page does in anonymous mode.
  final bool anonymousMode;

  @override
  String toString() => 'LookLiveDanmakuArgs($roomId, chatroom $chatroomId)';
}

/// LOOK's chat, without I/O: a NetEase Yunxin (网易云信) chatroom, joined
/// anonymously the way LOOK's website does with the Yunxin web SDK 5.0.1.
///
/// - The room's chat servers are `host:port` each; a guest sends no token.
/// - Every socket is socket.io 0.9: a GET of `/socket.io/1/?t=<ms>` answers
///   `<sid>:<heartbeat>:<close>:<transports>`, then the WebSocket opens at
///   `/socket.io/1/websocket/<sid>`. The server sends `1::` when the session is
///   open and `2::` every 25 s, which the client echoes; data travels in message
///   packets (`3:::<data>`).
/// - The data is the SDK's JSON: commands `{"SID", "CID", "SER", "Q"}`, answers
///   `{"sid", "cid", "ser", "code", "r"}`. Properties go by number.
/// - The client logs in anonymously (13-2) and sends the link heartbeat (1-2)
///   every 3 minutes. Chatroom messages come as notifications (4-10) wrapping
///   13-7.
///
/// Archived from the reference and mapped onto this tree's models: a chat colour
/// is the int white default, a gift keeps name/count/price (no id, icon, receiver
/// or note unit), and a chat line carries no sender level or fan club (no field
/// here).
abstract final class LookLiveDanmakuProtocol {
  /// LOOK's Yunxin app key (the website's public `online.appKey`).
  static const String appKey = '3a6a3e48f6854dfa4e4464f3bdaec3b4';

  /// The SDK's `info.sdkVersion` (web SDK 5.0.1).
  static const String sdkVersion = '47';

  /// The SDK's `info.protocolVersion`.
  static const int protocolVersion = 1;

  /// What the SDK reports as the system and browser on the desktop Chrome the
  /// handshake's user agent names; the server does not check them.
  static const String os = 'Windows 10 64-bit';

  /// See [os].
  static const String browser = 'Chrome 140.0.0.0';

  /// The chatroom name of a guest on LOOK's room page.
  static const String guestNick = '匿名用户';

  /// The chatroom avatar of a guest (the SDK's default, one space).
  static const String guestAvatar = ' ';

  /// The watchdog's tick: the socket is replaced after three silent ticks (90 s;
  /// the server sends `2::` every 25 s).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// Ticks per link heartbeat: 6 × 30 s, the SDK's 180 s.
  static const int ticksPerHeartbeat = 6;

  /// How long the login may take after the socket opened.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Chat server requests per connection: the website asks once more 2 s after a
  /// failure.
  static const int addressAttempts = 2;

  /// See [addressAttempts].
  static const Duration addressRetryDelay = Duration(seconds: 2);

  /// Refused logins in a row that are retried; the next one ends the connection.
  static const int maxRefusals = 3;

  /// Login refusals worth another socket: 408 timeout, 415 no chatroom server,
  /// 500 server error, 503 busy. Any other code ends the connection.
  static const Set<int> retriedRefusals = {408, 415, 500, 503};

  /// The SDK's kick reasons: 1 the chatroom closed, 2 put out by the host or a
  /// manager, 3 the same account elsewhere, 4 silently (reconnect), 5
  /// blacklisted.
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

  /// Web origin and the platform's user agent.
  static const String origin = 'https://look.163.com';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// The room page URL.
  static String roomUrl(String roomId) => '$origin/live?id=$roomId';

  /// Handshake headers of the socket: the website's origin and the platform's
  /// user agent.
  static const Map<String, String> socketHeaders = {'origin': origin, 'user-agent': _userAgent};

  /// socket.io's heartbeat packet, echoed as it arrives.
  static const String socketHeartbeat = '2::';

  /// The link heartbeat (service 1, command 2; serial 0).
  static const String heartbeat = '3:::{"SID":1,"CID":2,"SER":0}';

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  /// The largest chatroom id that stays exact as a JSON number (2^53 − 1).
  static const int _maxChatroomId = 9007199254740991;

  /// Largest [DateTime], in milliseconds.
  static const int _maxEpochMillis = 8640000000000000;

  static final RegExp _chatroomId = RegExp(r'^[1-9][0-9]{0,15}$');
  static final RegExp _sessionId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _packet = RegExp(r'^([^:]+):([0-9]+)?(\+)?:([^:]+)?:?([\s\S]*)$');
  static final RegExp _roomNumber = RegExp(r'^[1-9][0-9]*$');

  /// Whether [value] is a LOOK room number (a positive integer run).
  static bool isRoomNumber(String value) => _roomNumber.hasMatch(value.trim());

  /// [args] trimmed if they name a chat: a room number and a chatroom id that
  /// the login can carry as a number; null otherwise.
  static LookLiveDanmakuArgs? checked(LookLiveDanmakuArgs args) {
    final roomId = args.roomId.trim();
    final chatroomId = args.chatroomId.trim();
    if (!isRoomNumber(roomId) || !_chatroomId.hasMatch(chatroomId) || int.parse(chatroomId) > _maxChatroomId) {
      return null;
    }
    return LookLiveDanmakuArgs(roomId: roomId, chatroomId: chatroomId, anonymousMode: args.anonymousMode);
  }

  /// The socket of each chat server (`host:port`):
  /// `wss://<host>:<port>/socket.io/1/websocket/`, to which the handshake
  /// appends the session id. The SDK tries them in order.
  static List<Uri> endpoints(List<String> addresses) => [
    for (final address in addresses) Uri.parse('wss://$address/socket.io/1/websocket/'),
  ];

  /// The session id of a handshake [text] of the form
  /// ``sid:heartbeat:close:transports`` (colon-separated). A [status] other
  /// than 200, an id that does not fit a URL path segment, or transports
  /// without `websocket` throw [FormatException].
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

  /// The anonymous chatroom login (service 13, command 2) with serial [serial]
  /// for [chatroomId] as [guest]. [again] is a login after a reconnect: the
  /// chatroom `appLogin` is 1 and the IM one 0.
  static String login({
    required String chatroomId,
    required LookLiveGuest guest,
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

  /// One frame (text, or UTF-8 bytes): one socket.io packet, or several framed
  /// as `\ufffd<length>\ufffd<packet>…` (socket.io 0.9's `decodePayload`).
  ///
  /// - `1::` opens the session; `2::` is echoed; `0::` and `7:::…` drop the
  ///   socket; a message packet with an id and no `+` is acked (`6:::<id>`).
  /// - A message's data is an SDK answer: the login's (13-2), a kick (13-3), a
  ///   chatroom message (13-7), or a notification (4-10, 4-11) wrapping one.
  /// - Anything unreadable is skipped.
  static LookLiveDanmakuFrame decode(Object? data, {bool anonymousMode = false}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return const LookLiveDanmakuFrame();
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
    return LookLiveDanmakuFrame(
      messages: messages,
      replies: replies,
      opened: opened,
      joined: joined,
      refusal: refusal,
      kicked: kicked,
      dropped: dropped,
    );
  }

  /// The packets of a frame: one, or those of a `\ufffd`-framed payload (lengths
  /// in UTF-16 units, as in JavaScript).
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
  /// notification (4-10, 4-11) as the command it wraps with its body.
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

  /// A chatroom message (its numbered properties) as white chat, or null when it
  /// is not a chat line the website shows: a text message (`2` is 0) with text
  /// (`3`) and a `custom` (`4`) JSON whose `bizName` is `iplay` and a sender in
  /// `content.user`, not held for a risk level; or LOOK's emoji message (`2` is
  /// 100, from `musiclive_server`, `custom.type` 2601), the emoji's name in
  /// brackets. The name is masked to `X***` with [anonymousMode]. The message id
  /// is `idClient` (`1`), the time `time` (`20`, milliseconds).
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
    var name = _text(user['nickname']);
    if (name.isEmpty) name = _text(user['nickName']);
    if (anonymousMode && name.isNotEmpty) name = '${String.fromCharCode(name.runes.first)}***';
    var userId = _text(user['userId']);
    if (userId.isEmpty) userId = _text(message['21']);
    final time = _int(message['20']);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name,
      userId: userId,
      message: text,
      color: defaultColor,
      id: _text(message['1']),
      sentAt: time != null && time > 0 && time <= _maxEpochMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
    );
  }

  /// `custom.type` of a gift.
  static const int giftType = 102;

  /// A gift: a custom message (`2` is 100) whose `custom.type` is [giftType]
  /// with a gift id (`content.giftId`). The name, count and worth map onto
  /// [LiveGift] (the note currency is this tree's gold unit); the icon, receiver
  /// and sender level have no field here.
  static LiveMessage? gift(Object? message, {bool anonymousMode = false}) {
    if (message is! Map || _int(message['2']) != 100) return null;
    final custom = _custom(message['4']);
    if (custom == null || _int(custom['type']) != giftType) return null;
    final content = custom['content'];
    if (content is! Map) return null;
    final id = _int(content['giftId']);
    if (id == null || id <= 0) return null;
    final count = max(_int(content['number']) ?? 1, 1);
    final worth = _int(content['giftWorth']);
    final name = _text(content['giftName']);
    final user = content['user'] is Map ? content['user'] as Map : const <Object?, Object?>{};
    var sender = _text(user['nickname']);
    if (sender.isEmpty) sender = _text(user['nickName']);
    if (anonymousMode && sender.isNotEmpty) sender = '${String.fromCharCode(sender.runes.first)}***';
    var userId = _text(user['userId']);
    if (userId.isEmpty) userId = _text(message['21']);
    final time = _int(message['20']);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: sender,
      userId: userId,
      message: '$name ×$count',
      color: defaultColor,
      id: _text(message['1']),
      sentAt: time != null && time > 0 && time <= _maxEpochMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
      data: LiveGift(
        name: name,
        count: count,
        unitPrice: worth != null && worth >= 0 ? worth : 0,
        totalValue: worth != null && worth >= 0 ? worth * count : null,
      ),
    );
  }

  /// Whether a message is held back for a risk level the viewer lacks (a truthy
  /// `riskLevelKey`, which is never granted to a guest).
  static bool _held(Object? key) => switch (key) {
    null || false || '' => false,
    final num number => number != 0,
    _ => true,
  };

  /// A `custom` JSON text as an object, expanded when short-keyed (`sp` 1); null
  /// when it is not an object.
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

  /// LOOK's short keys (`encodeIM`'s table): each short key to its name and, for
  /// an object, its own table.
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

  /// [value] with its keys renamed by [table]: a key not in the table keeps its
  /// name, and so do the keys below it.
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

  static String _snippet(String text) {
    final trimmed = text.trim();
    return trimmed.length <= 80 ? trimmed : '${trimmed.substring(0, 80)}…';
  }
}
