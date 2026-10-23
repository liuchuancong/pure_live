import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/common/normalization/html_entities.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_endpoints.dart';
import 'package:live_sites/src/platforms/sixroom/api/sixroom_http.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_json.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one Six Rooms chat frame held ([SixroomDanmakuCodec.decode]).
final class SixroomDanmakuFrame {
  /// Creates the result.
  const SixroomDanmakuFrame({this.messages = const [], this.joined = false, this.loginFailed = false, this.refusal});

  /// Nothing to act on.
  static const SixroomDanmakuFrame empty = SixroomDanmakuFrame();

  /// Chat, super chats and gifts, in order.
  final List<LiveMessage> messages;

  /// The login was accepted (`command=result`, `content=login.success`).
  final bool joined;

  /// The login was refused (`content=login.failed`); the room page logs in
  /// again.
  final bool loginFailed;

  /// An error flag on which the room page stops its socket for good (kicked,
  /// room full, paid or password room, room closed, banned), as
  /// `flag <code>` and the server's text when it sent one; null otherwise.
  final String? refusal;
}

/// Six Rooms' room chat, as the public room page (`v.6.cn/<room>`) runs it
/// anonymously, without I/O.
///
/// - The chat servers of a room come from `GET /room/getChat.php?rid=<the
///   broadcaster's user id>`: `{"websock": ["<host>:<port>", …]}`, four
///   `*.6rooms.com` hosts on the room's shard port. The page shuffles them
///   and moves to the next one at every new login.
/// - Every frame is text: a line with the byte length of the rest, then
///   `key=value` lines (`\r\n`), each frame one command.
/// - The client logs in with `command=login`, its user id, its `encpass`
///   (empty for a guest) and the broadcaster's user id as `roomid`; a
///   guest's user id is a random number from 1800000000 to 1899999999 (the
///   page's `guest_id`). The server answers `command=result`, `content=
///   login.success` (or `login.failed`).
/// - The client then sends the page's heartbeat, `noop` deflated
///   (`y8vPLwAA`), every 16 s; a socket that sends nothing is closed after
///   20 s (measured). The server answers `send.success`, and a guest that
///   never asked for its own details (`priv_info`, which this client does
///   not send) also gets flag 205.
/// - Everything else comes as `command=receivemessage`, `enc=yes|no`,
///   `content=<Base64>`: with `enc=yes` raw DEFLATE with `+`, `/`, `=`
///   written `(`, `)`, `@`; a JSON object `{"flag": "001", "content": {…}}`
///   whose `typeID` says what it is (101 public chat, 110 a list of them,
///   1413 a list of any messages, 108 a fly-screen message). Another flag is
///   an error.
abstract final class SixroomDanmakuCodec {
  /// The page's heartbeat period (`_heartbeat`, 16 s).
  static const Duration heartbeatInterval = Duration(seconds: 16);

  /// How long the login may take (the page's `timeout`, 6 s).
  static const Duration joinTimeout = Duration(seconds: 6);

  /// How long one socket handshake may take.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Silence after which the socket is replaced: the server drops a socket
  /// that sends nothing for 20 s, so this only catches a half-open one.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// Refused logins in a row after which the connection gives up (the page
  /// logs in again up to 100 times; any frame resets the runtime's count, so
  /// the connection counts refusals itself).
  static const int maxRefusals = 3;

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Handshake headers: the site's origin and the adapter's desktop UA, as
  /// the room page sends them (the server also accepts a handshake without
  /// an origin).
  static Map<String, String> get socketHeaders => {
    'origin': SixroomEndpoints.origin,
    'user-agent': SixroomEndpoints.userAgent,
  };

  /// The heartbeat frame: `noop`, deflated and encoded (the page's
  /// `y8vPLwAA`).
  static const String heartbeat = 'command=sendmessage\r\ncontent=y8vPLwAA\r\n';

  /// Error flags on which the room page stops its socket (`parseErr`): 101
  /// kicked, 102 full, 103 paid room, 104 password room, 109–114 banned or
  /// removed, 204 room closed, 305 not allowed by rank, 306 log in again.
  /// Other flags only prompt a user who speaks (or, 205, a guest that never
  /// asked for its details) and are ignored.
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

  /// A list of public chat messages (`content`), each read like [publicChat].
  static const String publicChatList = '110';

