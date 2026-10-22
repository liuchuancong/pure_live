import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:math';
import 'dart:typed_data';

import 'package:es_compression/brotli.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_combo/live_gift_combo.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_protobuf.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_json.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one received WebSocket message held, in order: the messages to report,
/// the packets to write back (an acknowledgement, op 24) in order, the code of
/// the auth reply (op 8) when the message carried one, the count of version 3
/// packets no decoder here can read, and the error of a malformed message —
/// everything decoded before the fault is still there.
typedef BilibiliDanmakuFrame = ({
  List<LiveMessage> messages,
  List<Uint8List> sends,
  int? authCode,
  int brotliSkipped,
  FormatException? error,
});

/// Bilibili's classic JSON broadcast danmaku wire format, without I/O.
///
/// Every packet has a 16-byte big-endian header: total length (4), header
/// length (2), protocol version (2: 0 JSON, 1 int32, 2 zlib, 3 brotli),
/// operation (4) and sequence (4, 1 when sent). One WebSocket message holds
/// several packets, and a compressed packet holds another packet stream.
abstract final class BilibiliDanmakuProtocol {
  /// Header length.
  static const int headerLength = 16;

  /// Heartbeat (sent, empty body).
  static const int opHeartbeat = 2;

  /// Heartbeat reply with the popularity figure (4 bytes).
  static const int opHeartbeatReply = 3;

  /// Notice: JSON, or a compressed packet stream.
  static const int opNotice = 5;

  /// Auth (sent).
  static const int opAuth = 7;

  /// Auth reply.
  static const int opAuthReply = 8;

  /// Acknowledgement (sent).
  static const int opAck = 24;

  /// The protocol version the auth packet asks for: 3 (brotli), as the web
  /// player does. Version 2 (zlib) frames are still decoded; a malformed
  /// brotli frame is skipped and counted, never a crash.
  static const int protocolVersion = 3;

  /// Largest WebSocket message and packet.
  static const int maxMessageBytes = 8 * 1024 * 1024;

  /// Largest inflated packet stream (zlib).
  static const int maxInflatedBytes = 16 * 1024 * 1024;

  /// Most packets in one stream.
  static const int maxPackets = 4096;

  /// Deepest nesting of compressed streams.
  static const int maxNesting = 2;

  /// Heartbeat period (also the join, sent once the auth reply accepts).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long the auth reply may take before the socket is replaced.
  static const Duration joinTimeout = Duration(seconds: 8);

  /// Silence after which the socket is replaced (three heartbeats).
  static const Duration inactivityTimeout = Duration(seconds: 90);

  /// Reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  /// How long the base backoff of a reconnect is (it grows from there).
  static const Duration reconnectBase = Duration(seconds: 1);

  static final RegExp _masked = RegExp(r'\*{2,}|＊{2,}');

  /// Whether Bilibili masked [name] (`**` or `＊＊`): guests see `观***`, so a
  /// masked candidate name is only used when nothing else came.
  static bool isMaskedName(String name) => _masked.hasMatch(name);

  /// One client packet: [body] as UTF-8 after the header (version 0, sequence
  /// 1), big-endian like the web client writes it.
  static Uint8List packet(int operation, String body) {
    final data = utf8.encode(body);
    final buffer = Uint8List(headerLength + data.length);
    ByteData.sublistView(buffer)
      ..setUint32(0, buffer.length)
      ..setUint16(4, headerLength)
      ..setUint16(6, 0)
      ..setUint32(8, operation)
      ..setUint32(12, 1);
    buffer.setRange(headerLength, buffer.length, data);
    return buffer;
  }

  /// The heartbeat packet.
  static Uint8List heartbeat() => packet(opHeartbeat, '');

  /// The auth packet's body (op 7), in the web client's key order.
  static Map<String, Object> authPayload({
    required int uid,
    required int roomId,
    required String buvid,
    required String token,
    required String queueUuid,
  }) => {
    'uid': uid,
    'roomid': roomId,
    'protover': protocolVersion,
    'buvid': buvid,
    'support_ack': true,
    'queue_uuid': queueUuid,
    'scene': 'room',
    'platform': 'web',
    'type': 2,
    'key': token,
  };

