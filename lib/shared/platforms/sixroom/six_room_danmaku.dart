import 'dart:async';
import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

/// 六间房的弹幕参数（上游 M5.27）：`userId` 是主播的用户 id（网页的 `page.rid`，
/// 决定聊天服务器、也是登录的 `roomid`）；`roomId` 是房间号，只用作取服务器列表的
/// Referer。进房时放进 `danmakuData`，不多发请求。
class SixRoomDanmakuArgs {
  const SixRoomDanmakuArgs({required this.roomId, required this.userId});

  final String roomId;
  final String userId;
}

/// 六间房的聊天（上游 M5.27）：房间页的私有聊天 socket，按网页对游客的做法匿名加入。
///
/// - `GET /room/getChat.php?rid=<主播用户 id>` 取 `*.6rooms.com` 的服务器列表，
///   逐个尝试（服务端每次打乱顺序）；响应体是 JSON 但 mime 报的是 `text/html`，
///   所以按文本取回来自己解（见 [parseChatServers]）
/// - 打开后发 `command=login`（`uid` 是 1800000000～1899999999 的随机游客号，
///   `encpass` 为空，`roomid` 是主播的用户 id）；6 秒没等到 `login.success` 换下一台
/// - 登录成功后 1 秒开始、之后每 16 秒发网页的 `noop` 心跳
/// - 下行是 `enc=yes|no` + `command=receivemessage` + Base64；`enc=yes` 是原始 DEFLATE
///   （Base64 里 `+ / =` 写成 `( ) @`），解出 JSON 后按 `typeID` 取公聊（101、110、
///   1413 列表）与飞屏（108）
/// - 网页会直接停掉 socket 的 flag（被踢/人满/付费房/密码房/禁止/关房…）以失败结束，
///   不重连
class SixRoomDanmaku extends LiveDanmaku {
  SixRoomDanmaku();

  static const String _origin = 'https://v.6.cn';

  /// 网页会停掉 socket、不再重连的 flag（被踢、人满、付费、密码、禁言/移出、关房…）。
  static const Set<String> _terminalFlags = <String>{
    '101',
    '102',
    '103',
    '104',
    '109',
    '110',
    '111',
    '112',
    '113',
    '114',
    '204',
    '305',
    '306',
  };

  SixRoomDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _guestId = 0;
  var _loggedIn = false;
  Timer? _heartbeat;
  Timer? _loginDeadline;
  final List<String> _servers = <String>[];

