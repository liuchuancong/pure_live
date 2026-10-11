import 'dart:convert';

import 'package:live_sites/src/models/live_gift.dart';
import 'package:live_sites/src/models/live_message.dart';
import 'package:meta/meta.dart';

/// The credentials a SHOWROOM danmaku connection needs.
///
/// The host and the broadcast key come from the room's own `live/live_info`
/// answer (`bcsvr_host`, `bcsvr_key`), which is why a session is opened from
/// the room and not from the room id: the key is per broadcast, and a
/// reconnect after a restart has to re-read it.
@immutable
final class ShowroomDanmakuArgs {
  /// Danmaku credentials for a room.
  const new({required this.roomId, required this.host, required this.key});

  /// The numeric room id.
  final int roomId;

  /// The broadcast server host, without scheme.
  final String host;

  /// The broadcast key the client subscribes to.
  final String key;

  @override
  String toString() => 'ShowroomDanmakuArgs($roomId, $host)';
}

/// SHOWROOM's comment broadcast: a text protocol over one WebSocket.
///
/// A client subscribes with `SUB\t<key>` and the server pushes
/// `MSG\t<key>\t<json>` frames; `t` inside the JSON names the kind (1 a
/// comment, 2 a gift). `PING\tshowroom` is answered `ACK\tshowroom`, which is
/// also the only liveness check the protocol has.
abstract final class ShowroomDanmakuProtocol {
  /// How often the client pings; the site's own client uses a minute.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  /// The client's ping frame.
  static const String ping = 'PING\tshowroom';

  /// The server's answer to [ping].
  static const String ack = 'ACK\tshowroom';

  /// The `t` of a comment.
  static const int commentType = 1;

  /// The `t` of a gift.
  static const int giftType = 2;

  /// The largest `created_at` a `DateTime` can hold, in seconds.
  static const int _maxEpochSeconds = 8640000000000;

  /// The socket address of broadcast server [host].
  static Uri endpoint(String host) => Uri(scheme: 'wss', host: host, path: '/');

  /// The subscription frame for broadcast [key].
  static String subscribe(String key) => 'SUB\t$key';

  /// A gift's picture, when the room carries no catalog entry for it.
  static Uri giftImage(String id) => Uri.https('static.showroom-live.com', '/image/gift/${id}_s.png');

  /// Validates [args]: a host on `showroom-live.com` (lower-cased), and a
  /// key of at most 256 characters without whitespace or control characters.
  ///
  /// The validation exists because the host reaches a WebSocket URL: an
  /// answer that was tampered with, or a room whose broadcast ended and left
  /// an empty key, must become "no danmaku" rather than a connection to
  /// somewhere unintended.
  static ShowroomDanmakuArgs? checked(ShowroomDanmakuArgs args) {
    final host = args.host.trim().toLowerCase();
    final key = args.key.trim();
    if (host.isEmpty || !host.endsWith('showroom-live.com')) {
      return null;
    }
    if (key.isEmpty || key.length > 256 || RegExp(r'[\s\x00-\x1f]').hasMatch(key)) {
      return null;
    }
    return ShowroomDanmakuArgs(roomId: args.roomId, host: host, key: key);
  }

  /// The messages one frame carries.
  ///
  /// Frames of another broadcast (the connection is shared per host), the
  /// `ACK`, JSON that is not an object, and every event kind this build does
  /// not model give an empty list rather than an error: a busy room pushes
  /// kinds nobody maps, and dropping them is not a failure.
  static List<LiveMessage> decode(Object? data, {required String key}) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null || !text.startsWith('MSG\t')) {
      return const [];
    }
    final keyEnd = text.indexOf('\t', 4);
    if (keyEnd < 0 || text.substring(4, keyEnd) != key) {
      return const [];
    }
    final Object? event;
    try {
      event = jsonDecode(text.substring(keyEnd + 1));
    } on FormatException {
      return const [];
    }
    return [?comment(event), ?gift(event)];
  }

  /// A comment event (`t` 1) as a chat message, or null for anything else.
  ///
  /// The text is `cm` (a string, or a number as the site's own web client
  /// shows it); the name is `ac` and the user id `u`. Counting comments
  /// ("1", "2", …) are a SHOWROOM custom and are kept as they are. The
  /// platform gives no message id, so the gate upstream has to fall back to
  /// its time-and-text duplicate rule for this site.
  static LiveMessage? comment(Object? event) {
    if (event is! Map || !_isType(event['t'], commentType)) {
      return null;
    }
    final text = _text(event['cm']);
    if (text.isEmpty) {
      return null;
    }
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _text(event['ac']),
      userId: _text(event['u']),
      message: text,
      sentAt: _sentAt(event['created_at']),
    );
  }

  /// A gift event (`t` 2) as a gift message, or null for anything else.
  ///
  /// The gift's *name* and price need the room's gift catalog — a separate
  /// answer this build does not read yet — so a gift is reported by its id,
  /// with the count the site sends and no price: a name invented from the id
  /// would look like data and be wrong. The id is what the UI needs to show
  /// the conventional picture ([giftImage]) and what a later catalog
  /// migration will resolve properly.
  static LiveMessage? gift(Object? event) {
    if (event is! Map || !_isType(event['t'], giftType)) {
      return null;
    }
    final id = _text(event['g']);
    if (id.isEmpty || id == '0') {
      return null;
    }
    final count = event['n'];
    final gift = LiveGift(name: id, count: count is int && count > 0 ? count : 1);
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _text(event['ac']),
      userId: _text(event['u']),
      message: id,
      sentAt: _sentAt(event['created_at']),
      data: gift,
    );
  }

  static DateTime? _sentAt(Object? value) {
    if (value is! int || value <= 0 || value > _maxEpochSeconds) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  static bool _isType(Object? type, int expected) => (type is int && type == expected) || type == '$expected';

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };
}