  /// The auth packet.
  static Uint8List auth({
    required int uid,
    required int roomId,
    required String buvid,
    required String token,
    required String queueUuid,
  }) => packet(
    opAuth,
    jsonEncode(authPayload(uid: uid, roomId: roomId, buvid: buvid, token: token, queueUuid: queueUuid)),
  );

  /// A new `queue_uuid`: eight lower-case hexadecimal digits.
  static String queueUuid(Random random) => [for (var i = 0; i < 8; i++) random.nextInt(16).toRadixString(16)].join();

  /// The acknowledgement a [notice] asks for (`p_is_ack` true with a `msg_id`,
  /// a `cmd` and an integer `p_msg_type`), or null.
  static Uint8List? acknowledgement(Map<String, dynamic> notice) {
    if (notice['p_is_ack'] != true || !notice.containsKey('p_msg_type')) return null;
    final id = notice['msg_id']?.toString().trim() ?? '';
    final cmd = notice['cmd']?.toString().trim() ?? '';
    final type = int.tryParse(notice['p_msg_type']?.toString() ?? '');
    if (id.isEmpty || cmd.isEmpty || type == null) return null;
    return packet(opAck, jsonEncode({'msg_id': id, 'cmd': cmd, 'p_msg_type': type}));
  }

  /// Decodes one WebSocket message into its items, in order.
  ///
  /// A malformed message keeps what was decoded before the fault, which comes
  /// back as `error`: a message over [maxMessageBytes], a bad or truncated
  /// header, trailing bytes, too many packets, too deep nesting, corrupt or
  /// oversized zlib, an auth reply that is not JSON. A notice that is not JSON,
  /// a brotli frame, or a `cmd` this decoder does not know is skipped on its
  /// own.
  ///
  /// [gifts] fills in the gifts' pictures and prices their packet leaves out.
  static BilibiliDanmakuFrame decode(List<int> message, {BilibiliGiftCatalog gifts = BilibiliGiftCatalog.empty}) {
    final out = _Frame();
    try {
      if (message.length > maxMessageBytes) {
        throw FormatException('Bilibili danmaku message is too large: ${message.length} bytes');
      }
      _stream(message is Uint8List ? message : Uint8List.fromList(message), 0, out, gifts);
    } on FormatException catch (error) {
      return (
        messages: out.messages,
        sends: out.sends,
        authCode: out.authCode,
        brotliSkipped: out.brotliPackets,
        error: error,
      );
    }
    return (
      messages: out.messages,
      sends: out.sends,
      authCode: out.authCode,
      brotliSkipped: out.brotliPackets,
      error: null,
    );
  }

  static void _stream(Uint8List data, int depth, _Frame out, BilibiliGiftCatalog gifts) {
    if (depth > maxNesting) throw const FormatException('Bilibili danmaku packet nesting is too deep');
    final view = ByteData.sublistView(data);
    var offset = 0;
    var count = 0;
    while (offset + headerLength <= data.length) {
      if (++count > maxPackets) throw const FormatException('Bilibili danmaku message contains too many packets');
      final length = view.getUint32(offset);
      final header = view.getUint16(offset + 4);
      final version = view.getUint16(offset + 6);
      final operation = view.getUint32(offset + 8);
      // A zero length must not leave the offset where it is.
      if (header < headerLength || length < header || length > maxMessageBytes || offset + length > data.length) {
        throw FormatException(
          'Invalid Bilibili danmaku frame: offset=$offset, packet=$length, header=$header, total=${data.length}',
        );
      }
      _packet(version, operation, Uint8List.sublistView(data, offset + header, offset + length), depth, out, gifts);
      offset += length;
    }
    if (offset != data.length) {
      throw FormatException('Incomplete Bilibili danmaku frame: parsed=$offset, total=${data.length}');
    }
  }

