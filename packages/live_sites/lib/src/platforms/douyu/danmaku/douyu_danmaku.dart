import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';

/// Douyu's STT text format: `key@=value/` pairs; a list is its items each
/// followed by `/`; inside a value `@` is written `@A` and `/` is written
/// `@S`, once per nesting level.
///
/// Decoding is shallow: every value is unescaped exactly once and stays text;
/// only the fields Douyu nests (a super chat's `chatmsg`, a voice super chat's
/// `list` and `uat`) are decoded again by the caller.
abstract final class DouyuStt {
  /// Reverses the escaping (a value's `@S`→`/`, `@A`→`@`).
  static String unescape(String value) => value.replaceAll('@S', '/').replaceAll('@A', '@');

  /// The pairs of [text] with their values unescaped once. Parts without a key
  /// (`@=` missing or first) are skipped and a later duplicate wins.
  static Map<String, String> map(String text) {
    final pairs = <String, String>{};
    for (final part in text.split('/')) {
      final separator = part.indexOf('@=');
      if (separator <= 0) continue;
      pairs[part.substring(0, separator)] = unescape(part.substring(separator + 2));
    }
    return pairs;
  }

  /// The items of a list value, each unescaped once; empty items are skipped.
  static List<String> list(String value) => [
    for (final item in value.split('/'))
      if (item.isNotEmpty) unescape(item),
  ];
}

/// Douyu's danmaku protocol, without I/O.
///
/// A packet is `length(4) length(4) type(2) encrypted(1) reserved(1) body \0`,
/// little endian, where length counts itself out: `8 + body + 1`. Client
/// packets have type 689; one server frame usually carries several packets.
/// Chat is `chatmsg`, a super chat `comm_chatmsg` or `voice_trlt`, a gift `dgb`,
/// and an `rss` with `ss@=0` ends the broadcast.
///
/// Mapped onto this tree's models: this build does not fetch the room's gift
/// catalogue, so a `dgb` gift carries only its name, count and — while a combo
/// is running — a sender+gift combo key (no price, picture or free flag); the
/// sender level and fan medal, and the super chat's avatar and colours, have no
/// field here and are dropped; the currency counts as the paid-currency unit;
/// colour is an int and a message id is `id`.
abstract final class DouyuDanmakuProtocol {
  /// The danmaku TCP server (host and port; the session dials it raw).
  static const String host = 'danmakuMsg.douyucdn.cn';

  /// The danmaku TCP port.
  static const int port = 8501;

  /// Heartbeat period.
  static const Duration heartbeatInterval = Duration(seconds: 45);

  /// Packet type of client packets.
  static const int clientPacketType = 689;

  /// The detail of the run's end when the broadcast ends.
  static const String broadcastEnded = 'Broadcast ended';

  /// The colour of `col`; unknown values are white.
  static const Map<int, int> _colors = {1: 0xFF0000, 2: 0x1E87F0, 3: 0x7AC84B, 4: 0xFF7F00, 5: 0x9B39F4, 6: 0xFF69B4};

  /// One packet of [body]. The length counts UTF-8 bytes.
  static Uint8List packet(String body, {int type = clientPacketType}) {
    final text = utf8.encode(body);
    final length = 4 + 4 + text.length + 1;
    final out = BytesBuilder(copy: false);
    final head = ByteData(10)
      ..setUint32(0, length, Endian.little)
      ..setUint32(4, length, Endian.little)
      ..setUint16(8, type, Endian.little)
      ..setUint8(9, 0); // encrypted, reserved.
    out
      ..add(head.buffer.asUint8List())
      ..add(text)
      ..addByte(0);
    return out.toBytes();
  }

  /// What joins room [roomId] once the socket is open: `loginreq`, then
  /// `joingroup` with group −9999.
  static List<Uint8List> joinPackets(String roomId) => [
    packet('type@=loginreq/roomid@=$roomId/'),
    packet('type@=joingroup/rid@=$roomId/gid@=-9999/'),
  ];

  /// The heartbeat packet.
  static Uint8List heartbeat() => packet('type@=mrkl/');

  /// The bodies of the packets in [frame]. The last byte of each packet (its
  /// `\0`) is left out; a length below 9 or past the frame stops the split and
  /// drops the rest.
  static List<String> bodies(List<int> frame) {
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    final view = ByteData.sublistView(bytes);
    final bodies = <String>[];
    var offset = 0;
    while (offset + 12 <= bytes.length) {
      final length = view.getUint32(offset, Endian.little);
      if (length < 9 || offset + 4 + length > bytes.length) break;
      bodies.add(utf8.decode(Uint8List.sublistView(bytes, offset + 12, offset + 3 + length), allowMalformed: true));
      offset += 4 + length;
    }
    return bodies;
  }

  /// The messages of one server [frame] for room [roomId], and whether it ends
  /// the broadcast ([read]). A packet that fails to decode is skipped without
  /// losing the others.
  static List<LiveMessage> decode(List<int> frame, {required String roomId}) => read(frame, roomId: roomId).messages;

  /// [decode], and whether the frame says room [roomId]'s broadcast ended
  /// ([endsBroadcast]); the packets after that one are not read.
  static ({List<LiveMessage> messages, bool ended}) read(List<int> frame, {required String roomId}) {
    final messages = <LiveMessage>[];
    for (final body in bodies(frame)) {
      try {
        final fields = DouyuStt.map(body);
        if (endsBroadcast(fields, roomId)) return (messages: messages, ended: true);
        final message = switch (fields['type']) {
          'chatmsg' => _chat(fields, roomId),
          'comm_chatmsg' => _superChat(fields),
          'voice_trlt' => _voiceSuperChat(fields),
          'dgb' => gift(fields, roomId),
          _ => null,
        };
        if (message != null) messages.add(message);
      } on Object {
        // A malformed packet (a timestamp out of range) loses only itself.
      }
    }
    return (messages: messages, ended: false);
  }

