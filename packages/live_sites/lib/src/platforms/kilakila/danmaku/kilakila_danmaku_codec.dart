import 'dart:convert';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
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
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one KilaKila chat frame held.
final class KilakilaDanmakuFrame {
  /// Creates the result.
  const KilakilaDanmakuFrame({this.messages = const [], this.joined = false, this.refusal, this.dropped = false});

  /// Nothing to act on.
  static const KilakilaDanmakuFrame empty = KilakilaDanmakuFrame();

  /// Chat, audience, gifts and paid questions, in order.
  final List<LiveMessage> messages;

  /// The server confirmed the guest namespace (its `40` packet, or the
  /// `connect_error` event with `code 0`, which is how it says "join
  /// success").
  final bool joined;

  /// The server refused the join: the `connect_error` event with another
  /// code, or a Socket.IO error packet on the namespace. The text is its
  /// message, or the code.
  final String? refusal;

  /// The server left the namespace (Socket.IO `41`) or is closing the
  /// transport (Engine.IO `1`).
  final bool dropped;
}

/// The chat arguments of a broadcast: the current broadcast's `roomIdStr`,
/// which the socket's query and the namespace join name.
final class KilakilaDanmakuArgs {
  /// Creates the arguments.
  const KilakilaDanmakuArgs({required this.roomId});

  /// The current broadcast's `roomIdStr`.
  final String roomId;

  @override
  String toString() => 'KilakilaDanmakuArgs($roomId)';
}

/// KilaKila's guest chat room, without I/O: Socket.IO 2 over Engine.IO 3 on
/// a WebSocket, the namespace `/live_chat_room_guest`.
///
/// - The socket's query names the broadcast (`roomId`); the server
///   subscribes the socket by it.
/// - The client joins the namespace with a text frame, and sends the
///   Engine.IO ping `2` every 25 s (the server's `pingInterval`); the server
///   answers `3` and drops a socket that has not pinged for 85 s.
/// - Chat and room state come as `text_message` events whose payload is a
///   JSON string; its `body.response.content` is another JSON string with
///   short field names.
abstract final class KilakilaDanmakuCodec {
  /// The chat server.
  static const String host = 'wim.hongrenshuo.com.cn';

  /// The guest namespace (the live page's `ROOM_URI` path).
  static const String namespace = '/live_chat_room_guest';

  /// Engine.IO ping period: the server announces `pingInterval: 25000`.
  static const Duration heartbeatInterval = Duration(seconds: 25);

  /// The Engine.IO ping; the server answers `3`.
  static const String ping = '2';

  /// Silence after which the socket is replaced: the server drops a socket
  /// that has not pinged for 85 s, so this only catches a half-open one.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// The join budget: the room is joined when the server confirms it, within
  /// this, or the socket is replaced.
  static const Duration joinTimeout = Duration(seconds: 8);

  /// Refused joins in a row that are retried; the next one ends the session.
  static const int maxRefusals = 3;

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Handshake headers: the site's origin and the platform's user agent. No
  /// cookie: guests are anonymous.
  static const Map<String, String> handshakeHeaders = {
    'origin': KilakilaEndpoints.origin,
    'user-agent': KilakilaEndpoints.userAgent,
  };

  /// `content.t` of a chat line.
  static const int chatType = 200;

  /// `content.t` of the room state pushed about every 5 s, whose
  /// URL-encoded `c` holds `watchNumber`, the listeners now.
  static const int roomStateType = 637;

  /// `content.t` of a gift animation (the page's gift bar). A combo sends
  /// one per hit with the count so far.
  static const int giftType = 220;

  /// `content.t` of a gift line (the page's chat list), sent when a combo
  /// ends, with its total.
  static const int giftLineType = 10004;

  /// `content.t` of a paid question being asked. The page ignores it; not
  /// reported.
  static const int questionAskedType = 241;

  /// `content.t` of the messages that change the broadcast's board (room
  /// image, question card, microphone list).
  static const Set<int> boardTypes = {240, 300, 301, 532, 534, 706};

  /// `uc.uiType` values with which the page shows `uc.question` on the
  /// board; 8, 12 and 13 clear it.
  static const Set<int> questionUiTypes = {2, 3, 6, 7, 10, 11, 14, 15};

  /// How long a paid question stays a super chat: the page shows the card
  /// until the broadcaster takes it off the board; in 40 minutes of the 30
  /// busiest broadcasts paid questions stayed on the board 11–865 s, half of
  /// them under 4.5 minutes.
  static const Duration questionDisplay = Duration(minutes: 5);

