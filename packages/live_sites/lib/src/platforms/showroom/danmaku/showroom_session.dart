import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability.dart';
import 'package:live_sites/src/models/live_message.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku.dart';

/// A SHOWROOM danmaku session over one WebSocket.
///
/// Lifecycle: connect → `SUB <key>` (nothing confirms the subscription) →
/// a ping a minute, whose `ACK` is the only liveness signal the protocol
/// offers → `MSG` frames decoded into messages. A dropped socket ends the
/// session with an error on the stream; reconnecting belongs to the caller's
/// supervisor, which owns the retry policy — the same division as the
/// bilibili session, because a second retry policy inside an adapter would
/// fight the first one.
final class ShowroomDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (the same as the bilibili session).
  // ignore: unnecessary_type_name_in_constructor
  ShowroomDanmakuSession._(this._args, this._socket) {
    _socket.add(ShowroomDanmakuProtocol.subscribe(_args.key));
    _heartbeat = Timer.periodic(ShowroomDanmakuProtocol.heartbeatInterval, (_) {
      _socket.add(ShowroomDanmakuProtocol.ping);
    });
    _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final ShowroomDanmakuArgs _args;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final Timer _heartbeat;
  bool _closed = false;

  /// Opens a session for [args], which must have passed
  /// [ShowroomDanmakuProtocol.checked].
  static Future<ShowroomDanmakuSession> connect(ShowroomDanmakuArgs args) async {
    final socket = await WebSocket.connect(
      ShowroomDanmakuProtocol.endpoint(args.host).toString(),
      headers: const {'origin': 'https://www.showroom-live.com'},
    );
    return ShowroomDanmakuSession._(args, socket);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    ShowroomDanmakuProtocol.decode(data, key: _args.key).forEach(_messages.add);
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
