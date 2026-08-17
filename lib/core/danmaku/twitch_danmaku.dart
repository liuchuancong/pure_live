import 'dart:math';
import 'dart:convert';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class TwitchDanmaku implements LiveDanmaku {
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

  @override
  int heartbeatTime = 40 * 1000; //默认是40s

  var serverUrl = "wss://irc-ws.chat.twitch.tv";

  @override
  Function(String msg)? onClose;

  @override
  Function(LiveMessage msg)? onMessage;

  @override
  Function()? onReady;

  @override
  void heartbeat() {
    // 发送心跳包
    var data = utf8.encode("PONG :tmi.twitch.tv");
    webScoketUtils?.sendMessage(data);
  }

  @override
  Future start(args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e);
      },
      onReady: () {
        onReady?.call();
        markConnected();
        joinRoom(args);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        markDisconnected();
        onClose?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call("服务器连接失败$e");
      },
    );
    webScoketUtils?.connect();
  }

  void joinRoom(String roomId) {
    var user = "justinfan${1000 + Random().nextInt(99999 - 1000 + 1)}";
    webScoketUtils
      ?..sendMessage("CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership")
      ..sendMessage("PASS SCHMOOPIIE")
      ..sendMessage("NICK $user")
      ..sendMessage("USER $user 8 * :$user")
      ..sendMessage("JOIN #$roomId");
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    webScoketUtils?.close();
  }

  void decodeMessage(String data) {
    try {
      var message = data;

      if (message.startsWith("PING")) {
        // respond to PING according to https://dev.twitch.tv/docs/irc/#keepalive-messages
        webScoketUtils?.sendMessage(message.replaceFirst("PING", "PONG"));
      }

      if (!message.contains("PRIVMSG")) {}

      final lines = message.split('\n');
      for (final d in lines) {
        final contentMatch = RegExp(r"PRIVMSG [^:]+:(.+)").firstMatch(d);
        final nameMatch = RegExp(r"display-name=([^;]+);").firstMatch(d);
        final colorMatch = RegExp(r"color=#([a-zA-Z0-9]{6});").firstMatch(d);

        if (contentMatch != null && nameMatch != null && colorMatch != null) {
          final liveMsg = LiveMessage(
            type: LiveMessageType.chat,
            message: contentMatch.group(1) ?? "",
            userName: nameMatch.group(1) ?? "",
            color: LiveMessageColor.numberToColor(int.parse(colorMatch.group(1) ?? "FFFFFF", radix: 16)),
          );
          onMessage?.call(liveMsg);
        }
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }
}
