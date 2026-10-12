import 'dart:convert';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_parser.dart';
import 'package:meta/meta.dart';

/// What one KilaKila chat frame held ([KilakilaDanmakuProtocol.decode]).
@immutable
final class KilakilaDanmakuFrame {
  /// Creates the result.
  const new({this.messages = const [], this.joined = false, this.refusal, this.dropped = false});

  /// Nothing to act on.
  static const KilakilaDanmakuFrame empty = KilakilaDanmakuFrame();

  /// Chat, gifts and audience updates, in order.
  final List<LiveMessage> messages;

  /// The server confirmed the guest namespace (its `40` packet, or the
  /// `connect_error` event with `code 0`).
  final bool joined;

  /// The server refused the join. The text is its message, or the code.
  final String? refusal;

  /// The server left the namespace (Socket.IO `41`) or is closing the
  /// transport (Engine.IO `1`).
  final bool dropped;
}

/// KilaKila's guest chat room, without I/O: Socket.IO 2 over Engine.IO 3 on a
/// WebSocket, the namespace `/live_chat_room_guest`.
///
/// - The socket's query names the broadcast (`roomId`); the server subscribes
///   the socket by it. The client joins the namespace with a text frame and
///   sends the Engine.IO ping `2` every 25 s; the server answers `3`.
/// - Chat and room state come as `text_message` events whose payload is a JSON
///   string; `body.response.content` is another JSON string with short names.
///
/// Mapped onto this tree's models: red beans (the platform's paid currency)
/// count as [LiveGiftUnit.gold] and a gift's id, receiver name, picture and
/// per-hit combo total have no field here and are dropped (a combo keeps only
/// its send number in [LiveGift.combo]); a level has no field; colour is an
/// int and a message id is `id`.
abstract final class KilakilaDanmakuProtocol {
  /// The chat server.
  static const String host = 'wim.hongrenshuo.com.cn';

  /// The guest namespace.
  static const String namespace = '/live_chat_room_guest';

  /// Engine.IO ping period: the server announces `pingInterval: 25000`.
  static const Duration heartbeatInterval = Duration(seconds: 25);

  /// The Engine.IO ping; the server answers `3`.
  static const String ping = '2';

  /// Handshake headers: the site's origin and the desktop UA. No cookie:
  /// guests are anonymous.
  static Map<String, String> get handshakeHeaders => {
    'origin': 'https://${KilakilaParser.liveHost}',
    'user-agent': KilakilaParser.headers['user-agent']!,
  };

  /// `content.t` of a chat line.
  static const int chatType = 200;

  /// `content.t` of the room state pushed about every 5 s.
  static const int roomStateType = 637;

  /// `content.t` of a gift animation (the page's gift bar).
  static const int giftType = 220;

  /// `content.t` of a gift line (the page's chat list), sent when a combo ends.
  static const int giftLineType = 10004;

  /// `content.t` of the messages that change the broadcast's board (the paid
  /// question).
  static const Set<int> boardTypes = {240, 300, 301, 532, 534, 706};

  /// `uc.uiType` values with which the page shows `uc.question` on the board.
  static const Set<int> questionUiTypes = {2, 3, 6, 7, 10, 11, 14, 15};

  /// How long a paid question stays a super chat.
  static const Duration questionDisplay = Duration(minutes: 5);

  /// The unit the app writes for red beans.
  static const String beanUnit = '红豆';

  static const int _maxMillis = 8640000000000000;

  static String _query(String roomId) => 'roomId=$roomId&appId=111&clientType=1';

  /// The socket of broadcast [roomId].
  static Uri endpoint(String roomId) => Uri.parse('wss://$host/socket.io/?${_query(roomId)}&EIO=3&transport=websocket');

  /// The namespace connect packet for [roomId], sent as text as soon as the
  /// socket opens.
  static String join(String roomId) => '40$namespace?${_query(roomId)},';

  /// Reads one frame of [roomId]'s socket.
  ///
  /// - Engine.IO: `0` (open), `3` (pong) and `6` (noop) hold nothing; `1` means
  ///   the server is closing ([KilakilaDanmakuFrame.dropped]).
  /// - Socket.IO on the guest namespace: `40` joined, `41` dropped, `44` a
  ///   refusal, `42` an event: `connect_error` (joined when its `code` is 0, a
  ///   refusal otherwise) or `text_message`.
  ///
  /// Other namespaces, events, binary frames and anything malformed give
  /// nothing.
  static KilakilaDanmakuFrame decode(Object? data, {required String roomId, DateTime? now}) {
    if (data is! String || data.isEmpty) return KilakilaDanmakuFrame.empty;
    switch (data[0]) {
      case '1':
        return const KilakilaDanmakuFrame(dropped: true);
      case '4':
        return _packet(data.substring(1), roomId: roomId, now: now);
      default:
        return KilakilaDanmakuFrame.empty;
    }
  }