  /// The currency of every price on the platform.
  static const String currency = '红豆';

  static const int _maxMillis = 8640000000000000;

  static String _query(String roomId) => 'roomId=$roomId&appId=111&clientType=1';

  /// The socket of broadcast [roomId] (Socket.IO's default path with the
  /// live page's query).
  static Uri endpoint(String roomId) => Uri.parse('wss://$host/socket.io/?${_query(roomId)}&EIO=3&transport=websocket');

  /// The namespace connect packet for [roomId], sent as text as soon as the
  /// socket opens (socket.io-client 2's form: namespace, query, comma).
  static String join(String roomId) => '40$namespace?${_query(roomId)},';

  /// Reads one frame of [roomId]'s socket.
  ///
  /// - Engine.IO: `0` (open), `3` (pong) and `6` (noop) hold nothing; `1`
  ///   means the server is closing ([KilakilaDanmakuFrame.dropped]).
  /// - Socket.IO on the guest namespace: `40` joined, `41` dropped, `44` a
  ///   refusal, `42` an event: `connect_error` (joined when its `code` is 0,
  ///   a refusal otherwise) or `text_message`.
  ///
  /// Other namespaces, other events, binary frames and anything malformed
  /// give nothing.
  static KilakilaDanmakuFrame decode(Object? data, {required String roomId}) {
    if (data is! String || data.isEmpty) return KilakilaDanmakuFrame.empty;
    switch (data[0]) {
      case '1':
        return const KilakilaDanmakuFrame(dropped: true);
      case '4':
        return _packet(data.substring(1), roomId: roomId);
      default:
        return KilakilaDanmakuFrame.empty;
    }
  }

  static KilakilaDanmakuFrame _packet(String packet, {required String roomId}) {
    if (packet.isEmpty) return KilakilaDanmakuFrame.empty;
    final rest = packet.substring(1);
    if (!rest.startsWith(namespace)) return KilakilaDanmakuFrame.empty;
    final after = rest.substring(namespace.length);
    // The namespace ends at the comma before the data, or at the end.
    if (after.isNotEmpty && after[0] != ',') return KilakilaDanmakuFrame.empty;
    final body = after.isEmpty ? '' : after.substring(1);
    switch (packet[0]) {
      case '0':
        return const KilakilaDanmakuFrame(joined: true);
      case '1':
        return const KilakilaDanmakuFrame(dropped: true);
      case '2':
        return _event(body, roomId: roomId);
      case '4':
        return KilakilaDanmakuFrame(refusal: _errorText(body));
      default:
        return KilakilaDanmakuFrame.empty;
    }
  }

