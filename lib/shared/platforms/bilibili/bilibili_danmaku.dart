import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';
import 'package:flutter/foundation.dart';

import 'package:pure_live/core/network/network_image_url.dart';
import 'package:pure_live/core/utils/binary_writer.dart';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/utils/type_cast.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// 一条礼物（`SEND_GIFT`/`COMBO_SEND`/`GUARD_BUY`）的内容，放在礼物消息的
/// `data` 里（上游 bilibili 4-x 的 `BilibiliGift`）。
class BilibiliGift {
  const BilibiliGift({
    required this.id,
    required this.name,
    required this.count,
    this.goldCoins = 0,
    this.comboId = '',
  });

  /// `giftId`/`gift_id`；缺失或 0 时为空串。
  final String id;

  /// `giftName`/`gift_name`（小心心、舰长……）。
  final String name;

  /// 这条给了多少，至少 1（连击取 `total_num`，上舰取月数）。
  final int count;

  /// 价值多少金瓜子（1000 = 1 元）；免费（银瓜子）礼物或缺失为 0。
  final int goldCoins;

  /// `batch_combo_id`：同一次连击的每条消息共享它。
  final String comboId;
}

class BiliBiliDanmakuArgs {
  final int roomId;
  final String token;
  final String buvid;
  final List<String> serverUrls;
  final int uid;
  final String cookie;
  final Map<String, dynamic> headers;
  final Future<BiliBiliDanmakuArgs?> Function()? refresh;
  BiliBiliDanmakuArgs({
    required this.roomId,
    required this.token,
    required this.serverUrls,
    required this.buvid,
    required this.uid,
    required this.cookie,
    this.headers = const {},
    this.refresh,
  });
  @override
  String toString() {
    return json.encode({
      "roomId": roomId,
      "hasToken": token.isNotEmpty,
      "serverUrls": serverUrls,
      "hasBuvid": buvid.isNotEmpty,
      "uid": uid,
      "hasCookie": cookie.isNotEmpty,
    });
  }
}

class BiliBiliDanmaku implements LiveDanmaku {
  factory BiliBiliDanmaku({void Function(List<int> packet)? packetSender}) => BiliBiliDanmaku._(packetSender);

  BiliBiliDanmaku._(this._packetSender);

  final void Function(List<int> packet)? _packetSender;
  static const int _packetHeaderLength = 16;
  static const int _maxTransportMessageBytes = 8 * 1024 * 1024;
  static const int _maxDecompressedMessageBytes = 16 * 1024 * 1024;
  static const int _maxPacketsPerMessage = 4096;
  static const int _maxCompressedNestingDepth = 2;

  @override
  int heartbeatTime = 30 * 1000;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onReconnect;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  // String serverUrl = "wss://broadcastlv.chat.bilibili.com/sub";

  WebScoketUtils? webScoketUtils;
  late BiliBiliDanmakuArgs danmakuArgs;
  bool _refreshingCredentials = false;
  bool _stopped = false;
  int _credentialRefreshCount = 0;
  Timer? _authTimer;

  @override
  Future start(dynamic args) async {
    await webScoketUtils?.close();
    webScoketUtils = null;
    danmakuArgs = args as BiliBiliDanmakuArgs;
    _stopped = false;
    _credentialRefreshCount = 0;
    markDisconnected();
    if (danmakuArgs.token.isEmpty) {
      for (var attempt = 0; attempt < 3 && !_stopped; attempt++) {
        try {
          final refreshed = await danmakuArgs.refresh?.call();
          if (refreshed != null && refreshed.token.isNotEmpty) {
            danmakuArgs = refreshed;
            break;
          }
        } catch (error) {
          CoreLog.error(error);
        }
        if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
      if (_stopped || danmakuArgs.token.isEmpty) {
        onClose?.call("弹幕连接信息仍在更新，请稍后刷新房间");
        return;
      }
    }
    await _connect(danmakuArgs);
  }

  Future<void> _connect(BiliBiliDanmakuArgs args) async {
    if (_stopped) return;
    final endpoints = args.serverUrls.isEmpty ? const ['wss://broadcastlv.chat.bilibili.com/sub'] : args.serverUrls;
    webScoketUtils = WebScoketUtils(
      url: endpoints.first,
      serverUrls: endpoints,
      headers: args.headers.isNotEmpty ? args.headers : (args.cookie.isEmpty ? null : {"cookie": args.cookie}),
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        joinRoom(danmakuArgs);
        _authTimer?.cancel();
        _authTimer = Timer(const Duration(seconds: 8), () {
          if (!_stopped && !isConnected) webScoketUtils?.reconnect();
        });
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        _authTimer?.cancel();
        markDisconnected();
        onReconnect?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        _authTimer?.cancel();
        markDisconnected();
        onClose?.call("服务器连接失败$e");
      },
    );
    await webScoketUtils?.connect();
  }