  /// A fly-screen message (飞屏, a paid message flying over the video;
  /// `Room.GiftFly`): a super chat.
  static const String flyScreen = '108';

  /// What a fly-screen costs, in six coins: the room page's button says
  /// "飞屏，价格：1000个六币" (`data-sug`), and its script sends one
  /// (`prop_flymsg`) after asking "“飞屏”等同于礼物，价值1000六币" (checked
  /// 2026-10-09). The 2000-coin "跟风飞屏" is a gift (`gid` 1516) whose words
  /// come in another message ([followFlyScreen]), not a 108.
  static const int flyScreenPrice = 1000;

  /// A gift (`Room.present.parseGet`): read with [giftMessage].
  static const String gift = '201';

  /// A follow fly-screen (跟风飞屏, `Room.GiftFlyFollow`): `content.type` 1
  /// starts one with its words (`msg`), from `alias` (`uid`); other types
  /// count a viewer who followed it. Read with [followFly].
  static const String followFlyScreen = '324';

  /// What a follow fly-screen costs: "“跟风飞屏”等同于礼物，价值2000六币" (the
  /// page's `GiftFlyFollow.send`, checked 2026-10-09).
  static const int followFlyScreenPrice = 2000;

  /// The gift items that are a fly-screen's purchase (`106` 飞屏, `1516`
  /// 跟风飞屏, in the page's own gift table): their words come as a super
  /// chat ([flyScreen], [followFlyScreen]), so the gift itself is not
  /// reported a second time.
  static const Set<String> flyScreenGifts = {'106', '1516'};

  /// How long a fly-screen stays among the super chats: the page flies it
  /// across the video once and keeps no list, so the shortest step of
  /// Bilibili's super chats (one minute), which Kick and CHZZK use too.
  static const Duration flyScreenDuration = Duration(minutes: 1);

  /// A list of any messages (`content`), each dispatched by its own type.
  static const String batch = '1413';

  /// The text of a public chat message that is a picture (`picEmoji.pic`: the
  /// page shows the image instead of the text, with the alternative text
  /// AI表情).
  static const String pictureText = '[AI表情]';

  /// The platform's paid currency, which every price here is denominated in.
  static const String currency = '六币';

  /// Largest inflated message.
  static const int maxInflatedBytes = 4 * 1024 * 1024;

  /// Deepest nesting of lists ([batch]) that is read.
  static const int maxDepth = 4;

  static const int _maxEpochSeconds = 8640000000000;

  static final RegExp _roomId = RegExp(r'^[1-9]\d{1,11}$');
  static final RegExp _server = RegExp(r'^([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?):(\d{1,5})$');

  /// The request for the chat servers of [args]' room, as the page sends it
  /// (jQuery's JSON request from the room page).
  static Uri serversUrl(SixroomDanmakuArgs args) => SixroomEndpoints.chatServersUrl(args.userId);

  /// The chat servers of a `getChat.php` [response] (`websock`), as
  /// `wss://<host>:<port>` in the answer's order: hosts on `6rooms.com`,
  /// ports 1–65535, each once. Throws a [SixroomFailure] for a status that
  /// is not 2xx or an answer without such a server (a missing room gets
  /// `[]`).
  static List<Uri> servers(SixroomResponse response) {
    const what = 'chat servers';
    SixroomJson.checkBody(response.text, what, response.status);
    final Object? root;
    try {
      root = jsonDecode(response.text);
    } on FormatException {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, 'chat servers: not JSON');
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
    if (servers.isEmpty) {
      throw const SixroomFailure(SixroomFailureKind.apiChanged, '$what: answered no chat server');
    }
    return servers;
  }

  /// [args] if they name a room: a room number and a broadcaster's user id,
  /// trimmed; null otherwise.
  static SixroomDanmakuArgs? checked(SixroomDanmakuArgs args) {
    final roomId = args.roomId.trim();
    final userId = args.userId.trim();
    if (!_roomId.hasMatch(roomId) || !SixroomEndpoints.isUserId(userId)) return null;
    return SixroomDanmakuArgs(roomId: roomId, userId: userId);
  }

  /// A guest's user id, as the page makes one without a `_LiveGuestUser`
  /// cookie: `Math.floor(1e8 * Math.random() + 18e8)`.
  static int guestId(Random random) => 1800000000 + random.nextInt(100000000);

