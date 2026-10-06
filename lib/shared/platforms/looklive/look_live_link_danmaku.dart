import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/shared/platforms/looklive/look_live_danmaku.dart';
import 'package:pure_live/shared/platforms/looklive/look_live_api.dart';

class LookLiveDanmaku extends LiveDanmaku {
  LookLiveDanmaku();

  static const String _appKey = '3a6a3e48f6854dfa4e4464f3bdaec3b4';
  static const String _sdkVersion = '47';
  static const int _protocolVersion = 1;
  static const String _os = 'Windows 10 64-bit';
  static const String _browser = 'Chrome 140.0.0.0';
  static const String _guestNick = '匿名用户';
  static const String _guestAvatar = ' ';
  static const String _socketHeartbeat = '2::';
  static const String _heartbeat = '3:::{"SID":1,"CID":2,"SER":0}';
  static const Duration _tick = Duration(seconds: 30);
  static const int _ticksPerHeartbeat = 6;
  static const Duration _joinTimeout = Duration(seconds: 10);
  static const Set<int> _retriedRefusals = <int>{408, 415, 500, 503};
  static const int _maxRefusals = 3;
  static const List<String> _kickReasons = <String>[
    '',
    '聊天室已关闭',
    '被主播或管理员请出',
    '账号在其他地方登录',
    '静默重连',
    '已被拉黑',
  ];
  static final RegExp _packet = RegExp(r'^([^:]+):([0-9]+)?(\+)?:([^:]+)?:?([\s\S]*)$');

  LookLiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _opened = false;
  var _loggedIn = false;
  var _joined = false;
  var _serial = 0;
  var _refusals = 0;
  var _ticks = 0;
  late String _account;
  late String _deviceId;
  late String _session;
  Timer? _tickTimer;
  Timer? _joinWatch;

