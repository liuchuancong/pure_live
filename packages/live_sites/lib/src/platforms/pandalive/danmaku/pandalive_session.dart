import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku.dart';

/// A PandaTV danmaku session over one Centrifugo WebSocket.
///
/// Lifecycle: open on the chat server with a `live/play` guest token (the site
/// asks for one on every connect), send the connect and the subscribe, ping
/// with command 7 every 25 s, and decode publications into messages. The
/// subscription's reply is the join; a refused connect or subscription, a
/// dropped socket or an error ends the session with an error on the stream —
/// reconnecting belongs to the caller's supervisor, which owns the retry
/// policy (the same division as the showroom, soop and kick sessions). The
/// ~30-minute token is not auto-renewed here: a session that outlives it is
/// reopened by the caller with a fresh handshake.
///
/// Archived from the reference and not run against the live service.
final class PandaLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  PandaLiveDanmakuSession._(this._channel, this._socket, this._token) {
    _socket
      ..add(PandaLiveDanmakuProtocol.connect(_token))
      ..add(PandaLiveDanmakuProtocol.subscribe(_channel));
    _heartbeat = Timer.periodic(PandaLiveDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(PandaLiveDanmakuProtocol.ping(++_commandId));
    });
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final String _channel;
  final String _token;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  int _commandId = PandaLiveDanmakuProtocol.subscribeId;
  bool _closed = false;

  /// Opens a session for [channel] with [token] (from a `live/play` grant).
  static Future<PandaLiveDanmakuSession> connect(String channel, String token) async {
    final socket = await WebSocket.connect(
      PandaLiveDanmakuProtocol.endpoint.toString(),
      headers: PandaLiveDanmakuProtocol.socketHeaders,
    );
    return PandaLiveDanmakuSession._(channel, socket, token);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = PandaLiveDanmakuProtocol.decode(data, channel: _channel);
    frame.messages.forEach(_messages.add);
    if (frame.refusal case final refusal?) {
      _fail(SiteApiChangedError('pandalive chat: $refusal'), StackTrace.current);
    }
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
