import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku.dart';

/// The link of one socket: sequence numbers, the instance id and the session
/// key the register answer brings, and the web client's frames (register,
/// keep-alive, enter room, heartbeat, push acknowledgement). The seal and open
/// go through the `cryptography` AES, so every builder is `async`.
final class AcfunDanmakuLink {
  /// Starts a link for [args]; [security] is its decoded `acSecurity`
  /// ([AcfunDanmakuProtocol.securityKey]) and [random] draws the IVs.
  new(this.args, {required List<int> security, Random? random})
    : _security = Uint8List.fromList(security),
      _random = random ?? Random.secure(),
      _uid = int.tryParse(args.userId) ?? 0;

  /// The arguments.
  final AcfunDanmakuArgs args;

  final Uint8List _security;
  final Random _random;
  final int _uid;
  int _seq = 1;
  int _instanceId = 0;
  int _heartbeat = 0;
  Uint8List? _sessionKey;

  /// Whether the register answer brought the session key.
  bool get registered => _sessionKey != null;

  /// `Basic.Register`, sealed with `acSecurity`, the service token in the
  /// header: `RegisterRequest {appInfo 1 {sdkVersion "link-sdk", linkVersion
  /// "1.2.1"}, deviceInfo 2 {platformType 6 (H5), deviceModel "h5", did 5},
  /// presenceStatus 4 1, appActiveStatus 5 1, instanceId 8 0, ztCommonInfo
  /// 11 {kpn, kpf, uid 4, did 5}}`.
  Future<Uint8List> register() {
    final request = ProtoWriter()
      ..bytes(
        1,
        (ProtoWriter()
              ..string(1, 'link-sdk')
              ..string(4, '1.2.1'))
            .toBytes(),
      )
      ..bytes(
        2,
        (ProtoWriter()
              ..integer(1, 6)
              ..string(3, 'h5')
              ..string(5, args.deviceId))
            .toBytes(),
      )
      ..integer(4, 1)
      ..integer(5, 1)
      ..integer(8, 0)
      ..bytes(
        11,
        (ProtoWriter()
              ..string(1, AcfunDanmakuProtocol.kpn)
              ..string(2, AcfunDanmakuProtocol.kpf)
              ..integer(4, _uid)
              ..string(5, args.deviceId))
            .toBytes(),
      );
    return _send(AcfunDanmakuProtocol.registerCommand, request.toBytes(), serviceToken: true);
  }

  /// `Basic.KeepAlive {presenceStatus 1, appActiveStatus 1}`.
  Future<Uint8List> keepAlive() => _send(
    AcfunDanmakuProtocol.keepAliveCommand,
    (ProtoWriter()
          ..integer(1, 1)
          ..integer(2, 1))
        .toBytes(),
  );

  /// Enters the room with [ticket]: `ZtLiveCsEnterRoom {isAuthor 1 false,
  /// reconnectCount 2, enterRoomAttach 4, clientLiveSdkVersion 5}`.
  Future<Uint8List> enterRoom({required String ticket, int reconnects = 0}) => _command(
    'ZtLiveCsEnterRoom',
    (ProtoWriter()
          ..integer(1, 0)
          ..integer(2, reconnects)
          ..string(4, args.enterRoomAttach)
          ..string(5, AcfunDanmakuProtocol.sdkVersion))
        .toBytes(),
    ticket,
  );

  /// The next room heartbeat: `ZtLiveCsHeartbeat {clientTimestampMs 1,
  /// sequence 2}`, the sequence counting from 0 on this link.
  Future<Uint8List> heartbeat({required String ticket, required DateTime now}) => _command(
    'ZtLiveCsHeartbeat',
    (ProtoWriter()
          ..integer(1, now.millisecondsSinceEpoch)
          ..integer(2, _heartbeat++))
        .toBytes(),
    ticket,
  );

  /// The acknowledgement of [push]: its command without payload, the header
  /// carrying the push's sequence id; the link's own sequence does not move.
  Future<Uint8List> pushAck(AcfunDanmakuPacket push) =>
      _send(push.command, null, headerSeq: push.seqId, advance: false);

  /// `ZtLiveCsCmd {cmdType 1, payload 2, ticket 3, liveId 4}`.
  Future<Uint8List> _command(String type, List<int> payload, String ticket) => _send(
    AcfunDanmakuProtocol.roomCommand,
    (ProtoWriter()
          ..string(1, type)
          ..bytes(2, payload)
          ..string(3, ticket)
          ..string(4, args.liveId))
        .toBytes(),
  );

