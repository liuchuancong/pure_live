import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/pandalive/pandalive_api.dart';

class PandaLiveDanmakuArgs {
  const PandaLiveDanmakuArgs({required this.userId, required this.channel, required this.token});

  final String userId;
  final String channel;
  final String token;
}

class PandaLiveDanmaku extends LiveDanmaku {
  PandaLiveDanmaku({PandaLiveApi? api}) : _api = api ?? PandaLiveApi();

  final PandaLiveApi _api;
  static const String _server = 'wss://chat-ws.neolive.kr/connection/websocket';
  static const Duration _pingInterval = Duration(seconds: 25);

  PandaLiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _nextId = 2;
  var _pingTimer = Timer(Duration.zero, () {});
  Timer? _refreshTimer;

  @override
  Future start(dynamic args) async {
    if (args is! PandaLiveDanmakuArgs || args.token.trim().isEmpty || args.channel.trim().isEmpty) {
      onClose?.call('PandaTV：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _pingTimer.cancel();
    _refreshTimer?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        await _runSocket(generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('PandaTV chat failed: $error');
        onReconnect?.call('PandaTV 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
      final refreshed = await _refreshArgs(generation);
      if (!_running || generation != _generation) return;
      if (refreshed != null) _args = refreshed;
    }
  }

  Future<void> _runSocket(int generation) async {
    final ended = Completer<void>();
    final socket = WebScoketUtils(
      url: _server,
      heartBeatTime: 0,
      onReady: () {
        if (generation != _generation) return;
        _connectCommand();
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true), generation);
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
    _pingTimer.cancel();
    _refreshTimer?.cancel();
  }

  void _connectCommand() {
    _nextId = 2;
    _nextId++;
    _socket?.sendMessage(json.encode(<String, Object?>{
      'params': <String, Object?>{'token': _args?.token ?? '', 'name': 'js'},
      'id': 1,
    }));
    _socket?.sendMessage(json.encode(<String, Object?>{
      'method': 1,
      'params': <String, Object?>{'channel': _args?.channel ?? ''},
      'id': 2,
    }));
    _pingTimer.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _nextId++;
      _socket?.sendMessage(json.encode(<String, Object?>{'method': 7, 'id': _nextId}));
    });
  }

  void _handleFrame(String data, int generation) {
    for (final line in const LineSplitter().convert(data)) {
      final text = line.trim();
      if (text.isEmpty) continue;
      final Object? decoded;
      try {
        decoded = json.decode(text);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      final id = decoded['id'];
      final result = decoded['result'];
      if (result is! Map) continue;
      if (id is int) {
        if (id == 1) {
          final ttl = int.tryParse(result['ttl']?.toString() ?? '') ?? 0;
          if (ttl > 60) {
            _refreshTimer?.cancel();
            _refreshTimer = Timer(Duration(seconds: ttl - 60), () => unawaited(_refreshSocket(generation)));
          }
        }
        continue;
      }
      final channel = result['channel']?.toString() ?? '';
      final payload = result['data'];
      if (channel.isEmpty || payload is! Map) continue;
      final message = payload['data'];
      if (message is! Map) continue;
      final chat = _chat(message, channel, payload['offset']);
      if (chat != null) onMessage?.call(chat);
    }
  }

  LiveMessage? _chat(Map<dynamic, dynamic> message, String channel, Object? offset) {
    final type = message['type']?.toString() ?? '';
    if (!const <String>{'bj', 'chatter', 'manager', 'support'}.contains(type)) return null;
    final text = message['message']?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    final seq = offset?.toString() ?? '';
    final createdAt = int.tryParse(message['created_at']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: (message['nick'] ?? message['userNick'] ?? message['userId'])?.toString().trim() ?? '',
      userId: message['userId']?.toString() ?? '',
      message: text,
      messageId: seq.isEmpty ? '' : '$channel:$seq',
      sentAt: createdAt == null || createdAt <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAt > 100000000000 ? createdAt : createdAt * 1000),
      color: LiveMessageColor.white,
    );
  }

  Future<void> _refreshSocket(int generation) async {
    final refreshed = await _refreshArgs(generation);
    if (!_running || generation != _generation || refreshed == null) return;
    _args = refreshed;
    final socket = _socket;
    _socket = null;
    await socket?.close();
  }

  Future<PandaLiveDanmakuArgs?> _refreshArgs(int generation) async {
    final userId = _args?.userId ?? '';
    if (userId.isEmpty) return null;
    try {
      final room = await _api.room(userId);
      if (generation != _generation) return null;
      if (room.chatToken.isEmpty) return null;
      return PandaLiveDanmakuArgs(
        userId: userId,
        channel: room.chatChannel.isEmpty ? userId : room.chatChannel,
        token: room.chatToken,
      );
    } catch (error) {
      CoreLog.error('PandaTV chat token refresh failed: $error');
      return null;
    }
  }
}
