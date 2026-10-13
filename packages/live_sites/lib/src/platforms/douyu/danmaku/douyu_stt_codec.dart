import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';

/// Douyu's STT text format: `key@=value/` pairs; a list is its items, each
/// followed by `/`; inside a value `@` is written `@A` and `/` is written
/// `@S`, once per nesting level.
///
/// Decoding is shallow: every value is unescaped exactly once and stays
/// text. Only the fields douyu nests (a super chat's `chatmsg`, a voice
/// super chat's `list` and `uat`) are decoded again, by the protocol.
abstract final class DouyuStt {
  /// Escapes [value] for one nesting level.
  static String escape(String value) => value.replaceAll('@', '@A').replaceAll('/', '@S');

  /// Reverses [escape].
  static String unescape(String value) => value.replaceAll('@S', '/').replaceAll('@A', '@');

  /// The pairs of [text] with their values unescaped once. Parts without a
  /// key (`@=` missing or first) are skipped, a later duplicate wins, and
  /// keys stay as written.
  static Map<String, String> map(String text) {
    final pairs = <String, String>{};
    for (final part in text.split('/')) {
      final separator = part.indexOf('@=');
      if (separator <= 0) continue;
      pairs[part.substring(0, separator)] = unescape(part.substring(separator + 2));
    }
    return pairs;
  }

  /// The items of a list value, each unescaped once; empty items are
  /// skipped.
  static List<String> list(String value) => [
    for (final item in value.split('/'))
      if (item.isNotEmpty) unescape(item),
  ];
}

/// Douyu's danmaku protocol (the codec of the legacy client), without I/O.
///
/// A packet is `length(4) length(4) type(2) encrypted(1) reserved(1) body
/// \0`, little endian, where length counts itself out: 8 + body + 1.
/// Client packets have type 689; one server frame usually carries several
/// packets.
abstract final class DouyuDanmakuProtocol {
  /// Heartbeat period (the legacy client's 45 000 ms).
  static const Duration heartbeatInterval = Duration(seconds: 45);

  /// Packet type of client packets.
  static const int clientPacketType = 689;

  /// One packet of [body]. The length counts UTF-8 bytes.
  static Uint8List packet(String body, {int type = clientPacketType}) {
    final text = utf8.encode(body);
    final length = 4 + 4 + text.length + 1;
    final writer = BytesBuilder()
      ..add(_uint32(length))
      ..add(_uint32(length))
      ..add(_uint16(type))
      ..add([0, 0])
      ..add(text)
      ..add([0]);
    return writer.toBytes();
  }

  static Uint8List _uint32(int value) {
    final bytes = Uint8List(4);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
    return bytes;
  }

  static Uint8List _uint16(int value) {
    final bytes = Uint8List(2);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    return bytes;
  }

  /// What joins room [roomId] once the socket is open: `loginreq`, then
  /// `joingroup` with group −9999.
  static List<Uint8List> joinPackets(String roomId) => [
    packet('type@=loginreq/roomid@=$roomId/'),
    packet('type@=joingroup/rid@=$roomId/gid@=-9999/'),
  ];

  /// The heartbeat packet (`type@=mrkl/`).
  static Uint8List heartbeat() => packet('type@=mrkl/');

  /// The bodies of the packets in [frame], in order. The last byte of each
  /// packet (its `\0`) is left out; a length below 9 or past the end of the
  /// frame stops the split, and the rest of the frame is dropped.
  static List<String> bodies(List<int> frame) {
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    final view = ByteData.sublistView(bytes);
    final result = <String>[];
    var offset = 0;
    while (offset + 12 <= bytes.length) {
      final length = view.getUint32(offset, Endian.little);
      if (length < 9 || offset + 4 + length > bytes.length) break;
      result.add(utf8.decode(Uint8List.sublistView(bytes, offset + 12, offset + 3 + length), allowMalformed: true));
      offset += 4 + length;
    }
    return result;
  }

  /// The messages of one server [frame] for room [roomId]: chat
  /// (`chatmsg`), super chats (`comm_chatmsg`, `voice_trlt`) and gifts
  /// (`dgb`); other packets are ignored. A packet that fails to decode is
  /// skipped without losing the others. [filterSuspectedAutomated] is read
  /// for each suspected chat, so a changed setting applies at once. [gifts]
  /// prices and pictures the gifts it knows.
  static List<LiveMessage> decode(
    List<int> frame, {
    required String roomId,
    bool Function()? filterSuspectedAutomated,
    DouyuGiftCatalog gifts = DouyuGiftCatalog.empty,
  }) => read(frame, roomId: roomId, filterSuspectedAutomated: filterSuspectedAutomated, gifts: gifts).messages;

