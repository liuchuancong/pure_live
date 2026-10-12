import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku.dart';

/// The channel a yy connection joins: the top (`sid`) and sub (`ssid`)
/// channel numbers, as ints the binary join compares against the answers.
final class YyDanmakuArgs {
  /// A channel join target.
  const new({required this.topSid, required this.subSid});

  /// Top channel (`sid`).
  final int topSid;

  /// Sub channel (`ssid`).
  final int subSid;

  @override
  String toString() => 'YyDanmakuArgs($topSid/$subSid)';
}

/// YY's danmaku connection over one H5-service WebSocket: the anonymous
/// handshake ([YyDanmakuSession]) runs on every socket, the AP ping goes out
/// every 5 s once the AP login was sent, and a socket silent for 45 s or a
/// handshake that has not joined within 15 s is treated as dead.
///
/// Unlike the reference, which reconnects a refused or timed-out attempt up to
/// a limit, this build ends the stream on any handshake failure, a timeout or
/// silence — the caller's supervisor reconnects (the same division as the kick
/// and looklive sessions). A room that is not broadcasting joins the same way;
/// the chat channel stays open.
///
/// Archived from the reference and not run against the live service.
final class YyDanmakuConnection implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  YyDanmakuConnection._(this._protocol, this._socket) {
    _heartbeat = Timer.periodic(YyDanmakuProtocol.heartbeatInterval, (_) {
      if (_closed) return;
      final ping = _protocol.heartbeat();
      if (ping != null) _socket.add(ping);
    });
    _joinTimer = Timer(YyDanmakuProtocol.handshakeTimeout, () {
      if (!_ready) _fail(const SiteApiChangedError('yy danmaku: handshake timed out'));
    });
    _resetSilence();
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
    _socket.add(_protocol.beginHandshake());
  }

  /// Opens a connection for [args]; [random] makes the connection UUID (one
  /// per run, kept across the socket's lifetime).
  static Future<YyDanmakuConnection> connect(YyDanmakuArgs args, {Random? random}) async {
    final uuid = YyDanmakuProtocol.uuid(random ?? Random.secure());
    final socket = await WebSocket.connect(
      YyDanmakuProtocol.endpoint(uuid).toString(),
      headers: YyDanmakuProtocol.headers,
    );
    return YyDanmakuConnection._(YyDanmakuSession(topSid: args.topSid, subSid: args.subSid, uuid: uuid), socket);
  }

  final YyDanmakuSession _protocol;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _heartbeat;
  late final Timer _joinTimer;
  Timer? _silence;
  bool _ready = false;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed || data is! List<int>) return;
    _resetSilence();
    final batch = _protocol.consume(data);
    batch.outbound.forEach(_socket.add);
    if (batch.becameReady && !_ready) {
      _ready = true;
      _joinTimer.cancel();
    }
    batch.messages.forEach(_messages.add);
    if (batch.failure case final failure?) {
      _fail(SiteApiChangedError('yy danmaku: $failure'));
    }
  }

  void _resetSilence() {
    _silence?.cancel();
    _silence = Timer(
      YyDanmakuProtocol.inactivityTimeout,
      () => _fail(const SiteApiChangedError('yy danmaku: socket silent')),
    );
  }

  void _fail(Object error, [StackTrace? stack]) {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_socket.close());
    if (!_messages.isClosed) {
      _messages.addError(error, stack ?? StackTrace.current);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
    _silence?.cancel();
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
