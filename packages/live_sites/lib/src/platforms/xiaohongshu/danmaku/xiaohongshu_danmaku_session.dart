import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_codec.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef XiaohongshuDanmakuTimers = DanmakuTimers;

/// One read-only chat connection: the RWP socket of one broadcast, over a
/// [XiaohongshuGuest] bootstrap and a [SocketChannel].
///
/// - The bootstrap asks the visitor session for a push identity once per
///   connect run; a refused answer ends the connect, and normal reconnects
///   reuse the identity they were opened with. Browser resources are
///   released before the socket starts (the guest owns them); the identity
///   is never logged or stored.
/// - Every socket runs the three-step bootstrap — guest handshake, room
///   service register, broadcast subscribe — each step answered by an
///   acknowledgement carrying the id the request sent; the whole sequence
///   must finish within [joinTimeout] or the socket is replaced. Only the
///   room JSON service is registered, and exactly one broadcast is joined;
///   no chat is ever posted.
/// - A handshake refused (`c` other than 0) renews the identity once —
///   `refresh: true` — and starts over on a fresh socket; a second refusal,
///   or a refusal of the register or subscribe step, ends the session
///   instead of bootstrapping forever. A completed bootstrap clears the
///   renewal budget again.
/// - The beat every [heartbeatInterval] while the socket is up sends the
///   transport ping, the control ping and the viewing heart (no chat
///   content); there is no silence watchdog, the push service answering the
///   pings itself.
/// - A socket that errors or closes is replaced after a one-second step per
///   failure in a row, [maxReconnectAttempts] of them ending the session.
///   Chat ids already shown are dropped across reconnects
///   ([XiaohongshuDanmakuCodec.maxSeenMessages] remembered); a new connect
///   run forgets them.
///
/// The run lifecycle — the generation and socket-epoch accounting the
/// bootstrap, the socket callbacks and the retries guard with — is the shared
/// base's ([DanmakuSessionBase]): one [DanmakuRun] per [connect] (the old
/// `_generation`), whose [DanmakuRun.isActive] absorbs the disposed check, and
/// the per-socket epoch stays this session's own bookkeeping so a retry armed
/// for a superseded socket finds itself stale.
final class XiaohongshuDanmakuSession extends DanmakuSessionBase {
  /// The chat of [args]' broadcast for [guest]'s visitor identity, sockets
  /// opened by [connector]. [timers] is injectable for tests.
  XiaohongshuDanmakuSession({required this.args, required this.guest, SocketConnector? connector, super.timers})
    : _connector = connector ?? webSocketConnect;

  /// The broadcast this session subscribes to.
  final XiaohongshuDanmakuArgs args;

  /// The visitor bootstrap the identity and its renewal come from.
  final XiaohongshuGuest guest;

  /// How the chat's socket is connected.
  final SocketConnector _connector;

  /// Beat period (the reference's `heartbeatInterval`).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long the bootstrap may take per socket (the reference's
  /// `joinTimeout`).
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Opening one socket's budget.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Failed reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  final Set<String> _seen = {};

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _beat;
  Timer? _retry;
  XiaohongshuPushIdentity? _identity;
  CancelToken? _cancel;
  int _socketEpoch = 0;
  int _serial = 0;
  int _step = 0;
  int _renewals = 0;
  int _reconnectFailures = 0;
  String _expected = '';
  bool _channelLive = false;
  bool _reconnecting = false;

