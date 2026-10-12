import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

import 'package:live_sites/src/common/normalization/site_text.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_parser.dart';
import 'package:meta/meta.dart';

/// The `key=value` result of one Six Rooms frame ([SixRoomDanmakuProtocol.decode]).
@immutable
final class SixRoomDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.joined = false, this.loginFailed = false, this.refusal});

  /// Nothing to act on.
  static const SixRoomDanmakuFrame empty = SixRoomDanmakuFrame();

  /// Chat, gifts and super chats, in order.
  final List<LiveMessage> messages;

  /// The login was accepted (`command=result`, `content=login.success`).
  final bool joined;

  /// The login was refused (`content=login.failed`).
  final bool loginFailed;

  /// An error flag on which the room page stops its socket (kicked, room full,
  /// paid or password room, room closed, banned), as `flag <code>` and the
  /// server's text; null otherwise.
  final String? refusal;
}

/// Six Rooms' room chat, as the public room page (`v.6.cn/<room>`) runs it
/// anonymously, without I/O.
///
/// - The chat servers of a room come from `GET /room/getChat.php?rid=<the
///   broadcaster's user id>`: `{"websock": ["<host>:<port>", …]}` on the
///   room's shard.
/// - Every frame is text: a length line, then `key=value` lines (`\r\n`), one
///   command each. The client logs in with `command=login`, its guest id, an
///   empty `encpass` and the broadcaster's id as `roomid`; the server answers
///   `login.success` or `login.failed`.
/// - The client then sends the page's `noop` heartbeat every 16 s. Everything
///   else is `command=receivemessage`, `content=<Base64>`: raw DEFLATE with
///   `+`, `/`, `=` written `(`, `)`, `@` when `enc=yes`, then a JSON object
///   `{"flag": "001", "content": {…}}`.
///
/// Mapped onto this tree's models: six coins (the platform's paid currency)
/// count as [LiveGiftUnit.gold]; a gift's item id, receiver name, combo total
/// and picture, and the super chat's colours and avatar have no field here and
/// are dropped (a combo keeps only its key, in `combo`). Colour is an int, a
/// message id is `id`.
abstract final class SixRoomDanmakuProtocol {
  /// Where a room's chat servers are asked for.
  static Uri get serversUrl => Uri.parse('${SixRoomParser.origin}/room/getChat.php');

  /// The page's heartbeat period (`_heartbeat`, 16 s).
  static const Duration heartbeatInterval = Duration(seconds: 16);

  /// How long the login may take (the page's `timeout`, 6 s).
  static const Duration joinTimeout = Duration(seconds: 6);

  /// The heartbeat frame: `noop`, deflated and encoded (the page's
  /// `y8vPLwAA`).
  static const String heartbeat = 'command=sendmessage\r\ncontent=y8vPLwAA\r\n';

  /// Handshake headers: the site's origin and the desktop UA.
  static Map<String, String> get socketHeaders => {
    'origin': SixRoomParser.origin,
    'user-agent': SixRoomParser.headers['user-agent']!,
  };

  /// Error flags on which the room page stops its socket (`parseErr`).
  static const Set<String> stoppingFlags = {
    '101',
    '102',
    '103',
    '104',
    '109',
    '110',
    '111',
    '112',
    '113',
    '114',
    '204',
    '305',
    '306',
  };

  /// Public chat (the page's `parsePub`).
  static const String publicChat = '101';

  /// A list of public chat messages.
  static const String publicChatList = '110';

  /// A fly-screen message (飞屏, a paid message flying over the video): a
  /// super chat.
  static const String flyScreen = '108';

  /// What a fly-screen costs, in six coins.
  static const int flyScreenPrice = 1000;

  /// A gift (`Room.present.parseGet`).
  static const String gift = '201';

  /// A follow fly-screen (跟风飞屏, `Room.GiftFlyFollow`): type 1 starts one
  /// with its words; other types count a viewer who followed it.
  static const String followFlyScreen = '324';

  /// What a follow fly-screen costs, in six coins.
  static const int followFlyScreenPrice = 2000;

  /// The gift items that are a fly-screen's purchase; their words come as a
  /// super chat, so the gift itself is not reported a second time.
  static const Set<String> flyScreenGifts = {'106', '1516'};

