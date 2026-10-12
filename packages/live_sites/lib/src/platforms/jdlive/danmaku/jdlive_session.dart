import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku.dart';

/// A JD Live danmaku session over one WebSocket.
///
/// Lifecycle: the socket opens on a URL a `liveauth` handshake produced (the
/// site runs that handshake and hands the [JdLiveChatAuth] here); the client
/// sends nothing — the website's join frame only announces a visitor and is not
/// needed to receive the room. The server pushes the audience and chat; an
/// open socket counts as joined. `stop_live_broadcast` ends the session, and a
/// socket silent past [JdLiveDanmakuProtocol.silenceTimeout] is reported dead.
/// Reconnecting belongs to the caller's supervisor, which owns the retry
/// policy — the same division as the showroom and soop sessions.
///
/// Archived from the reference and not run against the live service.
final class JdLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  JdLiveDanmakuSession._(this._liveId, this._maskKey, this._socket) {
    _armSilence();
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final String _liveId;
  final String? _maskKey;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  Timer? _silence;
  bool _closed = false;

  /// Opens a session for [auth], filtered to broadcast [liveId].
  static Future<JdLiveDanmakuSession> connect(JdLiveChatAuth auth, {required String liveId}) async {
    final socket = await WebSocket.connect(auth.socketUrl.toString(), headers: JdLiveDanmakuProtocol.socketHeaders);
    return JdLiveDanmakuSession._(liveId, auth.maskKey, socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    _armSilence();
    final frame = JdLiveDanmakuProtocol.decode(data, liveId: _liveId, maskKey: _maskKey);
    frame.messages.forEach(_messages.add);
    if (frame.ended) {
      _done();
    }
  }

  void _armSilence() {
    _silence?.cancel();
    _silence = Timer(JdLiveDanmakuProtocol.silenceTimeout, () {
      _fail(const SiteApiChangedError('jdlive danmaku: socket silent'), StackTrace.current);
    });
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _silence?.cancel();
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
    _silence?.cancel();
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
    _silence?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
