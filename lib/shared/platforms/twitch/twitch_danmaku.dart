import 'dart:math';
import 'dart:convert';

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/config/cookie_settings_controller.dart';

class TwitchDanmaku implements LiveDanmaku {
  WebScoketUtils? webScoketUtils;
  bool _connected = false;

  /// 登录被拒过：这次连接之后不再用这份登录（上游 B-7）。
  bool _loginRefused = false;
  bool _loginRefusedReported = false;

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
  Function(String msg)? onReconnect;

  @override
  Function(String msg)? onClose;

  @override
  Function(LiveMessage msg)? onMessage;

  @override
  Function()? onReady;

  @override
  void heartbeat() {
    webScoketUtils?.sendMessage("PING :tmi.twitch.tv");
  }

  @override
  Future start(args) async {
    // 每次进房重新开始：这次的连接重新用参数里的登录（上游 B-7）。
    _loginRefused = false;
    _loginRefusedReported = false;
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
        onReconnect?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call("服务器连接失败$e");
      },
    );
    await webScoketUtils?.connect();
  }

  void joinRoom(String roomId) {
    final cookie = CookieSettingsController.to.twitchCookie.v;
    final cookieValues = _parseCookie(cookie);
    final token = cookieValues['auth-token']?.trim() ?? '';
    final login = cookieValues['login']?.trim().toLowerCase() ?? '';
    final authenticated = token.isNotEmpty && login.isNotEmpty && !_loginRefused;
    final user = authenticated ? login : "justinfan${1000 + Random.secure().nextInt(99000)}";
    webScoketUtils
      ?..sendMessage(authenticated ? "PASS oauth:$token" : "PASS SCHMOOPIIE")
      ..sendMessage("NICK $user")
      ..sendMessage("CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership")
      ..sendMessage("JOIN #${roomId.trim().toLowerCase()}");
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
    onReconnect = null;
    onClose = null;
    await webScoketUtils?.close();
    webScoketUtils = null;
    markDisconnected();
  }

  void decodeMessage(String data) {
    try {
      if (data.startsWith("PING")) {
        // respond to PING according to https://dev.twitch.tv/docs/irc/#keepalive-messages
        webScoketUtils?.sendMessage(data.replaceFirst("PING", "PONG").trim());
      }
      // 登录被拒（`NOTICE ... Login authentication failed` / `Login unsuccessful`）：
      // 报一次用户提示，并让这次连接之后改用匿名（上游 B-7 候选 4：一次 connect 只说
      // 一次；下一次 connect 会重新用参数里的登录，再被拒就再说一次）。
      if (_isLoginRefusal(data)) {
        _loginRefused = true;
        if (!_loginRefusedReported) {
          _loginRefusedReported = true;
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.notice,
              userName: '',
              message: i18n('twitch_cookie_expired_notice'),
              color: LiveMessageColor.white,
            ),
          );
        }
        return;
      }
      for (final message in parseMessages(data)) {
        onMessage?.call(message);
      }
    } catch (e) {
      CoreLog.error(e);
    }
  }

  /// 这条 IRC 帧是不是"登录被拒"。Twitch 用 `NOTICE` 回这两句（大小写不敏感）。
  static bool _isLoginRefusal(String data) {
    if (!data.toUpperCase().contains('NOTICE')) return false;
    final text = data.toLowerCase();
    return text.contains('login authentication failed') || text.contains('login unsuccessful');
  }

  /// Parses complete Twitch IRC frames. Kept separate from socket delivery so
  /// reconnect, empty-color and escaped display-name cases stay testable.
  List<LiveMessage> parseMessages(String data) {
    final messages = <LiveMessage>[];
    for (final rawLine in data.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

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

      // 管理员删除单条（`CLEARMSG`）与禁言/封禁/清屏（`CLEARCHAT`）都是撤回
      // （上游 B-7）：按消息 id、按用户 id、清屏全部撤；只有登录名没有 id 的跳过
      // ——聊天里没有登录名，对不上，也绝不能当成清屏。
      if (line.contains(' CLEARMSG ')) {
        final targetId = (tags['target-msg-id'] ?? '').trim();
        if (targetId.isNotEmpty) messages.add(_retraction(LiveRetraction.message(targetId)));
        continue;
      }
      if (line.contains(' CLEARCHAT ')) {
        final targetUser = (tags['target-user-id'] ?? '').trim();
        if (targetUser.isNotEmpty) {
          messages.add(_retraction(LiveRetraction.user(targetUser)));
          continue;
        }
        final commandEnd = line.indexOf(' CLEARCHAT ');
        final paramStart = line.indexOf(' :', commandEnd);
        if (paramStart >= 0 && line.substring(paramStart + 2).trim().isNotEmpty) continue;
        messages.add(_retraction(const LiveRetraction.all()));
        continue;
      }

      if (!line.contains(' PRIVMSG ')) continue;

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

  static LiveMessage _retraction(LiveRetraction target) => LiveMessage(
    type: LiveMessageType.retraction,
    userName: '',
    message: '',
    color: LiveMessageColor.white,
    data: target,
  );

  static String _decodeTag(String value) => value
      .replaceAll(r'\s', ' ')
      .replaceAll(r'\:', ';')
      .replaceAll(r'\r', '\r')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\\', '\\');
}