  static void _packet(int version, int operation, Uint8List body, int depth, _Frame out, BilibiliGiftCatalog gifts) {
    switch (operation) {
      case opHeartbeatReply:
        if (body.length < 4) return;
        final value = ByteData.sublistView(body).getUint32(0);
        out.messages.add(_audience(LiveAudienceSignalKind.popularity, value));
      case opNotice:
        switch (version) {
          case 2:
            _stream(_inflate(body), depth + 1, out, gifts);
          case 3:
            try {
              final decompressed = brotli.decode(body);
              if (decompressed.length > maxInflatedBytes) {
                throw const FormatException('Bilibili brotli decompressed message exceeds limit');
              }
              _stream(Uint8List.fromList(decompressed), depth + 1, out, gifts);
            } on FormatException {
              // Malformed brotli data is skipped; the session continues.
              out.brotliPackets++;
            }
          default:
            final text = utf8.decode(body, allowMalformed: true).trim();
            if (text.isNotEmpty) _notice(text, out, gifts);
        }
      case opAuthReply:
        final text = utf8.decode(body, allowMalformed: true).trim();
        final Object? reply = text.isEmpty ? const {'code': 0} : jsonDecode(text);
        final code = reply is Map ? int.tryParse(reply['code']?.toString() ?? '') : null;
        out.authCode = out.authCode ?? (code ?? -1);
    }
  }

  static Uint8List _inflate(Uint8List body) {
    final sink = _BoundedSink(maxInflatedBytes);
    ZLibDecoder().startChunkedConversion(sink)
      ..add(body)
      ..close();
    return sink.bytes.takeBytes();
  }

  /// One JSON notice, dispatched by its `cmd` string.
  static void _notice(String text, _Frame out, BilibiliGiftCatalog gifts) {
    final Object? notice;
    try {
      notice = jsonDecode(text);
    } on FormatException {
      return;
    }
    if (notice is! Map<String, dynamic>) return;
    if (acknowledgement(notice) case final ack?) out.sends.add(ack);
    final cmd = '${notice['cmd']}';
    final messages = switch (cmd) {
      // RECALL_DANMU_MSG contains DANMU_MSG: it must match before the chat.
      'RECALL_DANMU_MSG' => [?recall(notice)],
      _ when cmd.contains('DANMU_MSG') => [?chat(notice)],
      'WATCHED_CHANGE' => [?watched(notice)],
      'ONLINE_RANK_COUNT' => [?onlineRank(notice)],
      'SEND_GIFT' || 'COMBO_SEND' => [?gift(notice, gifts, combo: cmd == 'COMBO_SEND')],
      'SEND_GIFT_V2' => [?giftV2(notice, gifts)],
      'GUARD_BUY' => [?guard(notice, gifts)],
      'SUPER_CHAT_MESSAGE' => [?superChat(notice)],
      'SUPER_CHAT_MESSAGE_DELETE' => [
        for (final id in _superChatIds(notice)) _retraction(LiveRetraction(messageId: id)),
      ],
      'WARNING' => [_notify(notice, warningNotice)],
      'CUT_OFF' => [_notify(notice, cutOffNotice)],
      _ => const <LiveMessage>[],
    };
    out.messages.addAll(messages);
  }

  /// Start of the notice of `WARNING` (a moderator warned the room), before
  /// the platform's reason.
  static const String warningNotice = '直播间收到警告';

  /// Start of the notice of `CUT_OFF` (a moderator cut the stream off), before
  /// the platform's reason.
  static const String cutOffNotice = '直播被切断';

  /// `RECALL_DANMU_MSG`: `recall_type` 2 takes back every chat of
  /// `data.uinfo.uid` (else `data.target_id`), 3 the whole chat. Other types
  /// (0 nothing, 1 a single chat the web player does not handle here) and a
  /// uid of 0 (guests see every uid as 0) give nothing.
  static LiveMessage? recall(Map<String, dynamic> notice) {
    final data = jsonObject(notice['data']);
    if (data == null) return null;
    final LiveRetraction target;
    switch (jsonInt(data['recall_type'])) {
      case 2:
        final uid = jsonInt(jsonObject(data['uinfo'])?['uid']) ?? jsonInt(data['target_id']);
        if (uid == null || uid <= 0) return null;
        target = LiveRetraction(userId: '$uid');
      case 3:
        target = const LiveRetraction(all: true);
      default:
        return null;
    }
    return _retraction(target);
  }

