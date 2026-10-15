import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/danmaku/missevan_danmaku_codec.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates chat sessions for Missevan rooms.
///
/// The session joins by the room number and socket the room entry carries on
/// the room's danmaku handle — so a session is built from a fresh entry, live
/// or not. A room that is gone is not-found rather than joined empty.
final class MissevanDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which reads the room's entry).
  MissevanDanmakuProvider({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final MissevanDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! MissevanDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = MissevanDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef MissevanTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One chat connection: the guest session's cookie, then the room's socket —
/// one socket at a time.
///
/// - The handshake needs the guest session ([MissevanEndpoints.guestSession]
///   sets the `FM_SESS` cookie, [MissevanDanmakuCodec.session] reads it): it
///   is asked up to [MissevanDanmakuCodec.sessionAttempts] requests
///   [MissevanDanmakuCodec.sessionRetryDelay] apart, then reused by the
///   reconnects (it lasts three days). Without one the failed handshakes go
///   through the reconnect budget like any other.
/// - At every open the socket sends the join
///   ([MissevanDanmakuCodec.join], with `reconnect` once the room was joined
///   in this session); the room counts as joined when the server accepts the
///   join by its `uuid`, within [MissevanDanmakuCodec.joinTimeout], or the
///   socket is replaced.
/// - A refused join is answered with a fresh guest session and socket,
///   without a notice, [MissevanDanmakuCodec.maxRejoins] times; the next
///   refusal ends the session with a terminal system message.
/// - The heartbeat `❤️` goes out every
///   [MissevanDanmakuCodec.heartbeatInterval]; the server echoes it, so a
///   socket silent for [MissevanDanmakuCodec.silenceTimeout] is replaced. A
///   socket that errors or closes is replaced too;
///   [MissevanDanmakuCodec.maxReconnects] runs without a joined one end the
///   session the same way.
final class MissevanDanmakuSession implements LiveDanmakuSession {
  /// The chat of [args]' room over [site]. [now], [timers], [random] (the
  /// join's `uuid`) and [sessionRetryDelay] are injectable for tests.
  MissevanDanmakuSession({
    required this.args,
    required this.site,
    MissevanTimers? timers,
    DateTime Function()? now,
    Random? random,
    this.sessionRetryDelay = MissevanDanmakuCodec.sessionRetryDelay,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The room this session joins.
  final MissevanDanmakuArgs args;

  /// The site its guest sessions and sockets come from.
  final MissevanSite site;

  /// The wait between the guest session's attempts.
  final Duration sessionRetryDelay;

  final DateTime Function() _now;
  final MissevanTimers _timers;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  String? _session;
  String _uuid = '';
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;
  bool _joined = false;
  bool _joinedBefore = false;
  String _lastFailure = '';
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the room
  /// has no chat to join.
  ///
  /// A handshake that does not come to live starts the background retries
  /// instead of ending the session, so this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: _site, message: 'session is disposed');
    if (!MissevanEndpoints.isId(args.roomId.trim())) {
      return const LiveSiteError.notFound(siteId: _site, message: 'not a Missevan room');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    _joined = false;
    var session = _session ?? '';
    if (session.isEmpty) {
      session = await _guestSession(generation);
      if (_disposed || generation != _generation) return;
      if (session.isEmpty) {
        _failed(_lastFailure.isEmpty ? 'no guest session' : _lastFailure, generation);
        return;
      }
      _session = session;
    }
    final SocketChannel socket;
    try {
      socket = await site.connect(
        MissevanDanmakuCodec.endpoint(args.url, roomId: args.roomId.trim()),
        headers: MissevanDanmakuCodec.handshakeHeaders(MissevanEndpoints.headers, session),
        protocols: null,
        connectTimeout: MissevanDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed('$error', generation);
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
    _startHeartbeat();
    _startWatchdog();
    _uuid = MissevanDanmakuCodec.uuid(_random);
    _join = _timers.after(MissevanDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no join within ${MissevanDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
    _send(MissevanDanmakuCodec.join(args.roomId.trim(), uuid: _uuid, reconnect: _joinedBefore));
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

  /// The guest session's `FM_SESS` value: up to
  /// [MissevanDanmakuCodec.sessionAttempts] requests, '' when none set one
  /// or the session moved on meanwhile.
  Future<String> _guestSession(int generation) async {
    for (var attempt = 1; attempt <= MissevanDanmakuCodec.sessionAttempts; attempt++) {
      if (attempt > 1 && sessionRetryDelay > Duration.zero) {
        await Future<void>.delayed(sessionRetryDelay * (attempt - 1));
      }
      if (_disposed || generation != _generation) return '';
      try {
        final response = await site.http.get(
          MissevanEndpoints.guestSession,
          timeout: MissevanDanmakuCodec.sessionTimeout,
        );
        final session = MissevanDanmakuCodec.session(response.setCookies);
        if (session != null) return session;
        _lastFailure = 'no guest session';
      } on Object catch (error) {
        if (_disposed || generation != _generation) return '';
        _lastFailure = '$error';
      }
    }
    return '';
  }

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = MissevanDanmakuCodec.decode(data, roomId: args.roomId.trim(), uuid: _uuid, receivedAt: _now());
    switch (frame.joined) {
      case true when !_joined:
        _joined = true;
        _joinedBefore = true;
        _join?.cancel();
        _join = null;
        _refusals = 0;
        _failures = 0;
      case false:
        _refused(frame.refusal);
        return;
      default:
        break;
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      _report(message);
    }
  }

  /// A refused join: the cookie was not accepted, so a fresh one and a new
  /// socket follow without a notice; the refusal after the last rejoin ends
  /// the session.
  void _refused(String refusal) {
    _refusals += 1;
    if (_refusals > MissevanDanmakuCodec.maxRejoins) {
      _terminate('join refused: $refusal');
      return;
    }
    _session = null;
    _scheduleRetry('join refused: $refusal');
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(MissevanDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(MissevanDanmakuCodec.heartbeat);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(MissevanDanmakuCodec.silenceTimeout, () {
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

  /// The socket is to be replaced after the backoff's step;
  /// [MissevanDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > MissevanDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(MissevanDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
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

const String _site = 'missevan';
