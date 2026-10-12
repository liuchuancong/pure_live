import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show md5;
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_parser.dart';
import 'package:meta/meta.dart';

/// The anonymous visitor a Bigo chat socket logs in as, from the website's
/// `studio/getWebSocketLink`.
@immutable
final class BigoChatVisitor {
  /// Creates the visitor.
  const new({required this.userId, required this.token, required this.deviceId, this.userName = '0'});

  /// `userId`: the visitor's account, digits.
  final String userId;

  /// `uidToken` without the `###VER2` marker: the login's `cookie`. Never
  /// logged.
  final String token;

  /// `userName` (`0` for a visitor).
  final String userName;

  /// `deviceId`: the device the visitor was issued for.
  final String deviceId;

  @override
  String toString() => 'BigoChatVisitor($userId)';
}

/// The sender a gift line (`payload.tag` 6) names: the account, the name and
/// the level. The level has no field in this tree and is kept only to name the
/// gift.
typedef BigoGiftSender = ({String userId, String name});

/// What one Bigo chat frame held ([BigoDanmakuProtocol.decode]).
@immutable
final class BigoDanmakuFrame {
  /// Creates the result.
  const new({
    this.messages = const [],
    this.challenge,
    this.loggedIn = false,
    this.entered = false,
    this.idle = false,
    this.refusal,
    this.giftSender,
  });

  /// Chat, gifts and audience updates, in order.
  final List<LiveMessage> messages;

  /// The server's challenge (uri 256), which the client answers before it
  /// logs in; null otherwise.
  final String? challenge;

  /// The login was accepted (uri 512535, `res` "200").
  final bool loggedIn;

  /// The room was entered and has a broadcast (uri 1560, `resCode` "200").
  final bool entered;

  /// The room was entered but has no broadcast (`resCode` "200" with `sid`
  /// "0"): an offline or unknown room.
  final bool idle;

  /// Why the server refused the login or the room (`unsigned`, `login`,
  /// `enter`); null otherwise.
  final String? refusal;

  /// The sender a gift line names; it follows the gift's animation, which
  /// names nobody.
  final BigoGiftSender? giftSender;
}

/// Bigo Live's web chat, without I/O: a decimal uri then a JSON object per
/// frame, joined as an anonymous visitor the way the website's player does.
///
/// - On the socket the server first sends a challenge (256); the client
///   answers it (79108), logs in a second later (`2001|23`) and pings every
///   10 s from then on (`3|23`). An accepted login (`2002|23`) is followed by
///   entering the room (`5|24`); an accepted entry (`6|24`) by asking the
///   room's audience (`42|24`).
/// - Chat arrives as `10|24` (`NORMAL_TEXT`): `payload.tag` 1 a comment, 2 a
///   paid bullet comment, whose `payload.content` is Base64 of UTF-8 JSON with
///   the name `n` and text `m`. The audience arrives as `40|24` and in the
///   `43|24` answer.
///
/// Mapped onto this tree's models: a gift is a [LiveGift] of its name and count
/// (no id, combo total, bean total or price — the gift table is not asked for);
/// a level has no field; colour is an int and a message id is `id`; the
/// audience is one [LiveAudienceUpdate].
abstract final class BigoDanmakuProtocol {
  /// The chat socket.
  static final Uri endpoint = Uri.parse('wss://wss.bigolive.tv/live/official/web');

  /// Where the page gets its visitor account.
  static final Uri linkUrl = Uri.https('ta.bigo.tv', '/official_website/studio/getWebSocketLink');

  /// Handshake headers: the website's origin and the browser user agent.
  static Map<String, String> get socketHeaders => {
    'origin': BigoParser.origin,
    'user-agent': BigoParser.headers['user-agent']!,
  };

  /// Ping period.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How long after the socket opened the room must be entered.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Wait between answering the challenge and logging in.
  static const Duration loginDelay = Duration(seconds: 1);

  // The frame uris, the page's `toUri("high|low") = high << 8 | low`.
  static const int _challengeUri = 256; // 1|0
  static const int _answerUri = 79108;
  static const int _loginUri = 512279; // 2001|23
  static const int _loginReplyUri = 512535; // 2002|23
  static const int _enterUri = 1304; // 5|24
  static const int _enterReplyUri = 1560; // 6|24
  static const int _usersUri = 10776; // 42|24
  static const int _usersReplyUri = 11032; // 43|24
  static const int _textUri = 2584; // 10|24
  static const int _audienceUri = 10264; // 40|24
  static const int _pingUri = 791; // 3|23

