import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:brotli/brotli.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class MissevanDanmakuArgs {
  const MissevanDanmakuArgs({required this.roomId, this.url});

  final String roomId;
  final Uri? url;
}

class MissevanDanmaku extends LiveDanmaku {
  MissevanDanmaku();

  static const String _origin = 'https://fm.missevan.com';
  static const String _heartbeat = '❤️';
  static const int _flag = 1;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  MissevanDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _joined = false;
  var _joinedBefore = false;
  var _uuid = '';
  String _lastFailure = '';
  Timer? _heartbeatTimer;

  @override
  Future start(dynamic args) async {
    if (args is! MissevanDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('猫耳 FM：没有可用的房间');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _joinedBefore = false;
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _heartbeatTimer?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        final session = await _session(generation);
        if (!_running || generation != _generation) return;
        if (session == null) {
          onClose?.call('猫耳 FM：拿不到游客会话${_lastFailure.isEmpty ? '' : '（$_lastFailure）'}');
          return;
        }
        await _runSocket(session, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('Missevan chat failed: $error');
        onReconnect?.call('猫耳 FM 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<String?> _session(int generation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
        if (!_running || generation != _generation) return null;
      }
      try {
        final response = await HttpClient.instance.get(
          '$_origin/api/user/info',
          header: const <String, String>{'Referer': '$_origin/', 'Origin': _origin},
        );
        if (generation != _generation) return null;
        final value = sessionCookie(response.headers['set-cookie'] ?? const <String>[]);
        if (value != null) return value;
        _lastFailure = 'HTTP ${response.statusCode}';
      } catch (error) {
        _lastFailure = '$error';
      }
    }
    return null;
  }

  @visibleForTesting
  static String? sessionCookie(Iterable<String> setCookie) {
    for (final header in setCookie) {
      final value = _sessionCookie.firstMatch(header)?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static final RegExp _sessionCookie = RegExp(r'^\s*FM_SESS=([^;]*)');

  Uri _endpoint() {
    final roomId = _args?.roomId ?? '';
    final fallback = Uri.parse('wss://im.missevan.com/ws')
        .replace(queryParameters: <String, String>{'room_id': roomId});
    final url = _args?.url;
    if (url == null) return fallback;
    if (url.scheme != 'wss' ||
        url.userInfo.isNotEmpty ||
        (url.host != 'missevan.com' && !url.host.endsWith('.missevan.com'))) {
      return fallback;
    }
    final named = url.queryParametersAll['room_id'];
    if (named == null) return url.replace(queryParameters: <String, String>{...url.queryParameters, 'room_id': roomId});
    return named.length == 1 && named.single == roomId ? url : fallback;
  }

  Future<void> _runSocket(String session, int generation) async {
    final ended = Completer<void>();
    _joined = false;
    _uuid = _randomUuid();
    final socket = WebScoketUtils(
      url: _endpoint().toString(),
      heartBeatTime: 0,
      headers: <String, String>{'Origin': '$_origin/', 'Cookie': 'FM_SESS=$session'},
      onReady: () {
        if (generation != _generation) return;
        _socket?.sendMessage(
          json.encode(<String, Object?>{
            'action': 'join',
            'uuid': _uuid,
            'type': 'room',
            'room_id': int.tryParse(_args?.roomId ?? '') ?? 0,
            if (_joinedBefore) 'reconnect': 1,
          }),
        );
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _socket?.sendMessage(_heartbeat));
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event);
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
    await ended.future;
    _heartbeatTimer?.cancel();
  }

  void _handleFrame(Object? data) {
    final text = _frameText(data);
    if (text == null || text == _heartbeat) return;
    final Object? root;
    try {
      root = json.decode(text);
    } catch (_) {
      return;
    }
    final items = root is List ? root : <Object?>[root];
    for (final item in items) {
      if (item is! Map) continue;
      final type = item['type']?.toString() ?? '';
      final event = item['event']?.toString() ?? '';
      if (type == 'room' && event == 'join') {
        if (item['uuid']?.toString() != _uuid) continue;
        final code = item['code'];
        if (code == 0) {
          _joinedBefore = true;
          if (!_joined) {
            _joined = true;
            markConnected();
            onReady?.call();
          }
        }
        continue;
      }
      final room = int.tryParse(item['room_id']?.toString() ?? '');
      if (room != null && '${item['room_id']}' != (_args?.roomId ?? '')) continue;
      if (type == 'message' && (event == 'new' || event == 'danmaku')) {
        final message = _chat(item);
        if (message != null) onMessage?.call(message);
        continue;
      }
      if (type == 'room' && event == 'statistics') {
        for (final message in _audience(item['statistics'] ?? item)) {
          onMessage?.call(message);
        }
      }
    }
  }

  static String? _frameText(Object? data) {
    if (data is String) return data;
    if (data is! List<int>) return null;
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    if (bytes.length < 4 || bytes[0] != _flag) return null;
    final length = bytes[1] | (bytes[2] << 8) | (bytes[3] << 16);
    if (length <= 0) return null;
    try {
      final plain = brotliDecode(Uint8List.fromList(bytes.sublist(4)));
      if (plain.length != length) return null;
      return utf8.decode(plain, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  LiveMessage? _chat(Map<dynamic, dynamic> item) {
    final text = item['message'];
    if (text is! String || text.trim().isEmpty) return null;
    final user = item['user'];
    final userMap = user is Map ? user : const <dynamic, dynamic>{};
    final titles = item['titles'];
    Map<dynamic, dynamic>? titleOf(String key) {
      if (titles is! List) return null;
      for (final entry in titles) {
        if (entry is Map && entry['type'] == key) return entry;
      }
      return null;
    }

    final level = titleOf('level')?['level'];
    final medal = titleOf('medal');
    final medalMap = medal is Map ? medal : const <dynamic, dynamic>{};
    final time = int.tryParse(item['time']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userMap['username']?.toString() ?? '',
      userId: userMap['user_id']?.toString() ?? '',
      message: text.trim(),
      color: LiveMessageColor.white,
      userLevel: level == null ? '' : '$level',
      fansName: medalMap['name']?.toString() ?? '',
      fansLevel: medalMap['level'] == null ? '' : '${medalMap['level']}',
      sentAt: time == null || time <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(time > 100000000000 ? time : time * 1000),
    );
  }

  List<LiveMessage> _audience(Object? statistics) {
    if (statistics is! Map) return const <LiveMessage>[];
    final messages = <LiveMessage>[];
    for (final (key, kind) in const <(String, LiveAudienceMetricKind)>[
      ('heat', LiveAudienceMetricKind.popularity),
      ('online', LiveAudienceMetricKind.onlineViewers),
    ]) {
      final value = int.tryParse(statistics[key]?.toString() ?? '');
      if (value == null || value < 0) continue;
      messages.add(
        LiveMessage(
          type: LiveMessageType.online,
          userName: '',
          message: '',
          color: LiveMessageColor.white,
          data: LiveAudienceUpdate(kind: kind, value: value),
        ),
      );
    }
    return messages;
  }

  static String _randomUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