  /// The super chat ids a `SUPER_CHAT_MESSAGE_DELETE` takes down.
  static List<String> _superChatIds(Map<String, dynamic> notice) {
    final data = jsonObject(notice['data']);
    return [for (final raw in jsonList(data?['ids'])) ?jsonString(raw)];
  }

  /// `DANMU_MSG`: text `info[1]`, colour `info[0][3]` (0 is white), time
  /// `info[0][4]` (milliseconds above 1e11, else seconds), id `bilibili:` +
  /// `info[0][5]`, user `info[2]` (`[uid, uname, …]`), the fan badge and
  /// avatar of the rich user in `info[0][15]` (else `info[3]`) and the
  /// pictures from [emotes]. A chat without its user list is not shown.
  static LiveMessage? chat(Map<String, dynamic> notice) {
    final info = notice['info'];
    if (info is! List || info.length < 3) return null;
    final meta = info[0];
    final user = info[2];
    if (meta is! List || meta.length < 4 || user is! List || user.length < 2) return null;
    final color = jsonInt(meta[3]) ?? 0;
    final time = meta.length > 4 ? int.tryParse(meta[4]?.toString() ?? '') : null;
    final nonce = meta.length > 5 ? meta[5]?.toString() ?? '' : '';
    DateTime? sentAt;
    if (time != null && time.abs() <= _maxEpochMilliseconds) {
      final milliseconds = time > 100000000000 ? time : time * 1000;
      if (milliseconds != 0) sentAt = DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    }
    final rich = meta.length > 15 ? jsonObject(meta[15]) : null;
    final medal = _medal(rich, info.length > 3 ? info[3] : null);
    final text = '${info[1]}';
    return LiveMessage.normalized(
      text: text,
      sender: MessageSender.normalized(
        userId: user[0]?.toString() ?? '',
        userName: _userName(notice, rich, user[1]?.toString() ?? ''),
        avatarUrl: _avatar(rich),
        fanBadgeName: medal.name,
        fanBadgeLevel: medal.level,
      ),
      color: color == 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
      messageId: nonce.isEmpty ? '' : 'bilibili:$nonce',
      sentAt: sentAt,
      emotes: emotes(text, meta),
    );
  }

  /// The fan badge the sender wears: `user.medal{name, level}` of the rich user
  /// ([rich]), else the legacy `[level, name, …]` list (`info[3]`); empty
  /// without a name. Guests see it unmasked.
  static ({String name, String level}) _medal(Object? rich, Object? legacy) {
    String level(Object? value) => switch (jsonInt(value)) {
      final int number when number > 0 => '$number',
      _ => '',
    };

    String text(Object? value) => value is String ? value.trim() : '';
    final user = rich is Map ? (rich['user'] is Map ? rich['user'] as Map : rich) : null;
    if (user?['medal'] case final Map<Object?, Object?> medal when text(medal['name']).isNotEmpty) {
      return (name: text(medal['name']), level: level(medal['level']));
    }
    if (legacy is List && legacy.length > 1 && text(legacy[1]).isNotEmpty) {
      return (name: text(legacy[1]), level: level(legacy[0]));
    }
    return (name: '', level: '');
  }

  /// The sender's avatar: `user.base.face` (else
  /// `base.origin_info.face`) of the rich user, https, and on `hdslb.com`
  /// asked for at 96 × 96; empty when there is none.
  static String _avatar(Object? rich) {
    final map = jsonObject(rich);
    if (map == null) return '';
    final face = jsonObject(jsonObject(jsonObject(map['user']) ?? map)?['base']);
    if (face == null) return '';
    var url = _picture(face['face']);
    if (url.isEmpty) url = _picture(jsonObject(face['origin_info'])?['face']);
    if (url.isEmpty) return '';
    final uri = Uri.parse(url);
    final small = (uri.host == 'hdslb.com' || uri.host.endsWith('.hdslb.com')) && !uri.path.contains('@');
    return small ? '$url@96w_96h.jpg' : url;
  }

