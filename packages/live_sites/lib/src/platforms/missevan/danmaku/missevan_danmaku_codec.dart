import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/common/codec/brotli.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The chat arguments of a room: the room number and the socket to join.
///
/// [url] is the room detail's `websocket` entry
/// (`wss://im.missevan.com/ws?room_id=…`) once the codec accepted it, or that
/// fallback form when the answer listed none. The session asks the handshake
/// cookie for [url]'s host itself.
final class MissevanDanmakuArgs {
  /// Creates the arguments.
  const MissevanDanmakuArgs({required this.roomId, required this.url});

  /// The room number, sent (as a number) in the join message.
  final String roomId;

  /// The room's chat socket.
  final Uri url;

  @override
  String toString() => 'MissevanDanmakuArgs($roomId, $url)';
}

/// What one Missevan chat frame held.
final class MissevanDanmakuFrame {
  /// Creates the result.
  const MissevanDanmakuFrame({this.messages = const [], this.joined, this.refusal = ''});

  /// Nothing to act on.
  static const MissevanDanmakuFrame empty = MissevanDanmakuFrame();

  /// Chat, super chats (paid questions), retractions, notices, gifts and
  /// audience updates, in order.
  final List<LiveMessage> messages;

  /// The answer to this socket's join: true when the room was joined
  /// (`code 0`), false when the join was refused, null when the frame held
  /// no answer to it.
  final bool? joined;

  /// The refused join's code and text (`500030004 无法找到该聊天室`), for
  /// diagnostics.
  final String refusal;
}

/// Missevan's chat, without I/O.
///
/// The socket needs a guest session: `api/user/info` sets the `FM_SESS`
/// cookie, without which the handshake is refused; the client joins its room
/// with a JSON text frame and the server answers it by the join's `uuid`;
/// every server message is a binary frame, flag 1 and the UTF-8 length
/// (24 bits, little-endian) before a Brotli stream, holding a JSON object or
/// an array of them; the heartbeat `❤️` goes out every 30 s as text and
/// comes back as text.
abstract final class MissevanDanmakuCodec {
  /// Heartbeat period. The server drops a client that sends nothing for
  /// about two minutes.
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// The heartbeat, sent as a text frame; the server echoes it.
  static const String heartbeat = '❤️';

  /// How long the join's answer may take: the site gives up on any IM
  /// request after 5 s and reconnects.
  static const Duration joinTimeout = Duration(seconds: 5);

  /// Silence after which the socket is replaced: the server echoes the
  /// heartbeat, so a socket silent for max(3 × 30 s, 90 s) = 90 s is
  /// half-open.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// The first byte of a binary frame whose payload is Brotli.
  static const int brotliFlag = 1;

  /// Bytes before a frame's Brotli stream: the flag and the length.
  static const int headerLength = 4;

  /// How long a paid question shows as a super chat. The site has no such
  /// time (a question waits in the room's question panel until the host
  /// answers or cancels it); 60 s is Bilibili's shortest super chat, and a
  /// question costs a few yuan (tens of diamonds), below its lowest tier.
  static const Duration questionDuration = Duration(seconds: 60);

  /// `admin`/`message_clear` `opt`: every chat line.
  static const int clearAll = 1;

  /// `admin`/`message_clear` `opt`: the lines of `msg_ids`.
  static const int clearSpecific = 2;

  /// Requests per attempt to get a guest session.
  static const int sessionAttempts = 3;

  /// The wait before session attempt `n` (counting from 1):
  /// [sessionRetryDelay] × n.
  static const Duration sessionRetryDelay = Duration(milliseconds: 500);

  /// Longest wait for one guest session answer.
  static const Duration sessionTimeout = Duration(seconds: 5);

  /// Refused joins answered with a new session and socket; the next refusal
  /// ends the session.
  static const int maxRejoins = 3;

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// The currency every price on the platform is denominated in (钻石, ten
  /// to a yuan).
  static const String currency = '钻';

  static const int _maxMillis = 8640000000000000;

  static final RegExp _nonZero = RegExp('[^0]');

