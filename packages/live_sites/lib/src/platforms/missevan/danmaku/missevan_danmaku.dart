import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/common/brotli/brotli.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What one Missevan chat frame held ([MissevanDanmakuProtocol.decode]).
@immutable
final class MissevanDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.joined, this.refusal = ''});

  /// Chat, super chats (paid questions), retractions, notices, gifts and
  /// audience updates, in order.
  final List<LiveMessage> messages;

  /// The answer to this socket's join: true when the room was joined
  /// (`code 0`), false when refused, null when the frame held no answer to
  /// it.
  final bool? joined;

  /// The refused join's code and text, for diagnostics.
  final String refusal;
}

/// Missevan's (猫耳 FM) chat (the site's own IM client), without I/O.
///
/// - The socket needs a guest session (`api/user/info` sets the `FM_SESS`
///   cookie, [session]), without which the handshake is refused (HTTP 403).
/// - The client joins its room with a JSON text frame ([join]) and the server
///   answers it by the join's `uuid`.
/// - Every server message is a binary frame, flag 1 and the UTF-8 length
///   (24 bits, little-endian) before a Brotli stream ([text]), holding a JSON
///   object or an array of them; the heartbeat `❤️` goes out every 30 s as text
///   and comes back as text.
///
/// Archived from the reference and mapped onto this tree's models: a chat
/// colour is the int white default, a notice's `data` is the string `'system'`,
/// the message id field is `id`, a paid question is the reduced
/// [LiveSuperChat] (diamond price counted in this tree's gold unit), a gift
/// keeps only name/count/price/combo (no id, icon or lucky source), a
/// retraction is a [LiveMessageType.recall] by id (a clear-all has no field and
/// is dropped), and the sender's level and fan medal have no field here.
abstract final class MissevanDanmakuProtocol {
  /// Heartbeat period: the site's `IMHeartbeat` (30 000 ms).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// The heartbeat, sent as a text frame; the server echoes it.
  static const String heartbeat = '❤️';

  /// How long the join's answer may take (the site gives up on an IM request
  /// after 5 s).
  static const Duration joinTimeout = Duration(seconds: 5);

  /// The first byte of a binary frame whose payload is Brotli.
  static const int brotliFlag = 1;

  /// Bytes before a frame's Brotli stream: the flag and the length.
  static const int headerLength = 4;

  /// How long a paid question shows as a super chat (the site gives no time).
  static const Duration questionDuration = Duration(seconds: 60);

  /// White, the danmaku default.
  static const int defaultColor = 0xFFFFFF;

  /// `admin`/`message_clear` `opt`: every chat line (the site's `All`).
  static const int clearAll = 1;

  /// `admin`/`message_clear` `opt`: the lines of `msg_ids` (`Specific`).
  static const int clearSpecific = 2;

  /// The site's lines for a `pk` (random or invited PK) event, as a viewer.
  static const Map<String, String> pkLines = {
    'match_start': '主播正在匹配 PK 对手，请耐心等候',
    'match_success': 'PK 已开始，快送礼支持主播吧',
    'invite_refuse': '对方未接受邀请',
    'invite_timeout': '对方未接受邀请',
  };

  /// The site's line for a finished `pk` by `pk.result` (0 lost, 1 won, 2 drawn).
  static const Map<int, String> pkResults = {1: '恭喜主播获得 PK 胜利，继续支持主播吧', 0: '主播 PK 失败，再接再厉哦', 2: '主播 PK 平局，再接再厉哦'};

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

  /// The site's line for a finished `global_pk` by `pk.result` without a tip.
  static const Map<int, String> globalPkResults = {1: '恭喜胜利！', 2: '本场幻影 PK 战成平局', 0: '本场幻影 PK 遗憾落败'};

  /// The events whose `raid.progress.message_tip` (花神赐福) the site shows.
  static const Set<String> raidEvents = {'match_success', 'update', 'finish', 'close'};

  /// Largest time [DateTime] can hold, in milliseconds.
  static const int _maxMillis = 8640000000000000;

  /// A cookie value: RFC 6265 cookie-octets, for the handshake's `cookie`.
  static final RegExp _cookieValue = RegExp(r'^[\x21\x23-\x2B\x2D-\x3A\x3C-\x5B\x5D-\x7E]+$');

  static final RegExp _sessionCookie = RegExp(r'^\s*FM_SESS=([^;]*)');

  /// The chat socket of room [roomId] at [url]: [url] when it is a `wss` URL
  /// on `missevan.com` or a subdomain without user info, for this room; a URL
  /// without `room_id` gets it; anything else is
  /// `wss://im.missevan.com/ws?room_id={roomId}`.
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

  /// The `FM_SESS` value that [setCookie] (the guest session's `Set-Cookie`)
  /// sets, or null. `FM_SESS.sig` is not needed.
  static String? session(Iterable<String> setCookie) {
    for (final header in setCookie) {
      final value = _sessionCookie.firstMatch(header)?.group(1)?.trim();
      if (value != null && _cookieValue.hasMatch(value)) return value;
    }
    return null;
  }