  /// The login of guest [guestId] to the room of broadcaster [userId], with
  /// the empty `encpass` of a guest.
  static String login(int guestId, String userId) => 'command=login\r\nuid=$guestId\r\nencpass=\r\nroomid=$userId\r\n';

  /// The `key=value` lines of a frame; a line without `=` (the length line)
  /// is skipped, a key keeps its last value.
  static Map<String, String> fields(String frame) => {
    for (final line in frame.split('\r\n'))
      if (line.indexOf('=') case final at when at > 0) line.substring(0, at): line.substring(at + 1),
  };

  /// The JSON text of a `receivemessage` [content]: Base64 in the site's
  /// alphabet (standard Base64 reads the same), raw DEFLATE when [deflated].
  /// Throws [FormatException] when it is neither.
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
  /// - a `receivemessage` with flag `001` gives its chat ([messages]); one
  ///   of the [stoppingFlags] is a [SixroomDanmakuFrame.refusal]; other
  ///   flags say nothing;
  /// - anything that cannot be read says nothing.
  static SixroomDanmakuFrame decode(Object? data, {DateTime? now}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return SixroomDanmakuFrame.empty;
    final frame = fields(text);
    final content = frame['content'];
    if (content == null) return SixroomDanmakuFrame.empty;
    switch (frame['command']) {
      case 'result':
        return switch (content.trim()) {
          'login.success' => const SixroomDanmakuFrame(joined: true),
          'login.failed' => const SixroomDanmakuFrame(loginFailed: true),
          _ => SixroomDanmakuFrame.empty,
        };
      case 'receivemessage':
        final Object? root;
        try {
          root = jsonDecode(payload(content, deflated: frame['enc'] == 'yes'));
        } on FormatException {
          return SixroomDanmakuFrame.empty;
        }
        if (root is! Map) return SixroomDanmakuFrame.empty;
        final flag = _text(root['flag']);
        if (flag == '001') return SixroomDanmakuFrame(messages: messages(root['content'], now: now));
        if (!stoppingFlags.contains(flag)) return SixroomDanmakuFrame.empty;
        final said = _text(root['content']);
        return SixroomDanmakuFrame(refusal: said.isEmpty ? 'flag $flag' : 'flag $flag: $said');
      default:
        return SixroomDanmakuFrame.empty;
    }
  }

  /// The chat of one message (`content` of a `001` frame), as the page
  /// shows it to a guest:
  ///
  /// - public chat ([publicChat]) is read with [chat], fly-screen messages
  ///   ([flyScreen]) with [fly] (super chats), gifts ([gift]) with
  ///   [giftMessage] and follow fly-screens ([followFlyScreen]) with
  ///   [followFly];
  /// - a list of public chat ([publicChatList]) gives each entry's [chat];
  /// - a list of messages ([batch]) gives each entry's messages, at most
  ///   [maxDepth] lists deep;
  /// - a message the page hides from a guest ([shownToGuests]) and every
  ///   other type (entries, rankings, PK states, room notices) give
  ///   nothing.
  static List<LiveMessage> messages(Object? message, {DateTime? now}) {
    final found = <LiveMessage>[];
    _collect(message, 0, found, now: now);
    return found;
  }

  static void _collect(Object? message, int depth, List<LiveMessage> found, {DateTime? now}) {
    if (message is! Map || !shownToGuests(message)) return;
    switch (_text(message['typeID'])) {
      case publicChat:
        if (chat(message) case final LiveMessage line) found.add(line);
      case flyScreen:
        if (fly(message, now: now) case final LiveMessage line) found.add(line);
      case gift:
        if (giftMessage(message) case final LiveMessage line) found.add(line);
      case followFlyScreen:
        if (followFly(message, now: now) case final LiveMessage line) found.add(line);
      case publicChatList:
        for (final entry in _list(message['content'])) {
          if (entry is! Map) continue;
          if (chat(entry) case final LiveMessage line) found.add(line);
        }
      case batch when depth < maxDepth:
        for (final entry in _list(message['content'])) {
          _collect(entry, depth + 1, found, now: now);
        }
    }
  }