  static KilakilaDanmakuFrame _packet(String packet, {required String roomId, DateTime? now}) {
    if (packet.isEmpty) return KilakilaDanmakuFrame.empty;
    final rest = packet.substring(1);
    if (!rest.startsWith(namespace)) return KilakilaDanmakuFrame.empty;
    final after = rest.substring(namespace.length);
    if (after.isNotEmpty && after[0] != ',') return KilakilaDanmakuFrame.empty;
    final body = after.isEmpty ? '' : after.substring(1);
    switch (packet[0]) {
      case '0':
        return const KilakilaDanmakuFrame(joined: true);
      case '1':
        return const KilakilaDanmakuFrame(dropped: true);
      case '2':
        return _event(body, roomId: roomId, now: now);
      case '4':
        return KilakilaDanmakuFrame(refusal: _errorText(body));
      default:
        return KilakilaDanmakuFrame.empty;
    }
  }

  static KilakilaDanmakuFrame _event(String body, {required String roomId, DateTime? now}) {
    final Object? event;
    try {
      event = jsonDecode(body);
    } on FormatException {
      return KilakilaDanmakuFrame.empty;
    }
    if (event case [final String name, final String json, ...]) {
      final payload = _object(json);
      if (payload == null) return KilakilaDanmakuFrame.empty;
      switch (name) {
        case 'connect_error':
          final code = payload['code'];
          if (code == 0) return const KilakilaDanmakuFrame(joined: true);
          final message = payload['message'];
          return KilakilaDanmakuFrame(refusal: message is String && message.isNotEmpty ? message : 'code $code');
        case 'text_message':
          return KilakilaDanmakuFrame(
            messages: [?textMessage(payload, roomId: roomId, now: now)],
          );
      }
    }
    return KilakilaDanmakuFrame.empty;
  }

  static String _errorText(String body) {
    try {
      switch (jsonDecode(body)) {
        case final String error when error.isNotEmpty:
          return error;
        case {'message': final String message} when message.isNotEmpty:
          return message;
      }
    } on FormatException {
      // Not JSON: the text itself.
    }
    return body.isEmpty ? 'error' : body;
  }

  /// The message of one `text_message` [payload] of [roomId], or null.
  ///
  /// `body.response` holds `room_id` (another broadcast is skipped), `mid`,
  /// `created_at` and `content` (a JSON string whose `t` is the kind): a chat
  /// line ([chat]), the room state ([audience]), a gift ([gift]), or a paid
  /// question on the board ([question]). Everything else holds nothing.
  static LiveMessage? textMessage(Map<Object?, Object?> payload, {required String roomId, DateTime? now}) {
    if (payload case {'body': {'response': final Map<Object?, Object?> response}}) {
      final room = response['room_id'];
      if (room != null && '$room' != roomId) return null;
      final content = _object(response['content']);
      return switch (content?['t']) {
        chatType => chat(content!, response),
        roomStateType => audience(content!),
        giftType || giftLineType => gift(content!, response),
        final int type when boardTypes.contains(type) => question(content!, response, now: now),
        _ => null,
      };
    }
    return null;
  }

