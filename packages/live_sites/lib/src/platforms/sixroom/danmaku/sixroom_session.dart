import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku.dart';

/// A Six Rooms chat session over one guest socket.
///
/// Lifecycle: the room's chat servers (from `getChat.php`) are tried in turn —
/// each handshake opens a socket, logs in as a guest and waits for the server's
/// `login.success` within [SixRoomDanmakuProtocol.joinTimeout]; a refused or
/// timed-out login moves to the next server, and no server accepting ends the
/// connect with an error. A joined socket sends the page's `noop` heartbeat
/// every 16 s and reports chat, gifts and fly-screen super chats. An error flag
/// the room page stops on (kicked, paid, closed, …) ends the session; so does a
/// dropped socket. Reconnecting belongs to the caller's supervisor, which owns
/// the retry policy — the same division as the soop and showroom sessions.
///
/// Archived from the reference and not run against the live service.
final class SixRoomDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  SixRoomDanmakuSession._(this._socket) {
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  final _joined = Completer<bool>();
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  bool _closed = false;
  bool _joinSettled = false;

  /// Opens a session for [userId]'s room, trying [servers] in order as a guest
  /// with [guestId].
  static Future<SixRoomDanmakuSession> connect({
    required List<Uri> servers,
    required String userId,
    required int guestId,
  }) async {
    Object? lastError;
    for (final server in servers) {
      SixRoomDanmakuSession? session;
      try {
        final socket = await WebSocket.connect(server.toString(), headers: SixRoomDanmakuProtocol.socketHeaders);
        session = SixRoomDanmakuSession._(socket);
        socket.add(SixRoomDanmakuProtocol.login(guestId, userId));
        final joined = await session._joined.future.timeout(SixRoomDanmakuProtocol.joinTimeout, onTimeout: () => false);
        if (joined) return session;
      } on Object catch (error) {
        lastError = error;
      }
      await session?.close();
    }
    throw SiteNotFoundError('sixroom chat: no server accepted the guest login (${lastError.runtimeType})');
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final frame = SixRoomDanmakuProtocol.decode(data);
    if (frame.refusal case final refusal?) {
      _fail(SiteRiskControlError('sixroom chat: $refusal'), StackTrace.current);
      return;
    }
    if (frame.loginFailed) {
      _settleJoin(false);
      return;
    }
    if (frame.joined) {
      _settleJoin(true);
      _heartbeat ??= Timer.periodic(SixRoomDanmakuProtocol.heartbeatInterval, (_) {
        if (!_closed) _socket.add(SixRoomDanmakuProtocol.heartbeat);
      });
    }
    frame.messages.forEach(_messages.add);
  }

  /// Completes the connect's wait for the login result exactly once.
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
    _heartbeat?.cancel();
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
    _heartbeat?.cancel();
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
    _heartbeat?.cancel();
    _settleJoin(false);
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