  /// A cookie value: RFC 6265 cookie-octets (no space, quote, comma,
  /// semicolon or backslash); it goes into the handshake's `cookie` header.
  static final RegExp _cookieValue = RegExp(r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$');

  static final RegExp _sessionCookie = RegExp(r'^\s*FM_SESS=([^;]*)');

  /// The chat socket of room [roomId] at [url]: [url] when it is a `wss` URL
  /// on `missevan.com` or a subdomain without user info (the session cookie
  /// goes there), for this room. A URL without `room_id` gets it; anything
  /// else is replaced by `wss://im.missevan.com/ws?room_id={roomId}`, the
  /// form the site uses.
  static Uri endpoint(Uri url, {required String roomId}) {
    final fallback = Uri(scheme: 'wss', host: 'im.missevan.com', path: '/ws', queryParameters: {'room_id': roomId});
    if (url.scheme != 'wss' ||
        url.userInfo.isNotEmpty ||
        (url.host != 'missevan.com' && !url.host.endsWith('.missevan.com'))) {
      return fallback;
    }
    final Map<String, List<String>> query;
    try {
      query = url.queryParametersAll;
    } on FormatException {
      return fallback;
    }
    final named = query['room_id'];
    if (named == null) return url.replace(queryParameters: {...query, 'room_id': roomId});
    return named.length == 1 && named.single == roomId ? url : fallback;
  }

  /// The `FM_SESS` value that the [setCookie] lines (the guest session
  /// answer) set, or null. `FM_SESS.sig` is not needed.
  static String? session(List<String> setCookie) {
    for (final header in setCookie) {
      final value = _sessionCookie.firstMatch(header)?.group(1)?.trim();
      if (value != null && _cookieValue.hasMatch(value)) return value;
    }
    return null;
  }

  /// Handshake headers: [headers] (the API's, with the site's `Origin`, as
  /// the site's page sends them) with the session cookie in place of any
  /// cookie they carry. The cookie is what the server requires.
  static Map<String, String> handshakeHeaders(Map<String, String> headers, String session) => {
    for (final entry in headers.entries)
      if (entry.key.toLowerCase() != 'cookie') entry.key: entry.value,
    'cookie': 'FM_SESS=$session',
  };

  /// The join of [roomId] (sent as a number) with [uuid], as the site writes
  /// it; after the room was joined once, the rejoins carry
  /// `reconnect: 1`.
  static String join(String roomId, {required String uuid, bool reconnect = false}) => jsonEncode({
    'action': 'join',
    'uuid': uuid,
    'type': 'room',
    'room_id': int.parse(roomId),
    if (reconnect) 'reconnect': 1,
  });

  /// A random version 4 UUID, the join's `uuid`.
  static String uuid(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// The text of a received frame, as the site's client reads it: a text
  /// frame as it is; a binary one longer than its header with flag 1,
  /// Brotli-decoded, when the result has exactly the length the header
  /// declares. Anything else is null: another flag, a short frame, a stream
  /// that does not decode.
  static String? text(Object? data) {
    if (data is String) return data;
    if (data is! List<int> || data.length <= headerLength || data[0] != brotliFlag) return null;
    final length = data[1] | data[2] << 8 | data[3] << 16;
    final Uint8List plain;
    try {
      plain = brotliDecode(data.sublist(headerLength), maxOutput: length);
    } on FormatException {
      return null;
    }
    if (plain.length != length) return null;
    return utf8.decode(plain, allowMalformed: true);
  }

  /// Reads one frame of room [roomId]'s socket, whose join was sent with
  /// [uuid].
  ///
  /// The frame's JSON is an object or an array of objects, each named by
  /// `type` and `event`:
  ///
  /// - `room`/`join` with this [uuid]: the answer to the join;
  /// - `message`/`new`, and `message`/`danmaku` (a paid danmaku, a chat line
  ///   the site flies in a bubble): chat;
  /// - `room`/`statistics`: heat and the listeners in the room now;
  /// - `question`/`ask`, a paid question: a super chat, which starts at
  ///   [receivedAt] (default now) when the question has no time;
  /// - `admin`/`message_clear`: retractions;
  /// - `noble` (a noble title bought or renewed), `pk`, `global_pk` (幻影
  ///   PK) and `team_pk`: notices;
  /// - `gift`/`send`: a gift.
  ///
  /// An object naming another room (`room_id`) is skipped, as the site's
  /// client skips it; so is everything else (entries, ranks, global notices,
  /// the heartbeat's echo), a frame that is not JSON, and an item that is
  /// not an object. A field of the wrong type costs only that field or that
  /// line, never the frame.
  static MissevanDanmakuFrame decode(
    Object? data, {
    required String roomId,
    required String uuid,
    DateTime? receivedAt,
  }) {
    final frameText = MissevanDanmakuCodec.text(data);
    if (frameText == null || frameText == heartbeat) return MissevanDanmakuFrame.empty;
    final Object? root;
    try {
      root = jsonDecode(frameText);
    } on FormatException {
      return MissevanDanmakuFrame.empty;
    }
    final messages = <LiveMessage>[];
    bool? joined;
    var refusal = '';
    for (final item in root is List ? root : [root]) {
      if (item is! Map) continue;
      final type = item['type'];
      final event = item['event'];
      if (type == 'room' && event == 'join') {
        if (item['uuid'] != uuid) continue;
        final code = item['code'];
        joined = code == 0;
        if (!joined) refusal = [_scalar(code), if (item['info'] case final String info) info].join(' ').trim();
        continue;
      }
      final room = item['room_id'];
      if (room != null && '$room' != roomId) continue;
      switch ((type, event)) {
        case ('message', 'new' || 'danmaku'):
          if (chat(item) case final message?) messages.add(message);
        case ('room', 'statistics'):
          messages.addAll(audience(item['statistics']));
        case ('question', 'ask'):
          if (question(item, receivedAt: receivedAt ?? DateTime.now()) case final message?) messages.add(message);
        case ('admin', 'message_clear'):
          messages.addAll(retractions(item));
        case ('noble', _):
          if (noble(item) case final message?) messages.add(message);
        case ('pk', _):
          messages.addAll(pk(item, roomId: roomId));
        case ('global_pk', _):
          messages.addAll(globalPk(item));
        case ('team_pk', _):
          if (teamPk(item) case final message?) messages.add(message);
        case ('gift', 'send'):
          if (gift(item) case final message?) messages.add(message);
        default:
          break;
      }
    }
    return MissevanDanmakuFrame(messages: messages, joined: joined, refusal: refusal);
  }

  /// A paid question (`question`/`ask`) as a super chat, or null when its
  /// text is blank or its price is not a whole number of zero or more.
  ///
  /// The server sends the asker as `user` and the question as `question`:
  /// `question_id`, the text `question`, `price` in diamonds, `created_time`
  /// in milliseconds (the start; else [receivedAt]), and the asker again
  /// (`user_id`, `username`, `iconurl`) for a `user` that lacks them. It
  /// shows for [questionDuration]; the platform gives no colours.
  static LiveMessage? question(Map<Object?, Object?> item, {required DateTime receivedAt}) {
    final question = item['question'];
    if (question is! Map) return null;
    final text = _scalar(question['question']).trim();
    final price = _int(question['price']);
    if (text.isEmpty || price == null || price < 0) return null;
    final user = item['user'] is Map ? item['user']! as Map<Object?, Object?> : const <Object?, Object?>{};
    String field(String key) => _scalar(user[key]).isNotEmpty ? _scalar(user[key]) : _scalar(question[key]);
    final id = _scalar(question['question_id']).trim();
    final created = _time(question['created_time']);
    final start = created ?? receivedAt;
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: MessageSender.normalized(userId: field('user_id'), userName: field('username')),
      text: text,
      color: LiveMessageColor.white,
      messageId: id,
      sentAt: created,
      payload: LiveSuperChatMessage(
        messageId: id,
        userName: field('username'),
        faceUrl: _https(user['iconurl']) ?? _https(question['iconurl']) ?? '',
        text: text,
        price: SuperChatPrice(amount: price, currency: currency, displayText: '$price $currency'),
        startTime: start,
        endTime: start.add(questionDuration),
      ),
    );
  }

  /// The retractions of an `admin`/`message_clear`, as the site's chat list
  /// applies it: `opt` [clearAll] takes back every chat line; [clearSpecific]
  /// the lines whose `msg_id` is in `msg_ids`, once each; any other `opt`
  /// nothing.
  static List<LiveMessage> retractions(Map<Object?, Object?> item) {
    LiveMessage retraction(LiveRetraction target) =>
        LiveMessage.normalized(type: LiveMessageType.retraction, color: LiveMessageColor.white, payload: target);
    switch (_int(item['opt'])) {
      case clearAll:
        return [retraction(const LiveRetraction(all: true))];
      case clearSpecific:
        final ids = item['msg_ids'];
        if (ids is! List) return const [];
        final seen = <String>{};
        return [
          for (final id in ids.map(_scalar))
            if (id.trim().isNotEmpty && seen.add(id)) retraction(LiveRetraction(messageId: id)),
        ];
      default:
        return const [];
    }
  }

  /// A noble title bought (`registration`) or renewed (`renewal`), in this
  /// room or, in a team live, for another host (`cross_…`, naming
  /// `room.creator_username`), as a notice in the words of the site's chat
  /// line ("我开通了神话贵族"): `观众甲 开通了神话贵族`. Null for other events
  /// or without `noble.name`.
  static LiveMessage? noble(Map<Object?, Object?> item) {
    final event = item['event'];
    final action = switch (event) {
      'registration' || 'cross_registration' => '开通',
      'renewal' || 'cross_renewal' => '续费',
      _ => null,
    };
    final noble = item['noble'];
    if (action == null || noble is! Map) return null;
    final name = _scalar(noble['name']).trim();
    if (name.isEmpty) return null;
    final user = item['user'] is Map ? item['user']! as Map<Object?, Object?> : const <Object?, Object?>{};
    final userName = _scalar(user['username']).trim();
    final room = item['room'];
    final host = '$event'.startsWith('cross_') && room is Map ? _scalar(room['creator_username']).trim() : '';
    return _notice(
      '${userName.isEmpty ? '' : '$userName '}$action了${host.isEmpty ? '' : '$host的'}$name贵族',
      userName: userName,
      userId: _scalar(user['user_id']),
      sentAt: _time(item['time']),
    );
  }

  /// The site's lines for a `pk` (random or invited PK) event, as a viewer
  /// sees them (`addLocalSystemMsg` with the `PK` type).
  static const Map<String, String> pkLines = {
    'match_start': '主播正在匹配 PK 对手，请耐心等候',
    'match_success': 'PK 已开始，快送礼支持主播吧',
    'invite_refuse': '对方未接受邀请',
    'invite_timeout': '对方未接受邀请',
  };

  /// The site's line for a finished `pk` by `pk.result` (0 lost, 1 won,
  /// 2 drawn), as a viewer sees it.
  static const Map<int, String> pkResults = {1: '恭喜主播获得 PK 胜利，继续支持主播吧', 0: '主播 PK 失败，再接再厉哦', 2: '主播 PK 平局，再接再厉哦'};

  /// The notices of a `pk` event (a random or invited PK of two hosts), as
  /// a viewer sees them on the site: the 花神赐福 line of `raid` first, then
  /// the PK line ([pkLines]; a finished PK by `pk.result`, [pkResults]; an
  /// unanswered invitation only in the inviting room, `pk.from_room_id`).
  static List<LiveMessage> pk(Map<Object?, Object?> item, {required String roomId}) {
    final pk = item['pk'] is Map ? item['pk']! as Map<Object?, Object?> : const <Object?, Object?>{};
    final event = item['event'];
    final line = switch (event) {
      'finish' || 'close' => pkResults[_int(pk['result'])],
      'invite_timeout' when _scalar(pk['from_room_id']) != roomId => null,
      final String event => pkLines[event],
      _ => null,
    };
    return [?raid(item), if (line != null) _notice(line)];
  }

  /// The `global_pk` (幻影 PK) events the site reads, and its line for each
  /// when the event carries no `message_tip`.
  static const Map<String, String?> globalPkLines = {
    'match_ready': '幻影 PK 即将开启，准备迎战！',
    'match_skip': '本场幻影 PK 已跳过',
    'match_start': '幻影 PK 匹配中，敬请期待……',
    'match_fail': '本场幻影 PK 未匹配到合适的对手',
    'match_success': '匹配成功！幻影 PK 正式开战！',
    'update': null,
    'finish': '幻影 PK 已结束',
    'match_stop': null,
    'close': null,
    'punish_finish': null,
    'mute': null,
    'forced_mute': null,
    'unmute': null,
    'forced_unmute': null,
    'invite_request': null,
    'rank_invite_request': null,
    'invite_cancel': null,
    'invite_refuse': null,
    'invite_timeout': null,
  };

  /// The site's line for a finished `global_pk` by `pk.result` without a
  /// `message_tip`.
  static const Map<int, String> globalPkResults = {1: '恭喜胜利！', 2: '本场幻影 PK 战成平局', 0: '本场幻影 PK 遗憾落败'};

  /// The notices of a `global_pk` event (幻影 PK, matched by the platform),
  /// as the site's PK assistant writes them: `pk.message_tip`
  /// ([plainText]) or else the site's line for the event ([globalPkLines];
  /// a finish by `pk.result`, [globalPkResults]); an `update` only with a
  /// tip, and an event without either shows no line. The 花神赐福 line of
  /// `raid` follows.
  static List<LiveMessage> globalPk(Map<Object?, Object?> item) {
    final event = item['event'];
    final pk = item['pk'];
    if (event is! String || !globalPkLines.containsKey(event) || pk is! Map) return const [];
    final tip = plainText(pk['message_tip']);
    final line = tip.isNotEmpty
        ? tip
        : event == 'finish'
        ? globalPkResults[_int(pk['result'])] ?? globalPkLines[event]
        : globalPkLines[event];
    return [if (line != null) _notice(line), ?raid(item)];
  }

  /// A `team_pk` event's `pk.message_tip` ([plainText]) as a notice, as the
  /// site's team PK assistant shows it; null without one.
  static LiveMessage? teamPk(Map<Object?, Object?> item) {
    final pk = item['pk'];
    final tip = pk is Map ? plainText(pk['message_tip']) : '';
    return tip.isEmpty ? null : _notice(tip);
  }

  /// The 花神赐福 events whose `raid.progress.message_tip` the site shows.
  static const Set<String> raidEvents = {'match_success', 'update', 'finish', 'close'};

  /// The 花神赐福 line of a PK event: `raid.progress.message_tip`
  /// ([plainText]) as a notice, or null.
  static LiveMessage? raid(Map<Object?, Object?> item) {
    if (!raidEvents.contains(item['event'])) return null;
    final raid = item['raid'];
    final progress = raid is Map ? raid['progress'] : null;
    final tip = progress is Map ? plainText(progress['message_tip']) : '';
    return tip.isEmpty ? null : _notice(tip);
  }

  static final RegExp _linkHint = RegExp(
    r'''<font\s+color\s*=\s*['"]?#bdbdbd['"]?\s*>.*?</font\s*>''',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _tag = RegExp('<[^>]*>');
  static final RegExp _entity = RegExp('&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]+);');
  static final RegExp _space = RegExp(r'\s+');

  /// The words of a `message_tip`, which the site shows as HTML: the grey
  /// (`#BDBDBD`) parts are the links it adds ("详情", "结算详情", "去祈福")
  /// and are left out, as are images and every other tag (a line break
  /// becomes a space); entities are decoded, runs of white space become one
  /// space. Empty for anything but text.
  static String plainText(Object? html) {
    if (html is! String) return '';
    final text = html
        .replaceAll(_linkHint, '')
        .replaceAll(_lineBreak, ' ')
        .replaceAll(_tag, '')
        .replaceAllMapped(_entity, (match) => _decodeEntity(match) ?? match[0]!);
    return text.replaceAll(_space, ' ').trim();
  }

  static String? _decodeEntity(Match match) {
    final name = match[1]!;
    final code = name.startsWith('#x') || name.startsWith('#X')
        ? int.tryParse(name.substring(2), radix: 16)
        : name.startsWith('#')
        ? int.tryParse(name.substring(1))
        : null;
    if (code == null) return const {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '}[name];
    return code > 0 && code <= 0x10FFFF && (code < 0xD800 || code > 0xDFFF) ? String.fromCharCode(code) : null;
  }

  /// One gift of `gift`/`send`, or null without a `gift` that has a name.
  ///
  /// Fields: `gift` (`gift_id`, `name`, `num`, `price` in diamonds each,
  /// `icon_url`), the sender `user`, `time` in milliseconds, `oid` the order
  /// (all zeros for the later sends of a combo; then no message id), and
  /// `combo` (`id`, the first send's order; `num`, the count so far) when
  /// the send is part of a combo. The text is `幻彩礼炮 ×1`. The lucky gift a
  /// draw came from (`lucky`) has no v2 gift field and is left out.
  static LiveMessage? gift(Map<Object?, Object?> item) {
    final present = _gift(item['gift']);
    if (present == null) return null;
    final combo = item['combo'] is Map ? item['combo']! as Map<Object?, Object?> : const <Object?, Object?>{};
    final comboId = _scalar(combo['id']).trim();
    final comboTotal = _int(combo['num']);
    final user = item['user'] is Map ? item['user']! as Map<Object?, Object?> : const <Object?, Object?>{};
    final order = _scalar(item['oid']).trim();
    final data = present.copyWith(
      combo: LiveGiftCombo(
        comboKey: comboId.contains(_nonZero) ? comboId : '',
        comboTotal: comboTotal != null && comboTotal > 0 ? comboTotal : null,
      ),
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(userId: _scalar(user['user_id']), userName: _scalar(user['username'])),
      text: '${data.name} ×${data.count}',
      color: LiveMessageColor.white,
      messageId: order.contains(_nonZero) ? order : '',
      sentAt: _time(item['time']),
      payload: data,
    );
  }

  /// The gift of a `gift`/`send`: id, name, count and price. The platform's
  /// diamonds are written as gold here; a price of 0 is a free gift. Null
  /// without a name.
  static LiveGift? _gift(Object? gift) {
    if (gift is! Map) return null;
    final name = _scalar(gift['name']).trim();
    if (name.isEmpty) return null;
    final count = _int(gift['num']);
    final price = _int(gift['price']);
    final paid = price != null && price > 0;
    final unit = paid ? price : 0;
    return LiveGift(
      giftId: _scalar(gift['gift_id']).trim(),
      name: name,
      iconUrl: _https(gift['icon_url']),
      count: count != null && count > 0 ? count : 1,
      value: LiveGiftValue(
        unit: paid ? LiveGiftUnit.diamond : LiveGiftUnit.free,
        unitPrice: paid ? unit.toDouble() : null,
        totalValue: paid ? (unit * (count != null && count > 0 ? count : 1)).toDouble() : null,
      ),
    );
  }

  static LiveMessage _notice(String text, {String userName = '', String userId = '', DateTime? sentAt}) =>
      LiveMessage.normalized(
        type: LiveMessageType.notice,
        sender: userName.isEmpty && userId.isEmpty
            ? null
            : MessageSender.normalized(userId: userId, userName: userName),
        text: text,
        color: LiveMessageColor.white,
        sentAt: sentAt,
        payload: LiveNoticeKind.system,
      );

  /// One chat line, or null when its `message` is blank or neither text nor
  /// a number.
  ///
  /// Fields: `message` the text (trimmed), `user.username` and
  /// `user.user_id`, `msg_id` the message id, `time` the time in
  /// milliseconds. The user's `titles` carry the level (`type` `level`) and
  /// the fan medal (`medal`: its `name` and `level`). The site gives no
  /// text colour: white.
  static LiveMessage? chat(Map<Object?, Object?> item) {
    final text = _scalar(item['message']).trim();
    if (text.isEmpty) return null;
    final user = item['user'];
    final titles = user is Map && user['titles'] is List ? user['titles']! as List<Object?> : const <Object?>[];
    Map<Object?, Object?>? title(String type) =>
        titles.whereType<Map<Object?, Object?>>().where((entry) => entry['type'] == type).firstOrNull;
    final level = _int(title('level')?['level']);
    final medal = title('medal');
    final medalLevel = _int(medal?['level']);
    final medalName = medal?['name'];
    final time = item['time'];
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: user is Map ? _scalar(user['user_id']) : '',
        userName: user is Map ? _scalar(user['username']) : '',
        userLevel: level == null ? '' : '$level',
        fanBadgeName: medalName is String ? medalName.trim() : '',
        fanBadgeLevel: medalLevel == null ? '' : '$medalLevel',
      ),
      text: text,
      color: LiveMessageColor.white,
      messageId: _scalar(item['msg_id']),
      sentAt: time is int && time > 0 && time <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(time) : null,
    );
  }

  /// The figures of a `room`/`statistics` message's [statistics]: `score`,
  /// the heat the site shows, and `online`, the listeners in the room now
  /// (the room lists and the detail carry an `online` that is always 0).
  /// Each is a whole number, not negative, or left out.
  static List<LiveMessage> audience(Object? statistics) {
    if (statistics is! Map) return const [];
    return [
      for (final (key, kind) in const [
        ('score', LiveAudienceSignalKind.popularity),
        ('online', LiveAudienceSignalKind.onlineViewers),
      ])
        if (_int(statistics[key]) case final value? when value >= 0)
          LiveMessage.normalized(
            type: LiveMessageType.audienceUpdate,
            color: LiveMessageColor.white,
            payload: LiveAudienceUpdate.of(kind: kind, value: value),
          ),
    ];
  }

  /// A positive time in milliseconds that [DateTime] can hold, or null.
  static DateTime? _time(Object? value) =>
      value is int && value > 0 && value <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  /// [value] as an https URL (protocol-relative ones get `https:`), or
  /// null.
  static String? _https(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    final url = text.startsWith('//') ? 'https:$text' : text;
    final uri = Uri.tryParse(url);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? url : null;
  }

  /// A whole number: a JSON integer or its text.
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  static String _scalar(Object? value) => value is String || value is num ? '$value' : '';
}