  Future<Uint8List> _send(
    String command,
    List<int>? data, {
    bool serviceToken = false,
    int? headerSeq,
    bool advance = true,
  }) async {
    final upstream = ProtoWriter()
      ..string(1, command)
      ..integer(2, _seq)
      ..integer(3, 1);
    if (data != null) upstream.bytes(4, data);
    upstream.string(9, AcfunDanmakuProtocol.subBiz);
    final plain = upstream.toBytes();
    final key = serviceToken ? _security : _sessionKey;
    if (key == null) throw StateError('AcFun link: $command before the register answer');
    final header = ProtoWriter()
      ..integer(1, AcfunDanmakuProtocol.appId)
      ..integer(2, _uid)
      ..integer(3, _instanceId)
      ..integer(7, plain.length)
      ..integer(8, serviceToken ? 1 : 2);
    if (serviceToken) {
      header.bytes(
        9,
        (ProtoWriter()
              ..integer(1, 1)
              ..string(2, args.token))
            .toBytes(),
      );
    }
    header
      ..integer(10, headerSeq ?? _seq)
      ..string(12, AcfunDanmakuProtocol.kpn);
    if (advance) _seq++;
    final iv = Uint8List.fromList(List.generate(16, (_) => _random.nextInt(256)));
    final sealed = await AcfunDanmakuProtocol.seal(plain, key, iv);
    return AcfunDanmakuProtocol.frame(header.toBytes(), sealed);
  }

  /// Opens one received [frame]. The register answer's session key and
  /// instance id are kept for everything after it. Throws [FormatException]
  /// for a frame that does not add up or open (a wrong key included).
  Future<AcfunDanmakuPacket> read(List<int> frame) async {
    final (:header, :payload) = AcfunDanmakuProtocol.unframe(frame);
    final plain = switch (header.integer(8) ?? 0) {
      0 => payload,
      1 => await AcfunDanmakuProtocol.open(payload, _security),
      2 => await AcfunDanmakuProtocol.open(
        payload,
        _sessionKey ?? (throw const FormatException('AcFun frame before the session key')),
      ),
      final mode => throw FormatException('AcFun encryption mode $mode'),
    };
    final down = ProtoMessage.decode(plain);
    final packet = AcfunDanmakuPacket(
      command: down.string(1) ?? '',
      seqId: header.integer(10) ?? 0,
      payload: down.bytes(4) ?? Uint8List(0),
      errorCode: down.integer(3) ?? 0,
    );
    if (packet.command == AcfunDanmakuProtocol.registerCommand && packet.errorCode == 0) {
      final answer = ProtoMessage.decode(packet.payload);
      final key = answer.bytes(2);
      if (key != null && key.length == 16) {
        _sessionKey = Uint8List.fromList(key);
        _instanceId = answer.integer(3) ?? 0;
      }
    }
    return packet;
  }
}