  Future<void> _refreshCredentialsAndReconnect() async {
    if (_stopped || _refreshingCredentials || _credentialRefreshCount >= 3) return;
    _refreshingCredentials = true;
    _credentialRefreshCount++;
    try {
      final refreshed = await danmakuArgs.refresh?.call();
      if (_stopped || refreshed == null || refreshed.token.isEmpty) return;
      danmakuArgs = refreshed;
      await webScoketUtils?.close();
      if (_stopped) return;
      await _connect(refreshed);
    } catch (error) {
      CoreLog.error(error);
    } finally {
      _refreshingCredentials = false;
    }
  }

  void joinRoom(BiliBiliDanmakuArgs args) {
    _sendPacket(encodeData(json.encode(buildJoinPayload(args)), 7));
  }

  @visibleForTesting
  Map<String, dynamic> buildJoinPayload(BiliBiliDanmakuArgs args, {String? queueUuid}) {
    return {
      "uid": args.uid,
      "roomid": args.roomId,
      "protover": 3,
      "buvid": args.buvid,
      "support_ack": true,
      "queue_uuid": queueUuid ?? _newQueueUuid(),
      "scene": "room",
      "platform": "web",
      "type": 2,
      "key": args.token,
    };
  }

  String _newQueueUuid() {
    final random = Random.secure();
    return List<String>.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  void _sendPacket(List<int> packet) {
    final sender = _packetSender;
    if (sender != null) {
      sender(packet);
      return;
    }
    webScoketUtils?.sendMessage(packet);
  }

  @override
  void heartbeat() {
    _sendPacket(encodeData("", 2));
  }

  @override
  Future stop() async {
    _stopped = true;
    _authTimer?.cancel();
    _authTimer = null;
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    await webScoketUtils?.close();
    webScoketUtils = null;
  }

  List<int> encodeData(String msg, int action) {
    var data = utf8.encode(msg);
    //头部长度固定16
    var length = data.length + 16;
    var buffer = Uint8List(length);

    var writer = BinaryWriter([]);

    //数据包长度
    writer.writeInt(buffer.length, 4);
    //数据包头部长度,固定16
    writer.writeInt(16, 2);

    //协议版本，0=JSON,1=Int32,2=Buffer
    writer.writeInt(0, 2);

    //操作类型
    writer.writeInt(action, 4);

    //数据包头部长度,固定1

    writer.writeInt(1, 4);

    writer.writeBytes(data);

    return writer.buffer;
  }

  void decodeMessage(List<int> data) {
    try {
      if (data.length > _maxTransportMessageBytes) {
        throw FormatException('Bilibili danmaku message is too large: ${data.length} bytes');
      }
      _decodePacketStream(data, depth: 0);
    } catch (e) {
      CoreLog.error(e);
    }
  }

  /// A WebSocket message can contain multiple Bilibili packets. Compressed
  /// notification packets contain another complete packet stream, rather than
  /// plain JSON. Parsing the 16-byte frames recursively keeps packet-length
  /// bytes away from the JSON decoder and prevents valid DANMU_MSG events from
  /// being dropped.
  void _decodePacketStream(List<int> data, {required int depth}) {
    if (depth > _maxCompressedNestingDepth) {
      throw const FormatException('Bilibili danmaku packet nesting is too deep');
    }

    var offset = 0;
    var packetCount = 0;
    while (offset + _packetHeaderLength <= data.length) {
      packetCount++;
      if (packetCount > _maxPacketsPerMessage) {
        throw const FormatException('Bilibili danmaku message contains too many packets');
      }
      final packetLength = readInt(data, offset, 4);
      final headerLength = readInt(data, offset + 4, 2);
      final protocolVersion = readInt(data, offset + 6, 2);
      final operation = readInt(data, offset + 8, 4);

      // Validate both sides of the frame before slicing. In particular,
      // packetLength=0 must not leave [offset] unchanged and spin forever.
      if (headerLength < _packetHeaderLength ||
          packetLength < headerLength ||
          packetLength > _maxTransportMessageBytes ||
          offset + packetLength > data.length) {
        throw FormatException(
          'Invalid Bilibili danmaku frame: offset=$offset, packet=$packetLength, header=$headerLength, total=${data.length}',
        );
      }

      final body = data.sublist(offset + headerLength, offset + packetLength);
      _decodePacket(protocolVersion, operation, body, depth: depth);
      offset += packetLength;
    }

    if (offset != data.length) {
      throw FormatException('Incomplete Bilibili danmaku frame: parsed=$offset, total=${data.length}');
    }
  }

  void _decodePacket(int protocolVersion, int operation, List<int> body, {required int depth}) {
    if (operation == 3) {
      if (body.length < 4) return;
      final online = readInt(body, 0, 4);
      // 游客拿到的热度是占位值 1（上游 REG-BILIBILI-015）：房间详情里的真实热度
      // 不能被它顶掉，否则一进房人气就掉到 1。
      if (online <= 1) return;
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.online,
          data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.popularity, value: online),
          color: LiveMessageColor.white,
          message: "",
          userName: "",
        ),
      );
      return;
    }

    if (operation == 5) {
      if (protocolVersion == 2 || protocolVersion == 3) {
        final decoded = _decodeCompressedBody(body, protocolVersion);
        _decodePacketStream(decoded, depth: depth + 1);
      } else {
        final text = utf8.decode(body, allowMalformed: true).trim();
        if (text.isNotEmpty) parseMessage(text);
      }
      return;
    }

    if (operation == 8) {
      // The transport is usable only after Bilibili acknowledges auth.
      final text = utf8.decode(body, allowMalformed: true).trim();
      final dynamic decoded = text.isEmpty ? const <String, dynamic>{'code': 0} : json.decode(text);
      final auth = decoded is Map ? decoded : const <String, dynamic>{};
      final code = int.tryParse(auth['code']?.toString() ?? '') ?? -1;
      if (code == 0 && !isConnected) {
        _authTimer?.cancel();
        markConnected();
        heartbeat();
        onReady?.call();
      } else if (code != 0) {
        _authTimer?.cancel();
        markDisconnected();
        unawaited(_refreshCredentialsAndReconnect());
      }
    }
  }

  List<int> _decodeCompressedBody(List<int> body, int protocolVersion) {
    final sink = _BoundedBytesSink(_maxDecompressedMessageBytes);
    final decoder = protocolVersion == 2 ? zlib.decoder : brotli.decoder;
    final conversion = decoder.startChunkedConversion(sink);
    conversion.add(body);
    conversion.close();
    return sink.takeBytes();
  }

  void parseMessage(String jsonMessage) {
    try {
      var obj = json.decode(jsonMessage);
      _acknowledgeIfRequired(obj);
      var cmd = obj["cmd"].toString();
      // 撤回要排在 DANMU_MSG 之前：`RECALL_DANMU_MSG` 里也含 `DANMU_MSG`，否则会被
      // 当成一条普通聊天（上游 bilibili 4-x）。
      if (cmd == "RECALL_DANMU_MSG") {
        final data = obj["data"];
        if (data is Map) {
          final recallType = int.tryParse(data["recall_type"]?.toString() ?? '');
          final LiveRetraction? target;
          if (recallType == 2) {
            final uinfo = data["uinfo"];
            final uid = (uinfo is Map ? int.tryParse(uinfo["uid"]?.toString() ?? '') : null) ??
                int.tryParse(data["target_id"]?.toString() ?? '');
            // uid 0 是游客看到的占位（所有人都被打成 0），撤它等于撤所有人。
            target = uid == null || uid <= 0 ? null : LiveRetraction.user('$uid');
          } else if (recallType == 3) {
            target = const LiveRetraction.all();
          } else {
            // 0 是"什么都没撤"，1 是单条（网页播放器自己也不在这里处理）。
            target = null;
          }
          if (target != null) {
            onMessage?.call(
              LiveMessage(
                type: LiveMessageType.retraction,
                userName: '',
                message: '',
                color: LiveMessageColor.white,
                data: target,
              ),
            );
          }
        }
      } else if (cmd.contains("DANMU_MSG")) {
        if (obj["info"] != null && obj["info"].length != 0) {
          var message = obj["info"][1].toString();
          var color = asT<int?>(obj["info"][0][3]) ?? 0;
          if (obj["info"][2] != null && obj["info"][2].length != 0) {
            final metadata = obj["info"][0] is List ? obj["info"][0] as List : const <dynamic>[];
            final username = _preferredBilibiliUserName(obj, metadata, obj["info"][2][1]?.toString() ?? '');
            final rawTimestamp = metadata.length > 4 ? int.tryParse(metadata[4]?.toString() ?? '') : null;
            final rawNonce = metadata.length > 5 ? metadata[5]?.toString() ?? '' : '';
            final sentAt = rawTimestamp == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(rawTimestamp > 100000000000 ? rawTimestamp : rawTimestamp * 1000);
            var liveMsg = LiveMessage(
              type: LiveMessageType.chat,
              userName: username,
              userId: obj["info"][2][0]?.toString() ?? '',
              message: message,
              color: color == 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
              messageId: rawNonce.isEmpty ? '' : 'bilibili:$rawNonce',
              sentAt: sentAt,
              // 贴纸与内联表情（上游 M13.16）。
              emotes: _emotes(message, metadata),
            );
            onMessage?.call(liveMsg);
          }
        }
      } else if (cmd == "WATCHED_CHANGE") {
        final value = int.tryParse(obj["data"]?["num"]?.toString() ?? '');
        if (value != null && value >= 0) {
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.totalViewers, value: value),
              color: LiveMessageColor.white,
              message: "",
              userName: "",
            ),
          );
        }
      } else if (cmd == "SEND_GIFT" || cmd == "COMBO_SEND") {
        // 礼物：`SEND_GIFT`（`giftName`/`num`/gold `total_coin`）与 `COMBO_SEND`
        // （`gift_name`/`total_num`/`combo_total_coin`），两者都有 `uid`/`uname`/
        // `batch_combo_id`（上游 bilibili 4-x 的 `_gift`）。
        final gift = _giftMessage(obj["data"], combo: cmd == "COMBO_SEND");
        if (gift != null) onMessage?.call(gift);
      } else if (cmd == "GUARD_BUY") {
        // 上舰：`gift_name` 买了 `num` 个月，每月 `price` 金瓜子（上游 `_guard`）。
        final guard = _guardMessage(obj["data"]);
        if (guard != null) onMessage?.call(guard);
      } else if (cmd == "SUPER_CHAT_MESSAGE") {
        if (obj["data"] == null) {
          return;
        }
        LiveSuperChatMessage sc = LiveSuperChatMessage(
          backgroundBottomColor: obj["data"]["background_bottom_color"].toString(),
          backgroundColor: obj["data"]["background_color"].toString(),
          endTime: DateTime.fromMillisecondsSinceEpoch(obj["data"]["end_time"] * 1000),
          face: "${obj["data"]["user_info"]["face"]}@200w.jpg",
          message: obj["data"]["message"].toString(),
          price: obj["data"]["price"],
          startTime: DateTime.fromMillisecondsSinceEpoch(obj["data"]["start_time"] * 1000),
          userName: obj["data"]["user_info"]["uname"].toString(),
        );
        var liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: "SUPER_CHAT_MESSAGE",
          message: "SUPER_CHAT_MESSAGE",
          color: LiveMessageColor.white,
          // 同一条醒目留言的 id：稍后 `SUPER_CHAT_MESSAGE_DELETE` 按它撤回
          // （上游 bilibili 4-x）。
          messageId: obj["data"]["id"] == null ? '' : 'bilibili:${obj["data"]["id"]}',
          data: sc,
        );
        onMessage?.call(liveMsg);
      } else if (cmd == "SUPER_CHAT_MESSAGE_DELETE") {
        // 被退款/下架的醒目留言：按 id 逐条撤回（上游 bilibili 4-x）。
        final ids = obj["data"] is Map ? obj["data"]["ids"] : null;
        if (ids is List) {
          for (final raw in ids) {
            final id = raw?.toString().trim() ?? '';
            if (id.isEmpty) continue;
            onMessage?.call(
              LiveMessage(
                type: LiveMessageType.retraction,
                userName: '',
                message: '',
                color: LiveMessageColor.white,
                data: LiveRetraction.message('bilibili:$id'),
              ),
            );
          }
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  /// `SEND_GIFT` / `COMBO_SEND` → 一条 [LiveMessageType.gift]，文本 `<名称> ×<数量>`，
  /// `data` 里带 [BilibiliGift]；没有礼物名时不产生消息（上游 bilibili 4-x）。
  static LiveMessage? _giftMessage(dynamic raw, {required bool combo}) {
    if (raw is! Map) return null;
    final name = (combo ? raw['gift_name'] : raw['giftName'])?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final rawCount = int.tryParse((combo ? raw['total_num'] : raw['num'])?.toString() ?? '') ?? 0;
    final count = rawCount > 0 ? rawCount : 1;
    final rawCoins = combo
        ? int.tryParse(raw['combo_total_coin']?.toString() ?? '')
        : (raw['coin_type'] == 'gold' ? int.tryParse(raw['total_coin']?.toString() ?? '') : null);
    final rawSentAt = combo ? null : int.tryParse(raw['timestamp']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: raw['uname']?.toString() ?? '',
      userId: raw['uid']?.toString() ?? '',
      message: '$name ×$count',
      messageId: combo || (raw['tid']?.toString().trim() ?? '').isEmpty
          ? ''
          : 'bilibili:gift:${raw['tid'].toString().trim()}',
      color: LiveMessageColor.white,
      sentAt: rawSentAt == null || rawSentAt <= 0 || rawSentAt >= 100000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(rawSentAt * 1000),
      data: BilibiliGift(
        id: _giftId(combo ? raw['gift_id'] : raw['giftId']),
        name: name,
        count: count,
        goldCoins: rawCoins != null && rawCoins > 0 ? rawCoins : 0,
        comboId: raw['batch_combo_id']?.toString() ?? '',
      ),
    );
  }

  /// `GUARD_BUY` → 上舰同样是礼物消息（上游 bilibili 4-x）。
  static LiveMessage? _guardMessage(dynamic raw) {
    if (raw is! Map) return null;
    final name = raw['gift_name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final rawCount = int.tryParse(raw['num']?.toString() ?? '') ?? 0;
    final months = rawCount > 0 ? rawCount : 1;
    final price = int.tryParse(raw['price']?.toString() ?? '') ?? 0;
    final rawSentAt = int.tryParse(raw['start_time']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: raw['username']?.toString() ?? '',
      userId: raw['uid']?.toString() ?? '',
      message: '$name ×$months',
      color: LiveMessageColor.white,
      sentAt: rawSentAt == null || rawSentAt <= 0 || rawSentAt >= 100000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(rawSentAt * 1000),
      data: BilibiliGift(
        id: _giftId(raw['gift_id']),
        name: name,
        count: months,
        goldCoins: price > 0 ? price * months : 0,
      ),
    );
  }

  static String _giftId(Object? raw) {
    final id = raw?.toString().trim() ?? '';
    return id == '0' ? '' : id;
  }

  /// 一条聊天里的表情图片（上游 bilibili 4-x 的 `emotes`，M13.16）：贴纸
  /// （`info[0][12]` 为 1，图片在 `info[0][13].url`）就是整条消息；否则取内联
  /// 编码（`[dog]`）中出现在文本里的那些，映射来自 `info[0][15].extra.emots`。
  static List<LiveEmote> _emotes(String text, List<dynamic> meta) {
    if (text.isEmpty) return const <LiveEmote>[];
    final sticker = meta.length > 13 ? meta[13] : null;
    if (meta.length > 12 && meta[12] == 1 && sticker is Map) {
      final url = _pictureUrl(sticker['url']);
      return url.isEmpty ? const <LiveEmote>[] : [LiveEmote(code: text, url: url)];
    }
    var rich = meta.length > 15 ? meta[15] : null;
    if (rich is String) rich = _decodeJsonObject(rich);
    final extra = rich is Map ? _asJsonObject(rich['extra']) : null;
    final emots = extra is Map ? extra['emots'] : null;
    if (emots is! Map || emots.isEmpty) return const <LiveEmote>[];
    final codes = <String, String>{};
    for (final entry in emots.entries) {
      final code = entry.key;
      final value = entry.value;
      if (code is! String || code.isEmpty || value is! Map) continue;
      final url = _pictureUrl(value['url']);
      if (url.isNotEmpty) codes[code] = url;
    }
    return LiveEmote.inText(text, codes);
  }

  static Object? _decodeJsonObject(String raw) {
    final text = raw.trim();
    if (!text.startsWith('{')) return null;
    try {
      return json.decode(text);
    } catch (_) {
      return null;
    }
  }

  static Object? _asJsonObject(Object? value) => value is Map ? value : (value is String ? _decodeJsonObject(value) : null);

  /// 表情图片地址：能规范化成 http(s) 就用它，否则当作没有。
  static String _pictureUrl(Object? raw) {
    final value = normalizeNetworkImageUrl(raw?.toString());
    return value.startsWith('http') ? value : '';
  }

  void _acknowledgeIfRequired(dynamic packet) {
    if (packet is! Map || packet['p_is_ack'] != true) return;
    final msgId = packet['msg_id']?.toString().trim() ?? '';
    final cmd = packet['cmd']?.toString().trim() ?? '';
    if (!packet.containsKey('p_msg_type')) return;
    final msgType = int.tryParse(packet['p_msg_type']?.toString() ?? '');
    if (msgId.isEmpty || cmd.isEmpty || msgType == null) return;
    _sendPacket(encodeData(json.encode({'msg_id': msgId, 'cmd': cmd, 'p_msg_type': msgType}), 24));
  }

  String _preferredBilibiliUserName(dynamic packet, List<dynamic> metadata, String legacyName) {
    dynamic richInfo;
    if (metadata.length > 15) richInfo = metadata[15];
    if (richInfo is String && richInfo.trimLeft().startsWith('{')) {
      try {
        richInfo = json.decode(richInfo);
      } catch (_) {
        richInfo = null;
      }
    }

    String readName(dynamic root) {
      if (root is! Map) return '';
      final user = root['user'] is Map ? root['user'] : root;
      if (user is! Map) return '';
      final base = user['base'];
      if (base is! Map) return '';
      final name = base['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
      final origin = base['origin_info'];
      return origin is Map ? origin['name']?.toString().trim() ?? '' : '';
    }

    // Current packets include a richer user object in info[0][15]. Logged-in
    // sessions may expose a complete name there even when the legacy slot is
    // masked. Guest sessions currently mask both locations and omit the uid.
    dynamic packetUserInfo;
    dynamic packetDataUserInfo;
    if (packet is Map) {
      packetUserInfo = packet['uinfo'];
      final data = packet['data'];
      if (data is Map) packetDataUserInfo = data['uinfo'];
    }
    final candidates = <String>[];
    for (final candidate in [richInfo, packetUserInfo, packetDataUserInfo]) {
      final name = readName(candidate);
      if (name.isNotEmpty) candidates.add(name);
    }
    final masked = RegExp(r'\*{2,}|＊{2,}');
    for (final candidate in [...candidates, legacyName]) {
      if (candidate.isNotEmpty && !masked.hasMatch(candidate)) return candidate;
    }
    return candidates.isNotEmpty ? candidates.first : legacyName;
  }

  int readInt(List<int> buffer, int start, int len) {
    var bytes = Uint8List.fromList(buffer.getRange(start, start + len).toList());
    var byteBuffer = bytes.buffer;
    var data = ByteData.view(byteBuffer);
    var result = 0;

    if (len == 1) {
      result = data.getUint8(0);
    }
    if (len == 2) {
      result = data.getUint16(0, Endian.big);
    }
    if (len == 4) {
      result = data.getUint32(0, Endian.big);
    }
    if (len == 8) {
      result = data.getInt64(0, Endian.big);
    }

    return result;
  }
}

/// Accumulates decompressed protocol bytes while enforcing a hard output cap.
/// Both zlib and Brotli stream into this sink, so a highly-compressible frame
/// is rejected before it can materialize an unbounded output list.
class _BoundedBytesSink implements Sink<List<int>> {
  _BoundedBytesSink(this.limit);

  final int limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;
  bool _closed = false;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('Bilibili decompression sink is closed');
    if (data.length > limit - _length) {
      throw FormatException('Bilibili decompressed message exceeds $limit bytes');
    }
    _length += data.length;
    _builder.add(data);
  }

  @override
  void close() {
    _closed = true;
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