  @override
  Future start(dynamic args) async {
    if (args is! LookLiveDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('LOOK Live：没有可用的房间');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _refusals = 0;
    final random = Random.secure();
    String guid() => List<String>.generate(8, (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0')).join();
    _account = 'nimanon_${guid()}';
    _deviceId = guid();
    _session = guid();
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _tickTimer?.cancel();
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
        final servers = await _chatServers(generation);
        if (!_running || generation != _generation) return;
        if (servers.isEmpty) {
          onClose?.call('LOOK Live：拿不到聊天服务器');
          return;
        }
        final server = servers[attempt % servers.length];
        await _runServer(server, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('LOOK Live chat failed: $error');
        onReconnect?.call('LOOK Live 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<List<({String host, int port})>> _chatServers(int generation) async {
    for (var round = 0; round < 2; round++) {
      if (round > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!_running || generation != _generation) return const [];
      }
      try {
        final servers = await LookLiveApi().chatServers(_args!.roomId);
        if (generation != _generation) return const [];
        if (servers.isNotEmpty) return servers;
      } catch (error) {
        CoreLog.error('LOOK Live chat address failed: $error');
      }
    }
    return const [];
  }

  Future<void> _runServer(({String host, int port}) server, int generation) async {
    final handshake = await HttpClient.instance.getText(
      'https://${server.host}:${server.port}/socket.io/1/',
      queryParameters: <String, String>{'t': '${DateTime.now().millisecondsSinceEpoch}'},
      header: const <String, String>{'origin': LookLiveApi.origin, 'user-agent': 'Mozilla/5.0'},
    );
    if (generation != _generation) return;
    final parts = handshake.trim().split(':');
    if (parts.length < 4 || parts.first.trim().isEmpty || !parts[3].split(',').contains('websocket')) {
      throw StateError('LOOK Live socket.io handshake: $handshake');
    }
    final sid = parts.first.trim();
    final ended = Completer<void>();
    _opened = false;
    _loggedIn = false;
    _joined = false;
    _ticks = 0;
    final socket = WebScoketUtils(
      url: 'wss://${server.host}:${server.port}/socket.io/1/websocket/$sid',
      heartBeatTime: 0,
      headers: const <String, String>{'origin': LookLiveApi.origin, 'user-agent': 'Mozilla/5.0'},
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event, ended);
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
    _tickTimer?.cancel();
    _joinWatch?.cancel();
  }

  void _handleFrame(Object? data, Completer<void> ended) {
    final text = switch (data) {
      final String value => value,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null || text.isEmpty) return;
    for (final packet in _packets(text)) {
      final match = _packet.firstMatch(packet);
      if (match == null) continue;
      switch (match.group(1)) {
        case '0' || '7':
          if (!ended.isCompleted) ended.complete();
          return;
        case '1':
          if (_opened) continue;
          _opened = true;
          _login();
          _joinWatch?.cancel();
          _joinWatch = Timer(_joinTimeout, () {
            if (_running && !_joined && !ended.isCompleted) ended.complete();
          });
          break;
        case '2':
          _socket?.sendMessage(_socketHeartbeat);
          break;
        case '3':
          final id = match.group(2);
          if (id != null && match.group(3) == null) _socket?.sendMessage('6:::$id');
          _handleAnswer(match.group(5) ?? '', ended);
          break;
        default:
          break;
      }
    }
  }

  static List<String> _packets(String text) {
    if (!text.contains('\ufffd')) return <String>[text];
    final packets = <String>[];
    var index = 0;
    while (index < text.length) {
      if (text.codeUnitAt(index) != 0xfffd) {
        return <String>[text];
      }
      final lengthEnd = text.indexOf('\ufffd', index + 1);
      if (lengthEnd < 0) break;
      final length = int.tryParse(text.substring(index + 1, lengthEnd));
      if (length == null || length <= 0) break;
      final start = lengthEnd + 1;
      if (start + length > text.length) break;
      packets.add(text.substring(start, start + length));
      index = start + length;
    }
    return packets.isEmpty ? <String>[text] : packets;
  }

  void _login() {
    _serial++;
    final args = _args!;
    final chatroom = <String, Object>{
      '1': _appKey,
      '2': _account,
      '3': _deviceId,
      '5': int.tryParse(args.chatroomId) ?? 0,
      '8': _loggedIn ? 1 : 0,
      '20': _guestNick,
      '21': _guestAvatar,
      '26': _session,
      '38': 1,
    };
    final im = <String, Object>{
      '4': _os,
      '6': _sdkVersion,
      '8': _loggedIn ? 0 : 1,
      '9': _protocolVersion,
      '13': _deviceId,
      '18': _appKey,
      '19': _account,
      '24': _browser,
      '26': _session,
      '1000': '',
    };
    _socket?.sendMessage(
      '3:::${json.encode(<String, Object?>{'SID': 13, 'CID': 2, 'SER': _serial, 'Q': <Object?>[
        <String, Object?>{'t': 'byte', 'v': 1},
        <String, Object?>{'t': 'Property', 'v': chatroom},
        <String, Object?>{'t': 'Property', 'v': im},
      ]})}',
    );
    _ticks = 0;
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tick, (_) {
      _ticks++;
      if (!_joined) return;
      if (_ticks % _ticksPerHeartbeat == 0) _socket?.sendMessage(_heartbeat);
    });
  }

  void _handleAnswer(String data, Completer<void> ended) {
    final Object? decoded;
    try {
      decoded = json.decode(data);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final root = decoded;
    var sid = _int(root['sid']);
    var cid = _int(root['cid']);
    if (sid == null || cid == null) return;
    final code = _int(root['code']);
    var body = root['r'];
    if (sid == 4 && (cid == 10 || cid == 11)) {
      final wrapped = body is List && body.length > 1 ? body[1] : null;
      if (wrapped is! Map) return;
      final header = wrapped['headerPacket'];
      final headerMap = header is Map ? header : const <dynamic, dynamic>{};
      final innerSid = _int(headerMap['sid']);
      final innerCid = _int(headerMap['cid']);
      if (innerSid == null || innerCid == null) return;
      sid = innerSid;
      cid = innerCid;
      body = wrapped['body'];
    } else if (body is! List) {
      body = const <Object?>[];
    }
    switch ((sid, cid)) {
      case (13, 2):
        if (code == 200) {
          _refusals = 0;
          if (!_joined) {
            _joined = true;
            _loggedIn = true;
            _joinWatch?.cancel();
            markConnected();
            onReady?.call();
          }
        } else {
          _refuse(code ?? 0, ended);
        }
        break;
      case (13, 3):
        if (code != 200) return;
        final reason = _int(body is List && body.isNotEmpty ? body.first : null) ?? 0;
        if (reason == 4) {
          if (!ended.isCompleted) ended.complete();
          return;
        }
        final name = reason > 0 && reason < _kickReasons.length ? _kickReasons[reason] : '$reason';
        onClose?.call('LOOK Live 聊天结束：$name');
        if (!ended.isCompleted) ended.complete();
        break;
      case (13, 7):
        if (code != 200) return;
        final message = _chat(body is List && body.isNotEmpty ? body.first : null);
        if (message != null) onMessage?.call(message);
        break;
      default:
        break;
    }
  }

  void _refuse(int code, Completer<void> ended) {
    markDisconnected();
    if (_retriedRefusals.contains(code) && ++_refusals <= _maxRefusals) {
      if (!ended.isCompleted) ended.complete();
      return;
    }
    onClose?.call('LOOK Live 登录被拒：$code');
    if (!ended.isCompleted) ended.complete();
  }

  LiveMessage? _chat(Object? raw) {
    if (raw is! Map) return null;
    final custom = _custom(raw['4']);
    if (custom == null) return null;
    final type = _int(raw['2']);
    final String text;
    switch (type) {
      case 0:
        final body = _text(raw['3']);
        if (body.isEmpty || custom['bizName'] != 'iplay') return null;
        text = body;
        break;
      case 100 when _text(raw['21']) == 'musiclive_server' && _int(custom['type']) == 2601:
        final content = custom['content'];
        final emoji = content is Map ? _custom(content['emoji']) : null;
        final name = emoji == null ? '' : _text(emoji['name']);
        if (name.isEmpty) return null;
        text = '[$name]';
        break;
      default:
        return null;
    }
    final content = custom['content'];
    if (content is! Map) return null;
    final control = content['commonCtrl'];
    if (control is Map && _held(control['riskLevelKey'])) return null;
    final user = content['user'];
    if (user is! Map) return null;
    var name = _text(user['nickname']);
    if (name.isEmpty) name = _text(user['nickName']);
    if ((_args?.anonymousMode ?? false) && name.isNotEmpty) {
      name = '${String.fromCharCode(name.runes.first)}***';
    }
    var userId = _text(user['userId']);
    if (userId.isEmpty) userId = _text(raw['21']);
    final fanClub = user['fanClubInfo'];
    final fanClubMap = fanClub is Map ? fanClub : const <dynamic, dynamic>{};
    final millis = _int(raw['time']) ?? _int(raw['9']);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name,
      userId: userId,
      message: text,
      color: LiveMessageColor.white,
      userLevel: _level(user['liveLevel']),
      fansName: _text(fanClubMap['fanClubName']),
      fansLevel: _level(fanClubMap['fanClubLevel']),
      messageId: _text(raw['1']),
      sentAt: millis == null || millis <= 0 || millis > 8640000000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  static Map<dynamic, dynamic>? _custom(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = json.decode(value);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final custom = decoded;
    if (custom['sp'] != 1) return custom;
    return <dynamic, dynamic>{
      'bizName': custom['b'],
      'type': custom['t'],
      'content': _expandShort(custom['c']),
    };
  }

  static Object? _expandShort(Object? value) {
    if (value is! Map) return value;
    final out = <dynamic, dynamic>{};
    value.forEach((key, item) {
      switch ('$key') {
        case 'u':
          final user = item is Map ? item : const <dynamic, dynamic>{};
          out['user'] = <dynamic, dynamic>{
            'nickname': user['n'],
            'userId': user['i'],
            'liveLevel': user['l'],
            'fanClubInfo': <dynamic, dynamic>{
              'fanClubLevel': user['fcl'],
              'fanClubName': user['fcn'],
            },
          };
          break;
        case 'cc':
          final control = item is Map ? item : const <dynamic, dynamic>{};
          out['commonCtrl'] = <dynamic, dynamic>{'riskLevelKey': control['r']};
          break;
        case 'e':
          out['emoji'] = item;
          break;
        default:
          out['$key'] = item;
      }
    });
    return out;
  }

  static bool _held(Object? key) => switch (key) {
    null || false || '' => false,
    final num number => number != 0,
    _ => true,
  };

  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };

  static String _level(Object? value) => switch (_int(value)) {
    final int level when level > 0 => '$level',
    _ => '',
  };
}