  /// [decode], and whether the frame says room [roomId]'s broadcast ended
  /// ([endsBroadcast]); the packets after that one are not read.
  static ({List<LiveMessage> messages, bool ended}) read(
    List<int> frame, {
    required String roomId,
    bool Function()? filterSuspectedAutomated,
    DouyuGiftCatalog gifts = DouyuGiftCatalog.empty,
  }) {
    final messages = <LiveMessage>[];
    for (final body in bodies(frame)) {
      try {
        final fields = DouyuStt.map(body);
        if (endsBroadcast(fields, roomId)) return (messages: messages, ended: true);
        final message = switch (fields['type']) {
          'chatmsg' => _chat(fields, roomId, filterSuspectedAutomated),
          'comm_chatmsg' => _superChat(fields),
          'voice_trlt' => _voiceSuperChat(fields),
          'dgb' => gift(fields, roomId, gifts: gifts),
          _ => null,
        };
        if (message != null) messages.add(message);
      } on Object {
        // One malformed packet (a timestamp out of range) must not lose the
        // packets after it in the same frame.
      }
    }
    return (messages: messages, ended: false);
  }

  /// Whether [fields] is room [roomId]'s `rss` packet saying the broadcast
  /// ended (`ss@=0`). A start (`ss@=1`) gives nothing, nor does another
  /// room's packet.
  static bool endsBroadcast(Map<String, String> fields, String roomId) {
    if (fields['type'] != 'rss' || fields['ss'] != '0') return false;
    final packetRoomId = fields['rid'] ?? '';
    return packetRoomId.isEmpty || roomId.isEmpty || packetRoomId == roomId;
  }

  /// The colour of `col`; unknown values are white.
  static LiveMessageColor color(int col) => switch (col) {
    1 => const LiveMessageColor(255, 0, 0),
    2 => const LiveMessageColor(30, 135, 240),
    3 => const LiveMessageColor(122, 200, 75),
    4 => const LiveMessageColor(255, 127, 0),
    5 => const LiveMessageColor(155, 57, 244),
    6 => const LiveMessageColor(255, 105, 180),
    _ => LiveMessageColor.white,
  };

  /// A chat without `dms` whose `if` is not `1` (the suspected-automated
  /// rule; the filter is off unless the user turns it on).
  static bool isSuspectedAutomated(Map<String, String> fields) => fields['dms'] == null && fields['if'] != '1';

