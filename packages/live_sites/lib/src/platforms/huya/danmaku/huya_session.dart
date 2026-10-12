import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku.dart';

/// A Huya danmaku session over one anonymous WebSocket.
///
/// Lifecycle: open the socket (it counts as joined), register the streamer's
/// chat groups (command 16) and send a heartbeat, then a heartbeat every 60 s;
/// the server pushes binary Tars frames, decoded into chat, popularity and gift
/// messages. A stream-end notice for this streamer (or one naming nobody) ends
/// the session — the room is one broadcast and its replay has no live chat. A
/// dropped socket ends the session with an error on the stream; reconnecting
/// belongs to the caller's supervisor, which owns the retry policy — the same
/// division as the soop and showroom sessions. The headline (super chat) board
/// is not read yet.
///
/// Archived from the reference and not run against the live service.
final class HuyaDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  HuyaDanmakuSession._(this._uid, this._socket) {
    _socket
      ..add(HuyaDanmakuProtocol.register(_uid))
      ..add(HuyaDanmakuProtocol.heartbeat());
    _heartbeat = Timer.periodic(HuyaDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(HuyaDanmakuProtocol.heartbeat());
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final int _uid;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  /// Opens a session for streamer [uid]'s room.
  static Future<HuyaDanmakuSession> connect(int uid) async {
    final socket = await WebSocket.connect(HuyaDanmakuProtocol.endpoint.toString());
    return HuyaDanmakuSession._(uid, socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    // Huya only sends binary frames.
    if (data is! List<int>) {
      return;
    }
    final frame = HuyaDanmakuProtocol.decode(data, now: DateTime.now());
    frame.messages.forEach(_messages.add);
    if (frame.ended.any((uid) => uid == _uid || uid <= 0)) {
      _fail(const SiteNotFoundError('huya: ${HuyaDanmakuProtocol.broadcastEnded}'), StackTrace.current);
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
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
