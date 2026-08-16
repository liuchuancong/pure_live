import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../common/binary_writer.dart';

import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:meta/meta.dart';

class DouyuDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;
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
  String serverUrl = "wss://danmuproxy.douyu.com:8506";

  WebScoketUtils? webScoketUtils;
  String _roomId = '';
  int _generation = 0;

  @visibleForTesting
  void debugSetRoomId(String roomId) => _roomId = roomId;

  @override
  Future start(dynamic args) async {
    final generation = ++_generation;
    await webScoketUtils?.close();
    webScoketUtils = null;
    if (generation != _generation) return;
    _roomId = args.toString();
    markDisconnected();
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        if (generation == _generation) decodeMessage(e);
      },
      onReady: () {
        if (generation != _generation) return;
        markConnected();
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        if (generation != _generation) return;
        markDisconnected();
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        if (generation != _generation) return;
        markDisconnected();
        onClose?.call("服务器连接失败$e");
      },
    );
    await webScoketUtils?.connect();
  }

  void joinRoom(dynamic roomId) {
    webScoketUtils?.sendMessage(serializeDouyu("type@=loginreq/roomid@=$roomId/"));
    webScoketUtils?.sendMessage(serializeDouyu("type@=joingroup/rid@=$roomId/gid@=-9999/"));
  }

  @override
  void heartbeat() {
    var data = serializeDouyu("type@=mrkl/");
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

  void decodeMessage(List<int> data) {
    try {
      for (final result in deserializeDouyuPackets(data)) {
        final jsonData = sttToJObject(result);
        if (jsonData is! Map) continue;

        var type = jsonData["type"]?.toString();
        //斗鱼好像不会返回人气值
        if (type == "chatmsg") {
          // 屏蔽阴间弹幕
          if (jsonData["dms"] == null) continue;
          final packetRoomId = jsonData['rid']?.toString() ?? '';
          if (packetRoomId.isNotEmpty && _roomId.isNotEmpty && packetRoomId != _roomId) continue;
          var col = int.tryParse(jsonData["col"].toString()) ?? 0;
          final rawTimestamp = int.tryParse(jsonData['cst']?.toString() ?? '');
          final sentAt = rawTimestamp == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(rawTimestamp > 100000000000 ? rawTimestamp : rawTimestamp * 1000);
          final messageId = jsonData['cid']?.toString() ?? '';
          var liveMsg = LiveMessage(
            type: LiveMessageType.chat,
            userName: jsonData["nn"].toString(),
            userId: jsonData['uid']?.toString() ?? '',
            message: jsonData["txt"].toString(),
            color: getColor(col),
            messageId: messageId.isEmpty ? '' : 'douyu:$messageId',
            sentAt: sentAt,
          );

          onMessage?.call(liveMsg);
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  List<int> serializeDouyu(String body) {
    try {
      const int clientSendToServer = 689;
      const int encrypted = 0;
      const int reserved = 0;

      List<int> buffer = utf8.encode(body);

      var writer = BinaryWriter([]);
      writer.writeInt(4 + 4 + body.length + 1, 4, endian: Endian.little);
      writer.writeInt(4 + 4 + body.length + 1, 4, endian: Endian.little);
      writer.writeInt(clientSendToServer, 2, endian: Endian.little);
      writer.writeInt(encrypted, 1, endian: Endian.little);
      writer.writeInt(reserved, 1, endian: Endian.little);
      writer.writeBytes(buffer);
      writer.writeInt(0, 1, endian: Endian.little);
      return writer.buffer;
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  String? deserializeDouyu(List<int> buffer) {
    final packets = deserializeDouyuPackets(buffer);
    return packets.isEmpty ? null : packets.first;
  }

  /// A single WebSocket frame often contains several Douyu protocol packets.
  /// Parsing only the first packet silently loses chat messages and can leave
  /// the UI looking frozen during busy rooms.
  List<String> deserializeDouyuPackets(List<int> buffer) {
    final packets = <String>[];
    try {
      var offset = 0;
      while (offset + 12 <= buffer.length) {
        final header = ByteData.sublistView(Uint8List.fromList(buffer), offset, offset + 4);
        final fullMsgLength = header.getUint32(0, Endian.little);
        final frameLength = fullMsgLength + 4;
        final bodyLength = fullMsgLength - 9;
        if (fullMsgLength < 9 || bodyLength < 0 || offset + frameLength > buffer.length) break;
        final bodyStart = offset + 12;
        final bodyEnd = bodyStart + bodyLength;
        packets.add(utf8.decode(buffer.sublist(bodyStart, bodyEnd), allowMalformed: true));
        offset += frameLength;
      }
    } catch (e) {
      CoreLog.error(e);
    }
    return packets;
  }

  //辣鸡STT
  dynamic sttToJObject(String str) {
    if (str.contains("//")) {
      var result = [];
      for (var field in str.split("//")) {
        if (field.isEmpty) {
          continue;
        }
        result.add(sttToJObject(field));
      }
      return result;
    }
    if (str.contains("@=")) {
      var result = {};
      for (var field in str.split('/')) {
        if (field.isEmpty) {
          continue;
        }
        final separator = field.indexOf("@=");
        if (separator <= 0) continue;
        var k = field.substring(0, separator);
        var v = unscapeSlashAt(field.substring(separator + 2));
        result[k] = sttToJObject(v);
      }
      return result;
    } else if (str.contains("@A=")) {
      return sttToJObject(unscapeSlashAt(str));
    } else {
      return unscapeSlashAt(str);
    }
  }

  String unscapeSlashAt(String str) {
    return str.replaceAll("@S", "/").replaceAll("@A", "@");
  }

  LiveMessageColor getColor(int type) {
    switch (type) {
      case 1:
        return LiveMessageColor(255, 0, 0);
      case 2:
        return LiveMessageColor(30, 135, 240);
      case 3:
        return LiveMessageColor(122, 200, 75);
      case 4:
        return LiveMessageColor(255, 127, 0);
      case 5:
        return LiveMessageColor(155, 57, 244);
      case 6:
        return LiveMessageColor(255, 105, 180);
      default:
        return LiveMessageColor.white;
    }
  }
}
