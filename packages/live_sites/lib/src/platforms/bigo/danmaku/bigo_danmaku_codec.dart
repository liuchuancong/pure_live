import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_endpoints.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_chat_visitor.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The sender of a gift, as the chat list's gift line names them: the account,
/// the name and the level.
typedef BigoGiftSender = ({String userId, String name, String level});

/// What one bigo chat frame held.
final class BigoDanmakuFrame {
  /// Creates the result.
  const BigoDanmakuFrame({
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

  /// The server's challenge (uri 256), which the client answers before it logs
  /// in; null otherwise.
  final String? challenge;

  /// The login was accepted (uri 512535, `res` "200").
  final bool loggedIn;

  /// The room was entered and has a broadcast (uri 1560, `resCode` "200").
  final bool entered;

  /// The room was entered but has no broadcast (`resCode` "200" with `sid` "0":
  /// an offline or unknown room).
  final bool idle;

  /// Why the server refused the login or the room: `login: res …`, `enter:
  /// resCode …`, or `unsigned: …` with the refused uri (a login sent before the
  /// challenge was answered); null otherwise.
  final String? refusal;

  /// The sender a gift line (`payload.tag` 6) names; it follows the gift's
  /// animation, which names nobody.
  final BigoGiftSender? giftSender;
}

/// Bigo Live's web chat, as the website's scripts of 2026-09-30 speak it,
/// without I/O.
///
/// - Every frame is text: a decimal uri, then a JSON object. The client writes
///   them back to back (`791{…}`); the server puts a tab between them
///   (`791\t{…}`). A uri is the page's `toUri("a|b")`, `a << 8 | b` ([uri]).
/// - A visitor account comes from `studio/getWebSocketLink` ([visitor]). On the
///   socket ([endpoint]) the server first sends a challenge (256); the client
///   answers it (79108, [answer]), logs in a second later (`2001|23`, [login])
///   and pings every 10 s from then on (`3|23`, [ping]). An accepted login
///   (`2002|23`) is followed by entering the room (`5|24`, [enter]); an accepted
///   entry (`6|24`) by asking the room's audience (`42|24`, [users]).
/// - Chat arrives as `10|24` (`NORMAL_TEXT`): `payload.tag` 1 is a comment, 2 a
///   paid bullet comment, whose `payload.content` is Base64 of UTF-8 JSON with
///   the name `n` and the text `m`. The audience arrives as `40|24` (`NUMS`,
///   `totalUserCount`) and in the `43|24` answer (`total`).
abstract final class BigoDanmakuCodec {
  /// The chat socket of `www.bigo.tv`.
  static final Uri endpoint = Uri.parse('wss://${BigoEndpoints.chatHost}/live/official/web');

  /// Where the page gets its visitor account.
  static final Uri linkUrl = BigoEndpoints.chatLink();

  /// Handshake headers: the website's origin and the browser user agent (the
  /// server also accepts a handshake without an origin).
  static const Map<String, String> socketHeaders = {
    'origin': BigoEndpoints.webOrigin,
    'user-agent': BigoEndpoints.userAgent,
  };

  /// Ping period (the page's `setInterval(doPing, 1e4)`).
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How long after the socket opened the room must be entered: the challenge,
  /// the page's one-second wait, the login and the entry took 1.4 to 2.5 s in
  /// every session of 2026-09-30.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Wait between answering the challenge and logging in (the page's
  /// `setTimeout(…, 1e3)`).
  static const Duration loginDelay = Duration(seconds: 1);

  /// A socket quieter than this is replaced (the runtime's default silence
  /// watchdog).
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// Refused or unanswered joins in a row after which the connection gives up.
  static const int maxRefusals = 3;

  /// Failed reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// How long a gift waits for its line's sender name: the line came 75 ms after
  /// the animation in the recorded live session.
  static const Duration giftSenderWait = Duration(seconds: 1);

  /// The page's `toUri("high|low")`.
  static int uri(int high, int low) => high << 8 | low;

  /// The server's challenge (`Challenge_KEY`).
  static const int challengeUri = 256;

  /// The client's answer (`Challenge`).
  static const int answerUri = 79108;

  /// Login, `2001|23`.
  static const int loginUri = 512279;

  /// Login answer, `2002|23`.
  static const int loginReplyUri = 512535;

  /// Enter the room, `5|24`.
  static const int enterUri = 1304;

  /// Entry answer, `6|24`.
  static const int enterReplyUri = 1560;

  /// Ask the room's audience, `42|24`.
  static const int usersUri = 10776;

  /// Its answer, `43|24`.
  static const int usersReplyUri = 11032;

  /// Room broadcasts, chat among them, `10|24`.
  static const int textUri = 2584;

  /// Audience changes, `40|24`.
  static const int audienceUri = 10264;

  /// Ping and its answer, `3|23`.
  static const int pingUri = 791;

  /// `payload.tag` values that are chat: a comment and a paid bullet comment.
  static const Set<int> chatTags = {1, 2};

  /// The `oriUri` of a gift's animation in a `10|24` frame.
  static const String giftOriUri = '760969';

  /// The `payload.tag` of the chat list's line for a gift: it names the sender.
  static const int giftLineTag = 6;

  static final RegExp _digits = RegExp(r'^[0-9]{1,20}$');
  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{0,19}$');

  /// Printable ASCII without spaces: the token and the device id go into a JSON
  /// frame.
  static final RegExp _printable = RegExp(r'^[!-~]{1,4096}$');

  /// A device id as the page makes one for a new browser: `web_`, 32 hex digits
  /// (its fingerprint hash), 6 letters or digits, the time in milliseconds.
  static String deviceId(Random random, DateTime now) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final hash = [for (var i = 0; i < 32; i++) random.nextInt(16).toRadixString(16)].join();
    final tag = [for (var i = 0; i < 6; i++) alphabet[random.nextInt(alphabet.length)]].join();
    return 'web_${hash}_${tag}_${now.millisecondsSinceEpoch}';
  }

  /// The body of the `getWebSocketLink` request for [deviceId].
  static Map<String, String> linkFields(String deviceId) => {'deviceId': deviceId};

  /// The visitor of a `getWebSocketLink` answer: HTTP 200, `code` 0, a `userId`
  /// of digits and a usable `uidToken`; a [FormatException] otherwise. [deviceId]
  /// stands in when the answer names none.
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
    if (data is! Map ||
        userId is! String ||
        !_digits.hasMatch(userId) ||
        token == null ||
        !_printable.hasMatch(token)) {
      throw const FormatException('getWebSocketLink: no visitor');
    }
    final name = data['userName'];
    final device = data['deviceId'];
    return BigoChatVisitor(
      userId: userId,
      token: token,
      userName: name is String && _printable.hasMatch(name) ? name : '0',
      deviceId: device is String && _printable.hasMatch(device) ? device : deviceId,
    );
  }

