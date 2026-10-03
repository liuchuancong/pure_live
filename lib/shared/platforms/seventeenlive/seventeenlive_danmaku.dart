import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/seventeenlive/seventeenlive_api.dart';

/// 17LIVE 的弹幕参数（上游 M5.29）：`roomId` 就是 Ably 的频道名。
class SeventeenLiveDanmakuArgs {
  const SeventeenLiveDanmakuArgs({required this.roomId});

  final String roomId;
}

/// 17LIVE 的房间聊天（上游 M5.29）：Ably 的 JSON 实时协议。
///
/// - 匿名令牌来自 `POST /api/v1/messenger/auth`（`provider` 必须是 1 = Ably，否则说明
///   平台换了推送服务、连不上）；令牌在服务端拒绝之前一直复用
/// - socket 是 `wss://17media.realtime.ably.net/?format=json&heartbeats=true&v=3`
///   （外加官网的三个备用主机），令牌按 ably-js 的顺序放进查询串
/// - `CONNECTED`(4) 之后发 `ATTACH`(10) 附着频道；`ATTACHED`(11) 算加入；
///   `DETACHED`(13) 重新附着（10 秒没附着上就换 socket）
/// - 心跳由**服务端**每 15 秒发，客户端不发；25 秒没消息就换 socket
/// - `MESSAGE`(15) 里的 `data` 是 **base64 + gzip 的 JSON**：`type` 3 是评论
///   （`commentMsg`，`isDirty*` 为真则不显示），38 是直播数据
///   （`liveinfo.liveViewerCount` → 在线人数）
/// - 令牌错误（40140–40149）丢掉令牌与 socket；连续 3 次被拒（令牌错误或服务端 detach）
///   就结束这一轮
class SeventeenLiveDanmaku extends LiveDanmaku {
  SeventeenLiveDanmaku();

  static const String _primaryHost = '17media.realtime.ably.net';
  static const List<String> _fallbackHosts = <String>[
    '17-media-a-fallback.ably-realtime.com',
    '17-media-b-fallback.ably-realtime.com',
    '17-media-c-fallback.ably-realtime.com',
  ];
  static const int _ablyProvider = 1;
  static const int _maxRefusals = 3;
  static const Duration _joinTimeout = Duration(seconds: 10);

  SeventeenLiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _joined = false;
  var _refusals = 0;
  String _token = '';
  Timer? _joinWatch;