  @override
  Future start(dynamic args) async {
    if (args is! SixRoomDanmakuArgs || args.userId.trim().isEmpty) {
      onClose?.call('六间房：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _guestId = 1800000000 + Random.secure().nextInt(100000000);
    // 游客号每次 connect 生成一个（同一次连接里的重连沿用）。
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _heartbeat?.cancel();
    _loginDeadline?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        if (_servers.isEmpty) await _refreshServers(generation);
        if (!_running || generation != _generation) return;
        if (_servers.isEmpty) throw StateError('六间房：没有取到聊天服务器');
        final server = _servers[attempt % _servers.length];
        await _joinServer(server, generation);
        attempt++;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('Six Rooms chat failed: $error');
        onReconnect?.call('六间房弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _refreshServers(int generation) async {
    final rid = _args?.userId ?? '';
    final body = await HttpClient.instance.getText(
      '$_origin/room/getChat.php',
      queryParameters: <String, String>{'rid': rid},
      header: _headers(),
    );
    if (generation != _generation) return;
    final servers = parseChatServers(body);
    _servers
      ..clear()
      ..addAll(servers);
  }

  /// `getChat.php` 的响应体 → `*.6rooms.com:<port>` 聊天服务器列表。
  ///
  /// 入参是**文本**：这个接口回的是 `Content-Type: text/html; charset=UTF-8`，
  /// 而 dio 只在 JSON mime 下才解码，所以 `getJson` 拿到的一直是字符串。曾经这里
  /// 问的是 `response is Map`——永远为假，服务器列表永远是空的，弹幕于是永远停在
  /// "连接失败，正在重试"。解码放在这里而不是依赖 HTTP 层的 mime 判断，就是这个
  /// 坑的栅栏（`sixroom_danmaku_servers_test.dart` 用真实响应头钉住它）。
  ///
  /// 端口按主播不同（实测 5490 / 5590 / 5690），服务端每次还会打乱顺序，所以
  /// 列表要按房间取、按顺序轮询。坏响应直接抛给 `_loop` 重试，比静默返回空列表
  /// 诚实。
  @visibleForTesting
  static List<String> parseChatServers(String body) {
    final response = json.decode(body);
    final websock = response is Map ? response['websock'] : null;
    if (websock is! List) return const <String>[];
    final servers = <String>[];
    for (final entry in websock) {
      final value = entry?.toString().trim() ?? '';
      final separator = value.lastIndexOf(':');
      if (separator <= 0) continue;
      final host = value.substring(0, separator).toLowerCase();
      final port = int.tryParse(value.substring(separator + 1));
      if (port == null || port <= 0 || port > 65535) continue;
      if (host != '6rooms.com' && !host.endsWith('.6rooms.com')) continue;
      if (servers.contains(value)) continue;
      servers.add(value);
    }
    return servers;
  }

  Future<void> _joinServer(String server, int generation) async {
    final ended = Completer<void>();
    _loggedIn = false;
    final socket = WebScoketUtils(
      url: 'wss://$server',
      heartBeatTime: 0,
      headers: _headers(),
      onReady: () {
        if (generation != _generation) return;
        _sendLogin();
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true));
      },
      onReconnect: () {
        if (generation != _generation) return;
        markDisconnected();
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (error) {
        if (generation != _generation) return;
        markDisconnected();
        if (!ended.isCompleted) ended.complete();
      },
    );
    _socket = socket;
    await socket.connect();
    // 登录时限 6 秒：没等到 login.success 就换下一个服务器。
    _loginDeadline = Timer(const Duration(seconds: 6), () {
      if (generation != _generation || _loggedIn) return;
      if (!ended.isCompleted) ended.complete();
    });
    await ended.future;
    _heartbeat?.cancel();
    _loginDeadline?.cancel();
  }

  void _sendLogin() {
    final userId = _args?.userId ?? '';
    _socket?.sendMessage('command=login\r\nuid=$_guestId\r\nencpass=\r\nroomid=$userId\r\n');
  }

  void _handleFrame(String data) {
    final fields = _explode(data);
    final command = fields['command'] ?? '';
    if (command == 'result') {
      final content = fields['content'] ?? '';
      if (content == 'login.success') {
        _loggedIn = true;
        markConnected();
        onReady?.call();
        _loginDeadline?.cancel();
        // 登录成功后 1 秒开始心跳，之后每 16 秒一次。
        _heartbeat?.cancel();
        _heartbeat = Timer(const Duration(seconds: 1), () => _startHeartbeat());
      } else if (content == 'login.failed') {
        onReconnect?.call('六间房登录失败，正在换服务器重试');
      }
      return;
    }
    if (command != 'receivemessage') return;
    final payload = _decodePayload(fields);
    if (payload == null) return;
    final flag = payload['flag']?.toString() ?? '';
    if (flag != '001') {
      // 错误：`content` 是说明文字；网页会停掉 socket 的 flag 直接结束。
      if (_terminalFlags.contains(flag)) {
        onClose?.call('六间房聊天被拒绝：flag $flag');
      }
      return;
    }
    _reportMessages(payload['content'], depth: 0);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    // 网页的 `noop` 心跳（`y8vPLwAA` 就是 "noop" 压缩编码后的样子）。
    _socket?.sendMessage('command=sendmessage\r\ncontent=y8vPLwAA\r\n');
    _heartbeat = Timer.periodic(const Duration(seconds: 16), (_) {
      _socket?.sendMessage('command=sendmessage\r\ncontent=y8vPLwAA\r\n');
    });
  }

  /// 按 `typeID` 取公聊（101、110/1413 列表）与飞屏（108）；其余类型不报。
  void _reportMessages(Object? raw, {required int depth}) {
    if (depth > 4) return;
    if (raw is List) {
      for (final entry in raw) {
        _reportMessages(entry, depth: depth + 1);
      }
      return;
    }
    if (raw is! Map) return;
    final typeId = raw['typeID']?.toString() ?? '';
    switch (typeId) {
      case '101':
      case '108':
        final message = _chat(raw);
        if (message != null) onMessage?.call(message);
        break;
      case '110':
      case '1413':
        _reportMessages(raw['content'], depth: depth + 1);
        break;
      default:
        break;
    }
  }

  LiveMessage? _chat(Map<dynamic, dynamic> raw) {
    final text = _plainText(raw['content']);
    if (text == null) return null;
    final userName = raw['from']?.toString().trim() ?? '';
    final userId = raw['fid']?.toString() ?? '';
    final seconds = int.tryParse(raw['tm']?.toString() ?? '');
    final sentAt = seconds == null || seconds <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userName.isEmpty ? '六间房用户' : userName,
      userId: userId,
      message: text,
      sentAt: sentAt,
      color: LiveMessageColor.white,
    );
  }

  /// 文字按网页的读法：先把 `&amp;` 换成 `&`，再解字符引用，去首尾空白；空的不报。
  static String? _plainText(Object? value) {
    if (value is! String) return null;
    final decoded = value.replaceAll('&amp;', '&').replaceAllMapped(
      RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'),
      (match) {
        final body = match.group(1)!;
        if (body.startsWith('#x') || body.startsWith('#X')) {
          final code = int.tryParse(body.substring(2), radix: 16);
          return code == null ? match.group(0)! : String.fromCharCode(code);
        }
        if (body.startsWith('#')) {
          final code = int.tryParse(body.substring(1));
          return code == null ? match.group(0)! : String.fromCharCode(code);
        }
        return const <String, String>{'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' '}[body] ??
            match.group(0)!;
      },
    );
    final trimmed = decoded.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// `content` 的两种编码：`enc=yes` 是原始 DEFLATE（Base64 里 `+ / =` 写成 `( ) @`），
  /// 否则是标准 Base64。
  static Map<String, dynamic>? _decodePayload(Map<String, String> fields) {
    final raw = fields['content'] ?? '';
    if (raw.isEmpty) return null;
    try {
      final encoded = fields['enc'] == 'yes'
          ? raw.replaceAll('(', '+').replaceAll(')', '/').replaceAll('@', '=')
          : raw;
      final bytes = base64.decode(encoded);
      final inflated = fields['enc'] == 'yes'
          ? Uint8List.fromList(ZLibDecoder(raw: true).convert(bytes))
          : bytes;
      final decoded = json.decode(utf8.decode(inflated, allowMalformed: true));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (error) {
      CoreLog.error('Six Rooms chat payload failed: $error');
      return null;
    }
  }

  /// 下行是 `\r\n` 连接、末尾空行的 `key=value` 行。
  static Map<String, String> _explode(String data) {
    final fields = <String, String>{};
    for (final line in data.split(RegExp(r'\r?\n'))) {
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      fields[line.substring(0, separator)] = line.substring(separator + 1);
    }
    return fields;
  }

  Map<String, String> _headers() => <String, String>{
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Referer': '$_origin/${_args?.roomId ?? ''}',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': _origin,
  };
}