  static KilakilaDanmakuFrame _event(String body, {required String roomId}) {
    final Object? event;
    try {
      event = jsonDecode(body);
    } on FormatException {
      return KilakilaDanmakuFrame.empty;
    }
    // The payload is a JSON string, as the live page parses it.
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
          return KilakilaDanmakuFrame(messages: [?textMessage(payload, roomId: roomId)]);
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
  /// `body.response` holds `room_id` (a message of another broadcast is
  /// skipped), `mid` (the message id), `created_at` (milliseconds) and
  /// `content`, a JSON string whose `t` is the kind:
  ///
  /// - [chatType]: a chat line;
  /// - [roomStateType]: the room state, whose `watchNumber` is the listeners
  ///   now;
  /// - [giftType], [giftLineType]: a gift;
  /// - [boardTypes]: a paid question put on the board, as a super chat.
  ///
  /// Everything else holds nothing to show: a question being asked (241),
  /// entries (101, 603), leaves (102), likes (210) and the first light-up
  /// (211), rank and activity updates (635, 636, 654, 663…), the broadcast's
  /// end (103, or `msg_type` 11).
  static LiveMessage? textMessage(Map<Object?, Object?> payload, {required String roomId}) {
    if (payload case {'body': {'response': final Map<Object?, Object?> response}}) {
      final room = response['room_id'];
      if (room != null && '$room' != roomId) return null;
      final content = _object(response['content']);
      return switch (content?['t']) {
        chatType => chat(content!, response),
        roomStateType => audience(content!),
        giftType || giftLineType => gift(content!, response),
        final int type when boardTypes.contains(type) => question(content!, response),
        _ => null,
      };
    }
    return null;
  }

  /// A gift:
  ///
  /// - a gift line (10004): the page's chat line for a combo that ended,
  ///   with its total count (`c.doubleCount`) and the price of one gift
  ///   (`c.price`);
  /// - a combo hit (220 with `c.isDoubleHit` true): the combo's count so far
  ///   and `c.price` for all of them so far;
  /// - another gift animation (220): a gift sent at once, `c.price` for all
  ///   of it.
  ///
  /// Every one carries `c.no` as its combo key, which a combo's hits and its
  /// line share; a hit and a line count the whole combo so far (count and
  /// combo total both `c.doubleCount`), so the UI shows one line whose count
  /// goes up. The line that only repeats the last hit's count is left out by
  /// the session's combo filter.
  ///
  /// The price of one is known for a line (`c.price`), for an animation of
  /// one gift, and for a hit whose price divides by its count. The text is
  /// the shared `念念相守 ×3` form; the receiver stays in the gift's
  /// recipient. The sender is `n` and `u`, the level `l`, the id and time
  /// the response's `mid` and `created_at`. Null without a `c` object or a
  /// gift name.
  static LiveMessage? gift(Map<Object?, Object?> content, Map<Object?, Object?> response) {
    final item = content['c'];
    if (item is! Map<Object?, Object?>) return null;
    final line = content['t'] == giftLineType;
    final hit = !line && item['isDoubleHit'] == true;
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final count = switch (_int(item['doubleCount'])) {
      final int value when value > 0 => value,
      _ => 1,
    };
    final price = switch (_int(item['price'])) {
      final int value when value > 0 => value,
      _ => 0,
    };
    final receiver = item['giftReceiverName'];
    final receiverName = receiver is String ? receiver.trim() : '';
    final icon = _url(item['pic']);
    // The platform's red bean is its paid currency, written as gold here.
    final gift = LiveGift.of(
      giftId: _id(item['id']),
      name: name.trim(),
      iconUrl: icon != null && icon.scheme == 'https' ? '$icon' : null,
      count: count,
      value: LiveGiftValue.of(
        unit: price == 0 ? LiveGiftUnit.free : LiveGiftUnit.redBean,
        unitPrice: line || count == 1
            ? price.toDouble()
            : price % count == 0
            ? (price ~/ count).toDouble()
            : null,
        totalValue: price == 0 ? null : price.toDouble(),
      ),
      combo: LiveGiftCombo.of(comboKey: _id(item['no']), comboTotal: line || hit ? count : null),
      recipientName: receiverName,
    );
    final sender = content['n'];
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(
        userId: _id(content['u']),
        userName: sender is String ? sender : '',
        userLevel: _level(content['l']),
      ),
      text: '${gift.name} ×${gift.count}',
      color: LiveMessageColor.white,
      messageId: _id(response['mid']),
      sentAt: _time(response['created_at']),
      payload: gift,
    );
  }

