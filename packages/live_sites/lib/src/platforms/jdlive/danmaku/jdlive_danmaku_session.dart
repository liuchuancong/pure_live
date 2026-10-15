import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/jdlive/api/jdlive_endpoints.dart';
import 'package:live_sites/src/platforms/jdlive/danmaku/jdlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/jdlive/jdlive_site.dart';
import 'package:live_sites/src/platforms/jdlive/parsers/jdlive_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for JD Live broadcasts.
///
/// The session joins by the broadcast id, which the room detail carries on
/// the room's danmaku handle — so a session is built from a fresh detail. A
/// broadcast that is not live or is app-only has no handle and is reported
/// content-unavailable rather than joined empty.
final class JdliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  JdliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final JdliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final JdliveDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! JdliveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on JdliveFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = JdliveDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'jdlive';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own, so that the silence watchdog and a backoff step can be read
/// out of a connection without waiting out the platform's patience.
typedef JdliveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: the website's guest `liveauth` and the socket its
/// token opens, one socket per broadcast.
///
/// - Every handshake, the first and each reconnect, first POSTs `liveauth`
///   for a fresh token, as the page does after a socket error: a token opens
///   one socket. A request that fails or is refused counts as a failed
///   handshake; after [JdliveDanmakuCodec.maxReconnects] of them without a
///   live socket a terminal system message closes [events]. A handshake
///   under way when the session is closed is cancelled.
/// - The client sends nothing: the website's join frame only announces a
///   visitor. An open socket counts as joined.
/// - The server sends the audience about every 3.5 s while most broadcasts
///   are live, and drops a socket after 180 s without a frame;
///   [JdliveDanmakuCodec.silenceTimeout] without any frame replaces the
///   socket (a half-open one), and a socket that errors or closes likewise.
/// - `stop_live_broadcast` ends the session with a terminal system message:
///   the server pushes nothing more for that broadcast, and a new one has a
///   new id.
/// - Failures name the socket URL without its token.
final class JdliveDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [site]. [now], [timers] and
  /// [random] (the `liveauth` nonces) are injectable for tests.
  JdliveDanmakuSession({
    required this.args,
    required this.site,
    JdliveTimers? timers,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The broadcast this session joins.
  final JdliveDanmakuArgs args;

  /// The site its `liveauth` answers and sockets come from.
  final JdliveSite site;

  final DateTime Function() _now;
  final JdliveTimers _timers;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _watchdog;
  Timer? _retry;
  CancelToken? _auth;
  String? _maskKey;
  int _generation = 0;
  int _failures = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Runs the first handshake; null once the socket is on its way, else why
  /// the broadcast has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: 'jdlive', message: 'session is disposed');
    if (!JdliveEndpoints.isLiveId(args.liveId)) {
      return const LiveSiteError.notFound(siteId: 'jdlive', message: 'not a JD Live broadcast');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    final JdliveChatAuth auth;
    try {
      final cancel = _auth = CancelToken();
      final answer = await site.http.post(
        JdliveDanmakuCodec.endpoint(args.liveId),
        JdliveDanmakuCodec.authFields(args.liveId, now: _now(), nonce: JdliveDanmakuCodec.nonce(_random)),
        cancel: cancel,
        timeout: JdliveDanmakuCodec.silenceTimeout,
      );
      if (identical(_auth, cancel)) _auth = null;
      auth = JdliveDanmakuCodec.auth(answer.text, status: answer.status);
    } on CancelledFailure {
      return;
    } on Object catch (error) {
      _failed(JdliveDanmakuCodec.redact('$error'), generation);
      return;
    }
    if (_disposed || generation != _generation) return;
    _maskKey = auth.maskKey;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        auth.socketUrl,
        headers: JdliveDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: JdliveDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed(JdliveDanmakuCodec.redact('$error'), generation);
      return;
    }
    if (_disposed || generation != _generation) {
      // Closed or replaced while the handshake was in flight: close what we
      // just opened instead of parking it on a dead generation.
      try {
        await socket.close();
      } on Object {
        // Already closed or broken.
      }
      return;
    }
    _socket = socket;
    _failures = 0;
    _startWatchdog();
    _subscription = socket.stream.listen(
      (data) {
        if (generation == _generation && !_disposed) _onData(data);
      },
      onDone: () {
        if (generation == _generation && !_disposed) _scheduleRetry('socket closed');
      },
      onError: (Object error) {
        if (generation == _generation && !_disposed) _scheduleRetry(JdliveDanmakuCodec.redact('$error'));
      },
    );
  }

  /// A handshake or socket that did not come to live: counted, and retried
  /// after the backoff's step; the budget's end is told once and closes the
  /// stream.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = JdliveDanmakuCodec.decode(data, liveId: args.liveId, maskKey: _maskKey);
    for (final message in frame.messages) {
      if (_disposed) return;
      _report(message);
    }
    if (frame.ended) _terminate('Broadcast ended');
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(JdliveDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
    });
  }

  /// The socket is to be replaced after the backoff's step;
  /// [JdliveDanmakuCodec.maxReconnects] of them without a live one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > JdliveDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(JdliveDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
  }

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white, sentAt: _now()),
    );
    unawaited(dispose());
  }

  void _cancelTimers() {
    _watchdog?.cancel();
    _watchdog = null;
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    await _subscription?.cancel();
    _subscription = null;
    _socket = null;
    _maskKey = null;
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
    _auth?.cancel();
    _auth = null;
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    _auth?.cancel();
    _auth = null;
    await _teardownSocket();
    await _events.close();
  }
}
