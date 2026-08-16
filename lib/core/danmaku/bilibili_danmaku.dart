import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:brotli/brotli.dart';

import '../common/binary_writer.dart';

import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/convert_helper.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

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
        onClose?.call("与服务器断开连接，正在尝试重连");
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
    var joinData = encodeData(
      json.encode({
        "uid": args.uid,
        "roomid": args.roomId,
        "protover": 3,
        "buvid": args.buvid,
        "platform": "web",
        "type": 2,
        "key": args.token,
      }),
      7,
    );
    webScoketUtils?.sendMessage(joinData);
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(encodeData("", 2));
  }

  @override
  Future stop() async {
    _stopped = true;
    _authTimer?.cancel();
    _authTimer = null;
    markDisconnected();
    onMessage = null;
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
    if (depth > 8) {
      throw const FormatException('Bilibili danmaku packet nesting is too deep');
    }

    var offset = 0;
    while (offset + 16 <= data.length) {
      final packetLength = readInt(data, offset, 4);
      final headerLength = readInt(data, offset + 4, 2);
      final protocolVersion = readInt(data, offset + 6, 2);
      final operation = readInt(data, offset + 8, 4);

      if (headerLength < 16 || packetLength < headerLength || offset + packetLength > data.length) {
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
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.online,
          data: online,
          color: LiveMessageColor.white,
          message: "",
          userName: "",
        ),
      );
      return;
    }

    if (operation == 5) {
      if (protocolVersion == 2 || protocolVersion == 3) {
        final decoded = protocolVersion == 2 ? zlib.decode(body) : brotli.decode(body);
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

  void parseMessage(String jsonMessage) {
    try {
      var obj = json.decode(jsonMessage);
      var cmd = obj["cmd"].toString();
      if (cmd.contains("DANMU_MSG")) {
        if (obj["info"] != null && obj["info"].length != 0) {
          var message = obj["info"][1].toString();
          var color = asT<int?>(obj["info"][0][3]) ?? 0;
          if (obj["info"][2] != null && obj["info"][2].length != 0) {
            var username = obj["info"][2][1].toString();
            final metadata = obj["info"][0] is List ? obj["info"][0] as List : const <dynamic>[];
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
            );
            onMessage?.call(liveMsg);
          }
        }
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
          data: sc,
        );
        onMessage?.call(liveMsg);
      }
    } catch (e) {
      CoreLog.error(e);
    }
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
