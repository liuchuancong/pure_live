import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku.dart';

/// An FC2 Live comment session over one control WebSocket: connect on the
/// grant's socket, join when the server says `connect_complete`, send the
/// page's heartbeat every 30 s, and read `comment` and `user_count` messages
/// (applying the `ng_comment` lists).
///
/// A grant is good for one socket for about a minute, and `control_disconnection`
/// (the grant expired or the broadcast ended) and `move_server` ask for a
/// fresh one. This build does not hold the socket across that: it ends the
/// stream, and the caller's supervisor reconnects, which takes a new grant —
/// the same division as the kick and showroom sessions, and a natural fit for
/// the one-minute grant. Reconnect counts and the proxy route the reference
/// thread through its socket runtime are not ported here. Failures never name
/// the grant's token or cookie.
///
/// Archived from the reference and not run against the live service.
final class Fc2LiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  Fc2LiveDanmakuSession._(this._socket) {
    _heartbeat = Timer.periodic(Fc2LiveDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(Fc2LiveDanmakuProtocol.heartbeat(_nextId++));
    });
    _joinTimer = Timer(Fc2LiveDanmakuProtocol.joinTimeout, () {
      if (!_joined) _failWith('fc2live danmaku: no connect_complete in time');
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  final Fc2LiveNgList _ng = Fc2LiveNgList();
  final Fc2LiveAudience _audience = Fc2LiveAudience();
  late final StreamSubscription<Object?> _subscription;
  late final Timer _heartbeat;
  late final Timer _joinTimer;
  int _nextId = 1;
  bool _joined = false;
  bool _closed = false;

  /// Opens a session for [args], whose endpoint the site took from a fresh
  /// grant.
  static Future<Fc2LiveDanmakuSession> connect(Fc2LiveDanmakuArgs args) async {
    final socket = await WebSocket.connect(args.endpoint.toString(), headers: args.headers);
    return Fc2LiveDanmakuSession._(socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(Object? data) {
    if (_closed) return;
    final message = Fc2LiveDanmakuProtocol.decode(data);
    if (message == null) return;
    switch (message.name) {
      case 'connect_complete':
        _joined = true;
        _joinTimer.cancel();
      case 'ng_comment':
        _ng.apply(message.arguments);
      case 'comment':
        Fc2LiveDanmakuProtocol.comments(message.arguments, ng: _ng).forEach(_messages.add);
      case 'user_count':
        _audience.update(message.arguments).forEach(_messages.add);
      case '_response_' when message.arguments['status'] == 0:
        break;
      case 'control_disconnection':
        _failWith('fc2live danmaku: control disconnected (${message.arguments['code'] ?? 'grant'})');
      case 'move_server':
        _failWith('fc2live danmaku: server move');
      // initial_connect, connect_data, video_information, point_information
      // and the rest carry no chat.
    }
  }

  void _failWith(String message) => _fail(SiteApiChangedError(message), StackTrace.current);

  void _fail(Object error, StackTrace stack) {
    if (_closed) return;
    _closed = true;
    _heartbeat.cancel();
    _joinTimer.cancel();
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
    _heartbeat.cancel();
    _joinTimer.cancel();
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
    await _subscription.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
