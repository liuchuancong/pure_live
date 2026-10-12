import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku.dart';

/// A Kick danmaku session over one Pusher WebSocket.
///
/// Lifecycle: open on Kick's Pusher app, subscribe to the chat, broadcast and
/// Kicks channels once the server answers `pusher:connection_established`,
/// answer the server's pings and ping every 30 s, and decode events into
/// messages. A Pusher or subscription error ends the session with an error on
/// the stream; reconnecting belongs to the caller's supervisor, which owns the
/// retry policy — the same division as the showroom and soop sessions, because
/// a second retry policy inside an adapter would fight the first one.
///
/// Archived from the reference and not run against the live service.
final class KickDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  KickDanmakuSession._(this._args, this._socket) {
    _heartbeat = Timer.periodic(KickDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(KickDanmakuProtocol.ping);
    });
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final KickDanmakuArgs _args;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  bool _closed = false;

  /// Opens a session for [args], which must have passed
  /// [KickDanmakuProtocol.checked].
  static Future<KickDanmakuSession> connect(KickDanmakuArgs args) async {
    final socket = await WebSocket.connect(
      KickDanmakuProtocol.endpoint.toString(),
      headers: KickDanmakuProtocol.socketHeaders,
    );
    return KickDanmakuSession._(args, socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = KickDanmakuProtocol.read(data, _args);
    if (frame.established) {
      _socket
        ..add(KickDanmakuProtocol.subscribe(KickDanmakuProtocol.chatChannel(_args)))
        ..add(KickDanmakuProtocol.subscribe(KickDanmakuProtocol.broadcastChannel(_args)))
        ..add(KickDanmakuProtocol.subscribe(KickDanmakuProtocol.kicksChannel(_args)));
    }
    if (frame.ping) {
      _socket.add(KickDanmakuProtocol.pong);
    }
    if (frame.error != null) {
      _fail(SiteApiChangedError('kick danmaku: ${frame.error}'), StackTrace.current);
      return;
    }
    frame.messages.forEach(_messages.add);
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
