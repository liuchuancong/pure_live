import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class PicartoDanmakuArgs {
  const PicartoDanmakuArgs({required this.channelName});

  final String channelName;
}

class PicartoDanmaku extends LiveDanmaku {
  PicartoDanmaku();

  static const String _graphql = 'https://ptvintern.picarto.tv/ptvapi';
  static const Duration _tipDuration = Duration(seconds: 60);
  static const int _maxTokenRefreshes = 3;

  PicartoDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _refreshes = 0;

  @override
  Future start(dynamic args) async {
    if (args is! PicartoDanmakuArgs || args.channelName.trim().isEmpty) {
      onClose?.call('Picarto：没有可用的频道');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _refreshes = 0;
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
        final token = await _requestToken(generation);
        if (!_running || generation != _generation) return;
        if (token == null) {
          onClose?.call('Picarto：拿不到聊天令牌');
          return;
        }
        final refreshed = await _runSocket(token, generation);
        attempt = 0;
        if (!refreshed) {
          _refreshes++;
          if (_refreshes > _maxTokenRefreshes) {
            onClose?.call('Picarto：聊天令牌反复被拒');
            return;
          }
        } else {
          _refreshes = 0;
        }
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('Picarto chat failed: $error');
        onReconnect?.call('Picarto 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<String?> _requestToken(int generation) async {
    final channel = _args?.channelName ?? '';
    final response = await HttpClient.instance.postJson(
      _graphql,
      data: <String, Object?>{
        'query': r'query ($name: String) { generateJwtToken(channel_name: $name) { key } }',
        'variables': <String, Object?>{'name': channel},
      },
      header: const <String, String>{'origin': 'https://picarto.tv', 'referer': 'https://picarto.tv/'},
    );
    if (generation != _generation) return null;
    final data = response is Map ? response['data'] : null;
    final generated = data is Map ? data['generateJwtToken'] : null;
    final key = generated is Map ? generated['key'] : null;
    if (key is! String || key.split('.').length != 3) return null;
    return key;
  }

  Future<bool> _runSocket(String token, int generation) async {
    final ended = Completer<bool>();
    final socket = WebScoketUtils(
      url: 'wss://chat.picarto.tv/chat/token=$token',
      heartBeatTime: 0,
      headers: const <String, String>{'origin': 'https://picarto.tv', 'referer': 'https://picarto.tv/'},
      onReady: () {
        if (generation != _generation) return;
        markConnected();
        onReady?.call();
      },
      onMessage: (event) {
        if (generation != _generation) return;
        final refused = _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true));
        if (refused && !ended.isCompleted) ended.complete(false);
      },
      onReconnect: () {
        if (generation != _generation) return;
        markDisconnected();
        onReconnect?.call('与服务器断开连接，正在尝试重连');
      },
      onClose: (error) {
        if (generation != _generation) return;
        markDisconnected();
        if (!ended.isCompleted) ended.complete(true);
      },
    );
    _socket = socket;
    await socket.connect();
    final refreshed = await ended.future;
    await socket.close();
    return refreshed;
  }

