import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class KilakilaDanmakuArgs {
  const KilakilaDanmakuArgs({required this.roomId});

  final String roomId;
}

class KilakilaDanmaku extends LiveDanmaku {
  KilakilaDanmaku();

  static const String _host = 'wim.hongrenshuo.com.cn';
  static const String _namespace = '/live_chat_room_guest';
  static const Duration _pingInterval = Duration(seconds: 25);
  static const int _chatType = 200;
  static const int _roomStateType = 637;

  KilakilaDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _joined = false;
  Timer? _pingTimer;
  Timer? _joinTimer;

  static String _query(String roomId) => 'roomId=$roomId&appId=111&clientType=1';

  @override
  Future start(dynamic args) async {
    if (args is! KilakilaDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('KilaKila：没有可用的房间');
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
    _joinTimer?.cancel();
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
        CoreLog.error('KilaKila chat failed: $error');
        onReconnect?.call('KilaKila 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _runSocket(int generation) async {
    final ended = Completer<void>();
    final roomId = _args?.roomId ?? '';
    _joined = false;
    final socket = WebScoketUtils(
      url: 'wss://$_host/socket.io/?${_query(roomId)}&EIO=3&transport=websocket',
      heartBeatTime: 0,
      headers: const <String, String>{'Origin': 'https://www.hongrenshuo.com.cn', 'User-Agent': 'Mozilla/5.0'},
      onReady: () {
        if (generation != _generation) return;
        _socket?.sendMessage('40$_namespace?${_query(roomId)},');
        _pingTimer?.cancel();
        _pingTimer = Timer.periodic(_pingInterval, (_) => _socket?.sendMessage('2'));
        _joinTimer?.cancel();
        _joinTimer = Timer(const Duration(seconds: 8), () {
          if (generation != _generation || _joined) return;
          if (!ended.isCompleted) ended.complete();
        });
      },
      onMessage: (event) {
        if (generation != _generation) return;
        if (_handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true))) {
          if (!ended.isCompleted) ended.complete();
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
    _pingTimer?.cancel();
    _joinTimer?.cancel();
  }

  bool _handleFrame(String data) {
    final text = data.trim();
    if (text.isEmpty) return false;
    if (text == '3' || text.startsWith('2')) return false;
    if (text.startsWith('1')) return true;
    final rest = text.length > 1 ? text.substring(1) : '';
    if (rest.isNotEmpty && !rest.startsWith(_namespace)) {
      return false;
    }
    final after = rest.length <= _namespace.length ? '' : rest.substring(_namespace.length);
    if (after.isNotEmpty && !after.startsWith(',')) return false;
    final body = after.isEmpty ? '' : after.substring(1);
    final kind = text.substring(0, 1);
    switch (kind) {
      case '0':
        return true;
      case '4':
        final packet = text.length > 1 ? text.substring(1, 2) : '';
        switch (packet) {
          case '0':
            _markJoined();
            return false;
          case '1':
            return true;
          case '4':
            return _handleEvent(body);
          default:
            return false;
        }
      default:
        return false;
    }
  }

  bool _handleEvent(String body) {
    final Object? decoded;
    try {
      decoded = json.decode(body);
    } catch (_) {
      return false;
    }
    if (decoded is! List || decoded.isEmpty) return false;
    final name = decoded.first?.toString() ?? '';
    final payload = decoded.length > 1 ? decoded[1] : null;
    if (name == 'connect_error') {
      final code = payload is Map ? payload['code'] : null;
      if (code == 0) _markJoined();
      return false;
    }
    if (name != 'text_message') return false;
    final bodyJson = payload is String ? payload : null;
    if (bodyJson == null) return false;
    final Object? envelope;
    try {
      envelope = json.decode(bodyJson);
    } catch (_) {
      return false;
    }
    final Object? bodySource = envelope is Map ? envelope['body'] : null;
    final Object? response = bodySource is Map ? bodySource['response'] : null;
    final content = response is Map ? _object(response['content']) : null;
    if (content == null) return false;
    final message = switch (content['t']) {
      _chatType => _chat(content, response),
      _roomStateType => _audience(content),
      _ => null,
    };
    if (message != null) onMessage?.call(message);
    return false;
  }

  void _markJoined() {
    if (_joined) return;
    _joined = true;
    _joinTimer?.cancel();
    markConnected();
    onReady?.call();
  }

  LiveMessage? _chat(Map<dynamic, dynamic> content, Object? responseRaw) {
    final response = responseRaw is Map ? responseRaw : const <dynamic, dynamic>{};
    final raw = content['c'];
    if (raw is! String || raw.trim().isEmpty) return null;
    final name = content['n'];
    final created = response['created_at'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name is String ? name : '',
      userId: _scalar(content['u']),
      message: raw.trim(),
      color: LiveMessageColor.white,
      userLevel: _scalar(content['l']),
      messageId: _scalar(response['mid']),
      sentAt: created is int && created > 0 && created <= 8640000000000000
          ? DateTime.fromMillisecondsSinceEpoch(created)
          : null,
    );
  }

  LiveMessage? _audience(Map<dynamic, dynamic> content) {
    final encoded = content['c'];
    if (encoded is! String || encoded.isEmpty) return null;
    final Object? state;
    try {
      state = json.decode(Uri.decodeComponent(encoded));
    } catch (_) {
      return null;
    }
    final watching = state is Map ? state['watchNumber'] : null;
    if (watching is! int || watching < 0) return null;
    return LiveMessage(
      type: LiveMessageType.online,
      data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: watching),
      color: LiveMessageColor.white,
      message: '',
      userName: '',
    );
  }

  static Map<dynamic, dynamic>? _object(Object? value) {
    if (value is Map) return value;
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = json.decode(value);
        return decoded is Map ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _scalar(Object? value) => value == null ? '' : '$value';
}