  /// How long a fly-screen stays among the super chats (bilibili's shortest
  /// step, one minute).
  static const Duration flyScreenDuration = Duration(minutes: 1);

  /// A list of any messages, each dispatched by its own type.
  static const String batch = '1413';

  /// The text of a public chat message that is a picture.
  static const String pictureText = '[AI表情]';

  /// The unit the app writes for six coins.
  static const String coinUnit = '六币';

  /// Largest inflated message.
  static const int maxInflatedBytes = 4 * 1024 * 1024;

  /// Deepest nesting of lists ([batch]) that is read.
  static const int maxDepth = 4;

  static const int _maxEpochSeconds = 8640000000000;
  static final RegExp _server = RegExp(r'^([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?):(\d{1,5})$');

  /// The chat servers of a `getChat.php` answer (`websock`), as
  /// `wss://<host>:<port>` in the answer's order: hosts on `6rooms.com`, ports
  /// 1–65535, each once. Throws [FormatException] for a status that is not 2xx
  /// or an answer without such a server.
  static List<Uri> servers(String body, {required int status}) {
    if (status < 200 || status >= 300) throw FormatException('getChat.php answered HTTP $status');
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      throw const FormatException('getChat.php answered no JSON');
    }
    final listed = root is Map ? root['websock'] : null;
    final servers = <Uri>[];
    for (final entry in listed is List ? listed : const <Object?>[]) {
      final match = entry is String ? _server.firstMatch(entry.trim()) : null;
      if (match == null) continue;
      final host = match[1]!.toLowerCase();
      final port = int.parse(match[2]!);
      if (port < 1 || port > 65535 || (host != '6rooms.com' && !host.endsWith('.6rooms.com'))) continue;
      final server = Uri(scheme: 'wss', host: host, port: port);
      if (!servers.contains(server)) servers.add(server);
    }
    if (servers.isEmpty) throw const FormatException('getChat.php answered no chat server');
    return servers;
  }

  /// A guest's user id, as the page makes one without a cookie:
  /// `Math.floor(1e8 * Math.random() + 18e8)`.
  static int guestId(int randomUnderOneHundredMillion) => 1800000000 + randomUnderOneHundredMillion % 100000000;

  /// The login of guest [guest] to the room of broadcaster [userId], with the
  /// empty `encpass` of a guest.
  static String login(int guest, String userId) => 'command=login\r\nuid=$guest\r\nencpass=\r\nroomid=$userId\r\n';

  /// The `key=value` lines of a frame; a line without `=` (the length line) is
  /// skipped, a key keeps its last value.
  static Map<String, String> fields(String frame) => {
    for (final line in frame.split('\r\n'))
      if (line.indexOf('=') case final at when at > 0) line.substring(0, at): line.substring(at + 1),
  };

  /// The JSON text of a `receivemessage` [content]: Base64 in the site's
  /// alphabet, raw DEFLATE when [deflated]. Throws [FormatException] when it
  /// is neither.
  static String payload(String content, {required bool deflated}) {
    final encoded = content.trim().replaceAll('(', '+').replaceAll(')', '/').replaceAll('@', '=');
    final bytes = base64.decode(base64.normalize(encoded));
    return utf8.decode(deflated ? _inflate(bytes) : bytes, allowMalformed: true);
  }

  static Uint8List _inflate(List<int> bytes) {
    final sink = _BoundedSink(maxInflatedBytes);
    ZLibDecoder(raw: true).startChunkedConversion(sink)
      ..add(bytes)
      ..close();
    return sink.bytes.takeBytes();
  }

  /// One frame (text, or UTF-8 bytes):
  ///
  /// - a `result` says whether the login was accepted or refused; other
  ///   results (`send.success`) say nothing;
  /// - a `receivemessage` with flag `001` gives its chat; one of the
  ///   [stoppingFlags] is a [SixRoomDanmakuFrame.refusal]; other flags say
  ///   nothing;
  /// - anything that cannot be read says nothing.
  static SixRoomDanmakuFrame decode(Object? data) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return SixRoomDanmakuFrame.empty;
    final frame = fields(text);
    final content = frame['content'];
    if (content == null) return SixRoomDanmakuFrame.empty;
    switch (frame['command']) {
      case 'result':
        return switch (content.trim()) {
          'login.success' => const SixRoomDanmakuFrame(joined: true),
          'login.failed' => const SixRoomDanmakuFrame(loginFailed: true),
          _ => SixRoomDanmakuFrame.empty,
        };
      case 'receivemessage':
        final Object? root;
        try {
          root = jsonDecode(payload(content, deflated: frame['enc'] == 'yes'));
        } on FormatException {
          return SixRoomDanmakuFrame.empty;
        }
        if (root is! Map) return SixRoomDanmakuFrame.empty;
        final flag = _text(root['flag']);
        if (flag == '001') return SixRoomDanmakuFrame(messages: messages(root['content']));
        if (!stoppingFlags.contains(flag)) return SixRoomDanmakuFrame.empty;
        final said = _text(root['content']);
        return SixRoomDanmakuFrame(refusal: said.isEmpty ? 'flag $flag' : 'flag $flag: $said');
      default:
        return SixRoomDanmakuFrame.empty;
    }
  }

  /// The chat of one message (`content` of a `001` frame): public chat, a list
  /// of them ([publicChatList]), a fly-screen super chat, a gift, a follow
  /// fly-screen, or a list of any messages ([batch]) at most [maxDepth] deep;
  /// a message the page hides from a guest and every other type give nothing.
  static List<LiveMessage> messages(Object? message) {
    final found = <LiveMessage>[];
    _collect(message, 0, found);
    return found;
  }

  static void _collect(Object? message, int depth, List<LiveMessage> found) {
    if (message is! Map || !shownToGuests(message)) return;
    switch (_text(message['typeID'])) {
      case publicChat:
        if (chat(message) case final line?) found.add(line);
      case flyScreen:
        if (fly(message) case final line?) found.add(line);
      case gift:
        if (giftMessage(message) case final line?) found.add(line);
      case followFlyScreen:
        if (followFly(message) case final line?) found.add(line);
      case publicChatList:
        for (final entry in _list(message['content'])) {
          if (entry is! Map) continue;
          if (chat(entry) case final line?) found.add(line);
        }
      case batch when depth < maxDepth:
        for (final entry in _list(message['content'])) {
          _collect(entry, depth + 1, found);
        }
    }
  }

  /// Whether the page shows [message] to a guest (`Room.Msg.get`): not when its
  /// client mask `cli` is set without the PC bit 1, and not when it names a
  /// wealth (`newLimitLevel` not -1) or star (`starLimitLevel` not -1) level a
  /// guest lacks.
  static bool shownToGuests(Map<Object?, Object?> message) {
    final cli = message['cli'];
    if (_truthy(cli) && _int32(cli) & 1 == 0) return false;
    if (message.containsKey('newLimitLevel') && _int(message['newLimitLevel']) != -1) return false;
    final star = _int(message['starLimitLevel']);
    return star == null || star == -1;
  }

  /// A public chat message (typeID 101) as white chat, or null. Without a
  /// sender name it is shown only to a "supreme mystery" (`supremeMystery` 1);
  /// the text is `content` (HTML-decoded) or a picture's [pictureText].
  static LiveMessage? chat(Map<Object?, Object?> message) {
    final name = _text(message['from']);
    if (name.isEmpty && _int(message['supremeMystery']) != 1) return null;
    final picture = message['picEmoji'];
    final text = picture is Map && _text(picture['pic']).isNotEmpty ? pictureText : _html(message['content']);
    if (text.isEmpty) return null;
    return _line(name, message, text);
  }

  /// A fly-screen message (typeID 108) as a super chat: the name `from`, the
  /// text `content`, [flyScreenPrice] six coins, shown for
  /// [flyScreenDuration]. Null without text.
  static LiveMessage? fly(Map<Object?, Object?> message, {DateTime? now}) {
    final text = _html(message['content']);
    if (text.isEmpty) return null;
    final line = _line(_text(message['from']), message, text);
    final start = line.sentAt ?? now ?? DateTime.now();
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: line.userName,
      userId: line.userId,
      message: text,
      sentAt: line.sentAt,
      color: 0xFFFFFF,
      data: LiveSuperChat(
        message: text,
        price: flyScreenPrice,
        priceText: '$flyScreenPrice $coinUnit',
        startTime: start,
        endTime: start.add(flyScreenDuration),
      ),
    );
  }

  /// A gift (typeID 201) as a gift message, or null: not without a sender, an
  /// item, or for a fly-screen's purchase. Its id, receiver name, combo total
  /// and picture have no field here; a combo keeps only its key in [
  /// LiveGift.combo]. The text is `<name> ×<count>`.
  static LiveMessage? giftMessage(Map<Object?, Object?> message) {
    final sender = _text(message['fid']);
    if (sender.isEmpty || sender == '0') return null;
    final content = message['content'];
    if (content is! Map) return null;
    final item = _text(content['item']);
    if (item.isEmpty || item == '0' || flyScreenGifts.contains(item)) return null;
    final count = _positive(content['num'], 1);
    final coins = _int(content['giftCoin']) ?? 0;
    final keep = content['keep'];
    final combo = keep is Map ? _text(keep['tmp_id']) : '';
    final continued = _text(content['isContinue']) == '1' && combo.isNotEmpty && combo != '0';
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _text(message['from']),
      userId: sender,
      message: '${_html(content['itemName'])} ×$count',
      id: _text(message['askId']).isEmpty ? null : _text(message['askId']),
      sentAt: _time(message['tm']),
      color: 0xFFFFFF,
      data: LiveGift(
        name: _html(content['itemName']),
        count: count,
        unitPrice: coins > 0 && coins % count == 0 ? coins ~/ count : 0,
        totalValue: coins > 0 ? coins : null,
        combo: continued ? '$sender:$combo' : null,
      ),
    );
  }

  /// A follow fly-screen (typeID 324, `content.type` 1) as a super chat like
  /// [fly]'s: the name `alias`, the words `msg`, [followFlyScreenPrice] six
  /// coins, the id `follow-fly:<id>`. Null without words or for the other
  /// types.
  static LiveMessage? followFly(Map<Object?, Object?> message, {DateTime? now}) {
    final content = message['content'];
    if (content is! Map || _text(content['type']) != '1') return null;
    final text = _html(content['msg']);
    if (text.isEmpty) return null;
    final name = _text(content['alias']);
    final line = _line(name, {'tm': message['tm'], 'fid': content['uid']}, text);
    final start = line.sentAt ?? now ?? DateTime.now();
    final id = _text(content['id']);
    final key = id.isEmpty ? null : 'follow-fly:$id';
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: name,
      userId: line.userId,
      message: text,
      sentAt: line.sentAt,
      id: key,
      color: 0xFFFFFF,
      data: LiveSuperChat(
        message: text,
        price: followFlyScreenPrice,
        priceText: '$followFlyScreenPrice $coinUnit',
        startTime: start,
        endTime: start.add(flyScreenDuration),
      ),
    );
  }

  static LiveMessage _line(String name, Map<Object?, Object?> message, String text) => LiveMessage(
    type: LiveMessageType.chat,
    userName: name,
    userId: _text(message['fid']),
    message: text,
    sentAt: _time(message['tm']),
    color: 0xFFFFFF,
  );

  static DateTime? _time(Object? value) {
    final time = _int(value);
    return time != null && time > 0 && time <= _maxEpochSeconds
        ? DateTime.fromMillisecondsSinceEpoch(time * 1000)
        : null;
  }

  static String _html(Object? value) => switch (value) {
    final String text => SiteText.unescape(text.replaceAll('&amp;', '&')).trim(),
    final int number => '$number',
    _ => '',
  };

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };

  static int? _int(Object? value) => value is int ? value : int.tryParse('${value ?? ''}'.trim());

  static int _positive(Object? value, int fallback) {
    final number = _int(value);
    return number != null && number > 0 ? number : fallback;
  }

  static bool _truthy(Object? value) => switch (value) {
    null || false || '' => false,
    final num number => number != 0 && !number.isNaN,
    _ => true,
  };

  static int _int32(Object? value) => switch (value) {
    true => 1,
    final int number => number,
    final double number when number.isFinite => number.truncate(),
    final String text => switch (num.tryParse(text.trim())) {
      final num number when number.isFinite => number.truncate(),
      _ => 0,
    },
    _ => 0,
  };
}

/// Collects inflated bytes and fails once they pass [limit], so a highly
/// compressible message is rejected before it is all in memory.
final class _BoundedSink implements Sink<List<int>> {
  new(this.limit);

  final int limit;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) {
      throw FormatException('Six Rooms inflated message exceeds $limit bytes');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