  /// Whether the page shows [message] to a guest (`Room.Msg.get`), with
  /// JavaScript's conversions:
  ///
  /// - not when its client mask `cli` is set (truthy) without the PC bit 1;
  /// - not when it names a wealth level (`newLimitLevel` present and not -1)
  ///   or a star level (`starLimitLevel` a number other than -1): a guest
  ///   has neither.
  static bool shownToGuests(Map<Object?, Object?> message) {
    final cli = message['cli'];
    if (_truthy(cli) && _int32(cli) & 1 == 0) return false;
    if (message.containsKey('newLimitLevel') && jsonInt(message['newLimitLevel']) != -1) return false;
    final star = jsonInt(message['starLimitLevel']);
    return star == null || star == -1;
  }

  static bool _truthy(Object? value) => switch (value) {
    null || false || '' => false,
    final num number => number != 0 && !number.isNaN,
    _ => true,
  };

  /// The JSON whole number of [value] (a JSON number of integral value, or
  /// its text), else null.
  static int? jsonInt(Object? value) => switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.toInt() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
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

  /// A public chat message (typeID 101) as white chat, as the page's
  /// `parsePub` shows it, or null:
  ///
  /// - a message without a sender name (`from`) is not shown, unless the
  ///   sender is a "supreme mystery" (`supremeMystery` 1);
  /// - the text is `content` with `&amp;` read as `&` and then its character
  ///   references decoded (the page writes it as HTML), trimmed; a picture
  ///   (`picEmoji.pic`) is [pictureText]; face codes (`/狂笑`) stay as
  ///   written; no text: null;
  /// - the name is `from`, the user id `fid`, the time `tm` (seconds); the
  ///   addressee (`to`) is not shown.
  ///
  /// It has no message id.
  static LiveMessage? chat(Map<Object?, Object?> message) {
    final name = _text(message['from']);
    if (name.isEmpty && jsonInt(message['supremeMystery']) != 1) return null;
    final picture = message['picEmoji'];
    final text = picture is Map && _text(picture['pic']).isNotEmpty ? pictureText : _html(message['content']);
    if (text.isEmpty) return null;
    return _line(name, message, text);
  }

