import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pure_live/common/utils/color_util.dart';

import '../../common/binary_writer.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class DouyuDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 45 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;
  String serverUrl = "wss://danmuproxy.douyu.com:8506";

  WebScoketUtils? webScoketUtils;

  @override
  Future start(dynamic args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom(String roomId) {
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
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(List<int> data) {
    try {
      String? result = deserializeDouyu(data);
      if (result == null) {
        return;
      }
      var jsonData = sttToJObject(result);

      var type = jsonData["type"]?.toString();
      //斗鱼好像不会返回人气值
      //有些直播间存在阴间弹幕，不知道什么情况
      // CoreLog.d(jsonEncode(jsonData));
      if (type == "chatmsg") {
      // 屏蔽阴间弹幕

        if (jsonData["dms"] == null) {

          return;
        }

        // {"type":"chatmsg","rid":"9999","uid":"2000454","nn":"大沙河旁种柚子","txt":"煤气罐","cid":"c85cd4f3ebfb4558b4ba7a0000000000","ic":"avatar_v3/202302/6d3d5056ecd94f36b5848f23949bd1fb","level":"40","sahf":"0","col":"1","cst":"1736688217372","bnn":"小僵尸","bl":"25","brid":"9999","hc":"8ccfd113d28375263b0964c7221773bf","hl":"1","ifs":"1","lk":"","fl":"25","dms":"4","pdg":"52","pdk":"5","ext":"","if":"1"}
        // bnn 粉丝牌 bl 牌子等级 brid 牌子对应的直播间
        var col = int.tryParse(jsonData["col"].toString()) ?? 0;
        var liveMsg = LiveMessage(
          type: LiveMessageType.chat,
          userName: jsonData["nn"].toString(),
          message: jsonData["txt"].toString(),
          userLevel: jsonData["level"].toString(),
          fansName: jsonData["bnn"].toString(),
          fansLevel: jsonData["bl"].toString(),
          color: getColor(col),
        );

        onMessage?.call(liveMsg);
      } else if (type == "comm_chatmsg") {
        // 高能弹幕
        // {"type":"comm_chatmsg","tick":null,"res":null,"cmdEnum":null,"cmd":"comm_chatmsg","vrid":"1856171486511906816","btype":"voiceDanmu","chatmsg":{"nn":"King彡吖西","level":"14","type":"chatmsg","rid":"1126960","gag":"0","uid":"16751345","txt":"c桑又在赞elo了，上分给你玩明白了","hidenick":"0","nc":"0","ic":["avatar","016","75","13","45_avatar"],"nl":"0","tbid":"0","tbl":"0","tbvip":"0"},"range":"2","cprice":"3000","cmgType":"1","rid":"1126960","gbtemp":"2","uid":"16751345","crealPrice":"3000","cet":"60","now":"1731380814042","csuperScreen":"0","danmucr":"1"}
        // bnn 粉丝牌 bl 牌子等级 brid 牌子对应的直播间
        var chatMsg = jsonData["chatmsg"] ?? {};
        var col = int.tryParse(chatMsg["col"].toString()) ?? 0;
        var liveMsg = LiveMessage(
          type: LiveMessageType.superChat,
          userName: chatMsg["nn"].toString(),
          message: chatMsg["txt"].toString(),
          userLevel: chatMsg["level"].toString(),
          fansName: chatMsg["bnn"].toString(),
          fansLevel: chatMsg["bl"].toString(),
          color: getColor(col),
        );

        onMessage?.call(liveMsg);
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
    try {
      var reader = BinaryReader(Uint8List.fromList(buffer));
      int fullMsgLength = reader.readInt32(endian: Endian.little); //fullMsgLength
      reader.readInt32(endian: Endian.little); //fullMsgLength2
      int bodyLength = fullMsgLength - 9;
      reader.readShort(endian: Endian.little); //packType
      reader.readByte(endian: Endian.little); //encrypted
      reader.readByte(endian: Endian.little); //reserved

      var bytes = reader.readBytes(bodyLength);

      reader.readByte(endian: Endian.little); //固定为0
      return utf8.decode(bytes);
    } catch (e) {
      CoreLog.error(e);
      return null;
    }
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
        var tokens = field.split("@=");
        var k = tokens[0];
        var v = unscapeSlashAt(tokens[1]);
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

  Color getColor(int type) {
    switch (type) {
      case 1:
        return ColorUtil.fromRGB(255, 0, 0);
      case 2:
        return ColorUtil.fromRGB(30, 135, 240);
      case 3:
        return ColorUtil.fromRGB(122, 200, 75);
      case 4:
        return ColorUtil.fromRGB(255, 127, 0);
      case 5:
        return ColorUtil.fromRGB(155, 57, 244);
      case 6:
        return ColorUtil.fromRGB(255, 105, 180);
      default:
        return Colors.white;
    }
  }
}
