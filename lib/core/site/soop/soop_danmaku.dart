import 'dart:async';
import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/modules/util/list_util.dart';

class DanmakuArgs {
  String url;
  String chatNo;

  DanmakuArgs({
    required this.url,
    required this.chatNo,
  });

  DanmakuArgs.fromJson(Map<String, dynamic> json)
      : url = json['url'] ?? '',
        chatNo = json['chatNo'] ?? '';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'chatNo': chatNo,
    };
  }
}

class SoopDanmaku implements LiveDanmaku {
  @override
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  // 常量定义
  final String f = "\x0c";
  final String esc = "\x1b\x09";
  final String separator = "+${"-" * 70}+";

  WebScoketUtils? webScoketUtils;
  late DanmakuArgs danmakuArgs;

  @override
  Future start(dynamic args) async {
    CoreLog.d("start");
    if (args == null) {
      onClose?.call("服务器连接失败");
      return;
    }
    danmakuArgs = args as DanmakuArgs;
    var site = Sites.of(Sites.soopSite);
    var liveSite = site.liveSite as SoopSite;
    var mHeaders = liveSite.getHeaders();
    mHeaders={
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      "Origin": "https://play.sooplive.co.kr",
    };

    // final wsUrl = 'wss://${liveInfo.chDomain}:${liveInfo.chpt}/Websocket/$bid';
    CoreLog.d("args: ${json.encode(args)}");
    webScoketUtils = WebScoketUtils(
      url: danmakuArgs.url,
      heartBeatTime: heartbeatTime,
      protocols: ['chat'],
      headers: mHeaders,
      onMessage: (e) {
        try {
          if (e.runtimeType == String) {
            return decodeMessageStr(e);
          }
          return decodeMessage(e);
        } catch (err) {
          CoreLog.w("$e");
          CoreLog.error(err);
        }
      },
      onReady: () {
        onReady?.call();
        joinRoom(danmakuArgs);
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

  Future<void> joinRoom(dynamic joinData) async {
    danmakuArgs = joinData as DanmakuArgs;
    final connectPacket = '${esc}000100000600${f * 3}16$f';
    webScoketUtils?.sendMessage(connectPacket);

    // 延迟发送加入数据包
    await Future.delayed(const Duration(seconds: 2));
    final joinPacket = '${esc}0002${_calculateByteSize(danmakuArgs.chatNo).toString().padLeft(6, '0')}00$f${danmakuArgs.chatNo}${f * 5}';
    webScoketUtils?.sendMessage(joinPacket);
  }

  // 计算字节长度
  int _calculateByteSize(String string) {
    return utf8.encode(string).length + 6;
  }

  @override
  void heartbeat() {
    final pingPacket = '${esc}000000000100$f';
    webScoketUtils?.sendMessage(pingPacket);
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessageStr(String data) {
    CoreLog.w("decodeMessageStr: $data");
  }

  void decodeMessage(List<int> data) {
    int s = 0x0c;
    var parts = ListUtil.splitList(data, s);
    final messages = parts.map((part) => utf8.decode(part)).toList();

    CoreLog.d("chat messages : \n $messages");

    if (messages.length > 5 && !['-1', '1'].contains(messages[1]) && !messages[1].contains('|')) {
      final comment = messages[1];
      // final userId = messages[2];
      final userName = messages[6];
      onMessage?.call(LiveMessage(
        type: LiveMessageType.chat,
        color: Colors.white,
        message: comment,
        userName: userName,
        // fansLevel: fansLevel,
        // fansName: fansName,
      ));
    }
  }
}