  /// Whether [fields] is room [roomId]'s `rss` packet saying the broadcast
  /// ended (`ss@=0`). A start (`ss@=1`) and another room's packet give false.
  static bool endsBroadcast(Map<String, String> fields, String roomId) {
    if (fields['type'] != 'rss' || fields['ss'] != '0') return false;
    final packetRoomId = fields['rid'] ?? '';
    return packetRoomId.isEmpty || roomId.isEmpty || packetRoomId == roomId;
  }

  /// The colour a chat's `col` maps to (an int); unknown values are white.
  static int color(int col) => _colors[col] ?? 0xFFFFFF;

  /// `chatmsg`: another room's packet and empty text are dropped; `cst` above
  /// 10¹¹ is milliseconds, otherwise seconds. The id is `douyu:{cid}`.
  static LiveMessage? _chat(Map<String, String> fields, String roomId) {
    final packetRoomId = fields['rid'] ?? '';
    if (packetRoomId.isNotEmpty && roomId.isNotEmpty && packetRoomId != roomId) return null;
    final text = fields['txt'] ?? '';
    if (text.isEmpty) return null;
    final timestamp = int.tryParse(fields['cst'] ?? '');
    final messageId = fields['cid'] ?? '';
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: fields['nn'] ?? '',
      userId: fields['uid'] ?? '',
      message: text,
      color: color(int.tryParse(fields['col'] ?? '') ?? 0),
      id: messageId.isEmpty ? null : 'douyu:$messageId',
      sentAt: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp > 100000000000 ? timestamp : timestamp * 1000),
    );
  }

  /// `comm_chatmsg`: start `now` (ms), `cet` seconds, `cprice` cents and the
  /// nested `chatmsg` map (`nn`, `txt`). A notice without price or duration (a
  /// pandora box sharing the type) is not a super chat.
  static LiveMessage? _superChat(Map<String, String> fields) {
    final nested = fields['chatmsg'];
    final now = int.tryParse(fields['now'] ?? '');
    final seconds = int.tryParse(fields['cet'] ?? '');
    final cents = int.tryParse(fields['cprice'] ?? '');
    if (nested == null || !nested.contains('@=') || now == null || seconds == null || cents == null) return null;
    if (cents <= 0 || seconds <= 0) return null;
    final chat = DouyuStt.map(nested);
    final start = DateTime.fromMillisecondsSinceEpoch(now);
    return _superChatMessage(
      chat['nn'] ?? '',
      chat['txt'] ?? '',
      cents ~/ 100,
      start,
      start.add(Duration(seconds: seconds)),
    );
  }

  /// `voice_trlt`: the first map of `list`, with `acptime`/`etime` (seconds),
  /// `realPrice` (cents), `content` and `un`.
  static LiveMessage? _voiceSuperChat(Map<String, String> fields) {
    final items = DouyuStt.list(fields['list'] ?? '');
    if (items.isEmpty || !items.first.contains('@=')) return null;
    final item = DouyuStt.map(items.first);
    final end = int.tryParse(item['etime'] ?? '');
    final start = int.tryParse(item['acptime'] ?? '');
    final cents = int.tryParse(item['realPrice'] ?? '');
    if (end == null || start == null || cents == null) return null;
    return _superChatMessage(
      item['un'] ?? '',
      item['content'] ?? '',
      cents ~/ 100,
      DateTime.fromMillisecondsSinceEpoch(start * 1000),
      DateTime.fromMillisecondsSinceEpoch(end * 1000),
    );
  }

  static LiveMessage _superChatMessage(String userName, String text, int price, DateTime start, DateTime end) =>
      LiveMessage(
        type: LiveMessageType.superChat,
        userName: userName,
        message: text,
        color: 0xFFFFFF,
        data: LiveSuperChat(message: text, price: price, priceText: '¥$price', startTime: start, endTime: end),
      );

  /// `dgb`: a gift sent in this room. Without the room's gift catalogue this
  /// build reports a gift of name and count only; while `hits` counts, the
  /// combo key is the sender and the gift id (or name without one), as the
  /// packet has no combo id. Another room's packet and a gift without a name
  /// give nothing. The packet has no message id and no time.
  static LiveMessage? gift(Map<String, String> fields, String roomId) {
    final packetRoomId = fields['rid'] ?? '';
    if (packetRoomId.isNotEmpty && roomId.isNotEmpty && packetRoomId != roomId) return null;
    final name = (fields['gfn'] ?? '').trim();
    if (name.isEmpty) return null;
    final giftId = _id(fields['gfid']);
    final count = math.max(int.tryParse(fields['gfcnt'] ?? '') ?? 0, 1);
    final combo = int.tryParse(fields['hits'] ?? '') ?? 0;
    final senderId = fields['uid'] ?? '';
    final comboName = giftId.isNotEmpty ? giftId : name;
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: fields['nn'] ?? '',
      userId: senderId,
      message: '$name ×$count',
      color: 0xFFFFFF,
      data: LiveGift(name: name, count: count, combo: combo > 0 && senderId.isNotEmpty ? '$senderId:$comboName' : null),
    );
  }

  /// A positive id as the packet writes it; empty for 0 or anything else.
  static String _id(String? value) {
    final id = int.tryParse(value?.trim() ?? '') ?? 0;
    return id > 0 ? '$id' : '';
  }
}