  /// A gift: a gift line (10004) or animation (220). A combo's line and hits
  /// carry the running count in `doubleCount` and share the send number `c.no`
  /// as [LiveGift.combo]; a plain animation has no combo key. The price is red
  /// beans (its per-unit value when known). Null without a `c` object or a
  /// name. The receiver, picture and id have no field here.
  static LiveMessage? gift(Map<Object?, Object?> content, Map<Object?, Object?> response) {
    final item = content['c'];
    if (item is! Map<Object?, Object?>) return null;
    final line = content['t'] == giftLineType;
    final hit = !line && item['isDoubleHit'] == true;
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final count = _positive(item['doubleCount']);
    final price = _nonNegative(item['price']);
    final id = _id(response['mid']);
    final sender = content['n'];
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: sender is String ? sender : '',
      userId: _id(content['u']),
      message: '${name.trim()} ×$count',
      id: id.isEmpty ? null : id,
      sentAt: _time(response['created_at']),
      color: 0xFFFFFF,
      data: LiveGift(
        name: name.trim(),
        count: count,
        unitPrice: line || count == 1
            ? price
            : price % count == 0
            ? price ~/ count
            : 0,
        totalValue: line ? price * count : (price > 0 ? price : null),
        combo: (line || hit) ? _id(item['no']) : null,
      ),
    );
  }

  /// A paid question the broadcaster put on the board, as a super chat: a
  /// [boardTypes] message whose `uc.uiType` shows `uc.question` and whose
  /// `goldPrice` is above 0. The page URL-decodes every text field first. The
  /// asker is `questionNickname`/`questionUid`, the text `content`, the price
  /// `goldPrice` red beans, the id `questionId`, shown for [questionDisplay].
  /// No colours or avatar here. Null without a text.
  static LiveMessage? question(Map<Object?, Object?> content, Map<Object?, Object?> response, {DateTime? now}) {
    final board = content['uc'];
    if (board is! Map<Object?, Object?> || !questionUiTypes.contains(_integer(board['uiType']))) return null;
    final raw = board['question'];
    if (raw is! Map<Object?, Object?>) return null;
    final fields = <Object?, Object?>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      if (value is String) {
        final decoded = _decodeUriComponent(value);
        if (decoded == null) return null;
        fields[key] = decoded;
      } else {
        fields[key] = value;
      }
    }
    final price = _integer(fields['goldPrice']);
    if (price == null || price <= 0) return null;
    final body = fields['content'];
    final text = body is String ? body.trim() : '';
    if (text.isEmpty) return null;
    final asker = fields['questionNickname'];
    final name = asker is String ? asker : '';
    final id = _id(fields['questionId']);
    final sentAt = _time(response['created_at']);
    final start = sentAt ?? now ?? DateTime.now();
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: name,
      userId: _id(fields['questionUid']),
      message: text,
      color: 0xFFFFFF,
      id: id.isEmpty ? null : id,
      sentAt: sentAt,
      data: LiveSuperChat(
        message: text,
        price: price,
        priceText: '${amount(price)}$beanUnit',
        startTime: start,
        endTime: start.add(questionDisplay),
      ),
    );
  }

  /// [value] as the page writes an amount: thousands separated by commas.
  static String amount(int value) {
    final digits = value.abs().toString();
    final text = StringBuffer(value < 0 ? '-' : '');
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) text.write(',');
      text.write(digits[index]);
    }
    return text.toString();
  }

  /// A chat line (`t` 200) as white chat, or null when its text (`c`) is not
  /// text or blank. The name is `n`, the user id `u`, the id the response's
  /// `mid`, the time `created_at`. A level has no field here.
  static LiveMessage? chat(Map<Object?, Object?> content, Map<Object?, Object?> response) {
    final text = content['c'];
    if (text is! String || text.trim().isEmpty) return null;
    final name = content['n'];
    final id = _id(response['mid']);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name is String ? name : '',
      userId: _id(content['u']),
      message: text.trim(),
      color: 0xFFFFFF,
      id: id.isEmpty ? null : id,
      sentAt: _time(response['created_at']),
    );
  }

  /// The listeners now of a room state (`t` 637): its `c` is URL-encoded JSON
  /// whose `watchNumber` is what the page shows as “收听”. Null otherwise.
  static LiveMessage? audience(Map<Object?, Object?> content) {
    final encoded = content['c'];
    final state = _object(encoded is String ? _decodeUriComponent(encoded) : null);
    final watching = state?['watchNumber'];
    if (watching is! int || watching < 0) return null;
    return LiveMessage(
      type: LiveMessageType.audienceUpdate,
      userName: '',
      message: '',
      data: LiveAudienceUpdate(onlineViewers: watching),
    );
  }

  static final RegExp _badEscape = RegExp('%(?![0-9A-Fa-f]{2})');

  /// JavaScript's `decodeURIComponent`, or null where it throws.
  static String? _decodeUriComponent(String text) {
    if (!text.contains('%')) return text;
    if (_badEscape.hasMatch(text)) return null;
    final decoded = StringBuffer();
    var index = 0;
    while (index < text.length) {
      if (text.codeUnitAt(index) != 0x25) {
        decoded.writeCharCode(text.codeUnitAt(index++));
        continue;
      }
      final bytes = <int>[];
      while (index < text.length && text.codeUnitAt(index) == 0x25) {
        bytes.add(int.parse(text.substring(index + 1, index + 3), radix: 16));
        index += 3;
      }
      try {
        decoded.write(utf8.decode(bytes));
      } on FormatException {
        return null;
      }
    }
    return decoded.toString();
  }

  static Map<Object?, Object?>? _object(Object? value) {
    if (value is Map<Object?, Object?>) return value;
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<Object?, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime? _time(Object? created) =>
      created is int && created > 0 && created <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(created) : null;

  static String _id(Object? value) => switch (value) {
    final int number => '$number',
    final String text => text.trim(),
    _ => '',
  };

  static int? _integer(Object? value) => value is int ? value : int.tryParse('${value ?? ''}'.trim());

  static int _positive(Object? value) {
    final number = _integer(value);
    return number != null && number > 0 ? number : 1;
  }

  static int _nonNegative(Object? value) {
    final number = _integer(value);
    return number != null && number > 0 ? number : 0;
  }
}

/// The combos of one broadcast whose hits were reported: a combo's line or hit
/// whose count does not go above the count already reported for its send number
/// is left out, so the folded line shows one combo once.
final class KilakilaGiftCombos {
  /// Combos remembered; the oldest goes first.
  static const int capacity = 256;

  final Map<String, int> _counts = {};

  /// Whether [message] is reported: everything but a combo whose count is not
  /// above the count reported for its key so far.
  bool report(LiveMessage message) {
    final data = message.data;
    if (data is! LiveGift) return true;
    final key = data.combo;
    if (key == null || key.isEmpty) return true;
    final total = data.count;
    final shown = _counts.remove(key);
    final reported = shown == null || total > shown;
    _counts[key] = reported ? total : shown;
    if (_counts.length > capacity) _counts.remove(_counts.keys.first);
    return reported;
  }
}