  @override
  Future start(dynamic args) async {
    if (args is! SeventeenLiveDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('17LIVE：没有可用的房间');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _refusals = 0;
    _token = '';
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _joinWatch?.cancel();
    final socket = _socket;
    _socket = null;
    markDisconnected();
    await socket?.close();
  }

  Future<void> _loop(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      try {
        if (_token.isEmpty) {
          final token = await _requestToken(generation);
          if (!_running || generation != _generation) return;
          if (token == null) {
            onClose?.call('17LIVE：拿不到聊天令牌');
            return;
          }
          _token = token;
        }
        final host = attempt == 0 ? _primaryHost : _fallbackHosts[(attempt - 1) % _fallbackHosts.length];
        await _runSocket(host, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('17LIVE chat failed: $error');
        onReconnect?.call('17LIVE 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  /// `POST /api/v1/messenger/auth`：`provider` 必须是 Ably（1），令牌是它的 `token`。
  Future<String?> _requestToken(int generation) async {
    final response = await HttpClient.instance.postJson(
      '${SeventeenLiveApi.apiOrigin}/api/v1/messenger/auth',
      data: const <String, Object?>{},
      header: const <String, String>{
        'Origin': SeventeenLiveApi.origin,
        'Referer': '${SeventeenLiveApi.origin}/',
        'content-type': 'application/json',
      },
    );
    if (generation != _generation) return null;
    if (response is! Map) return null;
    final provider = response['provider'];
    if (provider != _ablyProvider) {
      onClose?.call('17LIVE：平台把聊天换成了别的推送服务（provider ${provider ?? '空'}）');
      return null;
    }
    final token = response['token']?.toString().trim() ?? '';
    if (token.isEmpty || token.length > 4096) return null;
    return token;
  }

  Future<void> _runSocket(String host, int generation) async {
    final ended = Completer<void>();
    _joined = false;
    final url = Uri(
      scheme: 'wss',
      host: host,
      path: '/',
      queryParameters: <String, String>{
        'format': 'json',
        'heartbeats': 'true',
        'v': '3',
        'access_token': _token,
      },
    );
    final socket = WebScoketUtils(
      url: url.toString(),
      heartBeatTime: 0,
      headers: const <String, String>{'Origin': SeventeenLiveApi.origin},
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event is String ? event : utf8.decode(event as List<int>, allowMalformed: true), ended);
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
    _joinWatch?.cancel();
  }

  void _handleFrame(String data, Completer<void> ended) {
    final text = data.trim();
    if (text.isEmpty) return;
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final action = int.tryParse(decoded['action']?.toString() ?? '') ?? -1;
    final channel = decoded['channel']?.toString() ?? '';
    final ours = channel.isEmpty || channel == (_args?.roomId ?? '');
    switch (action) {
      case 4: // CONNECTED：可以附着频道了
        _socket?.sendMessage(json.encode(<String, Object?>{'action': 10, 'channel': _args?.roomId ?? ''}));
        _joinWatch?.cancel();
        _joinWatch = Timer(_joinTimeout, () {
          if (_running && !_joined && !ended.isCompleted) ended.complete();
        });
        break;
      case 11: // ATTACHED
        if (!ours) return;
        _refusals = 0;
        _joinWatch?.cancel();
        if (!_joined) {
          _joined = true;
          markConnected();
          onReady?.call();
        }
        break;
      case 13: // DETACHED：重新附着（10 秒没附着上就换 socket）
        if (!ours) return;
        _refusals++;
        if (_refusals > _maxRefusals) {
          if (!ended.isCompleted) ended.complete();
          return;
        }
        _socket?.sendMessage(json.encode(<String, Object?>{'action': 10, 'channel': _args?.roomId ?? ''}));
        _joinWatch?.cancel();
        _joinWatch = Timer(_joinTimeout, () {
          if (_running && !ended.isCompleted) ended.complete();
        });
        break;
      case 15: // MESSAGE
        if (!ours) return;
        _reportMessages(decoded['messages']);
        break;
      case 9: // ERROR
        final error = _error(decoded['error']);
        if (error != null && error.isTokenError) {
          _token = '';
          if (++_refusals > _maxRefusals) {
            if (!ended.isCompleted) ended.complete();
          }
        } else if (!ended.isCompleted) {
          ended.complete();
        }
        break;
      case 6: // DISCONNECTED：换 socket
        if (!ended.isCompleted) ended.complete();
        break;
      case 17: // AUTH：同一个 socket 上换新令牌
        unawaited(_reauthorize(_generation));
        break;
      default:
        break;
    }
  }

  Future<void> _reauthorize(int generation) async {
    final token = await _requestToken(generation);
    if (!_running || generation != _generation || token == null) return;
    _token = token;
    _socket?.sendMessage(
      json.encode(<String, Object?>{
        'action': 17,
        'auth': <String, Object?>{'accessToken': token},
      }),
    );
  }

  void _reportMessages(Object? raw) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is! Map) continue;
      final payload = _payload(item['data']);
      if (payload == null) continue;
      final message = _message(payload, id: item['id']?.toString() ?? '');
      if (message != null) onMessage?.call(message);
    }
  }

  /// `data` 是 base64 + gzip 的 JSON（官网的 `gzip_base64`）。
  static Map<String, dynamic>? _payload(Object? data) {
    if (data is! String || data.isEmpty) return null;
    try {
      final bytes = gzip.decode(base64.decode(data));
      final decoded = json.decode(utf8.decode(bytes, allowMalformed: true));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// `type` 3 是评论（`isDirty*` 为真则不显示），38 是直播数据。
  static LiveMessage? _message(Map<String, dynamic> payload, {required String id}) {
    switch (int.tryParse(payload['type']?.toString() ?? '')) {
      case 3:
        final comment = payload['commentMsg'];
        if (comment is! Map) return null;
        if (comment['isDirty'] == true || comment['isDirtyWord'] == true || comment['isDirtyUser'] == true) {
          return null;
        }
        final body = comment['body'];
        final text = body is Map ? body['comment']?.toString().trim() ?? '' : '';
        if (text.isEmpty) return null;
        final user = comment['user'];
        final userMap = user is Map ? user : const <dynamic, dynamic>{};
        final name = userMap['displayName']?.toString().trim() ?? '';
        final level = comment['userLevel'];
        final colorText = body is Map ? body['textColor']?.toString().replaceFirst('#', '') : null;
        final color = colorText != null && colorText.length == 6
            ? int.tryParse(colorText, radix: 16)
            : null;
        return LiveMessage(
          type: LiveMessageType.chat,
          userName: name.isNotEmpty ? name : (userMap['openID']?.toString() ?? ''),
          userId: userMap['userID']?.toString() ?? '',
          message: text,
          messageId: id.isEmpty ? '' : '17live:$id',
          color: color == null ? LiveMessageColor.white : LiveMessageColor.numberToColor(color),
          userLevel: level == null ? '' : '$level',
        );
      case 38:
        final info = payload['liveinfo'];
        final viewers = info is Map ? int.tryParse(info['liveViewerCount']?.toString() ?? '') : null;
        if (viewers == null || viewers < 0) return null;
        return LiveMessage(
          type: LiveMessageType.online,
          userName: '',
          message: '',
          color: LiveMessageColor.white,
          data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: viewers),
        );
      default:
        return null;
    }
  }

  static _AblyError? _error(Object? raw) {
    if (raw is! Map) return null;
    return _AblyError(
      code: int.tryParse(raw['code']?.toString() ?? '') ?? 0,
      message: raw['message']?.toString() ?? '',
    );
  }
}

class _AblyError {
  const _AblyError({required this.code, this.message = ''});

  final int code;
  final String message;

  /// 令牌错误（40140–40149）。
  bool get isTokenError => code >= 40140 && code < 40150;
}
