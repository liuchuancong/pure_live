import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:meta/meta.dart';
import '../common/binary_writer.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';




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
  // ignore: unused_field
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
    for (final result in deserializeDouyuPackets(data)) {
      try {
        final jsonData = sttToJObject(result);
        if (jsonData is! Map) continue;

        final type = jsonData["type"]?.toString();
        LiveMessage? liveMsg;
        if (type == "chatmsg") {
          // Current packets mark visible chat with `dms`; older packets can
          // instead carry the fan flag. Rejecting every packet without `if=1`
          // dropped ordinary audience chat after the super-chat merge.
          if (jsonData["dms"] == null && jsonData["if"]?.toString() != '1') continue;
          final packetRoomId = jsonData['rid']?.toString() ?? '';
          if (packetRoomId.isNotEmpty && _roomId.isNotEmpty && packetRoomId != _roomId) continue;
          final col = int.tryParse(jsonData["col"]?.toString() ?? '') ?? 0;
          final rawTimestamp = int.tryParse(jsonData['cst']?.toString() ?? '');
          final sentAt = rawTimestamp == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(rawTimestamp > 100000000000 ? rawTimestamp : rawTimestamp * 1000);
          final messageId = jsonData['cid']?.toString() ?? '';
          liveMsg = LiveMessage(
            type: LiveMessageType.chat,
            userName: jsonData["nn"]?.toString() ?? '',
            userId: jsonData['uid']?.toString() ?? '',
            message: jsonData["txt"]?.toString() ?? '',
            color: getColor(col),
            messageId: messageId.isEmpty ? '' : 'douyu:$messageId',
            sentAt: sentAt,
          );
        } else if (type == "comm_chatmsg") {
          liveMsg = _parseCommonSuperChat(jsonData);
        } else if (type == "voice_trlt") {
          liveMsg = _parseVoiceSuperChat(jsonData);
        }
        if (liveMsg != null) onMessage?.call(liveMsg);
      } catch (e) {
        // One malformed packet must not discard the valid packets coalesced
        // after it in the same WebSocket frame.
        CoreLog.error("Douyu packet parse failed: $e");
      }
    }
  }

  LiveMessage? _parseCommonSuperChat(Map jsonData) {
    final chat = jsonData["chatmsg"];
    final now = int.tryParse(jsonData["now"]?.toString() ?? '');
    final duration = int.tryParse(jsonData["cet"]?.toString() ?? '');
    final rawPrice = int.tryParse(jsonData["cprice"]?.toString() ?? '');
    if (chat is! Map || now == null || duration == null || rawPrice == null) return null;
    final face = chat["ic"]?.toString() ?? '';
    final startTime = DateTime.fromMillisecondsSinceEpoch(now);
    final superChat = LiveSuperChatMessage(
      backgroundBottomColor: "#292a60",
      backgroundColor: "#c1c1ff",
      endTime: startTime.add(Duration(seconds: duration)),
      face: face.isEmpty ? '' : "https://apic.douyucdn.cn/upload/${face}_small.jpg",
      message: chat["txt"]?.toString() ?? '',
      price: rawPrice ~/ 100,
      startTime: startTime,
      userName: chat["nn"]?.toString() ?? '',
    );
    return _superChatMessage(superChat);
  }

  LiveMessage? _parseVoiceSuperChat(Map jsonData) {
    final list = jsonData["list"];
    if (list is! List || list.isEmpty || list.first is! Map) return null;
    final scData = list.first as Map;
    final endSeconds = int.tryParse(scData["etime"]?.toString() ?? '');
    final startSeconds = int.tryParse(scData["acptime"]?.toString() ?? '');
    final rawPrice = int.tryParse(scData["realPrice"]?.toString() ?? '');
    if (endSeconds == null || startSeconds == null || rawPrice == null) return null;
    final avatars = scData["uat"];
    final avatar = avatars is List && avatars.length > 1 ? avatars[1].toString() : '';
    final superChat = LiveSuperChatMessage(
      backgroundBottomColor: "#246488",
      backgroundColor: "#ffffff",
      endTime: DateTime.fromMillisecondsSinceEpoch(endSeconds * 1000),
      face: avatar.isEmpty ? '' : "https://$avatar",
      message: scData["content"]?.toString() ?? '',
      price: rawPrice ~/ 100,
      startTime: DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000),
      userName: scData["un"]?.toString() ?? '',
    );
    return _superChatMessage(superChat);
  }

  LiveMessage _superChatMessage(LiveSuperChatMessage data) {
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: "SUPER_CHAT_MESSAGE",
      message: "SUPER_CHAT_MESSAGE",
      color: LiveMessageColor.white,
      data: data,
    );
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

  /// One WebSocket frame commonly carries several complete Douyu packets.
  /// Iterate by each packet's own length instead of silently dropping every
  /// packet after the first.
  List<String> deserializeDouyuPackets(List<int> buffer) {
    final packets = <String>[];
    try {
      final bytes = Uint8List.fromList(buffer);
      var offset = 0;
      while (offset + 12 <= bytes.length) {
        final header = ByteData.sublistView(bytes, offset, offset + 4);
        final fullMsgLength = header.getUint32(0, Endian.little);
        final frameLength = fullMsgLength + 4;
        final bodyLength = fullMsgLength - 9;
        if (fullMsgLength < 9 || bodyLength < 0 || offset + frameLength > bytes.length) break;
        final bodyStart = offset + 12;
        final bodyEnd = bodyStart + bodyLength;
        packets.add(utf8.decode(bytes.sublist(bodyStart, bodyEnd), allowMalformed: true));
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
