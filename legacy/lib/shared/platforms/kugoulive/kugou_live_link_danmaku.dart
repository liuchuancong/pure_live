import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_protobuf.dart';
import 'package:pure_live/shared/platforms/kugoulive/kugou_live_api.dart';
import 'package:pure_live/shared/platforms/kugoulive/kugou_live_danmaku.dart';
import 'package:pure_live/shared/platforms/kugoulive/kugou_live_link.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class KugouLiveLinkDanmaku extends LiveDanmaku {
  KugouLiveLinkDanmaku();

  static const String _dispatchPath = '/socket_scheduler/pc/binary/v2/address.jsonp';
  static const String _signSalt = r'$_fan_xing_$';
  static const String _pageVersion = '7.0.0';
  static const int _socketVersion = 20240801;
  static const int _clientId = 100;
  static const int _roomType = 102;
  static const int _appId = 1010;
  static const int _platformId = 7;
  static const int _loginCommand = 201;
  static const int _reloginCommand = 2201;
  static const int _statusCommand = 901;
  static const int _chatCommand = 501;
  static const int _giftCommand = 601;
  static const int _ackCommand = 211;
  static const int _audienceCommand = 301005;
  static const int _tokenRejected = 622;
  static const int _magic = 100;
  static const int _maxContentBytes = 4 * 1024 * 1024;
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _joinTimeout = Duration(seconds: 10);
  static const Duration _defaultAge = Duration(minutes: 5);
  static const int _maxRefusals = 3;
  static final RegExp _badEscape = RegExp(r'%(?![0-9a-fA-F]{2})');

  KugouLiveDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  var _joined = false;
  var _everJoined = false;
  var _answered = false;
  var _refusals = 0;
  var _sessionId = '';
  String? _token;
  List<Uri> _endpoints = const <Uri>[];
  DateTime? _grantedAt;
  Duration _age = _defaultAge;
  late String _sid;
  late String _deviceNo;
  Timer? _heartbeatTimer;
  Timer? _joinWatch;

  @override
  Future start(dynamic args) async {
    if (args is! KugouLiveDanmakuArgs || args.roomId.trim().isEmpty) {
      onClose?.call('酷狗直播：没有可用的房间');
      return;
    }
    _args = args;
    _generation++;
    final generation = _generation;
    _running = true;
    _endpoints = const <Uri>[];
    _token = null;
    _sid = _uuid();
    _deviceNo = _uuid();
    unawaited(_loop(generation));
  }

  @override
  Future stop() async {
    _running = false;
    _generation++;
    _heartbeatTimer?.cancel();
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
        if (!_usableToken()) await _dispatch(generation);
        if (!_running || generation != _generation) return;
        if (_endpoints.isEmpty || _token == null) {
          onClose?.call('酷狗直播：拿不到聊天地址或令牌');
          return;
        }
        final endpoint = _endpoints[attempt % _endpoints.length];
        await _runSocket(endpoint, generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('Kugou Live chat failed: $error');
        onReconnect?.call('酷狗直播弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation == _generation) {
        _token = null;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  bool _usableToken() {
    if (_token == null || _endpoints.isEmpty || _grantedAt == null) return false;
    if (_everJoined && !_answered) return false;
    final age = DateTime.now().difference(_grantedAt!);
    return !age.isNegative && age < _age;
  }

  Future<void> _dispatch(int generation) async {
    const delays = <Duration>[Duration(milliseconds: 1500), Duration(milliseconds: 4500)];
    for (var round = 0; round < 3; round++) {
      if (round > 0) {
        await Future<void>.delayed(delays[round - 1]);
        if (!_running || generation != _generation) return;
      }
      try {
        final now = DateTime.now();
        final query = <String, String>{
          '_p': '0',
          '_v': _pageVersion,
          'pv': '$_socketVersion',
          'rid': _args!.roomId,
          'clienttime': '${now.millisecondsSinceEpoch}',
          'cid': '$_clientId',
          'at': '$_roomType',
        };
        final uri = Uri.https(KugouLiveApi.apiOrigin, _dispatchPath, <String, String>{
          ...query,
          'sign': _sign(query),
        });
        final response = await HttpClient.instance.getJson(
          uri.toString(),
          header: <String, String>{
            ...KugouLiveApi.apiHeaders,
            'referer': KugouLiveLink.watchUrl(_args!.roomId),
          },
        );
        if (generation != _generation) return;
        if (response is! Map) continue;
        final code = _int(response['code']);
        if (code != 0) {
          onClose?.call('酷狗直播：调度器拒绝（code $code ${response['msg'] ?? ''}）');
          return;
        }
        final data = response['data'];
        if (data is! Map) continue;
        final protocol = _text(data['protocol']).isEmpty ? 'ws://' : _text(data['protocol']);
        final endpoints = <Uri>[];
        final addrs = data['addrs'];
        if (addrs is List) {
          for (final address in addrs) {
            final host = address is Map ? _text(address['host']) : '';
            if (host.isEmpty) continue;
            final uri = Uri.tryParse('$protocol$host');
            if (uri == null || (uri.scheme != 'wss' && uri.scheme != 'ws') || uri.host.isEmpty) continue;
            if (!endpoints.contains(uri)) endpoints.add(uri);
          }
        }
        final token = _text(data['soctoken']);
        if (endpoints.isEmpty || !_tokenPattern.hasMatch(token)) continue;
        final age = _int(data['age']);
        _endpoints = endpoints;
        _token = token;
        _age = age != null && age > 0 ? Duration(milliseconds: age) : _defaultAge;
        _grantedAt = DateTime.now();
        return;
      } catch (error) {
        CoreLog.error('Kugou Live dispatch failed: $error');
      }
    }
  }

  static final RegExp _tokenPattern = RegExp(r'^[\x21-\x7e]+$');

  static String _sign(Map<String, String> query) {
    final keys = query.keys.toList()..sort();
    final text = '${keys.map((key) => '$key=${query[key]}').join('&')}$_signSalt';
    return md5.convert(utf8.encode(text)).toString().substring(8, 24);
  }

  Future<void> _runSocket(Uri endpoint, int generation) async {
    final ended = Completer<void>();
    _joined = false;
    _answered = false;
    final socket = WebScoketUtils(
      url: endpoint.toString(),
      heartBeatTime: 0,
      headers: <String, String>{'origin': KugouLiveApi.webOrigin, 'user-agent': KugouLiveApi.userAgent},
      onReady: () {
        if (generation != _generation) return;
        _socket?.sendMessage(_loginFrame());
        _joinWatch?.cancel();
        _joinWatch = Timer(_joinTimeout, () {
          if (_running && !_joined && !ended.isCompleted) ended.complete();
        });
        _heartbeatTimer?.cancel();
        _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => _socket?.sendMessage(_heartbeatFrame()));
      },
      onMessage: (event) {
        if (generation != _generation) return;
        _handleFrame(event);
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
    _heartbeatTimer?.cancel();
    _joinWatch?.cancel();
  }

  Uint8List _loginFrame() {
    final room = int.tryParse(_args?.roomId ?? '') ?? 0;
    final request = AcfunProtoWriter()
      ..integer(1, _everJoined ? _reloginCommand : _loginCommand)
      ..integer(2, room)
      ..integer(3, 0)
      ..string(4, '')
      ..integer(5, 1)
      ..integer(6, _appId)
      ..integer(7, _platformId)
      ..string(10, _deviceNo)
      ..integer(12, _socketVersion)
      ..integer(13, 0)
      ..integer(14, _clientId)
      ..string(15, _token ?? '')
      ..string(16, _sid)
      ..string(17, _sessionId)
      ..integer(18, 0)
      ..string(19, '-');
    return _frame(_everJoined ? _reloginCommand : _loginCommand, request.toBytes());
  }

  static Uint8List _heartbeatFrame() => Uint8List.fromList(const <int>[_magic, 0, 1, 0]);

  Uint8List _ackFrame({required String offset, required String msgId, required int repeat}) {
    final room = int.tryParse(_args?.roomId ?? '') ?? 0;
    final request = AcfunProtoWriter()
      ..integer(1, _ackCommand)
      ..integer(2, room)
      ..integer(3, 0)
      ..string(4, offset)
      ..string(5, msgId)
      ..integer(6, repeat);
    return _frame(_ackCommand, request.toBytes());
  }

  static Uint8List _frame(int command, List<int> content) {
    final message = (AcfunProtoWriter()..bytes(7, content)).toBytes();
    final header = ByteData(18)
      ..setUint8(0, _magic)
      ..setInt16(1, 3)
      ..setUint8(3, 1)
      ..setInt16(4, 12)
      ..setInt32(6, command)
      ..setInt32(10, message.length);
    return (BytesBuilder(copy: false)
          ..add(header.buffer.asUint8List())
          ..add(message))
        .toBytes();
  }

  void _handleFrame(Object? data) {
    if (data is! List<int>) return;
    final bytes = data is Uint8List ? data : Uint8List.fromList(data);
    if (bytes.length >= 4 && bytes[3] == 0) return;
    final packet = _packet(bytes);
    if (packet == null) return;
    final (command, map) = packet;
    switch (command) {
      case _statusCommand:
        if (_int(map['type']) != 1) return;
        if (_int(map['status']) == 1) {
          _answered = true;
          final session = _text(map['socsid']);
          if (session.isNotEmpty) _sessionId = session;
          if (!_joined) {
            _joined = true;
            _everJoined = true;
            _refusals = 0;
            _joinWatch?.cancel();
            markConnected();
            onReady?.call();
          }
        } else {
          final errorNo = _int(map['errorno']) ?? 0;
          if (errorNo == _tokenRejected) _token = null;
          _refusals++;
          if (_refusals > _maxRefusals) {
            onClose?.call('酷狗直播：登录被拒（errorno $errorNo ${_text(map['msg'])}）');
          }
          _socket?.close();
        }
        break;
      case _chatCommand:
        final message = _chat(map);
        if (message != null) onMessage?.call(message);
        break;
      case _audienceCommand:
        for (final message in _audience(map)) {
          onMessage?.call(message);
        }
        break;
      case _giftCommand:
        if (_int(map['ack']) == 1) {
          _socket?.sendMessage(
            _ackFrame(
              offset: _text(map['offset']),
              msgId: _text(map['msgId']),
              repeat: _int(map['rpt']) ?? 0,
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  (int, Map<String, Object?>)? _packet(Uint8List frame) {
    if (frame.length < 10) return null;
    final view = ByteData.sublistView(frame);
    final start = 6 + view.getInt16(4);
    if (start < 10 || start > frame.length) return null;
    final command = view.getInt32(6);
    final envelope = AcfunProtoMessage.decode(Uint8List.sublistView(frame, start));
    final content = _uncompress(envelope.bytes(7) ?? Uint8List(0), envelope.integer(5) ?? 0);
    if (content == null) return null;
    final Map<String, Object?>? packet;
    if ((envelope.integer(6) ?? 0) == 1) {
      packet = command == _statusCommand
          ? _status(AcfunProtoMessage.decode(content))
          : _content(AcfunProtoMessage.decode(content), command);
    } else {
      try {
        final decoded = json.decode(utf8.decode(content));
        packet = decoded is Map ? Map<String, Object?>.from(decoded) : null;
      } catch (_) {
        return null;
      }
    }
    if (packet == null) return null;
    return (command, packet);
  }

  static Map<String, Object?> _status(AcfunProtoMessage status) => <String, Object?>{
    'type': status.integer(2) ?? 0,
    'status': status.integer(4) ?? 0,
    'errorno': status.integer(5) ?? 0,
    'msg': status.string(6) ?? '',
    'socsid': status.string(7) ?? '',
  };

  static Map<String, Object?> _content(AcfunProtoMessage message, int command) {
    final packet = <String, Object?>{
      'cmd': message.integer(1) ?? 0,
      'roomid': message.integer(3) ?? 0,
      'receiverid': message.integer(4) ?? 0,
      'senderid': message.integer(6) ?? 0,
      'senderkugouid': message.integer(7) ?? 0,
      'time': message.integer(11) ?? 0,
    };
    if (command != _chatCommand || (message.integer(16) ?? 0) != 1) return packet;
    final chat = AcfunProtoMessage.decode(message.bytes(2) ?? Uint8List(0));
    final intimacy = AcfunProtoMessage.decode(message.bytes(14) ?? Uint8List(0)).message(39);
    final sinfo = message.message(15);
    return <String, Object?>{
      ...packet,
      'content': <String, Object?>{
        'chatmsg': chat.string(1) ?? '',
        'senderid': chat.integer(2) ?? 0,
        'senderkugouid': chat.integer(3) ?? 0,
        'sendername': chat.string(4) ?? '',
        'senderrichlevel': chat.integer(5) ?? 0,
        'senderrichlevelV2': chat.integer(17) ?? 0,
        'receiverid': chat.integer(6) ?? 0,
        'seq': chat.integer(12) ?? 0,
        'privateType': chat.integer(13) ?? 0,
      },
      if (intimacy != null)
        'ext': <String, Object?>{
          'intimacyVo': <String, Object?>{
            'nameplate': intimacy.string(1) ?? '',
            'level': intimacy.integer(2) ?? 0,
            'type': intimacy.integer(3) ?? 0,
            'lightUp': intimacy.integer(4) ?? 0,
          },
        },
      if (sinfo != null)
        'sinfo': <String, Object?>{'ck': sinfo.integer(5) ?? 0, 'ckid': sinfo.string(8) ?? ''},
    };
  }

  LiveMessage? _chat(Map<String, Object?> packet) {
    if ((_int(packet['receiverid']) ?? 0) != 0 || (_int(packet['senderid']) ?? 0) < 0) return null;
    final content = packet['content'];
    if (content is! Map || _int(content['privateType']) == 1) return null;
    final room = _int(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != (_args?.roomId ?? '')) return null;
    final text = _clean(content['chatmsg']);
    if (text.isEmpty) return null;
    final sinfo = packet['sinfo'];
    final sinfoMap = sinfo is Map ? sinfo : const <dynamic, dynamic>{};
    final sender = _int(packet['senderid']) ?? _int(content['senderid']);
    final alias = _int(sinfoMap['ck']) == 1 ? _text(sinfoMap['ckid']) : '';
    final rawLevel = _int(content['senderrichlevelV2']);
    final level = rawLevel != null && rawLevel > 0 ? rawLevel : _int(content['senderrichlevel']);
    final badge = _badge(packet['ext']);
    final messageId = _text(packet['msgId']);
    final seq = _int(content['seq']) ?? 0;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _clean(content['sendername']),
      userId: alias.isNotEmpty ? alias : (sender == null ? '' : '$sender'),
      message: text,
      color: LiveMessageColor.white,
      userLevel: level == null || level <= 0 ? '' : '$level',
      fansName: badge?.name ?? '',
      fansLevel: badge == null ? '' : '${badge.level}',
      messageId: messageId.isNotEmpty
          ? messageId
          : sender != null && seq > 0
          ? '$sender:$seq'
          : '',
      sentAt: _time(packet['time']),
    );
  }

  List<LiveMessage> _audience(Map<String, Object?> packet) {
    final content = packet['content'];
    if (content is! Map || content['actionId'] != 'roomAuNumber') return const <LiveMessage>[];
    final room = _int(packet['roomid']) ?? 0;
    if (room != 0 && '$room' != (_args?.roomId ?? '')) return const <LiveMessage>[];
    final data = content['data'];
    if (data is! Map) return const <LiveMessage>[];
    final messages = <LiveMessage>[];
    for (final (key, kind) in const <(String, LiveAudienceMetricKind)>[
      ('count', LiveAudienceMetricKind.onlineViewers),
      ('visited', LiveAudienceMetricKind.totalViewers),
    ]) {
      final value = _int(data[key]);
      if (value == null || value < 0) continue;
      messages.add(
        LiveMessage(
          type: LiveMessageType.online,
          userName: '',
          message: '',
          color: LiveMessageColor.white,
          data: LiveAudienceUpdate(kind: kind, value: value),
        ),
      );
    }
    return messages;
  }

  static ({String name, int level})? _badge(Object? ext) {
    var value = ext;
    if (value is String) {
      if (_badEscape.hasMatch(value)) return null;
      try {
        value = json.decode(Uri.decodeComponent(value));
      } catch (_) {
        return null;
      }
    }
    final intimacy = value is Map ? value['intimacyVo'] : null;
    if (intimacy is! Map) return null;
    final level = _int(intimacy['level']) ?? 0;
    final type = _int(intimacy['type']) ?? 0;
    final lightUp = _int(intimacy['lightUp']) ?? 0;
    if (level <= 0 || type < 1 || type > 4 || lightUp != 1) return null;
    return (name: _text(intimacy['nameplate']), level: level);
  }

  static Uint8List? _uncompress(Uint8List content, int compression) {
    switch (compression) {
      case 1:
        try {
          final plain = Uint8List.fromList(gzip.decode(content));
          return plain.length > _maxContentBytes ? null : plain;
        } catch (_) {
          return null;
        }
      case 2:
        try {
          return _snappy(content);
        } catch (_) {
          return null;
        }
      default:
        return content.length > _maxContentBytes ? null : content;
    }
  }

  static Uint8List _snappy(Uint8List input) {
    var position = 0;
    var length = 0;
    for (var shift = 0;; shift += 7) {
      if (position >= input.length || shift > 35) throw const FormatException('snappy length');
      final byte = input[position++];
      length |= (byte & 0x7f) << shift;
      if (byte < 0x80) break;
    }
    if (length <= 0 || length > _maxContentBytes) throw const FormatException('snappy length');
    final out = Uint8List(length);
    var written = 0;
    while (position < input.length) {
      final tag = input[position++];
      switch (tag & 0x03) {
        case 0:
          var size = tag >> 2;
          if (size < 60) {
            size += 1;
          } else {
            final bytes = size - 59;
            if (position + bytes > input.length) throw const FormatException('snappy literal length');
            var value = 0;
            for (var i = 0; i < bytes; i++) {
              value |= input[position + i] << (8 * i);
            }
            position += bytes;
            size = value + 1;
          }
          if (position + size > input.length || written + size > length) {
            throw const FormatException('snappy literal');
          }
          out.setRange(written, written + size, input, position);
          position += size;
          written += size;
          break;
        case 1:
          if (position >= input.length) throw const FormatException('snappy copy1');
          final size = 4 + ((tag >> 2) & 0x07);
          final offset = ((tag >> 5) << 8) | input[position++];
          written = _copy(out, written, offset, size, length);
          break;
        case 2:
          if (position + 2 > input.length) throw const FormatException('snappy copy2');
          final size = (tag >> 2) + 1;
          final offset = input[position] | (input[position + 1] << 8);
          position += 2;
          written = _copy(out, written, offset, size, length);
          break;
        default:
          if (position + 4 > input.length) throw const FormatException('snappy copy4');
          final size = (tag >> 2) + 1;
          final offset = input[position] |
              (input[position + 1] << 8) |
              (input[position + 2] << 16) |
              (input[position + 3] << 24);
          position += 4;
          written = _copy(out, written, offset, size, length);
          break;
      }
    }
    if (written != length) throw const FormatException('snappy short');
    return out;
  }

  static int _copy(Uint8List out, int written, int offset, int size, int length) {
    if (offset <= 0 || offset > written || written + size > length) {
      throw const FormatException('snappy copy');
    }
    for (var i = 0; i < size; i++) {
      out[written + i] = out[written - offset + i];
    }
    return written + size;
  }

  static String _clean(Object? value) => _text(value)
      .replaceAll(RegExp(r'[\u2027-\u202e]'), '')
      .trim();

  static DateTime? _time(Object? value) {
    final seconds = _int(value);
    if (seconds == null || seconds <= 0) return null;
    final millis = seconds > 100000000000 ? seconds : seconds * 1000;
    if (millis > 8640000000000000) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

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

  static String _uuid() {
    const hex = '0123456789abcdef';
    final random = Random.secure();
    final out = StringBuffer();
    for (final char in 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.split('')) {
      out.write(switch (char) {
        'x' => hex[random.nextInt(16)],
        'y' => hex[8 + random.nextInt(4)],
        _ => char,
      });
    }
    return out.toString();
  }
}
