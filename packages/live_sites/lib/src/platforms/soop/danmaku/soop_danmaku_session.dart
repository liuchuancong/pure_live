import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
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
typedef SoopTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One chat connection: one WebSocket per room.
///
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
final class SoopDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' room over [site]. [timers] and [joinDelay] are
  /// injectable for tests.
  SoopDanmakuSession({required this.args, required this.site, SoopTimers? timers, Duration? joinDelay})
    : _timers = timers ?? (after: Timer.new, every: Timer.periodic),
      _joinDelay = joinDelay ?? SoopDanmakuCodec.joinDelay;

  /// The chat this session joins.
  final SoopDanmakuArgs args;

  /// The site its socket connections come from.
  final SoopSite site;

  final SoopTimers _timers;

  /// The pause between the login and the join packet.
  final Duration _joinDelay;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;
  int _endpointIndex = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the room
  /// has no chat to join.
  ///
  /// The reference's runtime retries a failed handshake like any later one,
  /// so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: soopSiteId, message: 'session is disposed');
    if (!args.url.hasAuthority || args.chatNo.isEmpty) {
      return const LiveSiteError.contentUnavailable(siteId: soopSiteId, message: 'the room names no chat server');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
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
      if (generation == _generation && !_disposed) {
        _endpointIndex = (_endpointIndex + 1) % endpoints.length;
        _failed('$error', generation);
      }
      return;
    }
    if (_disposed || generation != _generation) {
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
    _send(SoopDanmakuCodec.login);
    _join = _timers.after(_joinDelay, () {
      if (generation == _generation && !_disposed) _send(SoopDanmakuCodec.join(args.chatNo));
    });
    _startHeartbeat();
    _startWatchdog();
    _subscription = socket.stream.listen(
      (data) {
        if (generation == _generation && !_disposed) _onData(data);
      },
      onDone: () {
        if (generation == _generation && !_disposed) _scheduleRetry('socket closed');
      },
      onError: (Object error) {
        if (generation == _generation && !_disposed) _scheduleRetry('$error');
      },
    );
  }

  void _onData(Object? data) {
    // Chat comes in binary frames; text frames carry nothing to decode.
    if (data is! List<int>) return;
    _startWatchdog();
    for (final message in SoopDanmakuCodec.decode(data)) {
      if (_disposed) return;
      _events.add(message);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(SoopDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(SoopDanmakuCodec.heartbeat);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(SoopDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
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
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  /// The socket is to be replaced after the backoff's step;
  /// [SoopDanmakuCodec.maxReconnects] runs without an opened one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > SoopDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(SoopDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _events.add(LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white));
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

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _generation += 1;
    _cancelTimers();
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    await _teardownSocket();
    await _events.close();
  }
}