  /// Whether [args] name a room: a Bigo id, an owner account (1 … 2⁵³ − 1) and a
  /// room id of up to 20 digits; false otherwise.
  static bool checks(BigoDanmakuArgs args) {
    final siteId = args.siteId.trim();
    final roomId = args.roomId.trim();
    if (!BigoRoomParser.isSiteId(siteId) || args.ownerId < 1 || args.ownerId > 9007199254740991) return false;
    return _roomId.hasMatch(roomId);
  }

  /// The answer to [challenge] at [now] (the page's `generateChallengeKey`):
  /// fixed fields, the time in seconds, and `sign`, the MD5 of
  /// `60#4#5#<time>#1#1#1#1#<the challenge's last 8 characters>`.
  static String answer(String challenge, DateTime now) {
    final time = '${now.millisecondsSinceEpoch ~/ 1000}';
    final tail = challenge.length > 8 ? challenge.substring(challenge.length - 8) : challenge;
    final sign = md5.convert(utf8.encode('60#4#5#$time#1#1#1#1#$tail')).toString();
    return '$answerUri${jsonEncode({'appId': '60', 'osType': '4', 'clientVersion': '5', 'timeStamp': time, 'nonce': '1', 'reservedForSecurity': '1', 'appSign': '1', 'redundancy': '1', 'sign': sign})}';
  }

  /// The login of [visitor] (the page's `doLogin` for a visitor: client type 7,
  /// no client address).
  static String login(BigoChatVisitor visitor) =>
      '$loginUri${jsonEncode({
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

  /// Entering room [roomId] at [now] (the page's `enterRoom` without a password:
  /// `secretKey` "0").
  static String enter(String roomId, BigoChatVisitor visitor, DateTime now) =>
      '$enterUri${jsonEncode({'secretKey': '0', 'seqId': '${now.millisecondsSinceEpoch}', 'roomId': roomId, 'reserver': '1', 'clientVersion': '0', 'clientType': '7', 'version': '15', 'deviceid': visitor.deviceId, 'other': <Object>[]})}';

