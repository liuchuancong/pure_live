import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/showroom/api/showroom_endpoints.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';

/// SHOWROOM's comment broadcast, without I/O.
///
/// - One WebSocket of text frames on the broadcast server `bcsvr_host`
///   (`wss://<host>/`, port 443). The client subscribes to a broadcast with
///   `SUB\t<bcsvr_key>`; nothing confirms it.
/// - The server pushes `MSG\t<key>\t<JSON object>`; the object's `t` is the
///   kind (1 comment, 2 gift, 5 support points, 8 caption, 18 system log,
///   101 broadcast ended, 104 broadcast started, …).
/// - `PING\tshowroom` is answered `ACK\tshowroom`.
abstract final class ShowroomDanmakuCodec {
  /// Ping period.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// The client ping; the server answers [ack].
  static const String ping = 'PING\tshowroom';

  /// The server's answer to [ping]: a frame like any other for the
  /// session's watchdog.
  static const String ack = 'ACK\tshowroom';

  /// Silence after which the socket is replaced: a socket without any frame
  /// for max(3 × [heartbeatInterval], 90 s) = 180 s is half-open, for the
  /// `ACK` answers every ping.
  static const Duration silenceTimeout = Duration(seconds: 180);

  /// Reconnects without a joined run before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// `t` of a comment.
  static const int commentType = 1;

  /// `t` of a gift.
  static const int giftType = 2;

  /// A gift's picture without the room's table: the address the table
  /// writes (`image`), by gift id.
  static Uri giftImage(String id) => Uri.https('static.showroom-live.com', '/image/gift/${id}_s.png');

  /// Handshake headers: the site's origin and the adapter's desktop UA, as
  /// the reference sent them.
  static const Map<String, String> socketHeaders = {
    'origin': ShowroomEndpoints.origin,
    'user-agent': ShowroomEndpoints.userAgent,
  };

  /// Largest [DateTime], in seconds.
  static const int _maxEpochSeconds = 8640000000000;

  /// The socket of broadcast server [host].
  static Uri endpoint(String host) => Uri(scheme: 'wss', host: host, path: '/');

  /// The subscription to broadcast [key].
  static String subscribe(String key) => 'SUB\t$key';

  /// [args] if they can be subscribed to: the host and key checks of
  /// [ShowroomParser.danmakuArgs] (a host on `showroom-live.com`, a key of at
  /// most 256 characters without white space or control characters; the host
  /// lower-cased), else null.
  static ShowroomDanmakuArgs? checked(ShowroomDanmakuArgs args) {
    final valid = ShowroomParser.danmakuArgs(roomId: 0, host: args.host, key: args.key);
    return valid == null ? null : ShowroomDanmakuArgs(roomId: args.roomId, host: valid.host, key: valid.key);
  }

  /// The chat and gifts of one frame (text, or UTF-8 bytes) of broadcast
  /// [key]: a `MSG` of that key whose object is a comment ([comment]) or a
  /// gift ([gift], named by [gifts]). Frames of another key, `ACK`, JSON that
  /// is not an object and every other kind give nothing.
  static List<LiveMessage> decode(
    Object? data, {
    required String key,
    ShowroomGiftCatalog gifts = ShowroomGiftCatalog.empty,
  }) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null || !text.startsWith('MSG\t')) return const [];
    final keyEnd = text.indexOf('\t', 4);
    if (keyEnd < 0 || text.substring(4, keyEnd) != key) return const [];
    final Object? event;
    try {
      event = jsonDecode(text.substring(keyEnd + 1));
    } on FormatException {
      return const [];
    }
    return [?comment(event), ?gift(event, gifts: gifts)];
  }

  /// A gift event (`t` 2) as a gift message with a [LiveGift], or null for
  /// any other event or one without a gift id:
  ///
  /// - [LiveGift.giftId] `g`, [LiveGift.count] `n`;
  /// - from the room's table ([gifts], by `g`): [LiveGift.name] `gift_name`,
  ///   and for a paid gift [LiveGiftValue.unitPrice] `point` and
  ///   [LiveGiftValue.totalValue] `point × n` in [LiveGiftUnit.point]
  ///   (SHOWROOM points, about a yen each); without the table the gift has
  ///   only its id, and `gt` 2 (the free kind of the recorded stars) is free;
  /// - [LiveGift.iconUrl] the table's `image`, else [giftImage];
  /// - the sender as a [comment]'s (`ac`, `u`, the class level `cl`), the
  ///   time `created_at`. The platform gives no message id and no combo.
  static LiveMessage? gift(Object? event, {ShowroomGiftCatalog gifts = ShowroomGiftCatalog.empty}) {
    if (event is! Map || !_isType(event['t'], giftType)) return null;
    final id = _text(event['g']);
    if (id.isEmpty || id == '0') return null;
    final count = event['n'];
    final info = gifts[id];
    final free = info?.free ?? _text(event['gt']) == '2';
    final price = free ? null : info?.point;
    final hits = count is int && count > 1 ? count : 1;
    final gift = LiveGift(
      giftId: id,
      name: info?.name ?? '',
      count: count is int ? count : 1,
      iconUrl: '${info?.image ?? giftImage(id)}',
      value: LiveGiftValue(
        unit: free ? LiveGiftUnit.free : LiveGiftUnit.point,
        unitPrice: price?.toDouble(),
        totalValue: price == null ? null : (price * hits).toDouble(),
      ),
    );
    final level = event['cl'];
    final created = event['created_at'];
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(
        userId: _text(event['u']),
        userName: _text(event['ac']),
        userLevel: level is int && level > 0 ? '$level' : '',
      ),
      text: '${gift.name} ×${gift.count}',
      color: LiveMessageColor.white,
      sentAt: _time(created),
      payload: gift,
    );
  }

  /// A comment event (`t` 1) as white chat, or null for any other event:
  ///
  /// - the text is `cm` (a string, or an integer as the web shows it),
  ///   trimmed; blank or anything else: null. Counting comments ("1", "2",
  ///   …) are a SHOWROOM custom and stay;
  /// - the name is `ac`, the user id `u`;
  /// - the level is the class level `cl` when above 0 (the web shows
  ///   "Class" and the number only then);
  /// - the time is `created_at` (seconds); not positive or out of
  ///   `DateTime`'s range: none.
  ///
  /// The platform gives no message id. The avatar (`av`), the class badges
  /// (`cifn`, `cbisc`, `cbiec`) and `ua`, `aft`, `at`, `d` are not read.
  static LiveMessage? comment(Object? event) {
    if (event is! Map || !_isType(event['t'], commentType)) return null;
    final text = _text(event['cm']);
    if (text.isEmpty) return null;
    final level = event['cl'];
    final created = event['created_at'];
    return LiveMessage.normalized(
      // The message type's default is a chat line.
      sender: MessageSender.normalized(
        userId: _text(event['u']),
        userName: _text(event['ac']),
        userLevel: level is int && level > 0 ? '$level' : '',
      ),
      text: text,
      color: LiveMessageColor.white,
      sentAt: _time(created),
    );
  }

  /// `t` is the expected kind, as an integer or (as the reference also read
  /// it) a string.
  static bool _isType(Object? type, int expected) => (type is int && type == expected) || type == '$expected';

  static DateTime? _time(Object? created) => created is int && created > 0 && created <= _maxEpochSeconds
      ? DateTime.fromMillisecondsSinceEpoch(created * 1000)
      : null;

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };
}