  bool _handleFrame(String data) {
    final text = data.trim();
    if (text.isEmpty) return false;
    final Object? root;
    try {
      root = json.decode(text);
    } catch (_) {
      return false;
    }
    if (root is! Map) return false;
    if (root['success'] == false && root['code']?.toString() == 'JWT_TOKEN') return true;
    final type = (root['type'] ?? root['t'])?.toString() ?? '';
    final payload = root['messages'] ?? root['m'];
    if (type == 'stream') {
      final viewers = payload is Map ? payload['viewers'] : null;
      if (viewers is int && viewers >= 0) {
        onMessage?.call(
          LiveMessage(
            type: LiveMessageType.online,
            data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: viewers),
            color: LiveMessageColor.white,
            message: '',
            userName: '',
          ),
        );
      }
      return false;
    }
    if (root['paginated'] == true || root['p'] == true) return false;
    if (type == 'rm') {
      final id = payload is Map ? payload['id']?.toString().trim() ?? '' : '';
      if (id.isNotEmpty) onMessage?.call(_retraction(LiveRetraction.message(id)));
      return false;
    }
    if (type == 'cm') {
      final user = payload is Map ? payload['u']?.toString().trim() ?? '' : '';
      if (user.isNotEmpty) onMessage?.call(_retraction(LiveRetraction.user(user)));
      return false;
    }
    if (type == 'raid') {
      final text = _raidText(payload);
      if (text != null) onMessage?.call(_notice(text));
      return false;
    }
    if (type == 'ns') {
      final text = _subscriptionText(payload);
      if (text != null) onMessage?.call(_notice(text));
      return false;
    }
    if (type == 'c' || type == 'ct' || type == 'system') {
      if (type == 'system' && root['c']?.toString() == 'b') return false;
      if (payload is List) {
        for (final line in payload) {
          final message = _line(line, type);
          if (message != null) onMessage?.call(message);
        }
      }
    }
    return false;
  }

  LiveMessage? _line(Object? raw, String frameType) {
    if (raw is! Map) return null;
    final type = raw['t']?.toString();
    final isTip = frameType == 'ct' || (type == null || type == 'c') && _truthy(raw['v']);
    if (isTip) return _tip(raw);
    if (type == null || type == 'c') return _chat(raw);
    if (type == 'system') {
      final text = _systemText(raw);
      return text == null ? null : _notice(text);
    }
    return null;
  }

  LiveMessage? _chat(Map<dynamic, dynamic> line) {
    final raw = line['m'];
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty) return null;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _scalar(line['n']),
      userId: _scalar(line['u']),
      message: text,
      messageId: _messageId(line),
      sentAt: _time(line['d']),
      color: _color(line['k']),
    );
  }

  LiveMessage? _tip(Map<dynamic, dynamic> line) {
    final chips = line['x'];
    if (chips is! int || chips <= 0) return null;
    final start = _time(line['d']) ?? DateTime.now();
    final text = line['m'] is String ? (line['m'] as String).trim() : '';
    final receiver = _scalar(line['rn']).trim();
    final channel = _args?.channelName ?? '';
    final elsewhere = receiver.isNotEmpty && channel.isNotEmpty && receiver != channel;
    final message = !elsewhere
        ? text
        : text.isEmpty
        ? '打赏给 $receiver'
        : '打赏给 $receiver：$text';
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: _scalar(line['n']),
      userId: _scalar(line['u']),
      message: message,
      color: LiveMessageColor.white,
      data: LiveSuperChatMessage(
        messageId: _messageId(line),
        userName: _scalar(line['n']),
        face: _scalar(line['i']),
        message: message,
        price: chips,
        startTime: start,
        endTime: start.add(_tipDuration),
        backgroundColor: '',
        backgroundBottomColor: '',
      ),
    );
  }

  String? _systemText(Map<dynamic, dynamic> line) {
    final raw = line['m'];
    final text = raw is String ? raw.trim() : '';
    if (text.isEmpty) return null;
    return text
        .replaceAllMapped(RegExp(r'\{link\}'), (_) => '')
        .replaceAllMapped(RegExp(r'\{icon\}'), (_) => '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _raidText(Object? raid) {
    if (raid is! Map) return null;
    final text = raid['m'] is String ? (raid['m'] as String).trim() : '';
    if (text.isNotEmpty) return text;
    final from = _scalar(raid['n']).trim();
    final to = _scalar(raid['rn']).trim();
    if (from.isEmpty || to.isEmpty) return null;
    return '$from 突袭了 $to';
  }

  String? _subscriptionText(Object? subscription) {
    if (subscription is! Map) return null;
    String name(Object? value) => _scalar(value).trim();
    final sender = name(subscription['sn']);
    final channel = name(subscription['n']);
    if (sender.isEmpty || channel.isEmpty) return null;
    final rawMonths = name(subscription['md']);
    final months = rawMonths.isEmpty ? '1' : rawMonths;
    final level = name(subscription['slvl']);
    final gifted = _truthy(subscription['sg']);
    final anonymous = _truthy(subscription['ag']);
    if (level.isNotEmpty) return '$sender 开通了 $channel 的 $level 级订阅';
    if (gifted) {
      final receiver = name(subscription['gn']);
      return receiver.isEmpty ? '$sender 赠送了 $channel 的订阅' : '$sender 赠送了 $channel 的订阅给 $receiver';
    }
    if (anonymous) return '匿名订阅了 $channel，$months 个月';
    return '$sender 订阅了 $channel，$months 个月';
  }

  static LiveMessage _notice(String text) => LiveMessage(
    type: LiveMessageType.notice,
    userName: '',
    message: text,
    color: LiveMessageColor.white,
  );

  static LiveMessage _retraction(LiveRetraction retraction) => LiveMessage(
    type: LiveMessageType.retraction,
    userName: '',
    message: '',
    color: LiveMessageColor.white,
    data: retraction,
  );

  static String _messageId(Map<dynamic, dynamic> line) {
    final raw = line['id'] ?? line['_id'];
    final id = raw is String ? raw.trim() : '';
    return id.isEmpty ? '' : 'picarto:$id';
  }

  static DateTime? _time(Object? value) {
    if (value is! int || value <= 0) return null;
    if (value > 8640000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static LiveMessageColor _color(Object? value) {
    final text = _scalar(value).replaceFirst('#', '').trim();
    if (text.length != 6) return LiveMessageColor.white;
    final parsed = int.tryParse(text, radix: 16);
    return parsed == null ? LiveMessageColor.white : LiveMessageColor.numberToColor(parsed);
  }

  static bool _truthy(Object? value) =>
      value == true || value == 1 || value?.toString() == '1' || value?.toString() == 'true';

  static String _scalar(Object? value) => value == null ? '' : '$value';
}