  /// Asking the audience of [args]'s room at [now] (the page's
  /// `pullChatRoomUser`).
  static String users(BigoDanmakuArgs args, DateTime now) =>
      '$usersUri${jsonEncode({'uid': '${args.ownerId}', 'seqId': '${now.millisecondsSinceEpoch}', 'roomid': args.roomId, 'contribution': '0', 'enterTimestamp': '0', 'number': '0', 'ident': '0', 'userGrade': '0', 'version': '0', 'lastUserBeanGrade': '0', 'lastUserId': '0', 'others': <Object>[]})}';

  /// The ping at [now] (the page's `doPing`).
  static String ping(DateTime now) =>
      '$pingUri${jsonEncode({'status': '0', 'seqid': '${now.millisecondsSinceEpoch}', 'flag': '0', 'roomId': '0', 'ownerStatus': '0', 'micUid': '0'})}';

  /// One frame (text, or UTF-8 bytes) of room [roomId], read as the page's
  /// `onmessage` and the room page's subscriptions read it:
  ///
  /// - everything up to the first `{` is the uri (white space and NUL ignored),
  ///   the rest one JSON object; anything else gives nothing;
  /// - an object with `info` "unsigned" or an `errUri` is a refusal, whatever its
  ///   uri;
  /// - 256 is the challenge; 512535 the login answer (`res` "200" logs in,
  ///   anything else is a refusal); 1560 the entry answer (`resCode` "200"
  ///   enters, or finds the room idle when `sid` is "0"; anything else is a
  ///   refusal);
  /// - 2584 of this room is chat when [chat] reads it, a gift when its `oriUri`
  ///   is [giftOriUri] ([gift]), a gift's sender when it is the gift line
  ///   ([giftLine]); 10264 and 11032 of this room are the audience ([audience]);
  /// - every other frame (pings, likes, entrance notices, the room's heat,
  ///   seats) gives nothing.
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
      case challengeUri:
        final challenge = body['challenge'];
        return challenge is String && challenge.isNotEmpty
            ? BigoDanmakuFrame(challenge: challenge)
            : const BigoDanmakuFrame();
      case loginReplyUri:
        final res = body['res'];
        return res == '200'
            ? const BigoDanmakuFrame(loggedIn: true)
            : BigoDanmakuFrame(refusal: 'login: res ${_scalar(res)}');
      case enterReplyUri:
        final code = body['resCode'];
        if (code != '200') return BigoDanmakuFrame(refusal: 'enter: resCode ${_scalar(code)}');
        final sid = _scalar(body['sid']);
        return sid.isEmpty || sid == '0' ? const BigoDanmakuFrame(idle: true) : const BigoDanmakuFrame(entered: true);
      case textUri:
        if (_scalar(body['oriUri']) == giftOriUri) {
          final present = gift(body, roomId: roomId);
          return present == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [present]);
        }
        if (giftLine(body, roomId: roomId) case final sender?) return BigoDanmakuFrame(giftSender: sender);
        final message = chat(body, roomId: roomId);
        return message == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [message]);
      case audienceUri || usersReplyUri:
        final message = audience(body, uri: uri!, roomId: roomId);
        return message == null ? const BigoDanmakuFrame() : BigoDanmakuFrame(messages: [message]);
      default:
        return const BigoDanmakuFrame();
    }
  }

  /// A `10|24` broadcast of room [roomId] as white chat, or null:
  ///
  /// - `room_id` is the room; `payload.tag` is 1 (comment) or 2 (a paid bullet
  ///   comment, shown as a comment as the page's chat list does);
  /// - `payload.content` is Base64 of UTF-8 JSON; one that does not decode is
  ///   dropped, as the page drops it;
  /// - the text is `m` trimmed (null when empty), the name `n` trimmed;
  /// - the user id is `payload.uid` (else `from_uid`), the level `payload.grade`;
  /// - the message id is `<user id>:<seqId>` (the server resent a message
  ///   unchanged, same `seqId`, on 2026-09-30);
  /// - no time: `payload.timestamp` is "0" in every recorded comment.
  static LiveMessage? chat(Map<Object?, Object?> frame, {required String roomId}) {
    if (_scalar(frame['room_id']) != roomId) return null;
    final payload = frame['payload'];
    if (payload is! Map) return null;
    final tag = int.tryParse(_scalar(payload['tag']));
    final content = payload['content'];
    if (tag == null || !chatTags.contains(tag) || content is! String) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(base64.decode(base64.normalize(content.trim()))));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final text = _scalar(decoded['m']).trim();
    if (text.isEmpty) return null;
    final userId = _userId(payload['uid'], frame['from_uid']);
    final level = _scalar(payload['grade']);
    final seq = _scalar(frame['seqId']);
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: userId,
        userName: _scalar(decoded['n']).trim(),
        userLevel: _digits.hasMatch(level) ? level : '',
      ),
      text: text,
      color: LiveMessageColor.white,
      messageId: userId.isNotEmpty && _digits.hasMatch(seq) ? '$userId:$seq' : '',
    );
  }

  /// A gift's animation in a `10|24` frame of room [roomId] (`oriUri`
  /// [giftOriUri]): `payload.vgift_typeid` (the id), `vgift_name`,
  /// `vgift_count`, `send_times` (the sends of the combo so far: the combo's
  /// gifts are `vgift_count × send_times`); the sender's account `from_uid`, no
  /// name (the gift line that follows names them). Bigo's animation carries no
  /// price and the gift table is not asked for, so the value stays unknown.
  /// Null for another room, or without a gift name.
  static LiveMessage? gift(Map<Object?, Object?> frame, {required String roomId}) {
    final payload = frame['payload'];
    if (payload is! Map) return null;
    final room = _scalar(payload['room_id']);
    if ((room.isEmpty ? _scalar(frame['room_id']) : room) != roomId) return null;
    final name = _scalar(payload['vgift_name']).trim();
    if (name.isEmpty) return null;
    final count = _count(payload['vgift_count']) ?? 1;
    final sends = _count(payload['send_times']);
    final userId = _userId(payload['from_uid'], frame['from_uid']);
    final seq = _scalar(frame['seqId']);
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(userId: userId),
      text: '$name x$count',
      color: LiveMessageColor.white,
      messageId: userId.isNotEmpty && _digits.hasMatch(seq) ? '$userId:$seq' : '',
      payload: LiveGift(
        giftId: _scalar(payload['vgift_typeid']).trim(),
        name: name,
        count: count,
        combo: LiveGiftCombo(comboTotal: sends == null ? null : count * sends),
      ),
    );
  }

  /// The sender of the chat list's gift line (`payload.tag` [giftLineTag] of a
  /// `10|24` frame of room [roomId]): the account `payload.uid` (else
  /// `from_uid`), the name `n` of the Base64 JSON `content` and the level
  /// `payload.grade`. Null for anything else, or without an account.
  static BigoGiftSender? giftLine(Map<Object?, Object?> frame, {required String roomId}) {
    if (_scalar(frame['room_id']) != roomId) return null;
    final payload = frame['payload'];
    if (payload is! Map || int.tryParse(_scalar(payload['tag'])) != giftLineTag) return null;
    final userId = _userId(payload['uid'], frame['from_uid']);
    if (userId.isEmpty) return null;
    final content = payload['content'];
    var name = '';
    if (content is String) {
      try {
        final decoded = jsonDecode(utf8.decode(base64.decode(base64.normalize(content.trim()))));
        if (decoded is Map) name = _scalar(decoded['n']).trim();
      } on FormatException {
        // A line without a name that reads.
      }
    }
    final level = _scalar(payload['grade']);
    return (userId: userId, name: name, level: _digits.hasMatch(level) ? level : '');
  }

  /// The concurrent audience of room [roomId] in a `40|24` frame
  /// (`totalUserCount`, when `gid` is the room) or the `43|24` answer (`total`,
  /// when `room_id` is the room); null otherwise. Both are the same count as the
  /// list's `user_count` (2472–2513 on the socket against 2557 in the list,
  /// 2026-09-30).
  static LiveMessage? audience(Map<Object?, Object?> frame, {required int uri, required String roomId}) {
    final (room, count) = switch (uri) {
      audienceUri => (frame['gid'], frame['totalUserCount']),
      _ => (frame['room_id'], frame['total']),
    };
    if (_scalar(room) != roomId) return null;
    final written = _scalar(count);
    final value = _digits.hasMatch(written) ? int.tryParse(written) : null;
    if (value == null || value < 0) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.audienceUpdate,
      color: LiveMessageColor.white,
      payload: LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: value),
    );
  }

  /// A whole number of at least 1 written as digits, or null.
  static int? _count(Object? value) {
    final text = _scalar(value);
    final count = _digits.hasMatch(text) ? int.tryParse(text) : null;
    return count != null && count > 0 ? count : null;
  }

  /// The sender's account: [primary] when it is digits, else [fallback].
  static String _userId(Object? primary, Object? fallback) {
    var userId = _scalar(primary);
    if (!_digits.hasMatch(userId)) userId = _scalar(fallback);
    if (!_digits.hasMatch(userId)) userId = '';
    return userId;
  }

  static String _scalar(Object? value) => switch (value) {
    final String text => text,
    final int number => '$number',
    _ => '',
  };
}
