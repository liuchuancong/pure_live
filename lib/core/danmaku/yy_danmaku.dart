import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/utils/yy/buffer_parser.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class YyDanmakuArgs {
  final int topSid;
  final int subSid;

  YyDanmakuArgs({required this.topSid, required this.subSid});

  @override
  String toString() {
    return json.encode({'topSid': topSid, 'subSid': subSid});
  }
}

class YyDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 5 * 1000;

  @override
  Function(String msg)? onClose;

  @override
  Function(LiveMessage msg)? onMessage;

  @override
  Function()? onReady;

  WebScoketUtils? webScoketUtils;

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

  final String appId = 'yymwebh5';
  final String appVersion = '3.2.10';

  final String uuid = const Uuid().v1();

  late YyDanmakuArgs danmakuArgs;

  int _generation = 0;

  String get serverUrl =>
      'wss://h5-sinchl.yy.com/websocket'
      '?appid=$appId'
      '&version=$appVersion'
      '&uuid=$uuid';

  @override
  Future start(dynamic args) async {
    final generation = ++_generation;
    await webScoketUtils?.close();
    webScoketUtils = null;
    if (generation != _generation) {
      return;
    }
    danmakuArgs = args as YyDanmakuArgs;
    markDisconnected();
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36',
      'Origin': 'https://www.yy.com',
    };
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      headers: headers,
      onMessage: (e) {
        if (generation != _generation) {
          return;
        }

        decodeMessage(e);
      },
      onReady: () {
        if (generation != _generation) {
          return;
        }

        markConnected();

        onReady?.call();

        joinRoom();

        heartbeat();
      },
      onHeartBeat: () {
        if (generation != _generation) {
          return;
        }

        heartbeat();
      },
      onReconnect: () {
        if (generation != _generation) {
          return;
        }

        markDisconnected();

        onClose?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (e) {
        if (generation != _generation) {
          return;
        }

        markDisconnected();

        onClose?.call('服务器连接失败$e');
      },
    );

    await webScoketUtils?.connect();
  }

  void joinRoom() {
    final data = _buildJoinChannelPacket();

    if (data != null) {
      webScoketUtils?.sendMessage(data);
    }
  }

  Uint8List? _buildJoinChannelPacket() {
    try {
      const uid = 0;

      final topSid = danmakuArgs.topSid;
      final subSid = danmakuArgs.subSid;

      const bufferSize = 256;

      final buffer = Uint8List(bufferSize);

      final byteData = ByteData.view(buffer.buffer);

      var offset = 0;

      // 协议头
      byteData.setUint32(offset, 0x10000001, Endian.little);
      offset += 4;

      // 加入频道指令
      byteData.setUint32(offset, 3104100, Endian.little);
      offset += 4;

      // 保留
      byteData.setUint16(offset, 0, Endian.little);
      offset += 2;

      // uid
      byteData.setUint32(offset, uid, Endian.little);
      offset += 4;

      // topSid
      byteData.setUint32(offset, topSid, Endian.little);
      offset += 4;

      // subSid
      byteData.setUint32(offset, subSid, Endian.little);
      offset += 4;

      // client type
      byteData.setUint32(offset, 10, Endian.little);
      offset += 4;

      // version
      final versionBytes = utf8.encode(appVersion);

      byteData.setUint16(offset, versionBytes.length, Endian.little);
      offset += 2;

      buffer.setAll(offset, versionBytes);

      offset += versionBytes.length;

      // uuid
      final uuidBytes = utf8.encode(uuid);

      byteData.setUint16(offset, uuidBytes.length, Endian.little);

      offset += 2;

      buffer.setAll(offset, uuidBytes);

      offset += uuidBytes.length;

      // 扩展字段
      byteData.setUint32(offset, 0, Endian.little);

      offset += 4;

      return buffer.sublist(0, offset);
    } catch (e) {
      CoreLog.error('YY 构造加入频道协议包异常：$e');

      return null;
    }
  }

  @override
  void heartbeat() {
    final data = <int>[0x0e00, 0x0000, 0x041e, 0x0c00, 0xc800, 0x0000, 0x0000];

    webScoketUtils?.sendMessage(data);
  }

  @override
  Future stop() async {
    _generation++;

    markDisconnected();

    onMessage = null;
    onClose = null;
    onReady = null;

    await webScoketUtils?.close();

    webScoketUtils = null;
  }

  void decodeMessage(Uint8List data) {
    try {
      final parser = BufferParser(data);

      // header
      parser.getUI32();

      // uri
      final ruri = parser.getUI32();

      // reserved
      parser.getUI16();

      switch (ruri) {
        case 3104600:
          _parseDanmu(parser);
          break;
      }
    } catch (e) {
      CoreLog.error('YY decodeMessage error: $e');
    }
  }

  void _parseDanmu(BufferParser parser) {
    try {
      parser.getUI32();
      parser.getUI32();
      parser.getUI32();

      final nick = parser.getUTF8();

      final msg = parser.getUTF8();

      onMessage?.call(
        LiveMessage(type: LiveMessageType.chat, message: msg, userName: nick, color: LiveMessageColor.white),
      );
    } catch (e) {
      CoreLog.error('YY parse danmaku error: $e');
    }
  }
}
