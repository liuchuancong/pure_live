import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class TwitcastingDanmakuArgs {
  const TwitcastingDanmakuArgs({required this.movieId});

  final int movieId;
}

class TwitcastingDanmaku extends LiveDanmaku {
  TwitcastingDanmaku();

  static const String _origin = 'https://twitcasting.tv';
  static const String _pubSubPath = 'eventpubsuburl.php';

  TwitcastingDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;

  final List<String> _seen = <String>[];

  @override
  Future start(dynamic args) async {
    if (args is! TwitcastingDanmakuArgs || args.movieId <= 0) {
      onClose?.call('TwitCasting：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _seen.clear();
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        final url = await _requestSocketUrl(generation);
        if (!_running || generation != _generation) return;
        if (url == null) throw StateError('TwitCasting: 没有取到弹幕地址');
        final ended = Completer<void>();
        final socket = WebScoketUtils(
          url: url,
          heartBeatTime: 0,
          headers: _headers(),
          inactivityTimeout: const Duration(seconds: 30),
          onMessage: (event) {
            if (generation != _generation) return;
            _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true));
          },
          onReady: () {
            if (generation != _generation) return;
            attempt = 0;
            if (!isConnected) {
              markConnected();
              onReady?.call();
            }
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
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('TwitCasting chat connect failed: $error');
        onReconnect?.call('TwitCasting 弹幕连接失败，正在重试');
      }
      if (!_running || generation != _generation) return;
      attempt++;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<String?> _requestSocketUrl(int generation) async {
    final movieId = _args?.movieId ?? 0;
    if (movieId <= 0) return null;
    final response = await HttpClient.instance.postJson(
      '$_origin/$_pubSubPath',
      data: <String, String>{'movie_id': '$movieId'},
      formUrlEncoded: true,
      header: _headers(),
    );
    if (generation != _generation) return null;
    final url = response is Map ? _text(response['url']) : null;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'wss') return null;
    final host = uri.host.toLowerCase();
    if (host != 'twitcasting.tv' && !host.endsWith('.twitcasting.tv')) return null;
    return uri.toString();
  }

  void _handleFrame(String data) {
    final text = data.trim();
    if (text.isEmpty) return;
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      return;
    }
    final events = decoded is List ? decoded : <Object?>[decoded];
    for (final event in events) {
      if (event is! Map) continue;
      final message = _comment(event);
      if (message != null) onMessage?.call(message);
    }
  }

  LiveMessage? _comment(Map<dynamic, dynamic> event) {
    if (_text(event['type']) != 'comment') return null;
    final message = _text(event['message'])?.trim() ?? '';
    if (message.isEmpty) return null;
    final id = event['id'];
    final key = id == null ? '' : '$id';
    if (key.isNotEmpty) {
      if (_seen.contains(key)) return null;
      _seen.add(key);
      if (_seen.length > 400) _seen.removeAt(0);
    }
    final author = event['author'];
    final authorMap = author is Map ? author : const <dynamic, dynamic>{};
    final name = _text(authorMap['name'])?.trim() ?? '';
    final screenName = _text(authorMap['screenName'])?.trim() ?? '';
    final createdAt = _int(event['createdAt']);
    final sentAt = createdAt == null || createdAt <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(createdAt);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name.isNotEmpty ? name : (screenName.isNotEmpty ? screenName : 'TwitCasting'),
      userId: _text(authorMap['id']) ?? '',
      message: message,
      messageId: key.isEmpty ? '' : 'twitcasting:$key',
      sentAt: sentAt,
      color: LiveMessageColor.white,
    );
  }

  static Map<String, String> _headers() => const <String, String>{
    'Referer': '$_origin/',
    'Origin': _origin,
    'User-Agent': 'Mozilla/5.0',
  };

  static String? _text(Object? value) {
    if (value is String) return value;
    if (value is num || value is bool) return '$value';
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
