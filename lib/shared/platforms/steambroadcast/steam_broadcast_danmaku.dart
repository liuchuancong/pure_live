import 'dart:async';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class SteamBroadcastDanmakuArgs {
  const SteamBroadcastDanmakuArgs({required this.steamId, this.broadcastId = ''});

  final String steamId;
  final String broadcastId;
}

class SteamBroadcastDanmaku extends LiveDanmaku {
  SteamBroadcastDanmaku();

  static const String _origin = 'https://steamcommunity.com';
  static const int _maxFailuresBeforeResolve = 8;

  SteamBroadcastDanmakuArgs? _args;
  var _generation = 0;
  var _running = false;
  String _broadcastId = '';

  @override
  Future start(dynamic args) async {
    if (args is! SteamBroadcastDanmakuArgs || args.steamId.trim().isEmpty) {
      onClose?.call('Steam 广播：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _broadcastId = args.broadcastId.trim();
    _generation++;
    final generation = _generation;
    _running = true;
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    markDisconnected();
  }

  Future<void> _loop(int generation) async {
    var failures = 0;
    while (_running && generation == _generation) {
      try {
        if (_broadcastId.isEmpty && !await _resolveBroadcast(generation)) {
          throw StateError('Steam 广播：拿不到这一场直播的 id');
        }
        if (!_running || generation != _generation) return;
        final template = await _chatTemplate(generation);
        if (!_running || generation != _generation) return;
        await _readWindows(template, generation);
        failures = 0;
      } catch (error) {
        if (generation != _generation) return;
        failures++;
        CoreLog.error('Steam broadcast chat failed: $error');
        onReconnect?.call('Steam 广播弹幕连接失败，正在重试');
        if (failures >= _maxFailuresBeforeResolve) {
          _broadcastId = '';
          failures = 0;
        }
        final wait = failures == 0 ? 1 : (1 << failures.clamp(0, 3));
        await Future<void>.delayed(Duration(seconds: wait.clamp(1, 8)));
      }
    }
  }

  Future<bool> _resolveBroadcast(int generation) async {
    final steamId = _args?.steamId ?? '';
    final response = await HttpClient.instance.getJson(
      '$_origin/broadcast/getbroadcastmpd/',
      queryParameters: <String, String>{
        'broadcastid': '0',
        'steamid': steamId,
        'viewertoken': '0',
        'sessionid': '',
      },
      header: _roomHeaders(json: true),
    );
    if (generation != _generation) return false;
    if (response is! Map) return false;
    final id = response['broadcastid']?.toString().trim() ?? '';
    final viewers = int.tryParse(response['num_viewers']?.toString() ?? '');
    if (viewers != null && viewers >= 0) {
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
    if (id.isEmpty || id == '0') return false;
    _broadcastId = id;
    return true;
  }

  Future<String> _chatTemplate(int generation) async {
    final steamId = _args?.steamId ?? '';
    final response = await HttpClient.instance.getJson(
      '$_origin/broadcast/getchatinfo/',
      queryParameters: <String, String>{
        'steamid': steamId,
        'broadcastid': _broadcastId,
        'viewertoken': '0',
        'sessionid': '',
      },
      header: _roomHeaders(json: true),
    );
    if (generation != _generation) throw StateError('cancelled');
    final template = response is Map ? response['view_url_template']?.toString().trim() ?? '' : '';
    if (template.isEmpty || !_acceptableChatUrl(template)) {
      _broadcastId = '';
      throw StateError('Steam 广播：聊天日志地址不可用');
    }
    return template;
  }

  Future<void> _readWindows(String template, int generation) async {
    var nudgeMs = 0;
    var failures = 0;
    var window = 0;
    var answer = await _fetchWindow(template, window, generation);
    if (answer == null) throw StateError('Steam 广播：窗口 0 没有回答');
    if (generation != _generation) return;
    markConnected();
    onReady?.call();
    var clock = DateTime.now();
    var initialDelay = answer.initialDelayMs;
    var next = answer.nextRequest;
    if (next <= 0) throw StateError('Steam 广播：窗口 0 没有给下一个窗口');
    while (_running && generation == _generation) {
      final due = clock.add(Duration(milliseconds: initialDelay + (next - window) + nudgeMs));
      final wait = due.difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!_running || generation != _generation) return;
      answer = await _fetchWindow(template, next, generation);
      if (generation != _generation) return;
      if (answer == null) {
        failures++;
        nudgeMs = (nudgeMs + 10).clamp(0, 1000);
        if (failures >= _maxFailuresBeforeResolve) {
          throw StateError('Steam 广播：聊天日志连续失败');
        }
        continue;
      }
      failures = 0;
      nudgeMs = 0;
      for (final message in answer.messages) {
        onMessage?.call(message);
      }
      window = next;
      if (answer.initialDelayMs > 0) {
        clock = DateTime.now();
        initialDelay = answer.initialDelayMs;
      }
      if (answer.nextRequest <= window) throw StateError('Steam 广播：下一个窗口没有前进');
      next = answer.nextRequest;
    }
  }

  Future<_SteamChatWindow?> _fetchWindow(String template, int window, int generation) async {
    final url = template.replaceFirst('{0}', '$window');
    final Object? response;
    try {
      response = await HttpClient.instance.getJson(url, header: _chatHeaders());
    } catch (error) {
      return null;
    }
    if (generation != _generation) return null;
    if (response is! Map) return null;
    final rows = response['messages'];
    final messages = <LiveMessage>[];
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) continue;
        final text = row['msg'];
        if (text is! String) continue;
        final trimmed = text.trim();
        if (trimmed.isEmpty) continue;
        final name = row['persona_name'];
        final steamId = row['steamid']?.toString() ?? '';
        messages.add(
          LiveMessage(
            type: LiveMessageType.chat,
            userName: name is String && name.trim().isNotEmpty ? name.trim() : 'Steam 用户',
            userId: steamId,
            message: trimmed,
            color: LiveMessageColor.white,
          ),
        );
      }
    }
    final nextRequest = int.tryParse(response['next_request']?.toString() ?? '') ?? 0;
    final initialDelay = int.tryParse(response['initial_delay']?.toString() ?? '') ?? 0;
    return _SteamChatWindow(messages: messages, nextRequest: nextRequest, initialDelayMs: initialDelay);
  }

  static bool _acceptableChatUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return false;
    if (uri.hasPort && uri.port != 443) return false;
    final host = uri.host.toLowerCase();
    if (host.endsWith('.akamaized.net') && host.startsWith('steambroadcast')) return true;
    for (final domain in const <String>['steamcommunity.com', 'steamcontent.com', 'steamserver.net', 'steamstatic.com']) {
      if (host == domain || host.endsWith('.$domain')) return true;
    }
    return false;
  }

  Map<String, String> _roomHeaders({bool json = false}) => <String, String>{
    if (json) 'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Referer': 'https://steamcommunity.com/broadcast/watch/${_args?.steamId ?? ''}',
    'X-Requested-With': 'XMLHttpRequest',
  };

  Map<String, String> _chatHeaders() => <String, String>{
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Origin': _origin,
    'Referer': 'https://steamcommunity.com/broadcast/watch/${_args?.steamId ?? ''}',
  };
}

class _SteamChatWindow {
  const _SteamChatWindow({required this.messages, required this.nextRequest, required this.initialDelayMs});

  final List<LiveMessage> messages;
  final int nextRequest;
  final int initialDelayMs;
}