  /// Handshake headers: [headers] with the session cookie in place of any
  /// cookie they carry. The cookie is what the server requires.
  static Map<String, String> handshakeHeaders(Map<String, String> headers, String session) => {
    for (final entry in headers.entries)
      if (entry.key.toLowerCase() != 'cookie') entry.key: entry.value,
    'cookie': 'FM_SESS=$session',
  };

  /// The join of [roomId] (sent as a number) with [uuid]; a rejoin after the
  /// room was joined once carries `reconnect: 1`.
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

  /// The text of a received frame: a text frame as it is; a binary one longer
  /// than its header with flag 1, Brotli-decoded when the result has exactly
  /// the length the header declares. Anything else is null.
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
  /// [uuid]: its `type`/`event` decide which lines [chat], [audience],
  /// [question], [retractions], [noble], [pk], [globalPk], [teamPk] and [gift]
  /// report. An object naming another room is skipped, as is anything else.
  static MissevanDanmakuFrame decode(
    Object? data, {
    required String roomId,
    required String uuid,
    DateTime? receivedAt,
  }) {
    final text = MissevanDanmakuProtocol.text(data);
    if (text == null || text == heartbeat) return const MissevanDanmakuFrame();
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const MissevanDanmakuFrame();
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

  /// A paid question (`question`/`ask`) as a super chat, or null when its text
  /// is blank or its price is not a whole number of zero or more. The diamond
  /// price is counted in this tree's gold unit; the asker's face and the
  /// platform colours have no field here.
  static LiveMessage? question(Map<Object?, Object?> item, {required DateTime receivedAt}) {
    final question = item['question'];
    if (question is! Map) return null;
    final text = _scalar(question['question']).trim();
    final price = _int(question['price']);
    if (text.isEmpty || price == null || price < 0) return null;
    final id = _scalar(question['question_id']).trim();
    final created = _time(question['created_time']);
    final start = created ?? receivedAt;
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: 'SUPER_CHAT_MESSAGE',
      message: 'SUPER_CHAT_MESSAGE',
      color: defaultColor,
      id: id.isEmpty ? null : id,
      sentAt: created,
      data: LiveSuperChat(
        message: text,
        price: price,
        priceText: '$price 钻',
        startTime: start,
        endTime: start.add(questionDuration),
      ),
    );
  }

  /// The retractions of an `admin`/`message_clear`: `opt` [clearAll] clears
  /// every line (this tree has no clear-all field, so it is dropped);
  /// [clearSpecific] recalls the listed `msg_ids`, once each; any other `opt`
  /// nothing.
  static List<LiveMessage> retractions(Map<Object?, Object?> item) {
    switch (_int(item['opt'])) {
      case clearAll:
        return const [];
      case clearSpecific:
        final ids = item['msg_ids'];
        if (ids is! List) return const [];
        final seen = <String>{};
        return [
          for (final id in ids.map(_scalar))
            if (id.trim().isNotEmpty && seen.add(id))
              LiveMessage(type: LiveMessageType.recall, userName: '', message: '', color: defaultColor, id: id),
        ];
      default:
        return const [];
    }
  }

  /// A noble title bought (`registration`) or renewed (`renewal`), in this room
  /// or, in a team live, for another host (`cross_…`), as a notice in the site's
  /// words; null for other events or without `noble.name`.
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
    final user = item['user'] is Map ? item['user']! as Map : const <Object?, Object?>{};
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

  /// The notices of a `pk` event: the 花神赐福 line of `raid` first, then the
  /// PK line; an unanswered invitation only in the inviting room.
  static List<LiveMessage> pk(Map<Object?, Object?> item, {required String roomId}) {
    final pk = item['pk'] is Map ? item['pk']! as Map : const <Object?, Object?>{};
    final event = item['event'];
    final line = switch (event) {
      'finish' || 'close' => pkResults[_int(pk['result'])],
      'invite_timeout' when _scalar(pk['from_room_id']) != roomId => null,
      final String event => pkLines[event],
      _ => null,
    };
    return [?raid(item), if (line != null) _notice(line)];
  }

  /// The notices of a `global_pk` event (幻影 PK): `pk.message_tip` or else the
  /// site's line for the event; a finish by `pk.result`; an event with neither
  /// shows no line. The 花神赐福 line of `raid` follows.
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

  /// A `team_pk` event's `pk.message_tip` as a notice; null without one.
  static LiveMessage? teamPk(Map<Object?, Object?> item) {
    final pk = item['pk'];
    final tip = pk is Map ? plainText(pk['message_tip']) : '';
    return tip.isEmpty ? null : _notice(tip);
  }

