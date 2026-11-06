import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:live_sites/src/platforms/soop/parsers/soop_failure.dart';
import 'package:live_sites/src/platforms/soop/soop_manifest.dart';
import 'package:live_sites/src/platforms/soop/soop_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for SOOP broadcasts.
///
/// The session joins by the player answer's chat server and `CHATNO`, which
/// the room detail carries on the room's danmaku handle — so a session is
/// built from a fresh detail. A room without chat data (offline, blocked,
/// restricted, or an answer without a chat server) has no handle and is
/// reported content-unavailable rather than joined empty.
final class SoopDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  SoopDanmakuProvider({required this.site});

  /// The site this capability serves.
  final SoopSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final SoopDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! SoopDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room ${room.roomId} opens no chat'));
      }
      args = handle;
    } on SoopFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = SoopDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'soop';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef SoopTimers = DanmakuTimers;

/// One chat connection: one WebSocket per room.
///
/// - The socket goes as a guest: [SoopDanmakuArgs.headers] carry no cookie
///   even in a room whose API requests were signed with the user's login — the
///   reference's chat edge does the same, and the login unlocks the streams,
///   not the chat.
/// - The socket's open counts as joined (3.x's reading): the login packet
///   goes out as soon as it opens, the join packet
///   [SoopDanmakuCodec.joinDelay] later; there is no join budget, because
///   the server confirms with nothing in particular. A socket that closes
///   or errors at once is the failed join.
/// - The keep-alive goes out every [SoopDanmakuCodec.heartbeatInterval]; a
///   socket silent for [SoopDanmakuCodec.silenceTimeout] is replaced.
/// - A connect failure is retried on the next endpoint of the room (the TLS
///   port first, the plain port second — the plain one answers where the
///   TLS port drops the handshake); the failure after
///   [SoopDanmakuCodec.maxReconnects] runs without an opened one ends the
///   session with a terminal system message. An open socket clears the
///   count.
///
/// The run lifecycle — the generation the handshakes and their callbacks
/// guard with — is the shared base's ([DanmakuSessionBase]): every handshake
/// is one [DanmakuRun], and the base drops whatever a dead one reports.
final class SoopDanmakuSession extends DanmakuSessionBase {
  /// The comments of [args]' room over [site]. [timers] and [joinDelay] are
  /// injectable for tests.
  SoopDanmakuSession({required this.args, required this.site, super.timers, Duration? joinDelay})
    : _joinDelay = joinDelay ?? SoopDanmakuCodec.joinDelay;

  /// The chat this session joins.
  final SoopDanmakuArgs args;

  /// The site its socket connections come from.
  final SoopSite site;

  /// The pause between the login and the join packet.
  final Duration _joinDelay;

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _failures = 0;
  int _endpointIndex = 0;

  /// Opens the first socket; null once it is on its way, else why the room
  /// has no chat to join.
  ///
  /// The reference's runtime retries a failed handshake like any later one,
  /// so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) return const LiveSiteError.unsupported(siteId: soopSiteId, message: 'session is disposed');
    if (!args.url.hasAuthority || args.chatNo.isEmpty) {
      return const LiveSiteError.contentUnavailable(siteId: soopSiteId, message: 'the room names no chat server');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (isDisposed) return;
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return;
    final endpoints = SoopDanmakuCodec.endpoints(args);
    final endpoint = endpoints[_endpointIndex % endpoints.length];
    final SocketChannel socket;
    try {
      socket = await site.connect(
        endpoint,
        headers: SoopDanmakuCodec.handshakeHeaders(args.headers),
        protocols: SoopDanmakuCodec.protocols,
        connectTimeout: SoopDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      if (run.isActive) {
        _endpointIndex = (_endpointIndex + 1) % endpoints.length;
        _failed('$error', run);
      }
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
    _failures = 0;
    _endpointIndex = 0;
    // An open socket counts as joined: the login goes out at once, the join
    // a pause later (3.x's `joinRoom`).
    run.joined();
    _send(SoopDanmakuCodec.login);
    _join = timers.after(_joinDelay, () {
      if (run.isActive) _send(SoopDanmakuCodec.join(args.chatNo));
    });
    _startHeartbeat();
    _startWatchdog(run);
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

  void _onData(Object? data, DanmakuRun run) {
    // Chat comes in binary frames; text frames carry nothing to decode.
    if (data is! List<int>) return;
    _startWatchdog(run);
    for (final message in SoopDanmakuCodec.decode(data)) {
      if (!run.isActive) return;
      run.message(message);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = timers.every(SoopDanmakuCodec.heartbeatInterval, (_) {
      if (!isDisposed) _send(SoopDanmakuCodec.heartbeat);
    });
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(SoopDanmakuCodec.silenceTimeout, () {
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

  /// A handshake that did not come to a socket: counted, and retried after
  /// the backoff's step; the budget's end is told once and closes the
  /// stream.
  void _failed(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    _scheduleRetry(reason, run);
  }

  /// The socket is to be replaced after the backoff's step;
  /// [SoopDanmakuCodec.maxReconnects] runs without an opened one end the
  /// session.
  void _scheduleRetry(String reason, DanmakuRun run) {
    _cancelTimers();
    if (!run.isActive) return;
    _failures += 1;
    if (_failures > SoopDanmakuCodec.maxReconnects) {
      _terminate(reason, run);
      return;
    }
    run.reconnecting(reason);
    _retry = timers.after(SoopDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (!run.isActive) return;
      unawaited(_handshake());
    });
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    run
      ..exhausted(reason)
      ..message(LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white));
    unawaited(dispose());
  }

  void _cancelTimers() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _join?.cancel();
    _join = null;
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

  /// Releases the transport and the protocol timers; safe when nothing is
  /// open.
  @override
  Future<void> stop() async {
    _cancelTimers();
    await _teardownSocket();
  }
}