  /// The pictures of a chat with text [text] and `info[0]` [meta]: a sticker
  /// (`info[0][12]` 1, the picture `info[0][13].url`) is its whole text;
  /// otherwise the inline codes (`[dog]`) of [text] that
  /// `info[0][15].extra.emots` names (`code` → `{url}`), each once.
  static List<LiveEmote> emotes(String text, List<Object?> meta) {
    if (text.isEmpty) return const [];
    final sticker = meta.length > 13 ? meta[13] : null;
    if (meta.length > 12 && meta[12] == 1 && sticker is Map) {
      final url = _picture(sticker['url']);
      return url.isEmpty ? const [] : [LiveEmote(code: text, url: url)];
    }
    // `info[0][15]` is the rich user, as an object or as JSON text.
    final rich = jsonObject(meta.length > 15 ? meta[15] : null);
    final extra = jsonObject(rich?['extra']);
    final emots = jsonObject(extra?['emots']);
    if (emots == null || emots.isEmpty) return const [];
    final found = <LiveEmote>[];
    for (final code in emots.keys.toList()) {
      if (code.isEmpty || !text.contains(code)) continue;
      final url = _picture(jsonObject(emots[code])?['url']);
      if (url.isNotEmpty) found.add(LiveEmote(code: code, url: url));
    }
    return found;
  }

