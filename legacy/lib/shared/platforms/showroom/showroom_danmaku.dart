import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class ShowroomDanmakuArgs {
  const ShowroomDanmakuArgs({required this.roomId, required this.host, required this.key});

  final int roomId;
  final String host;
  final String key;
}

class ShowroomDanmaku extends LiveDanmaku {
  ShowroomDanmaku();

  static const String _ping = 'PING\tshowroom';
  static const Duration _pingInterval = Duration(seconds: 60);

  ShowroomDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  Timer? _pingTimer;

  @override
  Future start(dynamic args) async {
    if (args is! ShowroomDanmakuArgs || args.host.trim().isEmpty || args.key.trim().isEmpty) {
      onClose?.call('SHOWROOM：没有可用的评论服务器或键');
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
    _pingTimer?.cancel();
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
        CoreLog.error('SHOWROOM chat failed: $error');
        onReconnect?.call('SHOWROOM 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _runSocket(int generation) async {
    final ended = Completer<void>();
    final host = _args?.host ?? '';
    final socket = WebScoketUtils(
      url: 'wss://$host/',
      heartBeatTime: 0,
      headers: const <String, String>{'Origin': 'https://www.showroom-live.com'},
      onReady: () {
        if (generation != _generation) return;
        _socket?.sendMessage('SUB\t${_args?.key ?? ''}');
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(_pingInterval, (_) => _socket?.sendMessage(_ping));
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
    await ended.future;
    _pingTimer?.cancel();
  }

  void _handleFrame(String data) {
    if (!data.startsWith('MSG\t')) return;
    final rest = data.substring(4);
    final separator = rest.indexOf('\t');
    if (separator <= 0) return;
    final key = rest.substring(0, separator);
    if (key != (_args?.key ?? '')) return;
    final Object? decoded;
    try {
      decoded = json.decode(rest.substring(separator + 1));
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    if (!isConnected) {
      markConnected();
      onReady?.call();
    }
    if (decoded['t']?.toString() != '1') return;
    final message = _comment(decoded);
    if (message != null) onMessage?.call(message);
  }

  LiveMessage? _comment(Map<dynamic, dynamic> frame) {
    final raw = frame['cm'];
    final text = switch (raw) {
      String value => value.trim(),
      int value => '$value',
      _ => '',
    };
    if (text.isEmpty) return null;
    final createdAt = int.tryParse(frame['created_at']?.toString() ?? '');
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: frame['ac']?.toString().trim() ?? '',
      userId: frame['u']?.toString() ?? '',
      message: text,
      sentAt: createdAt == null || createdAt <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      color: LiveMessageColor.white,
      userLevel: frame['cl']?.toString() ?? '',
    );
  }
}
