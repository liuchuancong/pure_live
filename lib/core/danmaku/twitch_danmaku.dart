import 'dart:math';
import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
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

  var serverUrl = 'wss://irc-ws.chat.twitch.tv';

  @override
  Function(String msg)? onClose;

  @override
  Function(LiveMessage msg)? onMessage;

  @override
  Function()? onReady;

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage('PING :tmi.twitch.tv');
  }

  @override
  Future start(args) async {
    webScoketUtils = WebScoketUtils(
      url: serverUrl,
      heartBeatTime: heartbeatTime,
      onMessage: (e) {
        decodeMessage(e is String ? e : utf8.decode(e as List<int>, allowMalformed: true));
      },
      onReady: () {
        markConnected();
        joinRoom(args.toString());
        onReady?.call();
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        markDisconnected();
        onClose?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call('服务器连接失败$e');
      },
    );
    await webScoketUtils?.connect();
  }

  void joinRoom(String roomId) {
    final cookie = SettingsService.to.cookieManager.twitchCookie.v;
    final cookieValues = _parseCookie(cookie);
    final token = cookieValues['auth-token']?.trim() ?? '';
    final login = cookieValues['login']?.trim().toLowerCase() ?? '';
    final authenticated = token.isNotEmpty && login.isNotEmpty;
    final user = authenticated ? login : 'justinfan${1000 + Random.secure().nextInt(99000)}';
    webScoketUtils
      ?..sendMessage(authenticated ? 'PASS oauth:$token' : 'PASS SCHMOOPIIE')
      ..sendMessage('NICK $user')
      ..sendMessage('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership')
      ..sendMessage('JOIN #${roomId.trim().toLowerCase()}');
  }

  static Map<String, String> _parseCookie(String cookie) {
    final result = <String, String>{};
    for (final part in cookie.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      result[part.substring(0, separator).trim()] = part.substring(separator + 1).trim();
    }
    return result;
  }

  @override
  Future stop() async {
    onMessage = null;
    onClose = null;
    await webScoketUtils?.close();
    webScoketUtils = null;
    markDisconnected();
  }

  void decodeMessage(String data) {
    try {
      if (data.startsWith('PING')) {
        // respond to PING according to https://dev.twitch.tv/docs/irc/#keepalive-messages
        webScoketUtils?.sendMessage(data.replaceFirst('PING', 'PONG').trim());
      }
      for (final message in parseMessages(data)) {
        onMessage?.call(message);
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  /// Parses complete Twitch IRC frames. Kept separate from socket delivery so
  /// reconnect, empty-color and escaped display-name cases stay testable.
  List<LiveMessage> parseMessages(String data) {
    final messages = <LiveMessage>[];
    for (final rawLine in data.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (!line.contains(' PRIVMSG ')) continue;

      final tags = <String, String>{};
      if (line.startsWith('@')) {
        final tagEnd = line.indexOf(' ');
        if (tagEnd > 1) {
          for (final entry in line.substring(1, tagEnd).split(';')) {
            final separator = entry.indexOf('=');
            if (separator < 0) continue;
            tags[entry.substring(0, separator)] = _decodeTag(entry.substring(separator + 1));
          }
        }
      }

      final messageStart = line.indexOf(' :', line.indexOf(' PRIVMSG '));
      if (messageStart < 0) continue;
      final content = line.substring(messageStart + 2);
      final prefixMatch = RegExp(r' :?([^! ]+)!').firstMatch(line);
      final userName = (tags['display-name']?.trim().isNotEmpty ?? false)
          ? tags['display-name']!.trim()
          : (prefixMatch?.group(1) ?? 'Twitch');
      final colorText = (tags['color'] ?? '').replaceFirst('#', '');
      final colorValue = int.tryParse(colorText, radix: 16) ?? 0xFFFFFF;
      final timestamp = int.tryParse(tags['tmi-sent-ts'] ?? '');

      messages.add(
        LiveMessage(
          type: LiveMessageType.chat,
          message: content,
          userName: userName,
          userId: tags['user-id'] ?? '',
          messageId: tags['id'] ?? '',
          sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
          color: LiveMessageColor.numberToColor(colorValue),
        ),
      );
    }
    return messages;
  }

  static String _decodeTag(String value) => value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', '\\');
}
