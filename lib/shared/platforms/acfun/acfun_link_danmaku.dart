import 'dart:async';
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_danmaku.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_protobuf.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';

class AcfunLinkDanmaku extends LiveDanmaku {
  AcfunLinkDanmaku();

  static const String _endpoint = 'wss://link.xiatou.com/';
  static const int _appId = 13;
  static const String _kpn = 'ACFUN_APP';
  static const String _kpf = 'PC_WEB';
  static const String _subBiz = 'mainApp';
  static const String _sdkVersion = 'kwai-acfun-live-link';
  static const String _registerCommand = 'Basic.Register';
  static const String _keepAliveCommand = 'Basic.KeepAlive';
  static const String _roomCommand = 'Global.ZtLiveInteractive.CsCmd';
  static const String _messageCommand = 'Push.ZtLiveInteractive.Message';
  static const String _pushPrefix = 'Push.';
  static const String _enterRoomAck = 'ZtLiveCsEnterRoomAck';
  static const Set<int> _ticketErrors = <int>{2, 3, 4, 7};
  static const Set<int> _refreshingStatuses = <int>{1, 2, 4};
  static const int _heartbeatsPerKeepAlive = 5;
  static const int _maxRefreshes = 3;

  AcfunDanmakuArgs? _args;
  WebScoketUtils? _socket;
  var _generation = 0;
  var _running = false;
  Uint8List? _securityKey;
  Uint8List? _sessionKey;
  var _uid = 0;
  var _seq = 1;
  var _instanceId = 0;
  var _heartbeat = 0;
  var _heartbeats = 0;
  var _ticketIndex = 0;
  var _ticketFailures = 0;
  var _opens = 0;
  var _refreshes = 0;
  var _joined = false;
  Timer? _heartbeatTimer;
  Timer? _joinWatch;

  @override
  Future start(dynamic args) async {
    if (args is! AcfunDanmakuArgs) {
      onClose?.call('AcFun：没有可用的弹幕参数');
      return;
    }
    if (args.security.isEmpty || args.tickets.isEmpty) {
      onClose?.call('AcFun：缺少 acSecurity 或票据');
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
        await _runSocket(generation);
        attempt = 0;
      } catch (error) {
        if (generation != _generation) return;
        CoreLog.error('AcFun link failed: $error');
        onReconnect?.call('AcFun 弹幕连接失败，正在重试');
        attempt++;
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(Duration(seconds: attempt.clamp(1, 8)));
    }
  }