  /// Asks for the visitor identity and opens the first socket; null once it
  /// is on its way, else why chat could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) {
      return const LiveSiteError.unsupported(siteId: xiaohongshuSiteId, message: 'session is disposed');
    }
    if (!XiaohongshuEndpoints.isRoomId(args.roomId)) {
      return LiveSiteError.notFound(
        siteId: xiaohongshuSiteId,
        message: 'room "${args.roomId}" is not a Xiaohongshu room',
      );
    }
    _seen.clear();
    _reconnectFailures = 0;
    final run = beginRun();
    final cancel = _cancel = CancelToken();
    final XiaohongshuPushIdentity identity;
    try {
      identity = await guest.pushIdentity(args.roomId, cancel: cancel);
    } on Object catch (error) {
      return LiveSiteError.authentication(
        siteId: xiaohongshuSiteId,
        message: 'the visitor bootstrap gave no push identity (${_causeOf(error)})',
      );
    }
    if (!run.isActive || cancel.isCancelled) {
      return const LiveSiteError.unsupported(siteId: xiaohongshuSiteId, message: 'session is disposed');
    }
    _identity = identity;
    return await _open(run, identity);
  }

  /// Opens one socket for [identity]: the channel, its subscriptions, the
  /// beat, the bootstrap watch, and the handshake as soon as it is up; null
  /// when the socket came up, else why it did not. Each open is one socket
  /// epoch, so a retry armed for a superseded socket finds itself stale.
  Future<LiveSiteError?> _open(DanmakuRun run, XiaohongshuPushIdentity identity) async {
    final epoch = ++_socketEpoch;
    _step = 0;
    _channelLive = false;
    await _teardownSocket();
    if (!run.isActive) return null;
    final SocketChannel socket;
    try {
      socket = await _connector(
        XiaohongshuDanmakuCodec.endpoint,
        headers: XiaohongshuDanmakuCodec.handshakeHeaders(identity),
        protocols: null,
        connectTimeout: connectTimeout,
      );
    } on Object catch (error) {
      return LiveSiteError.network(
        siteId: xiaohongshuSiteId,
        message: 'push socket failed on ${XiaohongshuDanmakuCodec.endpoint}: $error',
        cause: error,
      );
    }
    if (!run.isActive || epoch != _socketEpoch) {
      unawaited(socket.close());
      return null;
    }
    _socket = socket;
    _channelLive = true;
    run.handshakeDone();
    _startBeat();
    _subscription = socket.stream.listen(
      (data) {
        if (epoch == _socketEpoch && run.isActive) _onData(data, run);
      },
      onDone: () {
        _channelLive = false;
        if (epoch == _socketEpoch && run.isActive) _scheduleReconnect('socket closed', run);
      },
      onError: (Object error) {
        _channelLive = false;
        if (epoch == _socketEpoch && run.isActive) _scheduleReconnect('$error', run);
      },
    );
    _expected = _nextId();
    // The socket-epoch ledger stays: the budget is this socket's, and a
    // superseded socket's answer must not speak for the current one.
    run.armJoinTimeout(joinTimeout, () {
      if (epoch == _socketEpoch) _scheduleReconnect('bootstrap did not finish', run);
    });
    _send(XiaohongshuDanmakuCodec.handshake(_expected, identity));
    return null;
  }

  void _onData(Object? data, DanmakuRun run) {
    final frame = XiaohongshuDanmakuCodec.envelope(data);
    if (frame == null) return;
    if (frame['t'] == 2 && frame['m'] == _expected) {
      final code = XiaohongshuDanmakuCodec.ackCode(frame);
      if (code == null) return;
      if (code != 0) {
        _refused(run);
        return;
      }
      _expected = _nextId();
      if (_step == 0) {
        _step = 1;
        _send(XiaohongshuDanmakuCodec.register(_expected));
      } else if (_step == 1) {
        _step = 2;
        _send(XiaohongshuDanmakuCodec.join(_expected, args.roomId));
      } else if (_step == 2) {
        _step = 3;
        _renewals = 0;
        _reconnectFailures = 0;
        if (!run.isJoined) run.joined();
        _send(XiaohongshuDanmakuCodec.viewerHeart(_nextId(), args.roomId, _identity?.uid ?? ''));
      }
      return;
    }
    for (final message in XiaohongshuDanmakuCodec.messages(frame, args.roomId)) {
      if (message.type == LiveMessageType.chat && message.messageId.isNotEmpty) {
        if (!_seen.add(message.messageId)) continue;
        if (_seen.length > XiaohongshuDanmakuCodec.maxSeenMessages) _seen.remove(_seen.first);
      }
      run.message(message);
    }
  }

  /// A refused step: the handshake's first refusal renews the identity once
  /// and starts over; anything else ends the session.
  void _refused(DanmakuRun run) {
    run.cancelJoinTimeout();
    if (_step == 0 && _renewals++ == 0) {
      _step = -1;
      _expected = '';
      unawaited(_renew(run));
      return;
    }
    _terminate('push credentials unavailable', run);
  }

  /// A fresh identity (`refresh: true`) and a fresh socket, within the same
  /// session; a refused renewal ends it.
  Future<void> _renew(DanmakuRun run) async {
    final cancel = _cancel;
    final XiaohongshuPushIdentity identity;
    try {
      identity = await guest.pushIdentity(args.roomId, refresh: true, cancel: cancel);
    } on Object catch (error) {
      _terminate('push credentials unavailable (${_causeOf(error)})', run);
      return;
    }
    if (!run.isActive || (cancel?.isCancelled ?? false)) return;
    _identity = identity;
    final failure = await _open(run, identity);
    if (failure != null && run.isActive) _terminate(failure.message, run);
  }

  void _startBeat() {
    _beat?.cancel();
    _beat = timers.every(heartbeatInterval, (_) {
      if (isDisposed || !_channelLive) return;
      _send(XiaohongshuDanmakuCodec.control(_nextId(), 6, {}));
      _send(XiaohongshuDanmakuCodec.viewerHeart(_nextId(), args.roomId, _identity?.uid ?? ''));
      _send(XiaohongshuDanmakuCodec.transportHeartbeat);
    });
  }

  /// The socket is replaced after a one-second step per failure in a row;
  /// [maxReconnectAttempts] runs without a joined one end the session. The
  /// visitor identity in use is kept, as the reference's normal reconnects
  /// keep theirs. A retry armed for a socket that has since been superseded
  /// finds itself stale and does nothing.
  void _scheduleReconnect(String reason, DanmakuRun run) {
    if (!run.isActive || _reconnecting) return;
    _reconnecting = true;
    final epoch = _socketEpoch;
    _retry = timers.after(Duration(seconds: _reconnectFailures + 1), () {
      _retry = null;
      unawaited(() async {
        if (!run.isActive || epoch != _socketEpoch) {
          _reconnecting = false;
          return;
        }
        final identity = _identity;
        if (identity == null) {
          _reconnecting = false;
          return;
        }
        final failure = await _open(run, identity);
        _reconnecting = false;
        if (!run.isActive) return;
        if (failure == null) return;
        _reconnectFailures += 1;
        if (_reconnectFailures >= maxReconnectAttempts) {
          _terminate('$reason: ${failure.message}', run);
          return;
        }
        _scheduleReconnect(reason, run);
      }());
    });
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || !_channelLive) return;
    try {
      socket.add(frame);
    } on Object {
      // The reconnect path owns a broken socket.
    }
  }

  String _nextId() => 'pl-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason, DanmakuRun run) {
    if (run.isActive) {
      run
        ..exhausted(reason)
        ..message(
          LiveMessage.normalized(
            type: LiveMessageType.system,
            text: 'Danmaku connection lost ($reason)',
            color: LiveMessageColor.white,
          ),
        );
    }
    unawaited(dispose());
  }

  void _cancelTimers() {
    _beat?.cancel();
    _beat = null;
    run?.cancelJoinTimeout();
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _teardownSocket() async {
    _channelLive = false;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// Stops delivery, leaving the session able to [connect] again; an
  /// in-flight bootstrap request is cancelled with the run it belonged to.
  @override
  Future<void> stop() async {
    _cancelTimers();
    _cancel?.cancel();
    _cancel = null;
    await _teardownSocket();
  }

  /// What a swallowed bootstrap failure may say: the fixed failure texts
  /// carry no page content or credentials, and an unexpected error names
  /// its type alone.
  static String _causeOf(Object error) => switch (error) {
    TransportFailure() || XiaohongshuFailure() => error.toString(),
    _ => error.runtimeType.toString(),
  };
}