  /// An image address: http(s) only, `hdslb.com`'s made https.
  static String _picture(Object? value) {
    final url = value is String ? value.trim() : '';
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) return '';
    if (uri.scheme == 'http' && (uri.host == 'hdslb.com' || uri.host.endsWith('.hdslb.com'))) {
      return uri.replace(scheme: 'https').toString();
    }
    return url;
  }

  /// The display name: the first unmasked of the rich user in `info[0][15]`,
  /// the notice's `uinfo`, `data.uinfo` and [legacy] (`info[2][1]`); the first
  /// rich one when all are masked, else [legacy]. A guest gets every one of
  /// them masked (the server masks by connection).
  static String _userName(Map<String, dynamic> notice, Object? rich, String legacy) {
    final candidates = [
      for (final root in [rich, notice['uinfo'], jsonObject(notice['data'])?['uinfo']])
        if (_richName(root) case final name when name.isNotEmpty) name,
    ];
    for (final candidate in [...candidates, legacy]) {
      if (candidate.isNotEmpty && !isMaskedName(candidate)) return candidate;
    }
    return candidates.isNotEmpty ? candidates.first : legacy;
  }

  /// `user.base.name` (or `base.name` at the top), else
  /// `base.origin_info.name`, trimmed.
  static String _richName(Object? root) {
    final map = jsonObject(root);
    if (map == null) return '';
    final base = jsonObject(jsonObject(map['user']) ?? map)?['base'];
    final names = jsonObject(base);
    if (names == null) return '';
    final name = names['name']?.toString().trim() ?? '';
    return name.isNotEmpty ? name : jsonObject(names['origin_info'])?['name']?.toString().trim() ?? '';
  }

  /// `WATCHED_CHANGE`: the room's cumulative viewers, `data.num` when it is a
  /// whole number of zero or more.
  static LiveMessage? watched(Map<String, dynamic> notice) {
    final data = jsonObject(notice['data']);
    final value = jsonCount(data?['num']);
    return value == null ? null : _audience(LiveAudienceSignalKind.totalViewers, value);
  }

  /// `ONLINE_RANK_COUNT` (about every 3 s): the room's online viewers,
  /// `data.online_count`, else `data.count`.
  static LiveMessage? onlineRank(Map<String, dynamic> notice) {
    final data = jsonObject(notice['data']);
    final value = jsonCount(data?['online_count']) ?? jsonCount(data?['count']);
    return value == null ? null : _audience(LiveAudienceSignalKind.onlineViewers, value);
  }

  /// `SEND_GIFT` (logged in) and `COMBO_SEND` (a combo so far), both with
  /// `uid`, `uname`, `batch_combo_id`, `gift_info.img_basic`, the sender's fan
  /// medal and the receiver: a gift whose value rides in [LiveGiftValue]; a
  /// silver gift is free. A `COMBO_SEND`'s count is also its combo total.
  /// Without a name, nothing.
  static LiveMessage? gift(Map<String, dynamic> notice, BilibiliGiftCatalog gifts, {required bool combo}) {
    final data = jsonObject(notice['data']);
    if (data == null) return null;
    final count = jsonInt(data[combo ? 'total_num' : 'num']) ?? 0;
    final info = jsonObject(data['gift_info']);
    final receiver = jsonObject(data['receive_user_info']);
    final sender = jsonObject(data['sender_uinfo']);
    final tid = combo ? '' : jsonString(data['tid']) ?? '';
    final senderName = jsonString(data['uname'])?.trim() ?? '';
    return _giftOf(
      gifts,
      id: _giftId(data[combo ? 'gift_id' : 'giftId']),
      name: jsonString(data[combo ? 'gift_name' : 'giftName']) ?? '',
      count: count,
      coinType: jsonString(data['coin_type']) ?? '',
      price: combo ? null : jsonInt(data['price']),
      total: jsonInt(data[combo ? 'combo_total_coin' : 'total_coin']),
      comboId: jsonString(data['batch_combo_id']) ?? '',
      comboTotal: combo && count > 0 ? count : null,
      icon: BilibiliEndpoints.giftIcon(info?['img_basic']),
      receiver: jsonString(receiver?['uname'])?.trim() ?? '',
      userName: senderName.isNotEmpty ? senderName : _richName(sender),
      userId: jsonString(data['uid']) ?? '',
      medal: _giftMedal(sender, jsonObject(data['medal_info'])),
      messageId: tid.isEmpty ? '' : 'bilibili:gift:$tid',
      sentAt: combo ? null : jsonInt(data['timestamp']),
    );
  }

  /// `SEND_GIFT_V2`, what a guest gets instead of `SEND_GIFT`: `data.pb` is
  /// the same gift as protobuf, read schemalessly by tag
  /// (root 1 `uid`, 2 `uname`, 8 `medal_info`, 10 the gift, 15 `sender_uinfo`;
  /// gift 1 id, 2 name, 3 num, 5 price, 7 total, 8 `coin_type`, 9 `tid`,
  /// 10 time, 12 `batch_combo_id`, 29.1 receiver name, 35.1 picture). A packet
  /// that is not protobuf, or a gift without a name, gives nothing.
  static LiveMessage? giftV2(Map<String, dynamic> notice, BilibiliGiftCatalog gifts) {
    final encoded = jsonObject(notice['data'])?['pb'];
    if (encoded is! String || encoded.isEmpty) return null;
    final BilibiliProtoMessage root;
    final BilibiliProtoMessage? gift;
    try {
      root = BilibiliProtoMessage.decode(base64.decode(encoded));
      gift = root.message(10);
    } on FormatException {
      return null;
    }
    if (gift == null) return null;
    final sender = root.message(15);
    final medal = root.message(8);
    final rich = sender?.message(3);
    final medalName = medal?.string(6)?.trim() ?? '';
    final richName = rich?.string(1)?.trim() ?? '';
    final uid = root.integer(1) ?? 0;
    final tid = gift.string(9)?.trim() ?? '';
    String level(int? value) => value != null && value > 0 ? '$value' : '';
    return _giftOf(
      gifts,
      id: _giftId(gift.integer(1)),
      name: gift.string(2) ?? '',
      count: gift.integer(3) ?? 0,
      coinType: gift.string(8) ?? '',
      price: gift.integer(5),
      total: gift.integer(7),
      comboId: gift.string(12)?.trim() ?? '',
      icon: BilibiliEndpoints.giftIcon(gift.message(35)?.string(1)),
      receiver: gift.message(29)?.string(1)?.trim() ?? '',
      userName: (root.string(2)?.trim() ?? '').isNotEmpty
          ? root.string(2)!.trim()
          : sender?.message(2)?.string(1)?.trim() ?? '',
      userId: BilibiliProtoMessage.unsigned(uid),
      medal: medalName.isNotEmpty
          ? (name: medalName, level: level(medal?.integer(5)))
          : richName.isNotEmpty
          ? (name: richName, level: level(rich?.integer(2)))
          : (name: '', level: ''),
      messageId: tid.isEmpty ? '' : 'bilibili:gift:$tid',
      sentAt: gift.integer(10),
    );
  }

  /// A gift message from what [gift] and [giftV2] read, with the gift table
  /// [gifts] for what the packet leaves out: the name, else the table's;
  /// silver (`coin_type` `silver`, or the table's when the packet says nothing)
  /// is free and its value in silver seeds; the price of one is `total ÷ count`
  /// when a total is given, else `price`, else the table's for the same coin;
  /// the picture the packet's, else the table's.
  static LiveMessage? _giftOf(
    BilibiliGiftCatalog gifts, {
    required String id,
    required String name,
    required int count,
    required String coinType,
    required int? price,
    required int? total,
    required String comboId,
    required Uri? icon,
    required String receiver,
    required String userName,
    required String userId,
    required ({String name, String level}) medal,
    required String messageId,
    required int? sentAt,
    int? comboTotal,
  }) {
    final entry = id.isEmpty ? null : gifts[id];
    final title = name.trim().isNotEmpty ? name.trim() : entry?.name ?? '';
    if (title.isEmpty) return null;
    final number = count > 0 ? count : 1;
    final silver = coinType == 'silver' || (coinType.isEmpty && (entry?.silver ?? false));
    final paid = total != null && total > 0 ? total : null;
    var unit = price != null && price > 0 ? price : null;
    if (paid != null && (unit == null || unit * number != paid)) unit = paid % number == 0 ? paid ~/ number : null;
    if (unit == null && entry != null && entry.silver == silver && entry.price > 0) unit = entry.price;
    final value = paid ?? (unit == null ? null : unit * number);
    final gift = LiveGift(
      giftId: id,
      name: title,
      iconUrl: (icon ?? entry?.icon)?.toString(),
      count: number,
      value: LiveGiftValue(
        unit: silver ? LiveGiftUnit.silver : LiveGiftUnit.goldSeed,
        unitPrice: unit?.toDouble(),
        totalValue: value?.toDouble(),
      ),
      combo: LiveGiftCombo(comboKey: comboId, comboTotal: comboTotal),
      recipientName: receiver,
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${gift.name} ×${gift.count}',
      sender: MessageSender.normalized(
        userId: userId,
        userName: userName,
        fanBadgeName: medal.name,
        fanBadgeLevel: medal.level,
      ),
      color: LiveMessageColor.white,
      messageId: messageId,
      sentAt: _seconds(sentAt),
      payload: gift,
    );
  }

  /// The fan medal of a gift's sender: `sender_uinfo.medal{name, level}`, else
  /// `medal_info{medal_name, medal_level}`; guests see it unmasked.
  static ({String name, String level}) _giftMedal(Object? rich, Map<String, dynamic>? legacy) {
    final medal = _medal(rich, null);
    if (medal.name.isNotEmpty || legacy == null) return medal;
    return _medal(null, [legacy['medal_level'], legacy['medal_name']]);
  }

  /// `GUARD_BUY`: `username` bought `num` months of guard `guard_level`
  /// (1 总督, 2 提督, 3 舰长; `gift_name`, else the level's name) at `price`
  /// gold coins each — a membership gift holding the level.
  static LiveMessage? guard(Map<String, dynamic> notice, BilibiliGiftCatalog gifts) {
    final data = jsonObject(notice['data']);
    if (data == null) return null;
    final guard = jsonInt(data['guard_level']) ?? 0;
    final level = guard >= 1 && guard <= 3 ? guard : 0;
    var name = jsonString(data['gift_name'])?.trim() ?? '';
    if (name.isEmpty) name = BilibiliEndpoints.guardName(level);
    if (name.isEmpty) return null;
    final count = jsonInt(data['num']) ?? 0;
    final months = count > 0 ? count : 1;
    final price = jsonInt(data['price']) ?? 0;
    final gift = LiveGift(
      giftId: _giftId(data['gift_id']),
      name: name,
      iconUrl: gifts.guards[level]?.icon.toString(),
      kind: LiveGiftKind.subscription,
      count: months,
      value: LiveGiftValue(
        unit: LiveGiftUnit.goldSeed,
        unitPrice: price > 0 ? price.toDouble() : null,
        totalValue: price > 0 ? (price * months).toDouble() : null,
      ),
      recipientName: jsonString(data['username']) ?? '',
    );
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: '${gift.name} ×${gift.count}',
      sender: MessageSender.normalized(
        userId: jsonString(data['uid']) ?? '',
        userName: jsonString(data['username']) ?? '',
      ),
      color: LiveMessageColor.white,
      sentAt: _seconds(jsonInt(data['start_time'])),
      payload: gift,
    );
  }

  /// `SUPER_CHAT_MESSAGE`: `data` read like an item of the snapshot
  /// `BilibiliRoomParser.superChats`, so both give the same id (`data.id`) and
  /// the room page merges them. A later `SUPER_CHAT_MESSAGE_DELETE` takes the
  /// message back by that id.
  static LiveMessage? superChat(Map<String, dynamic> notice) {
    final data = jsonObject(notice['data']);
    if (data == null) return null;
    final start = _seconds(jsonInt(data['start_time']));
    final end = _seconds(jsonInt(data['end_time']));
    if (start == null || end == null) return null;
    final user = jsonObject(data['user_info']);
    final id = jsonString(data['id']) ?? '';
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      text: jsonString(data['message']) ?? '',
      sender: MessageSender.normalized(
        userId: jsonString(user?['uid']) ?? '',
        userName: jsonString(user?['uname']) ?? '',
        avatarUrl: sizedImage(user?['face'], '@200w.jpg'),
      ),
      color: LiveMessageColor.white,
      messageId: id,
      payload: LiveSuperChatMessage(
        messageId: id,
        userName: jsonString(user?['uname']) ?? '',
        faceUrl: sizedImage(user?['face'], '@200w.jpg'),
        text: jsonString(data['message']) ?? '',
        price: SuperChatPrice(amount: jsonInt(data['price']), currency: 'CNY'),
        startTime: start,
        endTime: end,
        display: SuperChatDisplay(
          backgroundColor: jsonString(data['background_color']) ?? '',
          backgroundBottomColor: jsonString(data['background_bottom_color']) ?? '',
        ),
      ),
    );
  }

  /// A retraction line: no sender, no text of its own.
  static LiveMessage _retraction(LiveRetraction target) =>
      LiveMessage.normalized(type: LiveMessageType.retraction, color: LiveMessageColor.white, payload: target);

  /// A system notice: [lead], then the platform's reason `msg` when there is
  /// one.
  static LiveMessage _notify(Map<String, dynamic> notice, String lead) {
    final reason = jsonString(notice['msg'])?.trim() ?? '';
    return LiveMessage.normalized(
      type: LiveMessageType.notice,
      text: reason.isEmpty ? lead : '$lead：$reason',
      color: LiveMessageColor.white,
      payload: LiveNoticeKind.system,
    );
  }

  static LiveMessage _audience(LiveAudienceSignalKind kind, int value) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    color: LiveMessageColor.white,
    payload: LiveAudienceUpdate(kind: kind, value: value),
  );

  static String _giftId(Object? raw) {
    final id = jsonString(raw)?.trim() ?? '';
    return id.isEmpty || id == '0' ? '' : id;
  }

  static const int _maxEpochMilliseconds = 8640000000000000;

  /// Platform Unix seconds as UTC; 0, a negative and an implausible value read
  /// as no time.
  static DateTime? _seconds(Object? value) => switch (jsonInt(value)) {
    final int seconds when seconds > 0 && seconds < 100000000000 => DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ),
    _ => null,
  };
}

/// What one message accumulated while it was decoded.
final class _Frame {
  final List<LiveMessage> messages = <LiveMessage>[];
  final List<Uint8List> sends = <Uint8List>[];
  int? authCode;

  /// How many brotli (version 3) packets were skipped (see the class note on
  /// `BilibiliDanmakuProtocol`).
  int brotliPackets = 0;
}

/// Collects inflated bytes and fails once they pass [limit], so a highly
/// compressible packet is rejected before it is all in memory.
final class _BoundedSink implements Sink<List<int>> {
  _BoundedSink(this.limit);

  final int limit;
  final BytesBuilder bytes = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (chunk.length > limit - bytes.length) {
      throw FormatException('Bilibili decompressed message exceeds $limit bytes');
    }
    bytes.add(chunk);
  }

  @override
  void close() {}
}