  /// `payload.tag` values that are chat.
  static const Set<int> chatTags = {1, 2};

  /// The `oriUri` of a gift's animation in a `10|24` frame.
  static const String giftOriUri = '760969';

  /// The `payload.tag` of the chat list's line naming a gift's sender.
  static const int giftLineTag = 6;

  /// How long a gift waits for its line's sender name.
  static const Duration giftSenderWait = Duration(seconds: 1);

  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{0,19}$');
  static final RegExp _digits = RegExp(r'^[0-9]{1,20}$');
  static final RegExp _token = RegExp(r'^[!-~]{1,4096}$');
  static final RegExp _siteId = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$');

  /// Whether [value] is a Bigo id.
  static bool isSiteId(String value) => _siteId.hasMatch(value.trim());

  /// A device id as the page makes one for a new browser.
  static String deviceId(Random random, DateTime now) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final hash = [for (var i = 0; i < 32; i++) random.nextInt(16).toRadixString(16)].join();
    final tag = [for (var i = 0; i < 6; i++) alphabet[random.nextInt(alphabet.length)]].join();
    return 'web_${hash}_${tag}_${now.millisecondsSinceEpoch}';
  }

  /// The form fields of the page's `getWebSocketLink({deviceId})`.
  static Map<String, String> linkFields(String deviceId) => {'deviceId': deviceId};

  /// The visitor of a `getWebSocketLink` body: HTTP 200, `code` 0, a `userId`
  /// of digits and a usable `uidToken`; a [FormatException] otherwise.
  static BigoChatVisitor visitor(String body, {required int status, required String deviceId}) {
    if (status != 200) throw FormatException('getWebSocketLink: HTTP $status');
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw const FormatException('getWebSocketLink: not JSON');
    }
    if (root is! Map || root['code'] != 0) {
      throw FormatException('getWebSocketLink: code ${root is Map ? root['code'] : null}');
    }
    final data = root['data'];
    final userId = data is Map ? data['userId'] : null;
    final rawToken = data is Map ? data['uidToken'] : null;
    final token = rawToken is String ? rawToken.replaceAll('###VER2', '') : null;
    if (data is! Map || userId is! String || !_digits.hasMatch(userId) || token == null || !_token.hasMatch(token)) {
      throw const FormatException('getWebSocketLink: no visitor');
    }
    final name = data['userName'];
    final device = data['deviceId'];
    return BigoChatVisitor(
      userId: userId,
      token: token,
      userName: name is String && _token.hasMatch(name) ? name : '0',
      deviceId: device is String && _token.hasMatch(device) ? device : deviceId,
    );
  }

  /// [siteId], [ownerId] and [roomId] if they name a room: a Bigo id, an owner
  /// account (1 … 2⁵³ − 1) and a room id of up to 20 digits; null otherwise.
  static ({String siteId, int ownerId, String roomId})? checked({
    required String siteId,
    required int ownerId,
    required String roomId,
  }) {
    final site = siteId.trim();
    final room = roomId.trim();
    if (!isSiteId(site) || ownerId < 1 || ownerId > 9007199254740991 || !_roomId.hasMatch(room)) return null;
    return (siteId: site, ownerId: ownerId, roomId: room);
  }

  /// The answer to [challenge] at [now] (the page's `generateChallengeKey`):
  /// fixed fields, the time in seconds, and `sign`, the MD5 of
  /// `60#4#5#<time>#1#1#1#1#<the challenge's last 8 characters>`.
  static String answer(String challenge, DateTime now) {
    final time = '${now.millisecondsSinceEpoch ~/ 1000}';
    final tail = challenge.length > 8 ? challenge.substring(challenge.length - 8) : challenge;
    final sign = md5.convert(utf8.encode('60#4#5#$time#1#1#1#1#$tail')).toString();
    return '$_answerUri${jsonEncode({'appId': '60', 'osType': '4', 'clientVersion': '5', 'timeStamp': time, 'nonce': '1', 'reservedForSecurity': '1', 'appSign': '1', 'redundancy': '1', 'sign': sign})}';
  }

  /// The login of [visitor] (client type 7, no client address).
  static String login(BigoChatVisitor visitor) =>
      '$_loginUri${jsonEncode({
        'uid': visitor.userId,
        'cookie': visitor.token,
        'secret': '0',
        'userName': visitor.userName,
        'deviceId': visitor.deviceId,
        'userFlag': '0',
        'status': '0',
        'password': '0',
        'sdkVersion': '0',
        'displayType': '0',
        'pbVersion': '0',
        'lang': 'cn',
        'loginLevel': '0',
        'clientVersionCode': '0',
        'clientType': '7',
        'clientOsVer': '0',
        'netConf': {'clientIp': '0', 'proxySwitch': '0', 'proxyTimestamp': '0', 'mcc': '0', 'mnc': '0', 'countryCode': 'CN'},
      })}';

  /// Entering room [roomId] at [now] (without a password).
  static String enter(String roomId, BigoChatVisitor visitor, DateTime now) =>
      '$_enterUri${jsonEncode({'secretKey': '0', 'seqId': '${now.millisecondsSinceEpoch}', 'roomId': roomId, 'reserver': '1', 'clientVersion': '0', 'clientType': '7', 'version': '15', 'deviceid': visitor.deviceId, 'other': <Object>[]})}';

  /// Asking the audience of the room at [now].
  static String users(int ownerId, String roomId, DateTime now) =>
      '$_usersUri${jsonEncode({'uid': '$ownerId', 'seqId': '${now.millisecondsSinceEpoch}', 'roomid': roomId, 'contribution': '0', 'enterTimestamp': '0', 'number': '0', 'ident': '0', 'userGrade': '0', 'version': '0', 'lastUserBeanGrade': '0', 'lastUserId': '0', 'others': <Object>[]})}';

  /// The ping at [now].
  static String ping(DateTime now) =>
      '$_pingUri${jsonEncode({'status': '0', 'seqid': '${now.millisecondsSinceEpoch}', 'flag': '0', 'roomId': '0', 'ownerStatus': '0', 'micUid': '0'})}';

  /// One frame of room [roomId]: everything up to the first `{` is the uri,
  /// the rest one JSON object. An `info` "unsigned" or an `errUri` is a
  /// refusal; 256 is the challenge; 512535 the login answer; 1560 the entry
  /// answer (idle when `sid` is "0"); 2584 chat / gift / gift sender; 10264 and
  /// 11032 the audience. Every other frame gives nothing.
  static BigoDanmakuFrame decode(Object? data, {required String roomId}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    final brace = text?.indexOf('{') ?? -1;
    if (text == null || brace < 0) return const BigoDanmakuFrame();
    final Object? body;
    try {
      body = jsonDecode(text.substring(brace));
    } on FormatException {
      return const BigoDanmakuFrame();
    }
    if (body is! Map) return const BigoDanmakuFrame();
    final errUri = body['errUri'];
    if (body['info'] == 'unsigned' || (errUri != null && errUri != '' && errUri != 0 && errUri != false)) {
      return BigoDanmakuFrame(refusal: 'unsigned: ${_scalar(errUri)}');
    }
    final uri = int.tryParse(text.substring(0, brace).replaceAll(RegExp(r'[\s\x00]'), ''));
    switch (uri) {
      case _challengeUri:
        final challenge = body['challenge'];
        return challenge is String && challenge.isNotEmpty
            ? BigoDanmakuFrame(challenge: challenge)
            : const BigoDanmakuFrame();
      case _loginReplyUri:
        final res = body['res'];
        return res == '200'
            ? const BigoDanmakuFrame(loggedIn: true)
            : BigoDanmakuFrame(refusal: 'login: res ${_scalar(res)}');
      case _enterReplyUri:
        final code = body['resCode'];
        if (code != '200') return BigoDanmakuFrame(refusal: 'enter: resCode ${_scalar(code)}');
        final sid = _scalar(body['sid']);
        return sid.isEmpty || sid == '0' ? const BigoDanmakuFrame(idle: true) : const BigoDanmakuFrame(entered: true);
      case _textUri:
        if (_scalar(body['oriUri']) == giftOriUri) {
          final present = gift(body, roomId: roomId);
          return present == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [present]);
        }
        if (giftLine(body, roomId: roomId) case final sender?) return BigoDanmakuFrame(giftSender: sender);
        final message = chat(body, roomId: roomId);
        return message == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [message]);
      case _audienceUri:
      case _usersReplyUri:
        final message = audience(body, uri: uri!, roomId: roomId);
        return message == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [message]);
      default:
        return const BigoDanmakuFrame();
    }
  }

  /// A `10|24` broadcast of room [roomId] as white chat, or null. `payload.tag`
  /// 1 or 2; `payload.content` is Base64 of UTF-8 JSON (name `n`, text `m`); the
  /// user id `payload.uid` (else `from_uid`); the id `<user id>:<seqId>`. A
  /// level has no field here. No time (`payload.timestamp` is "0").
  static LiveMessage? chat(Map<Object?, Object?> frame, {required String roomId}) {
    if (_scalar(frame['room_id']) != roomId) return null;
    final payload = frame['payload'];
    if (payload is! Map) return null;
    final tag = int.tryParse(_scalar(payload['tag']));
    final content = payload['content'];
    if (tag == null || !chatTags.contains(tag) || content is! String) return null;
    final decoded = _base64Json(content);
    if (decoded == null) return null;
    final text = _scalar(decoded['m']).trim();
    if (text.isEmpty) return null;
    final userId = _digitsValue(payload['uid']) ?? _digitsValue(frame['from_uid']) ?? '';
    final seq = _scalar(frame['seqId']);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _scalar(decoded['n']).trim(),
      userId: userId,
      message: text,
      id: userId.isNotEmpty && _digits.hasMatch(seq) ? '$userId:$seq' : null,
      color: 0xFFFFFF,
    );
  }

  /// A gift's animation in a `10|24` frame of room [roomId]: name, count and
  /// the sender's account (`from_uid`, no name — the gift line that follows
  /// names them). The message id is `<account>:<seqId>`. Null for another room
  /// or without a name. This tree has no gift id, combo total, bean total or
  /// price.
  static LiveMessage? gift(Map<Object?, Object?> frame, {required String roomId}) {
    final payload = frame['payload'];
    if (payload is! Map) return null;
    final room = _scalar(payload['room_id']);
    if ((room.isEmpty ? _scalar(frame['room_id']) : room) != roomId) return null;
    final name = _scalar(payload['vgift_name']).trim();
    if (name.isEmpty) return null;
    final count = _positive(payload['vgift_count']) ?? 1;
    final userId = _digitsValue(payload['from_uid']) ?? _digitsValue(frame['from_uid']) ?? '';
    final seq = _scalar(frame['seqId']);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: '',
      userId: userId,
      message: '$name ×$count',
      id: userId.isNotEmpty && _digits.hasMatch(seq) ? '$userId:$seq' : null,
      color: 0xFFFFFF,
      data: LiveGift(name: name, count: count),
    );
  }

  /// The sender of the chat list's gift line (`payload.tag` 6 of a `10|24`
  /// frame of room [roomId]): the account, and the name of the Base64 JSON
  /// `content`. Null for anything else or without an account.
  static BigoGiftSender? giftLine(Map<Object?, Object?> frame, {required String roomId}) {
    if (_scalar(frame['room_id']) != roomId) return null;
    final payload = frame['payload'];
    if (payload is! Map || int.tryParse(_scalar(payload['tag'])) != giftLineTag) return null;
    final userId = _digitsValue(payload['uid']) ?? _digitsValue(frame['from_uid']);
    if (userId == null) return null;
    var name = '';
    if (payload['content'] is String) {
      final decoded = _base64Json(payload['content'] as String);
      if (decoded != null) name = _scalar(decoded['n']).trim();
    }
    return (userId: userId, name: name);
  }

  /// The concurrent audience of room [roomId] in a `40|24` frame
  /// (`totalUserCount`, when `gid` is the room) or the `43|24` answer (`total`,
  /// when `room_id` is the room); null otherwise.
  static LiveMessage? audience(Map<Object?, Object?> frame, {required int uri, required String roomId}) {
    final (room, count) = uri == _audienceUri
        ? (frame['gid'], frame['totalUserCount'])
        : (frame['room_id'], frame['total']);
    if (_scalar(room) != roomId) return null;
    final text = _scalar(count);
    final value = int.tryParse(text);
    if (value == null || value < 0 || !_digits.hasMatch(text)) return null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      data: LiveAudienceUpdate(onlineViewers: value),
    );
  }

  static Map<Object?, Object?>? _base64Json(String content) {
    try {
      final decoded = jsonDecode(utf8.decode(base64.decode(base64.normalize(content.trim()))));
      return decoded is Map<Object?, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String? _digitsValue(Object? value) {
    final text = _scalar(value);
    return _digits.hasMatch(text) ? text : null;
  }

  static int? _positive(Object? value) {
    final text = _scalar(value);
    final count = _digits.hasMatch(text) ? int.tryParse(text) : null;
    return count != null && count > 0 ? count : null;
  }

  static String _scalar(Object? value) => switch (value) {
    final String text => text,
    final int number => '$number',
    _ => '',
  };
}