/// An AcFun danmaku session over one link WebSocket
/// (`wss://link.xiatou.com/`): register (sealed with `acSecurity`), whose
/// answer brings the session key, then a keep-alive and the enter-room
/// command with the first ticket. The enter-room answer opens the stream; a
/// room heartbeat goes out every 10 s (a keep-alive with every fifth) and
/// every push is acknowledged.
///
/// A dead ticket is rotated to the next one on the same socket, as the web
/// client does; once every ticket has failed, the broadcast closed, reopened
/// or was banned, the register or a command was refused, or the socket failed,
/// the stream ends. Reconnecting belongs to the caller's supervisor, which
/// owns the retry policy and would re-fetch the tickets — the same division as
/// the kick, huya and douyu sessions, so a second policy inside the adapter
/// does not fight the first. The room's gift table is not fetched, so gifts
/// carry only their signal's name, count and combo id.
///
/// Archived from the reference and not run against the live service.
final class AcfunDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  AcfunDanmakuSession._(this._link, this._socket) {
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
    unawaited(_start());
  }

  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const int _heartbeatsPerKeepAlive = 5;

  final AcfunDanmakuLink _link;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  Timer? _heartbeat;
  int _heartbeats = 0;
  int _ticket = 0;
  int _ticketFailures = 0;
  bool _joined = false;
  bool _closed = false;

  /// Opens a session for [args].
  static Future<AcfunDanmakuSession> connect(AcfunDanmakuArgs args) async {
    final key = AcfunDanmakuProtocol.securityKey(args.security);
    if (key == null) throw const SiteApiChangedError('acfun danmaku: no acSecurity');
    if (args.tickets.isEmpty) throw const SiteApiChangedError('acfun danmaku: no tickets');
    final socket = await WebSocket.connect(AcfunDanmakuProtocol.endpoint.toString(), headers: args.headers);
    return AcfunDanmakuSession._(AcfunDanmakuLink(args, security: key), socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  Future<void> _start() async {
    try {
      _socket.add(await _link.register());
    } on Object catch (error, stack) {
      _fail(error, stack);
    }
  }

  void _onData(Object? data) {
    if (_closed || data is! List<int>) return;
    unawaited(_handle(data));
  }

  Future<void> _handle(List<int> frame) async {
    final AcfunDanmakuPacket packet;
    try {
      packet = await _link.read(frame);
    } on FormatException {
      // A frame that does not add up or open: dropped on its own.
      return;
    }
    if (_closed) return;
    switch (packet.command) {
      case AcfunDanmakuProtocol.registerCommand:
        if (packet.errorCode != 0 || !_link.registered) {
          _failWith('acfun danmaku: register refused (${packet.errorCode})');
          return;
        }
        _send(await _link.keepAlive());
        _send(await _link.enterRoom(ticket: _currentTicket));
      case AcfunDanmakuProtocol.roomCommand:
        if (packet.errorCode != 0) {
          _failWith('acfun danmaku: command refused (${packet.errorCode})');
          return;
        }
        final ({String type, int code, Uint8List payload}) ack;
        try {
          ack = AcfunDanmakuProtocol.ack(packet.payload);
        } on FormatException {
          return;
        }
        if (ack.code != 0) {
          if (AcfunDanmakuProtocol.ticketErrors.contains(ack.code)) {
            await _nextTicket();
          } else {
            _failWith('acfun danmaku: command error ${ack.code}');
          }
        } else if (ack.type == AcfunDanmakuProtocol.enterRoomAck && !_joined) {
          _joined = true;
          _ticketFailures = 0;
          _heartbeat = Timer.periodic(_heartbeatInterval, (_) => unawaited(_beat()));
        }
      case AcfunDanmakuProtocol.messageCommand:
        _send(await _link.pushAck(packet));
        final push = AcfunDanmakuProtocol.push(packet.payload);
        for (final message in push.messages) {
          if (_closed) return;
          _messages.add(message);
        }
        if (push.ticketInvalid) {
          await _nextTicket();
        } else if (AcfunDanmakuProtocol.refreshingStatuses.contains(push.statusChanged)) {
          _failWith('acfun danmaku: broadcast status ${push.statusChanged}');
        }
      default:
        if (packet.command.startsWith(AcfunDanmakuProtocol.pushPrefix)) {
          _send(await _link.pushAck(packet));
        } else if (packet.errorCode != 0) {
          _failWith('acfun danmaku: ${packet.command} refused (${packet.errorCode})');
        }
    }
  }

  Future<void> _beat() async {
    if (_closed || !_joined) return;
    _heartbeats += 1;
    if (_heartbeats % _heartbeatsPerKeepAlive == 0) _send(await _link.keepAlive());
    _send(await _link.heartbeat(ticket: _currentTicket, now: DateTime.now()));
  }

  /// The web client's answer to a dead ticket: enter again with the next one.
  /// Once every ticket has failed, the stream ends.
  Future<void> _nextTicket() async {
    _ticketFailures += 1;
    if (_ticketFailures >= args.tickets.length) {
      _failWith('acfun danmaku: every ticket failed', stack: StackTrace.current);
      return;
    }
    _ticket = (_ticket + 1) % args.tickets.length;
    _joined = false;
    _heartbeat?.cancel();
    _send(await _link.enterRoom(ticket: _currentTicket));
  }

  String get _currentTicket => args.tickets[_ticket % args.tickets.length];

  /// The join arguments (the broadcast id, tickets and visitor the link
  /// carries).
  AcfunDanmakuArgs get args => _link.args;

  void _send(Uint8List data) {
    if (!_closed) _socket.add(data);
  }

  void _failWith(String message, {StackTrace? stack}) =>
      _fail(SiteApiChangedError(message), stack ?? StackTrace.current);

  void _fail(Object error, StackTrace stack) {
    if (_closed) return;
    _closed = true;
    _heartbeat?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) return;
    _closed = true;
    _heartbeat?.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
