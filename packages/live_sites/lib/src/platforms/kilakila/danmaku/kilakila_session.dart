import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku.dart';

/// A KilaKila guest chat session over one Socket.IO WebSocket.
///
/// Lifecycle: open on the guest namespace's socket, send the join packet at
/// once, ping with the Engine.IO `2` every 25 s, and decode `text_message`
/// events into messages (a combo's repeated hit is folded by
/// [KilakilaGiftCombos]). The join is confirmed by a `40` packet (or a
/// `connect_error` with code 0) within 8 s; a refusal, a transport close or a
/// join that never confirms ends the session with an error on the stream.
/// Reconnecting belongs to the caller's supervisor, which owns the retry
/// policy — the same division as the soop and showroom sessions.
///
/// Archived from the reference and not run against the live service.
final class KilakilaDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  KilakilaDanmakuSession._(this._roomId, this._socket) {
    _socket.add(KilakilaDanmakuProtocol.join(_roomId));
    _heartbeat = Timer.periodic(KilakilaDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(KilakilaDanmakuProtocol.ping);
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  /// How long the join may take before the socket is given up.
  static const Duration joinTimeout = Duration(seconds: 8);

  final String _roomId;
  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  final _joined = Completer<bool>();
  final KilakilaGiftCombos _combos = KilakilaGiftCombos();
  late final Timer _heartbeat;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  bool _joinSettled = false;

  /// Opens a session for broadcast [roomId].
  static Future<KilakilaDanmakuSession> connect(String roomId) async {
    final socket = await WebSocket.connect(
      KilakilaDanmakuProtocol.endpoint(roomId).toString(),
      headers: KilakilaDanmakuProtocol.handshakeHeaders,
    );
    final session = KilakilaDanmakuSession._(roomId, socket);
    final joined = await session._joined.future.timeout(joinTimeout, onTimeout: () => false);
    if (!joined) {
      await session.close();
      throw const SiteNotFoundError('kilakila chat: join refused or timed out');
    }
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = KilakilaDanmakuProtocol.decode(data, roomId: _roomId);
    for (final message in frame.messages) {
      if (_combos.report(message)) _messages.add(message);
    }
    if (frame.joined) {
      _settleJoin(true);
    }
    if (frame.refusal case final refusal?) {
      _fail(SiteApiChangedError('kilakila chat: $refusal'), StackTrace.current);
      return;
    }
    if (frame.dropped) {
      _done();
    }
  }

  void _settleJoin(bool value) {
    if (_joinSettled) {
      return;
    }
    _joinSettled = true;
    _joined.complete(value);
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    _settleJoin(false);
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
    _settleJoin(false);
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
    _settleJoin(false);
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
