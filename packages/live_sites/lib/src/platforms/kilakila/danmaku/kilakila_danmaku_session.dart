import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/api/kilakila_endpoints.dart';
import 'package:live_sites/src/platforms/kilakila/danmaku/kilakila_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for KilaKila broadcasts.
///
/// The session joins by the current broadcast's `roomIdStr`, which the room
/// detail carries on the room's danmaku handle — so a session is built from a
/// fresh detail. An anchor without a current broadcast has no handle and is
/// reported content-unavailable rather than joined empty.
final class KilakilaDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the anchor's broadcast).
  KilakilaDanmakuProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final KilakilaDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! KilakilaDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'anchor ${room.roomId} has no broadcast'));
      }
      args = handle;
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = KilakilaDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'kilakila';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef KilakilaTimers = DanmakuTimers;

/// One comment connection: one Socket.IO socket per broadcast.
///
/// - The namespace join goes out as soon as the socket opens; the room is
///   joined when the server confirms it, within
///   [KilakilaDanmakuCodec.joinTimeout], or the socket is replaced.
/// - The Engine.IO ping goes out every
///   [KilakilaDanmakuCodec.heartbeatInterval] from the open; the server
///   answers every one, so a socket silent for
///   [KilakilaDanmakuCodec.silenceTimeout] is replaced.
/// - A refused join reconnects, [KilakilaDanmakuCodec.maxRefusals] times in a
///   row; the next refusal ends the session with a terminal system message. A
///   confirmed join clears the count. A server that leaves the namespace or
///   closes the transport, and a socket that errors, closes or goes silent,
///   is reconnected; [KilakilaDanmakuCodec.maxReconnects] runs without a
///   joined one end the session the same way.
/// - A combo hit or line that only repeats a count already reported for its
///   combo is left out (see [KilakilaGiftCombos]).
///
/// The run lifecycle — the generation the handshakes and their callbacks
/// guard with — is the shared base's ([DanmakuSessionBase]): every handshake
/// is one [DanmakuRun], and the base drops whatever a dead one reports.
final class KilakilaDanmakuSession extends DanmakuSessionBase {
  /// The comments of [args]' broadcast over [site]. [timers] and [now] are
  /// injectable for tests.
  KilakilaDanmakuSession({required this.args, required this.site, super.timers, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The broadcast this session joins.
  final KilakilaDanmakuArgs args;

  /// The site its socket connections come from.
  final KilakilaSite site;

  final DateTime Function() _now;

  final KilakilaGiftCombos _combos = KilakilaGiftCombos();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _retry;
  int _failures = 0;
  int _refusals = 0;

  /// Opens the first socket; null once it is on its way, else why the
  /// broadcast has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) return const LiveSiteError.unsupported(siteId: kilakilaSiteId, message: 'session is disposed');
    if (!KilakilaEndpoints.isId(args.roomId)) {
      return const LiveSiteError.notFound(siteId: kilakilaSiteId, message: 'not a KilaKila broadcast');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (isDisposed) return;
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        KilakilaDanmakuCodec.endpoint(args.roomId),
        headers: KilakilaDanmakuCodec.handshakeHeaders,
        protocols: null,
        connectTimeout: KilakilaDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed('$error', run);
      return;
    }
    if (!run.isActive) {
      try {
        await socket.close();
      } on Object {
        // Already closed or broken.
      }
      return;
    }
    _socket = socket;
    run.handshakeDone();
    _startHeartbeat();
    _startWatchdog(run);
    run.armJoinTimeout(KilakilaDanmakuCodec.joinTimeout, () {
      _scheduleRetry('no join within ${KilakilaDanmakuCodec.joinTimeout.inSeconds} s', run);
    });
    // The namespace join goes out as soon as the socket opens.
    _send(KilakilaDanmakuCodec.join(args.roomId));
    _subscription = socket.stream.listen(
      (data) {
        if (run.isActive) _onData(data, run);
      },
      onDone: () {
        if (run.isActive) _scheduleRetry('socket closed', run);
      },
      onError: (Object error) {
        if (run.isActive) _scheduleRetry('$error', run);
      },
    );
  }

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    _scheduleRetry(reason, run);
  }

  void _onData(Object? data, DanmakuRun run) {
    _startWatchdog(run);
    final frame = KilakilaDanmakuCodec.decode(data, roomId: args.roomId);
    if (frame.refusal case final refusal?) {
      _refused(refusal, run);
      return;
    }
    if (frame.dropped) {
      _scheduleRetry('the server left the room', run);
      return;
    }
    if (frame.joined && !run.isJoined) {
      run.joined();
      _refusals = 0;
      _failures = 0;
      return;
    }
    for (final message in frame.messages) {
      if (!run.isActive) return;
      if (_combos.report(message)) run.message(message);
    }
  }

  /// A refused join: the socket is replaced; the refusal after the last
  /// retry ends the session.
  void _refused(String refusal, DanmakuRun run) {
    _refusals += 1;
    if (_refusals > KilakilaDanmakuCodec.maxRefusals) {
      _terminate('join refused: $refusal', run);
      return;
    }
    _scheduleRetry('join refused: $refusal', run);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = timers.every(KilakilaDanmakuCodec.heartbeatInterval, (_) {
      if (!isDisposed) _send(KilakilaDanmakuCodec.ping);
    });
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(KilakilaDanmakuCodec.silenceTimeout, () {
      if (run.isActive) _scheduleRetry('socket silent', run);
    });
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(frame);
    } on Object {
      // The retry path owns a broken socket.
    }
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    run
      ..exhausted(reason)
      ..message(
        LiveMessage.normalized(
          type: LiveMessageType.system,
          text: reason,
          color: LiveMessageColor.white,
          sentAt: _now(),
        ),
      );
    unawaited(dispose());
  }

  void _cancelTimers() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    run?.cancelJoinTimeout();
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    await _subscription?.cancel();
    _subscription = null;
    _socket = null;
    try {
      await socket?.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// The socket is to be replaced after the backoff's step;
  /// [KilakilaDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason, DanmakuRun run) {
    _cancelTimers();
    if (!run.isActive) return;
    _failures += 1;
    if (_failures > KilakilaDanmakuCodec.maxReconnects) {
      _terminate(reason, run);
      return;
    }
    run.reconnecting(reason);
    _retry = timers.after(KilakilaDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (!run.isActive) return;
      unawaited(_handshake());
    });
  }

  /// Releases the transport and the protocol timers; safe when nothing is
  /// open.
  @override
  Future<void> stop() async {
    _cancelTimers();
    await _teardownSocket();
  }
}
