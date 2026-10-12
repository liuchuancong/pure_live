import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku.dart';

/// A SOOP danmaku session over one WebSocket.
///
/// Lifecycle (3.x `SoopDanmaku`, simplified to showroom's shape): open on the
/// TLS endpoint, fall back to the plain one when the edge drops the
/// ClientHello; on open send the login packet, the join packet 200 ms later,
/// a keep-alive every 20 s, and treat a socket silent for [SoopDanmakuProtocol
/// .silenceLimit] as dead. An open socket counts as joined — 3.x saw no join
/// acknowledgement, so there is none here.
///
/// A dropped or silent socket ends the session with an error on the stream;
/// reconnecting belongs to the caller's supervisor, which owns the retry
/// policy — the same division as the showroom and bilibili sessions, because a
/// second retry policy inside an adapter would fight the first one.
///
/// Archived from 3.x and not run against the live service: the handshake
/// header spelling the edges are said to be picky about passes through
/// [SoopDanmakuProtocol.handshakeHeaders], but `dart:io` normalises header
/// case, so that exactness is unverified here.
final class SoopDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  SoopDanmakuSession._(this._args, this._socket) {
    _socket.add(SoopDanmakuProtocol.login);
    _join = Timer(SoopDanmakuProtocol.joinDelay, () {
      if (!_closed) _socket.add(SoopDanmakuProtocol.join(_args.chatNo));
    });
    _heartbeat = Timer.periodic(SoopDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(SoopDanmakuProtocol.heartbeat);
    });
    _armSilence();
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final SoopDanmakuArgs _args;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _join;
  late final Timer _heartbeat;
  Timer? _silence;
  bool _closed = false;

  /// Opens a session for [args], trying [SoopDanmakuProtocol.endpoints] in
  /// order. The cookie travels only over TLS.
  static Future<SoopDanmakuSession> connect(SoopDanmakuArgs args) async {
    final endpoints = SoopDanmakuProtocol.endpoints(args);
    Object? lastError;
    for (var i = 0; i < endpoints.length; i++) {
      final endpoint = endpoints[i];
      final headers = i == 0
          ? SoopDanmakuProtocol.handshakeHeaders(args.headers)
          : SoopDanmakuProtocol.plainHeaders(SoopDanmakuProtocol.handshakeHeaders(args.headers));
      try {
        final socket = await WebSocket.connect(
          endpoint.toString(),
          protocols: SoopDanmakuProtocol.protocols,
          headers: headers,
        );
        return SoopDanmakuSession._(args, socket);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw SiteNotFoundError('soop danmaku: no chat server reached (${lastError.runtimeType})');
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    _armSilence();
    // Chat comes in binary frames; 3.x only logged text frames.
    if (data is! List<int>) {
      return;
    }
    SoopDanmakuProtocol.decode(data).forEach(_messages.add);
  }

  /// (Re)arms the silence watchdog; a frame that never comes closes the
  /// stream as a dead socket.
  void _armSilence() {
    _silence?.cancel();
    _silence = Timer(SoopDanmakuProtocol.silenceLimit, () {
      _fail(const SiteNotFoundError('soop danmaku: socket silent'), StackTrace.current);
    });
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _teardown();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _teardown();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _teardown();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }

  void _teardown() {
    _closed = true;
    _join.cancel();
    _heartbeat.cancel();
    _silence?.cancel();
  }
}