  /// The 花神赐福 line of a PK event ([raidEvents]):
  /// `raid.progress.message_tip` as a notice, or null.
  static LiveMessage? raid(Map<Object?, Object?> item) {
    if (!raidEvents.contains(item['event'])) return null;
    final raid = item['raid'];
    final progress = raid is Map ? raid['progress'] : null;
    final tip = progress is Map ? plainText(progress['message_tip']) : '';
    return tip.isEmpty ? null : _notice(tip);
  }

  /// The words of a `message_tip`, shown as HTML: the grey (`#BDBDBD`) link
  /// hints and every other tag are left out (a line break becomes a space);
  /// entities are decoded, runs of white space become one. Empty for anything
  /// but text.
  static String plainText(Object? html) {
    if (html is! String) return '';
    final text = html
        .replaceAll(_linkHint, '')
        .replaceAll(_lineBreak, ' ')
        .replaceAll(_tag, '')
        .replaceAllMapped(_entity, (match) => _decodeEntity(match) ?? match[0]!);
    return text.replaceAll(_space, ' ').trim();
  }

  /// One gift of `gift`/`send`, or null without a `gift` that has a name. The
  /// name, count, price and combo id map onto [LiveGift]; the id, icon and
  /// lucky-gift source have no field here.
  static LiveMessage? gift(Map<Object?, Object?> item) {
    final gift = item['gift'];
    if (gift is! Map) return null;
    final name = _scalar(gift['name']).trim();
    if (name.isEmpty) return null;
    final count = _int(gift['num']);
    final total = count != null && count > 0 ? count : 1;
    final price = _int(gift['price']);
    final unit = price != null && price >= 0 ? price : 0;
    final combo = item['combo'] is Map ? item['combo']! as Map : const <Object?, Object?>{};
    final comboRaw = _scalar(combo['id']).trim();
    final comboKey = comboRaw.contains(_nonZero) ? comboRaw : '';
    final user = item['user'] is Map ? item['user']! as Map : const <Object?, Object?>{};
    final order = _scalar(item['oid']).trim();
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _scalar(user['username']),
      userId: _scalar(user['user_id']),
      message: '$name ×$total',
      color: defaultColor,
      id: order.contains(_nonZero) ? order : null,
      sentAt: _time(item['time']),
      data: LiveGift(
        name: name,
        count: total,
        unitPrice: unit,
        totalValue: unit * total,
        combo: comboKey.isEmpty ? null : comboKey,
      ),
    );
  }

  static LiveMessage _notice(String text, {String userName = '', String userId = '', DateTime? sentAt}) => LiveMessage(
    type: LiveMessageType.notice,
    userName: userName,
    userId: userId.isEmpty ? null : userId,
    message: text,
    color: defaultColor,
    sentAt: sentAt,
    data: 'system',
  );

  /// A positive time in milliseconds that [DateTime] can hold, or null.
  static DateTime? _time(Object? value) =>
      value is int && value > 0 && value <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(value) : null;

  static final RegExp _linkHint = RegExp(
    r'''<font\s+color\s*=\s*['"]?#bdbdbd['"]?\s*>.*?</font\s*>''',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _nonZero = RegExp('[^0]');
  static final RegExp _lineBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _tag = RegExp('<[^>]*>');
  static final RegExp _entity = RegExp('&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]+);');
  static final RegExp _space = RegExp(r'\s+');

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

  /// One chat line, or null when its `message` is blank or neither text nor a
  /// number. The sender's level and fan medal are not kept (no field here).
  static LiveMessage? chat(Map<Object?, Object?> item) {
    final text = _scalar(item['message']).trim();
    if (text.isEmpty) return null;
    final user = item['user'];
    final time = item['time'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: user is Map ? _scalar(user['username']) : '',
      userId: user is Map ? _scalar(user['user_id']) : '',
      message: text,
      color: defaultColor,
      id: _scalar(item['msg_id']),
      sentAt: _time(time),
    );
  }

  /// The figures of a `room`/`statistics` message's [statistics]: `score`, the
  /// heat the site shows (this tree's `watching`), and `online`, the listeners
  /// now (`onlineViewers`). Each a whole number of zero or more, or left out.
  static List<LiveMessage> audience(Object? statistics) {
    if (statistics is! Map) return const [];
    final updates = <LiveAudienceUpdate>{};
    final score = _int(statistics['score']);
    final online = _int(statistics['online']);
    if (score != null && score >= 0) updates.add(LiveAudienceUpdate(watching: score));
    if (online != null && online >= 0) updates.add(LiveAudienceUpdate(onlineViewers: online));
    return [
      for (final data in updates)
        LiveMessage(type: LiveMessageType.audienceUpdate, userName: '', message: '', data: data),
    ];
  }

  /// A whole number: a JSON integer or its text.
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text),
    _ => null,
  };

  static String _scalar(Object? value) => value is String || value is num ? '$value' : '';
}
