import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
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
typedef KilakilaTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

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
final class KilakilaDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [site]. [now], [timers] and
  /// [random] are injectable for tests.
  KilakilaDanmakuSession({required this.args, required this.site, KilakilaTimers? timers, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The broadcast this session joins.
  final KilakilaDanmakuArgs args;

  /// The site its socket connections come from.
  final KilakilaSite site;

  final DateTime Function() _now;
  final KilakilaTimers _timers;

  final _events = StreamController<LiveMessage>.broadcast();
  final KilakilaGiftCombos _combos = KilakilaGiftCombos();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the
  /// broadcast has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: kilakilaSiteId, message: 'session is disposed');
    if (!KilakilaEndpoints.isId(args.roomId)) {
      return const LiveSiteError.notFound(siteId: kilakilaSiteId, message: 'not a KilaKila broadcast');
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
    final SocketChannel socket;
    try {
      socket = await site.connect(
        KilakilaDanmakuCodec.endpoint(args.roomId),
        headers: KilakilaDanmakuCodec.handshakeHeaders,
        protocols: null,
        connectTimeout: KilakilaDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed('$error', generation);
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
    _startHeartbeat();
    _startWatchdog();
    _join = _timers.after(KilakilaDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no join within ${KilakilaDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
    // The namespace join goes out as soon as the socket opens.
    _send(KilakilaDanmakuCodec.join(args.roomId));
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

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = KilakilaDanmakuCodec.decode(data, roomId: args.roomId);
    if (frame.refusal case final refusal?) {
      _refused(refusal);
      return;
    }
    if (frame.dropped) {
      _scheduleRetry('the server left the room');
      return;
    }
    if (frame.joined && !_joined) {
      _joined = true;
      _join?.cancel();
      _join = null;
      _refusals = 0;
      _failures = 0;
      return;
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      if (_combos.report(message)) _report(message);
    }
  }

  /// A refused join: the socket is replaced; the refusal after the last
  /// retry ends the session.
  void _refused(String refusal) {
    _refusals += 1;
    if (_refusals > KilakilaDanmakuCodec.maxRefusals) {
      _terminate('join refused: $refusal');
      return;
    }
    _scheduleRetry('join refused: $refusal');
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(KilakilaDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(KilakilaDanmakuCodec.ping);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(KilakilaDanmakuCodec.silenceTimeout, () {
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
  /// [KilakilaDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > KilakilaDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(KilakilaDanmakuCodec.reconnectBaseDelay * _failures, () {
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
