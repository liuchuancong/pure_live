import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class BigoDanmakuArgs {
  const BigoDanmakuArgs({required this.siteId, required this.ownerId, required this.roomId});

  final String siteId;
  final int ownerId;
  final String roomId;
}

class BigoDanmaku extends LiveDanmaku {
  BigoDanmaku();

  static const String _socketUrl = 'wss://wss.bigolive.tv/live/official/web';
  static const String _accountUrl = 'https://ta.bigo.tv/official_website/studio/getWebSocketLink';
  static const Duration _pingInterval = Duration(seconds: 10);

  BigoDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _loggedIn = false;
  var _joined = false;
  var _answeredChallenge = false;
  Timer? _pingTimer;
  String _uid = '';
  String _uidToken = '';
  String _deviceId = '';

  @override
  Future start(dynamic args) async {
    if (args is! BigoDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('BIGO LIVE：没有可用的弹幕参数');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _uid = '';
    _uidToken = '';
    _deviceId = _newDeviceId();
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
        if (_uid.isEmpty) await _requestAccount(generation);
        if (!_running || generation != _generation) return;
        await _runSocket(generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('BIGO chat failed: $error');
        onReconnect?.call('BIGO 弹幕连接失败，正在重试');
        attempt++;
        _uid = '';
        _uidToken = '';
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _requestAccount(int generation) async {
    final response = await HttpClient.instance.postJson(
      _accountUrl,
      data: <String, String>{'deviceId': _deviceId},
      formUrlEncoded: true,
      header: <String, String>{'Origin': 'https://www.bigo.tv', 'User-Agent': 'Mozilla/5.0'},
    );
    if (generation != _generation) return;
    final data = response is Map ? response['data'] : null;
    if (data is! Map) throw StateError('BIGO：游客账号回答读不懂');
    _uid = data['userId']?.toString().trim() ?? '';
    _uidToken = data['uidToken']?.toString().trim() ?? '';
    if (_uid.isEmpty || _uidToken.isEmpty) throw StateError('BIGO：游客账号不完整');
  }

  Future<void> _runSocket(int generation) async {
    final ended = Completer<void>();
    _loggedIn = false;
    _joined = false;
    _answeredChallenge = false;
    final socket = WebScoketUtils(
      url: _socketUrl,
      heartBeatTime: 0,
      headers: const <String, String>{'Origin': 'https://www.bigo.tv', 'User-Agent': 'Mozilla/5.0'},
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
    final text = data.trim();
    if (text.isEmpty) return;
    final split = _splitEvent(text);
    if (split == null) return;
    final (event, payload) = split;
    switch (event) {
      case 79108:
        if (_answeredChallenge) return;
        _answeredChallenge = true;

        _answerChallenge(text);
        break;
      case 512535:
        if (payload['res']?.toString() != '200') {
          throw StateError('BIGO：登录被拒');
        }
        _loggedIn = true;
        _enterRoom();
        break;
      case 11032:
        final total = int.tryParse(payload['total']?.toString() ?? '');
        if (total != null && total >= 0) {
          onMessage?.call(
            LiveMessage(
              type: LiveMessageType.online,
              data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: total),
              color: LiveMessageColor.white,
              message: '',
              userName: '',
            ),
          );
        }
        break;
      case 2584:
        _reportBroadcast(payload);
        break;
      case 1304:
        if (_joined) return;
        _joined = true;
        markConnected();
        onReady?.call();
        _requestAudience();
        _startPing();
        break;
      default:
        break;
    }
  }

  void _answerChallenge(String raw) {
    final suffix = raw.length <= 8 ? raw : raw.substring(raw.length - 8);
    final seconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final sign = md5.convert(utf8.encode('60#4#5#$seconds#1#1#1#1#$suffix')).toString();
    _send(79108, <String, Object?>{
      'appId': '60',
      'osType': '4',
      'clientVersion': '5',
      'timeStamp': seconds,
      'nonce': '1',
      'reservedForSecurity': '1',
      'appSign': '1',
      'redundancy': '1',
      'sign': sign,
    });
    Timer(const Duration(seconds: 1), () {
      if (_running) _login();
    });
  }

  void _login() {
    if (_loggedIn) return;
    _send(512279, <String, Object?>{
      'uid': _uid,
      'cookie': _uidToken.replaceAll('###VER2', ''),
      'secret': '0',
      'userName': '0',
      'deviceId': _deviceId,
      'clientType': '7',
      'netConf': <String, Object?>{'clientIp': '0', 'countryCode': 'CN'},
    });
  }

  void _enterRoom() {
    _send(1304, <String, Object?>{
      'secretKey': '0',
      'seqId': DateTime.now().millisecondsSinceEpoch,
      'roomId': _args?.roomId ?? '',
      'reserver': '1',
      'clientVersion': '0',
      'clientType': '7',
      'version': '15',
      'deviceid': _deviceId,
      'other': const <Object?>[],
    });
  }

  void _requestAudience() {
    _send(10776, <String, Object?>{
      'uid': _args?.ownerId ?? 0,
      'seqId': DateTime.now().millisecondsSinceEpoch,
      'roomid': _args?.roomId ?? '',
      'others': const <Object?>[],
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _send(791, <String, Object?>{
        'status': '0',
        'seqid': DateTime.now().millisecondsSinceEpoch,
        'flag': '0',
        'roomId': '0',
        'ownerStatus': '0',
        'micUid': '0',
      });
    });
  }

  void _reportBroadcast(Map<String, dynamic> payload) {
    final tag = int.tryParse(payload['tag']?.toString() ?? '');
    if (tag != 1 && tag != 2) return;
    final content = payload['content']?.toString() ?? '';
    if (content.isEmpty) return;
    final Object? decoded;
    try {
      final normalized = content.padRight(content.length + ((4 - content.length % 4) % 4), '=');
      decoded = json.decode(utf8.decode(base64.decode(normalized)));
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final text = decoded['m']?.toString().trim() ?? '';
    if (text.isEmpty) return;
    final uid = payload['uid']?.toString().trim() ?? '';
    final fromUid = payload['from_uid']?.toString().trim() ?? '';
    final seqId = payload['seqId']?.toString().trim() ?? '';
    final timestamp = int.tryParse(payload['timestamp']?.toString() ?? '');
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: decoded['n']?.toString().trim() ?? '',
        userId: uid.isEmpty ? fromUid : uid,
        message: text,
        messageId: seqId.isEmpty ? '' : 'bigo:$seqId',
        sentAt: timestamp == null || timestamp <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(timestamp > 100000000000 ? timestamp : timestamp * 1000),
        color: LiveMessageColor.white,
      ),
    );
  }

  void _send(int event, Map<String, Object?> payload) {
    _socket?.sendMessage('$event${json.encode(payload)}');
  }

  static (int, Map<String, dynamic>)? _splitEvent(String raw) {
    final match = RegExp(r'^(\d{1,7})[\t ]?(\{.*)$', dotAll: true).firstMatch(raw);
    if (match == null) return null;
    final event = int.tryParse(match.group(1)!);
    if (event == null) return null;
    final Object? payload;
    try {
      payload = json.decode(match.group(2)!);
    } catch (_) {
      return null;
    }
    if (payload is! Map) return null;
    return (event, Map<String, dynamic>.from(payload));
  }

  static String _newDeviceId() {
    final random = Random.secure();
    final suffix = List<int>.generate(6, (_) => random.nextInt(10)).join();
    return 'web_${random.nextInt(1 << 32).toRadixString(16)}$suffix${DateTime.now().millisecondsSinceEpoch}';
  }
}