  /// `chatmsg`: another room's packet and empty text are dropped; `cst`
  /// above 10^11 is milliseconds, otherwise seconds.
  static LiveMessage? _chat(Map<String, String> fields, String roomId, bool Function()? filterSuspectedAutomated) {
    final packetRoomId = fields['rid'] ?? '';
    if (packetRoomId.isNotEmpty && roomId.isNotEmpty && packetRoomId != roomId) return null;
    final text = fields['txt'] ?? '';
    if (text.isEmpty) return null;
    if (isSuspectedAutomated(fields) && (filterSuspectedAutomated?.call() ?? false)) return null;
    final timestamp = int.tryParse(fields['cst'] ?? '');
    final messageId = fields['cid'] ?? '';
    final level = int.tryParse(fields['level'] ?? '') ?? 0;
    final fans = (fields['bnn'] ?? '').trim();
    final fansLevel = int.tryParse(fields['bl'] ?? '') ?? 0;
    return LiveMessage.normalized(
      text: text,
      sender: MessageSender.normalized(
        userId: fields['uid'] ?? '',
        userName: fields['nn'] ?? '',
        fanBadgeName: fans,
        fanBadgeLevel: fans.isNotEmpty && fansLevel > 0 ? '$fansLevel' : '',
        userLevel: level > 0 ? '$level' : '',
      ),
      color: color(int.tryParse(fields['col'] ?? '') ?? 0),
      messageId: messageId.isEmpty ? '' : 'douyu:$messageId',
      sentAt: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp > 100000000000 ? timestamp : timestamp * 1000, isUtc: true),
    );
  }

  /// `comm_chatmsg`: start `now` (ms), `cet` seconds, `cprice` cents and
  /// the nested `chatmsg` map (`nn`, `txt`, `ic`). A notice without price
  /// or duration (a pandora box opening shares the type) is not a super
  /// chat.
  static LiveMessage? _superChat(Map<String, String> fields) {
    final nested = fields['chatmsg'];
    final now = int.tryParse(fields['now'] ?? '');
    final seconds = int.tryParse(fields['cet'] ?? '');
    final cents = int.tryParse(fields['cprice'] ?? '');
    if (nested == null || !nested.contains('@=') || now == null || seconds == null || cents == null) return null;
    if (cents <= 0 || seconds <= 0) return null;
    final chat = DouyuStt.map(nested);
    final face = chat['ic'] ?? '';
    final start = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
    return _superChatMessage(
      LiveSuperChatMessage(
        userName: chat['nn'] ?? '',
        faceUrl: face.isEmpty ? '' : 'https://apic.douyucdn.cn/upload/${face}_small.jpg',
        text: chat['txt'] ?? '',
        price: SuperChatPrice(amount: cents ~/ 100, currency: 'CNY', displayText: '￥${cents ~/ 100}'),
        startTime: start,
        endTime: start.add(Duration(seconds: seconds)),
        display: const SuperChatDisplay(backgroundColor: '#c1c1ff', backgroundBottomColor: '#292a60'),
      ),
    );
  }

  /// `voice_trlt`: the first map of `list`, with `acptime` and `etime`
  /// (seconds), `realPrice` (cents), `content`, `un`, and the avatar
  /// `https://` + the second item of `uat`.
  static LiveMessage? _voiceSuperChat(Map<String, String> fields) {
    final items = DouyuStt.list(fields['list'] ?? '');
    if (items.isEmpty || !items.first.contains('@=')) return null;
    final item = DouyuStt.map(items.first);
    final end = int.tryParse(item['etime'] ?? '');
    final start = int.tryParse(item['acptime'] ?? '');
    final cents = int.tryParse(item['realPrice'] ?? '');
    if (end == null || start == null || cents == null) return null;
    final avatars = DouyuStt.list(item['uat'] ?? '');
    final avatar = avatars.length > 1 ? avatars[1] : '';
    return _superChatMessage(
      LiveSuperChatMessage(
        userName: item['un'] ?? '',
        faceUrl: avatar.isEmpty ? '' : 'https://$avatar',
        text: item['content'] ?? '',
        price: SuperChatPrice(amount: cents ~/ 100, currency: 'CNY', displayText: '￥${cents ~/ 100}'),
        startTime: DateTime.fromMillisecondsSinceEpoch(start * 1000, isUtc: true),
        endTime: DateTime.fromMillisecondsSinceEpoch(end * 1000, isUtc: true),
        display: const SuperChatDisplay(backgroundColor: '#ffffff', backgroundBottomColor: '#246488'),
      ),
    );
  }

  /// `dgb`: a gift sent in this room, reported as a gift message. The
  /// sender is `nn`/`uid`, with their level and fan medal (`bnn`, `bl`);
  /// the text is the gift's plain text. While `hits` counts, the combo key
  /// is the sender and the gift (the packet has no combo id). From [gifts],
  /// by `gfid`: the price of one in fen (× `gfcnt` the total), the picture
  /// and the name when `gfn` is blank. A gift the catalogues do not know
  /// keeps its name only; a backpack prop (`gpf` 1, or `gfid` 0 with a
  /// `pid`) is free. Another room's packet and a gift without a name give
  /// nothing.
  static LiveMessage? gift(
    Map<String, String> fields,
    String roomId, {
    DouyuGiftCatalog gifts = DouyuGiftCatalog.empty,
  }) {
    final packetRoomId = fields['rid'] ?? '';
    if (packetRoomId.isNotEmpty && roomId.isNotEmpty && packetRoomId != roomId) return null;
    final giftId = _id(fields['gfid']);
    final propId = _id(fields['pid']);
    final info = giftId.isEmpty ? null : gifts[giftId];
    final name = (fields['gfn'] ?? '').trim();
    final shownName = name.isNotEmpty ? name : info?.name ?? '';
    if (shownName.isEmpty) return null;
    final id = giftId.isNotEmpty ? giftId : propId;
    final count = int.tryParse(fields['gfcnt'] ?? '') ?? 0;
    final countAtLeastOne = count > 0 ? count : 1;
    final combo = int.tryParse(fields['hits'] ?? '') ?? 0;
    final backpack = fields['gpf'] == '1' || (giftId.isEmpty && propId.isNotEmpty);
    final free = backpack || (info?.free ?? false);
    final priceFen = free ? null : info?.price;
    final senderId = fields['uid'] ?? '';
    final present = DouyuGiftParser.toLiveGift(
      id: id,
      name: shownName,
      count: countAtLeastOne,
      combo: combo > 0 ? combo : 0,
      receiverName: fields['receive_nn'] ?? '',
      comboKey: combo > 0 && senderId.isNotEmpty ? '$senderId:${id.isEmpty ? shownName : id}' : '',
      free: free,
      priceFen: priceFen,
      iconUrl: info?.iconUrl,
    );
    final level = int.tryParse(fields['level'] ?? '') ?? 0;
    final fans = (fields['bnn'] ?? '').trim();
    final fansLevel = int.tryParse(fields['bl'] ?? '') ?? 0;
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${present.name} ×${present.count}',
      sender: MessageSender.normalized(
        userId: senderId,
        userName: fields['nn'] ?? '',
        fanBadgeName: fans,
        fanBadgeLevel: fans.isNotEmpty && fansLevel > 0 ? '$fansLevel' : '',
        userLevel: level > 0 ? '$level' : '',
      ),
      color: LiveMessageColor.white,
      payload: present,
    );
  }

  /// A positive id as the packet writes it; empty for 0 or anything else.
  static String _id(String? value) {
    final id = int.tryParse(value?.trim() ?? '') ?? 0;
    return id > 0 ? '$id' : '';
  }

  static LiveMessage _superChatMessage(LiveSuperChatMessage data) => LiveMessage.normalized(
    type: LiveMessageType.superChat,
    text: 'SUPER_CHAT_MESSAGE',
    color: LiveMessageColor.white,
    payload: data,
  );
}
