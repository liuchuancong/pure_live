import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/site/huya/huya_utils.dart';
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
  String serverUrl = "wss://wsapi.huya.com";

  WebScoketUtils? webScoketUtils;

  /// Current website heartbeat: `EWSCmdC2S_HeartBeatReq` (20).
  List<int> get heartbeatData {
    final command = TarsOutputStream();
    command.write(20, 0);
    command.write(Uint8List(0), 1);
    return command.toUint8List();
  }

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
        // Keep the new room-group connection alive immediately.
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
      final group = TarsOutputStream();
      group.write(<String>['live:$uid', 'chat:$uid'], 0);
      group.write('', 1);

      final command = TarsOutputStream();
      command.write(16, 0); // EWSCmdC2S_RegisterGroupReq
      command.write(group.toUint8List(), 1);
      return command.toUint8List();
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

  Future<void> decodeMessage(List<int> data) async {
    try {
      var stream = TarsInputStream(Uint8List.fromList(data));
      var type = stream.read(0, 0, false);
      if (type == 7) {
        stream = TarsInputStream(stream.readBytes(1, false));
        HYPushMessage wSPushMessage = HYPushMessage();
        wSPushMessage.readFrom(stream);
        await _decodePush(wSPushMessage.uri, wSPushMessage.msg);
      } else if (type == 22) {
        final push = HYPushMessageV2();
        push.readFrom(TarsInputStream(stream.readBytes(1, false)));
        for (final item in push.items) {
          await _decodePush(item.uri, item.msg, messageId: item.messageId);
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  Future<void> _decodePush(int uri, List<int> payload, {int messageId = 0}) async {
    if (uri == 1400) {
      final messageNotice = HYMessage();
      messageNotice.readFrom(TarsInputStream(Uint8List.fromList(payload)));
      final color = messageNotice.bulletFormat.fontColor;
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.chat,
          color: color <= 0 ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
          message: messageNotice.content,
          userName: messageNotice.userInfo.nickName,
          userId: messageNotice.userInfo.uid.toString(),
          messageId: messageId > 0 ? 'huya:$messageId' : '',
        ),
      );
    } else if (uri == 8006) {
      final attendeeCount = TarsInputStream(Uint8List.fromList(payload)).read(0, 0, false);
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.online,
          // Current website captures keep iAttendeeCount in the same
          // multi-million popularity range as the list value.
          data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.popularity, value: attendeeCount),
          color: LiveMessageColor.white,
          message: '',
          userName: '',
          messageId: messageId > 0 ? 'huya:$messageId' : '',
        ),
      );
    } else if (uri == 2001314) {
      var sc = await getHuyaSuperChatMessageList(lPid: danmakuArgs.topSid);
      if (sc.isNotEmpty) {
        onMessage?.call(
          LiveMessage(
            type: LiveMessageType.superChat,
            userName: "SUPER_CHAT_MESSAGE",
            message: "SUPER_CHAT_MESSAGE",
            color: LiveMessageColor.white,
            data: sc.first,
          ),
        );
      }
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

class HYPushMessageV2 extends TarsStruct {
  String groupId = '';
  List<HYMessageItem> items = <HYMessageItem>[];

  @override
  void readFrom(TarsInputStream inputStream) {
    groupId = inputStream.read(groupId, 0, false);
    items = inputStream.readList<HYMessageItem>(<HYMessageItem>[HYMessageItem()], 1, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(groupId, 0);
    outputStream.write(items, 1);
  }

  @override
  Object deepCopy() => HYPushMessageV2()
    ..groupId = groupId
    ..items = items.map((item) => item.deepCopy() as HYMessageItem).toList();

  @override
  void displayAsString(StringBuffer sb, int level) {}
}

class HYMessageItem extends TarsStruct {
  int uri = 0;
  List<int> msg = <int>[];
  int messageId = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    uri = inputStream.read(uri, 0, false);
    msg = inputStream.readBytes(1, false);
    messageId = inputStream.read(messageId, 2, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(uri, 0);
    outputStream.write(Uint8List.fromList(msg), 1);
    outputStream.write(messageId, 2);
  }

  @override
  Object deepCopy() => HYMessageItem()
    ..uri = uri
    ..msg = List<int>.from(msg)
    ..messageId = messageId;

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