  /// A paid question the broadcaster put on the board, as a super chat: a
  /// [boardTypes] message whose `uc.uiType` shows `uc.question` and whose
  /// `goldPrice` is above 0. Free questions and boards without a question
  /// give nothing.
  ///
  /// The page URL-decodes every text field of the question first (and loses
  /// the message when one does not decode) and trims `content`. The super
  /// chat is the asker (`questionNickname`, `questionHeadUrl` when https,
  /// `questionUid`), the text `content`, the price `goldPrice` in red beans
  /// with the page's writing of it, the id `questionId` (the same question
  /// shown again is the same super chat), from `created_at` for
  /// [questionDisplay]; no colours. Null without a text.
  static LiveMessage? question(Map<Object?, Object?> content, Map<Object?, Object?> response) {
    final board = content['uc'];
    if (board is! Map<Object?, Object?> || !questionUiTypes.contains(_int(board['uiType']))) return null;
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
    final price = _int(fields['goldPrice']);
    if (price == null || price <= 0) return null;
    final body = fields['content'];
    final text = body is String ? body.trim() : '';
    if (text.isEmpty) return null;
    final asker = fields['questionNickname'];
    final name = asker is String ? asker : '';
    final face = _url(fields['questionHeadUrl']);
    final id = _id(fields['questionId']);
    final sentAt = _time(response['created_at']);
    final start = sentAt ?? DateTime.now();
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      sender: MessageSender.normalized(userId: _id(fields['questionUid']), userName: name),
      text: text,
      color: LiveMessageColor.white,
      messageId: id,
      sentAt: sentAt,
      payload: LiveSuperChatMessage.of(
        messageId: id,
        userName: name,
        faceUrl: face != null && face.scheme == 'https' ? '$face' : '',
        text: text,
        price: SuperChatPrice.of(amount: price, currency: currency, displayText: '${amount(price)}$currency'),
        startTime: start,
        endTime: start.add(questionDisplay),
      ),
    );
  }

  /// [value] as the page writes an amount: thousands separated by commas
  /// (6000 → `6,000`).
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
  /// text or blank: the text is `c`, trimmed; the name `n`; the user id `u`;
  /// the level `l`; the message id the response's `mid`, the time its
  /// `created_at` (left out when not a positive whole number within
  /// `DateTime`'s range). The avatar `a`, badges (`ui`, `uc`), `vip`, `m`
  /// (manager) and `g` (gender) are not read.
  static LiveMessage? chat(Map<Object?, Object?> content, Map<Object?, Object?> response) {
    final text = content['c'];
    if (text is! String || text.trim().isEmpty) return null;
    final name = content['n'];
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: _id(content['u']),
        userName: name is String ? name : '',
        userLevel: _level(content['l']),
      ),
      text: text.trim(),
      color: LiveMessageColor.white,
      messageId: _id(response['mid']),
      sentAt: _time(response['created_at']),
    );
  }

  /// `created_at`: a positive whole number of milliseconds within
  /// `DateTime`'s range, else null.
  static DateTime? _time(Object? created) =>
      created is int && created > 0 && created <= _maxMillis ? DateTime.fromMillisecondsSinceEpoch(created) : null;

  /// The listeners now of a room state (`t` 637): its `c` is URL-encoded
  /// JSON whose `watchNumber`, a whole number not below 0, is what the page
  /// shows as 收听 while the broadcast is live. Null for anything else.
  static LiveMessage? audience(Map<Object?, Object?> content) {
    final encoded = content['c'];
    final state = _object(encoded is String ? _decodeUriComponent(encoded) : null);
    final watching = state?['watchNumber'];
    if (watching is! int || watching < 0) return null;
    return LiveMessage.normalized(
      type: LiveMessageType.audienceUpdate,
      color: LiveMessageColor.white,
      payload: LiveAudienceUpdate.of(kind: LiveAudienceSignalKind.onlineViewers, value: watching),
    );
  }

  static final RegExp _badEscape = RegExp('%(?![0-9A-Fa-f]{2})');

  /// JavaScript's `decodeURIComponent`, or null where it throws (a `%`
  /// without two hex digits, bytes that are not UTF-8). Characters that are
  /// not escapes stay as they are, whatever they are: `Uri.decodeComponent`
  /// throws on any character above U+007F (question texts are plain Chinese
  /// and emoji).
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

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final num number when number.isFinite && number == number.toInt() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  static Uri? _url(Object? value) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty || text.length > 8192) return null;
    return Uri.tryParse(text);
  }

  static String _id(Object? value) => switch (value) {
    final int number => '$number',
    final String text => text.trim(),
    _ => '',
  };

  static String _level(Object? value) => switch (value) {
    final int number => '$number',
    final String text => int.tryParse(text)?.toString() ?? '',
    _ => '',
  };
}

/// The combos of one broadcast whose hits were reported: a combo hit or line
/// (10004) that only repeats a count already reported for its combo (`c.no`)
/// is left out, so the UI does not take the same count for a new combo (its
/// line shows one combo once). A line that says more (the last hits were
/// skipped), and the line of a combo whose hits were not seen, are reported.
final class KilakilaGiftCombos {
  /// Combos remembered; the oldest goes first.
  static const int capacity = 256;

  final Map<String, int> _counts = {};

  /// Whether [message] is reported: everything but a combo's hit or line
  /// whose count is not above the count reported for its combo so far.
  bool report(LiveMessage message) {
    final gift = message.giftOrNull;
    if (gift is! LiveGift || gift.combo.comboKey.isEmpty || gift.combo.comboTotal == null) return true;
    final key = gift.combo.comboKey;
    final total = gift.combo.comboTotal!;
    final shown = _counts.remove(key);
    final reported = shown == null || total > shown;
    _counts[key] = reported ? total : shown;
    if (_counts.length > capacity) _counts.remove(_counts.keys.first);
    return reported;
  }
}