  /// A fly-screen message (typeID 108) as a super chat: the name `from`, the
  /// text `content` (read like [chat]'s), the user id `fid` and the time
  /// `tm` when given; the price [flyScreenPrice] six coins; shown from `tm`
  /// (else [now], default the current time) for [flyScreenDuration]. The
  /// page draws it in its own look and names no colours, and gives no
  /// avatar. Null without text. The page flies it over the video as
  /// `<from>说：<content>`.
  static LiveMessage? fly(Map<Object?, Object?> message, {DateTime? now}) {
    final text = _html(message['content']);
    if (text.isEmpty) return null;
    final name = _text(message['from']);
    final line = _line(name, message, text);
    final start = line.sentAt ?? now ?? DateTime.now();
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: line.sender,
      text: text,
      sentAt: line.sentAt,
      color: LiveMessageColor.white,
      payload: LiveSuperChatMessage.of(
        userName: name,
        text: text,
        price: SuperChatPrice.of(amount: flyScreenPrice, currency: currency, displayText: '$flyScreenPrice$currency'),
        startTime: start,
        endTime: start.add(flyScreenDuration),
      ),
    );
  }

  /// A gift (typeID 201) as a [LiveMessageType.gift] message with a
  /// [LiveGift], as the page's chat list writes it
  /// (`Room.present.chatMsg`: `<from> 送N个<title>`), or null:
  ///
  /// - not without a sender (`fid` empty or 0: the page writes a game's
  ///   prize, `<to> 参与 <from> 获得…`, not a gift), without an item, or for
  ///   a fly-screen's purchase ([flyScreenGifts]);
  /// - [LiveGift.giftId] `content.item`, [LiveGift.name] `content.itemName`
  ///   (the page's table title), [LiveGift.count] `content.num`;
  /// - [LiveGift.value] `content.giftCoin`, the six coins the send cost
  ///   (0, a gift from the viewer's stock, has no value), the unit price
  ///   that over the count when it divides;
  /// - a combo (`content.isContinue` 1 with `content.keep.tmp_id`, which the
  ///   page folds into one line for 6 s) has [LiveGift.combo]'s key
  ///   `<fid>:<tmp_id>` and total `num × groupnum`, the count the folded
  ///   line shows;
  /// - [LiveGift.iconUrl] only for a picture the message carries
  ///   (`content.aiGiftPic`): the page's gift table, which has the others,
  ///   is an 8 MB script; [LiveGift.recipientName] `to`;
  /// - the sender `from` and `fid`, the time `tm`, the id `askId`.
  static LiveMessage? giftMessage(Map<Object?, Object?> message) {
    final sender = _text(message['fid']);
    if (sender.isEmpty || sender == '0') return null;
    final content = message['content'];
    if (content is! Map) return null;
    final item = _text(content['item']);
    if (item.isEmpty || item == '0' || flyScreenGifts.contains(item)) return null;
    final count = max(1, jsonInt(content['num']) ?? 1);
    final coins = jsonInt(content['giftCoin']) ?? 0;
    final keep = content['keep'];
    final combo = keep is Map ? _text(keep['tmp_id']) : '';
    final continued = _text(content['isContinue']) == '1' && combo.isNotEmpty && combo != '0';
    final hits = max(1, jsonInt(content['groupnum']) ?? 1);
    final picture = Uri.tryParse(_text(content['aiGiftPic']));
    final data = LiveGift.of(
      giftId: item,
      name: _html(content['itemName']),
      count: count,
      value: LiveGiftValue.of(
        unit: coins > 0 ? LiveGiftUnit.sixCoin : LiveGiftUnit.free,
        unitPrice: coins > 0 && coins % count == 0 ? (coins ~/ count).toDouble() : null,
        totalValue: coins > 0 ? coins.toDouble() : null,
      ),
      combo: LiveGiftCombo.of(comboKey: continued ? '$sender:$combo' : '', comboTotal: continued ? count * hits : null),
      iconUrl: picture != null && picture.host.isNotEmpty && (picture.isScheme('https') || picture.isScheme('http'))
          ? '${picture.replace(scheme: 'https')}'
          : null,
      recipientName: _text(message['to']),
    );
    final text = '${data.name} ×${data.count}';
    final line = _line(_text(message['from']), message, text);
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: line.sender,
      text: text,
      color: LiveMessageColor.white,
      messageId: _text(message['askId']),
      sentAt: line.sentAt,
      payload: data,
    );
  }

  /// A follow fly-screen (typeID 324, `content.type` 1) as a super chat like
  /// [fly]'s: the name `alias`, the user id `uid`, the words `msg` (read
  /// like [chat]'s), [followFlyScreenPrice] six coins, shown from `tm` (else
  /// [now]) for [flyScreenDuration]; the id `follow-fly:<id>`. Null without
  /// words, and for the other types (a viewer who followed: the page only
  /// counts them).
  static LiveMessage? followFly(Map<Object?, Object?> message, {DateTime? now}) {
    final content = message['content'];
    if (content is! Map || _text(content['type']) != '1') return null;
    final text = _html(content['msg']);
    if (text.isEmpty) return null;
    final name = _text(content['alias']);
    final line = _line(name, {'tm': message['tm'], 'fid': content['uid']}, text);
    final start = line.sentAt ?? now ?? DateTime.now();
    final id = _text(content['id']);
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: line.sender,
      text: text,
      sentAt: line.sentAt,
      messageId: id.isEmpty ? '' : 'follow-fly:$id',
      color: LiveMessageColor.white,
      payload: LiveSuperChatMessage.of(
        messageId: id.isEmpty ? '' : 'follow-fly:$id',
        userName: name,
        text: text,
        price: SuperChatPrice.of(
          amount: followFlyScreenPrice,
          currency: currency,
          displayText: '$followFlyScreenPrice$currency',
        ),
        startTime: start,
        endTime: start.add(flyScreenDuration),
      ),
    );
  }

  static LiveMessage _line(String name, Map<Object?, Object?> message, String text) {
    final time = jsonInt(message['tm']);
    return LiveMessage.normalized(
      sender: MessageSender.normalized(userId: _text(message['fid']), userName: name),
      text: text,
      sentAt: time != null && time > 0 && time <= _maxEpochSeconds
          ? DateTime.fromMillisecondsSinceEpoch(time * 1000)
          : null,
      color: LiveMessageColor.white,
    );
  }

  static String _html(Object? value) => switch (value) {
    final String text => decodeHtmlEntities(text.replaceAll('&amp;', '&')).trim(),
    final int number => '$number',
    _ => '',
  };

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };
}

/// Collects inflated bytes and fails once they pass [limit], so a highly
/// compressible message is rejected before it is all in memory.
final class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this.limit);

  final int limit;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) {
      throw const FormatException('Six Rooms inflated message exceeds 4194304 bytes');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