  Future<void> _runSocket(int generation) async {
    final ended = Completer<void>();
    final args = _args!;
    _securityKey = _security(args.security);
    if (_securityKey == null) {
      onClose?.call('AcFun：acSecurity 不是 Base64 的 AES-128 密钥');
      return;
    }
    _sessionKey = null;
    _uid = int.tryParse(args.userId) ?? 0;
    _seq = 1;
    _instanceId = 0;
    _heartbeat = 0;
    _heartbeats = 0;
    _ticketFailures = 0;
    _joined = false;
    _opens++;
    final socket = WebScoketUtils(
      url: _endpoint,
      heartBeatTime: 0,
      headers: const <String, String>{'origin': 'https://www.acfun.cn'},
      onReady: () {
        if (generation != _generation) return;
        _socket?.sendMessage(_register());
      },
      onMessage: (event) {
        if (generation != _generation) return;
        unawaited(_handleFrame(event, ended));
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

  static Uint8List? _security(String encoded) {
    try {
      final key = base64.decode(encoded);
      return key.length == 16 ? Uint8List.fromList(key) : null;
    } catch (_) {
      return null;
    }
  }

  String get _ticket {
    final tickets = _args!.tickets;
    return tickets[_ticketIndex.clamp(0, tickets.length - 1)];
  }

  Uint8List _register() {
    final request = AcfunProtoWriter()
      ..message(
        1,
        AcfunProtoWriter()
          ..string(1, 'link-sdk')
          ..string(4, '1.2.1'),
      )
      ..integer(4, 1)
      ..integer(5, 1)
      ..integer(8, 0)
      ..message(
        11,
        AcfunProtoWriter()
          ..string(1, _kpn)
          ..string(2, _kpf)
          ..integer(4, _uid)
          ..string(5, _args?.deviceId ?? ''),
      );
    return _send(_registerCommand, request.toBytes(), serviceToken: true);
  }

  Uint8List _keepAlive() =>
      _send(_keepAliveCommand, (AcfunProtoWriter()..integer(1, 1)..integer(2, 1)).toBytes());

  Uint8List _roomCommandFrame(String type, AcfunProtoWriter payload, String ticket) => _send(
    _roomCommand,
    (AcfunProtoWriter()
          ..string(1, type)
          ..bytes(2, payload.toBytes())
          ..string(3, ticket)
          ..string(4, _args?.liveId ?? ''))
        .toBytes(),
  );

  Uint8List _enterRoom(String ticket) => _roomCommandFrame(
    'ZtLiveCsEnterRoom',
    AcfunProtoWriter()
      ..integer(1, 0)
      ..integer(2, _opens - 1)
      ..string(4, _args?.enterRoomAttach ?? '')
      ..string(5, _sdkVersion),
    ticket,
  );

  Uint8List _heartbeatFrame(String ticket) => _roomCommandFrame(
    'ZtLiveCsHeartbeat',
    AcfunProtoWriter()
      ..integer(1, DateTime.now().millisecondsSinceEpoch)
      ..integer(2, _heartbeat++),
    ticket,
  );

  Uint8List _pushAck(int seqId) => _send(_lastPushCommand ?? '', null, headerSeq: seqId, advance: false);

  String? _lastPushCommand;

  Uint8List _send(String command, List<int>? data, {bool serviceToken = false, int? headerSeq, bool advance = true}) {
    final key = serviceToken ? _securityKey : _sessionKey;
    if (key == null) throw StateError('AcFun link: $command before the register answer');
    final upstream = AcfunProtoWriter()
      ..string(1, command)
      ..integer(2, _seq)
      ..integer(3, 1);
    if (data != null) upstream.bytes(4, data);
    upstream.string(9, _subBiz);
    final plain = upstream.toBytes();
    final iv = Uint8List.fromList(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final sealed = Uint8List.fromList(<int>[...iv, ..._encrypt(plain, key, iv)]);
    final header = AcfunProtoWriter()
      ..integer(1, _appId)
      ..integer(2, _uid)
      ..integer(3, _instanceId)
      ..integer(7, plain.length)
      ..integer(8, serviceToken ? 1 : 2);
    if (serviceToken) {
      header.bytes(
        9,
        (AcfunProtoWriter()
              ..integer(1, 1)
              ..string(2, _args?.visitorToken ?? ''))
            .toBytes(),
      );
    }
    if (headerSeq != null) header.integer(10, headerSeq);
    header.string(12, _kpn);
    final headerBytes = header.toBytes();
    final frame = BytesBuilder(copy: false);
    frame.add(<int>[0xAB, 0xCD, 0x00, 0x01]);
    frame.add(_u32(headerBytes.length));
    frame.add(_u32(sealed.length));
    frame.add(headerBytes);
    frame.add(sealed);
    if (advance) _seq++;
    return frame.toBytes();
  }

  static List<int> _u32(int value) =>
      <int>[(value >> 24) & 0xff, (value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff];

  Future<void> _handleFrame(Object? event, Completer<void> ended) async {
    if (event is! List<int>) return;
    final packet = _read(event);
    if (packet == null) return;
    switch (packet.command) {
      case _registerCommand:
        if (packet.errorCode != 0 || _sessionKey == null) {
          await _refresh(ended, 'Register refused (${packet.errorCode})');
          return;
        }
        _socket?.sendMessage(_keepAlive());
        _socket?.sendMessage(_enterRoom(_ticket));
        _joinWatch?.cancel();
        _joinWatch = Timer(const Duration(seconds: 10), () {
          if (_running && !_joined && !ended.isCompleted) ended.complete();
        });
        break;
      case _roomCommand:
        if (packet.errorCode != 0) {
          await _handleCommandError(ended, packet.errorCode);
          return;
        }
        final ack = _ack(packet.payload);
        if (ack.type == _enterRoomAck) {
          if (!_joined) {
            _joined = true;
            _ticketFailures = 0;
            _refreshes = 0;
            markConnected();
            onReady?.call();
          }
          _startHeartbeat(ack.payload);
        } else if (ack.code != 0) {
          await _handleCommandError(ended, ack.code);
        }
        break;
      case _messageCommand:
        _lastPushCommand = packet.command;
        _socket?.sendMessage(_pushAck(packet.seqId));
        final push = _push(packet.payload);
        for (final message in push.messages) {
          onMessage?.call(message);
        }
        if (push.ticketInvalid) {
          await _nextTicket(ended);
        } else if (push.statusChanged != null && _refreshingStatuses.contains(push.statusChanged)) {
          await _refresh(ended, 'Broadcast status ${push.statusChanged}');
        }
        break;
      default:
        if (packet.command.startsWith(_pushPrefix)) {
          _lastPushCommand = packet.command;
          _socket?.sendMessage(_pushAck(packet.seqId));
        } else if (packet.errorCode != 0) {
          await _handleCommandError(ended, packet.errorCode);
        }
        break;
    }
  }

  void _startHeartbeat(List<int> enterRoomAck) {
    final millis = AcfunProtoMessage.decode(enterRoomAck).integer(1) ?? 0;
    final interval = millis > 0 ? Duration(milliseconds: millis) : const Duration(seconds: 10);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(interval, (_) {
      _heartbeats++;
      if (_heartbeats % _heartbeatsPerKeepAlive == 0) _socket?.sendMessage(_keepAlive());
      _socket?.sendMessage(_heartbeatFrame(_ticket));
    });
  }

  Future<void> _handleCommandError(Completer<void> ended, int code) async {
    if (_ticketErrors.contains(code)) {
      await _nextTicket(ended);
      return;
    }
    await _refresh(ended, 'Command error $code');
  }

  Future<void> _nextTicket(Completer<void> ended) async {
    _ticketFailures++;
    if (_ticketFailures >= _args!.tickets.length) {
      await _refresh(ended, 'Every ticket failed');
      return;
    }
    _ticketIndex = (_ticketIndex + 1) % _args!.tickets.length;
    _socket?.sendMessage(_enterRoom(_ticket));
  }

  Future<void> _refresh(Completer<void> ended, String reason) async {
    final refresh = _args?.refresh;
    if (refresh == null || _refreshes >= _maxRefreshes) {
      onClose?.call('AcFun 弹幕结束：$reason');
      if (!ended.isCompleted) ended.complete();
      return;
    }
    _refreshes++;
    try {
      final fresh = await refresh();
      if (!_running) return;
      _args = fresh;
      _securityKey = _security(fresh.security);
      _ticketIndex = 0;
      _ticketFailures = 0;
      if (!ended.isCompleted) ended.complete();
    } catch (error) {
      CoreLog.error('AcFun refresh failed: $error');
      if (!ended.isCompleted) ended.complete();
    }
  }

  _Packet? _read(List<int> frame) {
    final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
    if (bytes.length < 12 || bytes[0] != 0xAB || bytes[1] != 0xCD) return null;
    if (bytes[2] != 0x00 || bytes[3] != 0x01) return null;
    final headerLength = (bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7];
    final payloadLength = (bytes[8] << 24) | (bytes[9] << 16) | (bytes[10] << 8) | bytes[11];
    if (headerLength < 0 || payloadLength < 0) return null;
    if (12 + headerLength + payloadLength > bytes.length) return null;
    final header = AcfunProtoMessage.decode(bytes.sublist(12, 12 + headerLength));
    final sealed = bytes.sublist(12 + headerLength, 12 + headerLength + payloadLength);
    if (sealed.length < 32) return null;
    final mode = header.integer(8) ?? 0;
    final key = switch (mode) {
      1 => _securityKey,
      2 => _sessionKey,
      _ => null,
    };
    if (key == null) return null;
    final Uint8List plain;
    try {
      plain = _decrypt(sealed.sublist(16), key, sealed.sublist(0, 16));
    } catch (_) {
      return null;
    }
    final down = AcfunProtoMessage.decode(plain);
    final packet = _Packet(
      command: down.string(1) ?? '',
      seqId: header.integer(10) ?? 0,
      payload: down.bytes(4) ?? Uint8List(0),
      errorCode: down.integer(3) ?? 0,
      error: down.string(5) ?? '',
    );
    _instanceId = header.integer(3) ?? _instanceId;
    if (packet.command == _registerCommand && packet.errorCode == 0) {
      final answer = AcfunProtoMessage.decode(packet.payload);
      final key = answer.bytes(2);
      if (key != null && key.length == 16) {
        _sessionKey = Uint8List.fromList(key);
        _instanceId = answer.integer(3) ?? _instanceId;
      }
    }
    return packet;
  }

  static ({String type, int code, List<int> payload}) _ack(List<int> payload) {
    final message = AcfunProtoMessage.decode(payload);
    return (type: message.string(1) ?? '', code: message.integer(2) ?? 0, payload: message.bytes(4) ?? const <int>[]);
  }

  _Push _push(List<int> payload) {
    final messages = <LiveMessage>[];
    final message = AcfunProtoMessage.decode(payload);
    var body = message.bytes(3) ?? Uint8List(0);
    if (message.integer(2) == 2) {
      try {
        body = Uint8List.fromList(gzip.decode(body));
      } catch (_) {
        return _Push(messages);
      }
    }
    switch (message.string(1)) {
      case 'ZtLiveScActionSignal':
        for (final signal in _signals(body)) {
          if (signal.string(1) != 'CommonActionSignalComment') continue;
          for (final chunk in signal.chunks(2)) {
            final chat = _comment(chunk);
            if (chat != null) messages.add(chat);
          }
        }
        break;
      case 'ZtLiveScStateSignal':
        for (final signal in _signals(body)) {
          if (signal.string(1) != 'CommonStateSignalDisplayInfo') continue;
          final watching = AcfunProtoMessage.decode(signal.bytes(2) ?? Uint8List(0)).integer(1) ?? -1;
          if (watching < 0) continue;
          messages.add(
            LiveMessage(
              type: LiveMessageType.online,
              userName: '',
              message: '',
              color: LiveMessageColor.white,
              data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: watching),
            ),
          );
        }
        break;
      case 'ZtLiveScTicketInvalid':
        return _Push(messages, ticketInvalid: true);
      case 'ZtLiveScStatusChanged':
        return _Push(messages, statusChanged: AcfunProtoMessage.decode(body).integer(1) ?? 0);
      default:
        break;
    }
    return _Push(messages);
  }

  static List<AcfunProtoMessage> _signals(Uint8List body) =>
      AcfunProtoMessage.decode(body).messages(1);

  static LiveMessage? _comment(Uint8List payload) {
    final signal = AcfunProtoMessage.decode(payload);
    final text = signal.string(1) ?? '';
    final user = signal.message(3);
    if (text.isEmpty || user == null) return null;
    final id = user.integer(1);
    final millis = signal.integer(2);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: user.string(2) ?? '',
      userId: id == null || id <= 0 ? '' : '$id',
      message: text,
      color: LiveMessageColor.white,
      sentAt: millis == null || millis <= 0 || millis > 8640000000000000
          ? null
          : DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }

  // ---------------------------------------------------------------- AES-CBC

  static Uint8List _encrypt(List<int> plain, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher.process(Uint8List.fromList(plain));
  }

  static Uint8List _decrypt(List<int> sealed, Uint8List key, Uint8List iv) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        false,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
          null,
        ),
      );
    return cipher.process(Uint8List.fromList(sealed));
  }
}

class _Packet {
  const _Packet({
    required this.command,
    required this.seqId,
    required this.payload,
    required this.errorCode,
    required this.error,
  });

  final String command;
  final int seqId;
  final List<int> payload;
  final int errorCode;
  final String error;
}

class _Push {
  const _Push(this.messages, {this.ticketInvalid = false, this.statusChanged});

  final List<LiveMessage> messages;
  final bool ticketInvalid;
  final int? statusChanged;
}
