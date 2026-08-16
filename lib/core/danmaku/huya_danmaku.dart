import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';

// ignore_for_file: no_leading_underscores_for_local_identifiers

class HuyaDanmakuArgs {
  final int uid;
  final int topSid;
  final int subSid;
  HuyaDanmakuArgs({required this.uid, required this.topSid, required this.subSid});
  @override
  String toString() {
    return json.encode({"uid": uid, "topSid": topSid, "subSid": subSid});
  }
}

class HuyaDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 60 * 1000;
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
  String serverUrl = "wss://cdnws.api.huya.com";

  WebScoketUtils? webScoketUtils;

  /// Current Huya `OnUserHeartBeat` packet.
  ///
  /// The former short packet is still accepted by the WebSocket handshake but
  /// no longer keeps the room subscription alive on the current gateway.
  final heartbeatData = <int>[
    0x00,
    0x03,
    0x1d,
    0x00,
    0x00,
    0x69,
    0x00,
    0x00,
    0x00,
    0x69,
    0x10,
    0x03,
    0x2c,
    0x3c,
    0x4c,
    0x56,
    0x08,
    0x6f,
    0x6e,
    0x6c,
    0x69,
    0x6e,
    0x65,
    0x75,
    0x69,
    0x66,
    0x0f,
    0x4f,
    0x6e,
    0x55,
    0x73,
    0x65,
    0x72,
    0x48,
    0x65,
    0x61,
    0x72,
    0x74,
    0x42,
    0x65,
    0x61,
    0x74,
    0x7d,
    0x00,
    0x00,
    0x3c,
    0x08,
    0x00,
    0x01,
    0x06,
    0x04,
    0x74,
    0x52,
    0x65,
    0x71,
    0x1d,
    0x00,
    0x00,
    0x2f,
    0x0a,
    0x0a,
    0x0c,
    0x16,
    0x00,
    0x26,
    0x00,
    0x36,
    0x07,
    0x61,
    0x64,
    0x72,
    0x5f,
    0x77,
    0x61,
    0x70,
    0x46,
    0x00,
    0x0b,
    0x12,
    0x03,
    0xae,
    0xf0,
    0x0f,
    0x22,
    0x03,
    0xae,
    0xf0,
    0x0f,
    0x3c,
    0x42,
    0x6d,
    0x52,
    0x02,
    0x60,
    0x5c,
    0x60,
    0x01,
    0x7c,
    0x82,
    0x00,
    0x0b,
    0xb0,
    0x1f,
    0x9c,
    0xac,
    0x0b,
    0x8c,
    0x98,
    0x0c,
    0xa8,
    0x0c,
    0x20,
  ];

  late HuyaDanmakuArgs danmakuArgs;
  int _generation = 0;

  @override
  Future start(dynamic args) async {
    final generation = ++_generation;
    await webScoketUtils?.close();
    webScoketUtils = null;
    if (generation != _generation) return;
    danmakuArgs = args as HuyaDanmakuArgs;
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
        joinRoom();
        // Request the first room statistic immediately. Waiting for the
        // 60-second periodic tick keeps the UI on the fallback heat value for
        // a full minute even though the socket is already ready.
        heartbeat();
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

  void joinRoom() {
    var joinData = getJoinData(danmakuArgs.uid);
    webScoketUtils?.sendMessage(joinData);
  }

  List<int> getJoinData(int uid) {
    try {
      var oos = TarsOutputStream();
      oos.write(uid, 0);
      oos.write(false, 1);
      oos.write("", 2);
      oos.write("", 3);
      oos.write(0, 4);
      oos.write(0, 5);
      oos.write(uid, 6);
      oos.write(3, 7);

      var wscmd = TarsOutputStream();
      wscmd.write(1, 0);
      wscmd.write(oos.toUint8List(), 1);
      return wscmd.toUint8List();
    } catch (e) {
      CoreLog.error(e);
      return [];
    }
  }

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage(heartbeatData);
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
      var stream = TarsInputStream(Uint8List.fromList(data));
      var type = stream.read(0, 0, false);
      if (type == 7) {
        stream = TarsInputStream(stream.readBytes(1, false));
        HYPushMessage wSPushMessage = HYPushMessage();
        wSPushMessage.readFrom(stream);
        if (wSPushMessage.uri == 1400) {
          HYMessage messageNotice = HYMessage();
          messageNotice.readFrom(TarsInputStream(Uint8List.fromList(wSPushMessage.msg)));
          var uname = messageNotice.userInfo.nickName;
          var content = messageNotice.content;

          var color = messageNotice.bulletFormat.fontColor;

          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.chat,
              color: color <= 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
              message: content,
              userName: uname,
              userId: messageNotice.userInfo.uid.toString(),
            ),
          );
        } else if (wSPushMessage.uri == 8006) {
          int online = 0;
          var s = TarsInputStream(Uint8List.fromList(wSPushMessage.msg));
          online = s.read(online, 0, false);
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: online,
              color: LiveMessageColor.white,
              message: "",
              userName: "",
            ),
          );
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }
}

class HYPushMessage extends TarsStruct {
  int pushType = 0;
  int uri = 0;
  List<int> msg = <int>[];
  int protocolType = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    pushType = inputStream.read(pushType, 0, false);
    uri = inputStream.read(uri, 1, false);
    msg = inputStream.readBytes(2, false);
    protocolType = inputStream.read(protocolType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {}

  @override
  Object deepCopy() {
    return HYPushMessage()
      ..pushType = pushType
      ..uri = uri
      ..msg = List<int>.from(msg)
      ..protocolType = protocolType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYSender extends TarsStruct {
  int uid = 0;
  int lMid = 0;
  String nickName = "";
  int gender = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    uid = inputStream.read(uid, 0, false);
    lMid = inputStream.read(lMid, 0, false);
    nickName = inputStream.read(nickName, 2, false);
    gender = inputStream.read(gender, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {}

  @override
  Object deepCopy() {
    return HYSender()
      ..uid = uid
      ..lMid = lMid
      ..nickName = nickName
      ..gender = gender;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYMessage extends TarsStruct {
  HYSender userInfo = HYSender();
  String content = "";
  HYBulletFormat bulletFormat = HYBulletFormat();

  @override
  void readFrom(TarsInputStream inputStream) {
    userInfo = inputStream.readTarsStruct(userInfo, 0, false) as HYSender;
    content = inputStream.read(content, 3, false);
    bulletFormat = inputStream.readTarsStruct(bulletFormat, 6, false) as HYBulletFormat;
  }

  @override
  void writeTo(TarsOutputStream outputStream) {}

  @override
  Object deepCopy() {
    return HYMessage()
      ..userInfo = userInfo.deepCopy() as HYSender
      ..content = content
      ..bulletFormat = bulletFormat.deepCopy() as HYBulletFormat;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYBulletFormat extends TarsStruct {
  int fontColor = 0;
  int fontSize = 4;
  int textSpeed = 0;
  int transitionType = 1;

  @override
  void readFrom(TarsInputStream inputStream) {
    fontColor = inputStream.read(fontColor, 0, false);
    fontSize = inputStream.read(fontSize, 1, false);
    textSpeed = inputStream.read(textSpeed, 2, false);
    transitionType = inputStream.read(transitionType, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {}

  @override
  Object deepCopy() {
    return HYBulletFormat()
      ..fontColor = fontColor
      ..fontSize = fontSize
      ..textSpeed = textSpeed
      ..transitionType = transitionType;
  }

  @override
  void displayAsString(StringBuffer sb, int level) {}
}
