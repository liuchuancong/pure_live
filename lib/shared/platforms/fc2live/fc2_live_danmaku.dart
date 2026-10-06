import 'dart:async';
import 'dart:convert';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_api.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class Fc2LiveDanmakuArgs {
  const Fc2LiveDanmakuArgs({required this.channelId});

  final String channelId;
}

class Fc2LiveDanmaku extends LiveDanmaku {
  Fc2LiveDanmaku({Fc2Api? api}) : _api = api ?? Fc2Api();

  final Fc2Api _api;
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  Fc2LiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _joined = false;
  var _heartbeatId = 0;
  Timer? _heartbeat;
  final _ng = _Fc2NgList();
  int? _onlineViewers;
  int? _totalViewers;

  static const Map<String, int> _colors = <String, int>{
    'red': 0xE63D37,
    'pink': 0xE13396,
    'orange': 0xDC7611,
    'yellow': 0xE1AC00,
    'green': 0x33BD4A,
    'cyan': 0x1B94C7,
    'blue': 0x4472F3,
    'purple': 0xB84AC5,
  };

  @override
  Future start(dynamic args) async {
    if (args is! Fc2LiveDanmakuArgs || args.channelId.trim().isEmpty) {
      onClose?.call('FC2 LIVE：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _joined = false;
    _ng.clear();
    _onlineViewers = null;
    _totalViewers = null;
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _heartbeat?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        final grant = await _api.controlGrant(_args!.channelId);
        if (!_running || generation != _generation) return;
        await _runSocket(grant, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('FC2 LIVE chat failed: $error');
        onReconnect?.call('FC2 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _runSocket(Fc2ControlGrant grant, int generation) async {
    final ended = Completer<void>();
    _joined = false;
    final endpoint = grant.webSocket.replace(queryParameters: <String, String>{
      ...grant.webSocket.queryParameters,
      'control_token': grant.controlToken,
    });
    final socket = WebScoketUtils(
      url: endpoint.toString(),
      heartBeatTime: 0,
      headers: <String, String>{
        'Origin': 'https://live.fc2.com',
        'Cookie': 'l_ortkn=${grant.orz}',
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true));
      },
      onReady: () {
        if (generation != _generation) return;
        _heartbeat?.cancel();
        _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _sendHeartbeat());
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
    _heartbeat?.cancel();
  }

  void _sendHeartbeat() {
    _heartbeatId++;
    _socket?.sendMessage(json.encode(<String, Object?>{
      'name': 'heartbeat',
      'arguments': const <String, Object?>{},
      'id': _heartbeatId,
    }));
  }

  void _handleFrame(String data) {
    final text = data.trim();
    if (text.isEmpty || text.length > 2 * 1024 * 1024) return;
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final name = decoded['name']?.toString() ?? '';
    final arguments = decoded['arguments'];
    final args = arguments is Map ? arguments : const <dynamic, dynamic>{};
    switch (name) {
      case 'connect_complete':
        if (_joined) return;
        _joined = true;
        markConnected();
        onReady?.call();
        break;
      case 'comment':
        _reportComments(args['comments']);
        break;
      case 'user_count':
        _reportUserCount(args);
        break;
      case 'ng_comment':
        _ng.update(args);
        break;
      case 'control_disconnection':
        final code = args['code']?.toString() ?? '';
        CoreLog.error('FC2 LIVE control disconnection: $code');
        _socket?.close();
        break;
      default:
        break;
    }
  }

  void _reportComments(Object? raw) {
    if (raw is! List) return;
    for (final entry in raw) {
      if (entry is! Map) continue;
      if (entry['history']?.toString() == '1') continue;
      final body = entry['comment'];
      if (body is! String) continue;
      final text = _plainText(body);
      if (text == null) continue;
      if (_ng.blocks(userName: entry['user_name']?.toString() ?? '', text: text)) continue;
      final colorName = entry['color']?.toString() ?? '';
      final color = _colors[colorName];
      final timestamp = int.tryParse(entry['timestamp']?.toString() ?? '');
      onMessage?.call(
        LiveMessage(
          type: LiveMessageType.chat,
          userName: entry['user_name']?.toString().trim() ?? '',
          message: text,
          sentAt: timestamp == null || timestamp <= 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(timestamp),
          color: color == null ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
        ),
      );
    }
  }

  void _reportUserCount(Map<dynamic, dynamic> args) {
    int? read(Object? value) => int.tryParse(value?.toString() ?? '');
    final online = (read(args['pc_user_count']) ?? 0) + (read(args['mobile_user_count']) ?? 0);
    final total = (read(args['pc_total_count']) ?? 0) + (read(args['mobile_total_count']) ?? 0);
    if (_joined || args.containsKey('pc_user_count') || args.containsKey('mobile_user_count')) {
      if (_onlineViewers != online) {
        _onlineViewers = online;
        onMessage?.call(
          LiveMessage(
            type: LiveMessageType.online,
            data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: online),
            color: LiveMessageColor.white,
            message: '',
            userName: '',
          ),
        );
      }
    }
    if (args.containsKey('pc_total_count') || args.containsKey('mobile_total_count')) {
      if (_totalViewers != total) {
        _totalViewers = total;
        onMessage?.call(
          LiveMessage(
            type: LiveMessageType.online,
            data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.totalViewers, value: total),
            color: LiveMessageColor.white,
            message: '',
            userName: '',
          ),
        );
      }
    }
  }

  static String? _plainText(String raw) {
    final withoutTags = raw.replaceAll(RegExp(r'<[^>]*>'), '');
    final decoded = withoutTags.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);'), (match) {
      final body = match.group(1)!;
      if (body.startsWith('#x') || body.startsWith('#X')) {
        final code = int.tryParse(body.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (body.startsWith('#')) {
        final code = int.tryParse(body.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return const <String, String>{
            'lt': '<',
            'gt': '>',
            'amp': '&',
            'quot': '"',
            'apos': "'",
            'nbsp': ' ',
          }[body] ??
          match.group(0)!;
    });
    final trimmed = decoded.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _Fc2NgList {
  final Set<String> _keywords = <String>{};
  final Set<String> _users = <String>{};
  var _adminNg = false;
  var _sharedLevel = 0;

  void clear() {
    _keywords.clear();
    _users.clear();
    _adminNg = false;
    _sharedLevel = 0;
  }

  void update(Map<dynamic, dynamic> args) {
    _adminNg = args['admin_ng']?.toString() == '1';
    _sharedLevel = int.tryParse(args['shared_ng_level']?.toString() ?? '') ?? 0;
    final rows = args['ng_comments'];
    if (rows is! List) return;
    for (final row in rows) {
      if (row is! Map) continue;
      final type = row['type']?.toString() ?? '';
      final value = (row['ng_comment'] ?? row['comment'] ?? row['value'])?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      if (!_applies(type)) continue;
      final isUser = type.endsWith('_user') || type == 'user';
      final target = isUser ? _users : _keywords;
      final mode = row['mode']?.toString() ?? 'add';
      if (mode == 'add' || mode.isEmpty) {
        target.add(isUser ? value : value.toLowerCase());
      } else {
        target.remove(isUser ? value : value.toLowerCase());
      }
    }
  }

  bool _applies(String type) {
    if (type.startsWith('admin_')) return _adminNg;
    if (type == 'share_low') return _sharedLevel >= 1;
    if (type == 'share_high') return _sharedLevel >= 2;
    return true;
  }

  bool blocks({required String userName, required String text}) {
    if (_users.contains(userName.trim())) return true;
    final lower = text.toLowerCase();
    for (final keyword in _keywords) {
      if (keyword.isNotEmpty && lower.contains(keyword)) return true;
    }
    return false;
  }
}
