import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What the danmaku connection needs to join one room (3.x's
/// `SoopDanmakuArgs`): the chat endpoints and the room's chat number, with
/// the WebSocket handshake headers 3.x built for it. Anonymous: no cookie
/// (3.x carried the user's; the v2 context hands a site no credentials).
final class SoopDanmakuArgs {
  /// Creates the arguments.
  const SoopDanmakuArgs({required this.url, required this.plainUrl, required this.chatNo, required this.headers});

  /// `wss://<chat host>:<CHPT + 1>/Websocket/<room id>`: the TLS port next
  /// to the plain one, as the official HTTPS player connects.
  final Uri url;

  /// `ws://<chat host>:<CHPT>/Websocket/<room id>`: the plain port, the
  /// fallback where the TLS port is unreachable.
  final Uri plainUrl;

  /// `CHATNO`, sent in the join packet.
  final String chatNo;

  /// Handshake headers: the API headers with `Origin` of the player page.
  final Map<String, String> headers;

  @override
  String toString() => 'SoopDanmakuArgs($url, $chatNo)';
}

/// One packet of SOOP's chat protocol ([SoopDanmakuCodec.packets]): its
/// service number (1 login, 2 join, 5 chat, …) and body.
typedef SoopPacket = ({int service, Uint8List body});

/// SOOP's chat protocol, without I/O.
///
/// A packet is `ESC TAB`, a 4-digit decimal service, a 6-digit decimal body
/// length in bytes, `00` and the body, whose fields are separated by form
/// feeds; one frame may carry several packets. The client sends its packets
/// as text frames, the server answers in binary frames.
abstract final class SoopDanmakuCodec {
  /// Subprotocol the chat edges require.
  static const List<String> protocols = ['chat'];

  /// Heartbeat period (3.x `heartbeatTime`).
  static const Duration heartbeatInterval = Duration(seconds: 20);

  /// Pause between the login and the join packet (3.x `joinRoom`).
  static const Duration joinDelay = Duration(milliseconds: 200);

  /// Silence after which the socket is replaced: 3.x replaced a socket
  /// silent for max(3 × 20 s, 90 s) = 90 s.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// Connect failures in a row that are retried; the next one ends the
  /// session (the v2 reconnect budget).
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Service number of a chat line.
  static const int chatService = 5;

  /// Service of a star balloon (`SVC_SENDBALLOON`, 별풍선) sent in this
  /// room.
  static const int balloonService = 18;

  /// Service of a star balloon relayed from another room of the broadcast
  /// (`SVC_SENDBALLOONSUB`; the web player reads its fields one further on).
  static const int relayedBalloonService = 33;

  /// Service of an ad balloon (`SVC_ADCON_EFFECT`, 애드벌룬).
  static const int adBalloonService = 87;

  /// Service of a subscription (`SVC_FOLLOW_ITEM`, 구독).
  static const int subscriptionService = 91;

  /// Service of a subscription's ceremony with its months
  /// (`SVC_FOLLOW_ITEM_EFFECT`).
  static const int subscriptionMonthsService = 93;

  /// Service of a video balloon (`SVC_VIDEOBALLOON`, 영상풍선: star balloons
  /// sent with a video).
  static const int videoBalloonService = 105;

  /// The platform's name of what [balloonService] reports, as it writes it.
  static const String starBalloonName = '별풍선';

  /// The platform's name of what [adBalloonService] reports.
  static const String adBalloonName = '애드벌룬';

  /// The platform's name of what [videoBalloonService] reports.
  static const String videoBalloonName = '영상풍선';

  /// Header bytes before a packet's body.
  static const int headerLength = 14;

  static const String _escape = '\x1b\t';
  static const String _separator = '\f';

  /// The login packet (service 1), sent as soon as the socket opens.
  static const String login = '${_escape}000100000600$_separator$_separator${_separator}16$_separator';

  /// The keep-alive packet (service 0).
  static const String heartbeat = '${_escape}000000000100$_separator';

  /// The packet joining chat room [chatNo] (service 2); the length counts
  /// UTF-8 bytes, as 3.x did.
  static String join(String chatNo) =>
      '${_escape}0002${(utf8.encode(chatNo).length + 6).toString().padLeft(6, '0')}00'
      '$_separator$chatNo${_separator * 5}';

  /// Endpoints of a room, in order: the TLS port (`CHPT + 1`), then the
  /// plain port (`CHPT`), which answers where the TLS port drops the
  /// connection.
  static List<Uri> endpoints(SoopDanmakuArgs args) => [args.url, args.plainUrl];

  /// [headers] with every name spelled as 3.x wrote it (`user-agent` →
  /// `User-Agent`): the chat edges see the handshake as written.
  static Map<String, String> handshakeHeaders(Map<String, String> headers) => {
    for (final MapEntry(:key, :value) in headers.entries) headerName(key): value,
  };

  /// [name] with each word capitalised and the rest in lower case.
  static String headerName(String name) => name
      .split('-')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join('-');

  /// The packet's fields as the web player's `readBody` gives them: the body
  /// split at form feeds, without the empty field before the first one,
  /// each read as UTF-8.
  static List<String> fieldsOf(List<int> body) =>
      [for (final part in splitList(body, 0x0c)) utf8.decode(part, allowMalformed: true)].skip(1).toList();

  /// [list] split at every [separator], which is dropped. Separators at the
  /// ends or next to each other give empty parts, like `String.split`; an
  /// empty list gives no parts.
  static List<List<int>> splitList(List<int> list, int separator) {
    if (list.isEmpty) return [];
    final parts = <List<int>>[];
    var start = 0;
    for (var index = 0; index < list.length; index++) {
      if (list[index] == separator) {
        parts.add(list.sublist(start, index));
        start = index + 1;
      }
    }
    parts.add(list.sublist(start));
    return parts;
  }

  /// The packets of [frame], in order. The split stops at a packet without
  /// the `ESC TAB` prefix, with a service or length that is not a number,
  /// with a negative length, or running past the end of the frame; the rest
  /// of the frame is dropped. Fewer than 14 bytes left over are ignored, and
  /// so are the two bytes after the length.
  static List<SoopPacket> packets(List<int> frame) {
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    final packets = <SoopPacket>[];
    var offset = 0;
    while (offset + headerLength <= bytes.length) {
      if (bytes[offset] != 0x1b || bytes[offset + 1] != 0x09) break;
      final service = int.tryParse(ascii.decode(bytes.sublist(offset + 2, offset + 6), allowInvalid: true));
      final length = int.tryParse(ascii.decode(bytes.sublist(offset + 6, offset + 12), allowInvalid: true));
      if (service == null || length == null || length < 0) break;
      final end = offset + headerLength + length;
      if (end > bytes.length) break;
      packets.add((service: service, body: Uint8List.sublistView(bytes, offset + headerLength, end)));
      offset = end;
    }
    return packets;
  }

  /// The chat lines of one server [frame], its balloons ([balloon]) and
  /// subscriptions ([subscription]); other services (viewer lists, flags,
  /// …) are ignored.
  static List<LiveMessage> decode(List<int> frame) => [
    for (final packet in packets(frame))
      ?switch (packet.service) {
        chatService => chat(packet.body),
        balloonService || relayedBalloonService || adBalloonService || videoBalloonService => balloon(packet),
        subscriptionService || subscriptionMonthsService => subscription(packet),
        _ => null,
      },
  ];

  /// A chat line: text in field 1, nick in field 6, both trimmed, in white,
  /// and the sender's id from field 2 ([userId]). Null with fewer than
  /// seven fields or an empty text or nick.
  static LiveMessage? chat(List<int> body) {
    final fields = [for (final part in splitList(body, 0x0c)) utf8.decode(part, allowMalformed: true)];
    if (fields.length <= 6) return null;
    final text = fields[1].trim();
    final name = fields[6].trim();
    if (text.isEmpty || name.isEmpty) return null;
    return LiveMessage.normalized(
      sender: MessageSender.normalized(userId: userId(fields[2]), userName: name),
      text: text,
      color: LiveMessageColor.white,
    );
  }

  /// The sender's id of a chat line's field 2, without the `(n)` a second
  /// session of the same account gets (`loo3672(2)` → `loo3672`), as the web
  /// player's `realID` reads it: the run of word characters followed only by
  /// digits and parentheses up to the end; the trimmed field itself when
  /// there is no such run.
  static String userId(String field) {
    final id = field.trim();
    return _realId.firstMatch(id)?.group(1) ?? id;
  }

  static final RegExp _realId = RegExp(r'(\w+)[()0-9]*$');

  static final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// A star balloon, relayed star balloon, ad balloon or video balloon as a
  /// [LiveMessageType.gift] message with a priced [LiveGift], as the web
  /// player reads the packet; null for another service, or without a sender
  /// or a count above 0:
  ///
  /// - [LiveGift.name] the platform's name ([starBalloonName],
  ///   [adBalloonName], [videoBalloonName]), [LiveGift.count] `cnt`
  ///   (`adcon_cnt`);
  /// - star and video balloons are their own value: one star balloon the
  ///   unit price, the count the total (a paid currency → the v2 gold
  ///   unit); ad balloons have no value this app can place (the v2 other
  ///   unit);
  /// - an ad balloon's picture is its `urlImg`;
  /// - the sender is `sender_nickname` and `sender_id` ([userId]); the id
  ///   the packet's uuid when it has one (star and ad balloons).
  static LiveMessage? balloon(SoopPacket packet) {
    final fields = fieldsOf(packet.body);
    String at(int index) => index < fields.length ? fields[index].trim() : '';
    final (String sender, String name, String count, String kind, String id, String picture) = switch (packet.service) {
      balloonService => (at(1), at(2), at(3), starBalloonName, at(11), ''),
      relayedBalloonService => (at(3), at(4), at(5), starBalloonName, at(12), ''),
      videoBalloonService => (at(2), at(3), at(4), videoBalloonName, '', ''),
      adBalloonService => (at(2), at(3), at(9), adBalloonName, at(15), at(7)),
      _ => ('', '', '', '', '', ''),
    };
    final amount = int.tryParse(count);
    if (sender.isEmpty || name.isEmpty || amount == null || amount <= 0) return null;
    final valued = kind != adBalloonName;
    final image = Uri.tryParse(picture);
    final gift = LiveGift(
      name: kind,
      count: amount,
      kind: LiveGiftKind.tip,
      value: LiveGiftValue(
        unit: valued ? LiveGiftUnit.gold : LiveGiftUnit.other,
        unitPrice: valued ? 1.0 : null,
        totalValue: valued ? amount.toDouble() : null,
      ),
      iconUrl: image != null && image.isScheme('https') && image.host.isNotEmpty ? '$image' : null,
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      sender: MessageSender.normalized(userId: userId(sender), userName: name),
      text: '${gift.name} ×${gift.count}',
      color: LiveMessageColor.white,
      messageId: _uuid.hasMatch(id) ? id : '',
      payload: gift,
    );
  }

  /// A subscription (`SVC_FOLLOW_ITEM`) or its ceremony with the months
  /// (`SVC_FOLLOW_ITEM_EFFECT`) as a [LiveNoticeKind.subscription] notice,
  /// in Chinese around the platform's name: `<name> 订阅了频道` and, with the
  /// months (`accMonth`, else `month`), `，已订阅 N 个月`. The sender is
  /// `sendNick` and `sendId`; the id `subscription:<uuid>`. Null for another
  /// service or without a sender.
  static LiveMessage? subscription(SoopPacket packet) {
    final fields = fieldsOf(packet.body);
    String at(int index) => index < fields.length ? fields[index].trim() : '';
    final (String sender, String name, int? months, String id) = switch (packet.service) {
      subscriptionService => (at(2), at(3), null, at(8)),
      subscriptionMonthsService => (at(1), at(2), int.tryParse(at(6)) ?? int.tryParse(at(3)), at(8)),
      _ => ('', '', null, ''),
    };
    if (sender.isEmpty || name.isEmpty) return null;
    final text = months != null && months > 0 ? '订阅了频道，已订阅 $months 个月' : '订阅了频道';
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      sender: MessageSender.normalized(userId: userId(sender), userName: name),
      text: '$name $text',
      color: LiveMessageColor.white,
      messageId: _uuid.hasMatch(id) ? 'subscription:$id' : '',
      payload: LiveNoticeKind.subscription,
    );
  }
}
