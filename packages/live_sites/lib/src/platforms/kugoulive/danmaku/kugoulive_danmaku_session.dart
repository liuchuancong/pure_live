import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for Kugou Live rooms.
///
/// The session joins by the room number, which the room detail carries on
/// the room's danmaku handle — so a session is built from a fresh detail. A
/// room that is not live has no handle and is reported content-unavailable
/// rather than joined empty.
final class KugouliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room and its transport).
  KugouliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final KugouliveDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! KugouliveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room $roomId has no live session'));
      }
      args = handle;
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = KugouliveDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'kugoulive';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef KugouliveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection, as the website's room page joins anonymously.
///
/// - Before the first socket it asks the scheduler for the room's hosts and
///   token (three tries, 1.5 s and 4.5 s apart, the page's backoff); a
///   refusal or three failures end the session with a terminal message.
/// - Every socket logs in (201; 2201 with the last session once the room has
///   been joined) and is joined when the status frame accepts it; a socket
///   that is not joined in [KugouliveDanmakuCodec.joinTimeout] is replaced.
/// - The token is kept for the next sockets, as the page keeps it, until it
///   is older than the scheduler's `age`, was refused (622) or went on a
///   socket that was replaced before the server answered its login: then the
///   handshake asks the scheduler again first.
/// - The binary heartbeat goes every 10 s; a socket silent for
///   [KugouliveDanmakuCodec.silenceTimeout] is replaced;
///   [KugouliveDanmakuCodec.maxReconnects] runs without a joined one end the
///   session.
/// - Chat of the room, its audience and its gifts are reported; gifts are
///   acknowledged as the page does, and a gift the server sends again (the
///   same `msgId`) is reported once.
final class KugouliveDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' room over [site]. [now], [timers] and [random]
  /// (the login's session and device ids) are injectable for tests.
  KugouliveDanmakuSession({
    required this.args,
    required this.site,
    KugouliveTimers? timers,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The room this session joins.
  final KugouliveDanmakuArgs args;

  /// The site its scheduler answers and sockets come from.
  final KugouliveSite site;

  final DateTime Function() _now;
  final KugouliveTimers _timers;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();

  /// The `msgId`s of the last gifts reported; the server repeats an
  /// unacknowledged gift twice, about 2 s apart.
  final LinkedHashSet<String> _gifts = LinkedHashSet();
  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  KugouliveChatGrant? _grant;
  DateTime _grantedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sent = false;
  bool _answered = false;
  bool _everJoined = false;
  String _sessionId = '';
  String _sid = '';
  String _deviceNo = '';
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Asks the scheduler and opens the first socket; null once it is on its
  /// way, else why the room has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: 'kugoulive', message: 'session is disposed');
    if (KugouliveDanmakuCodec.checkedRoom(args.roomId) == null) {
      return const LiveSiteError.notFound(siteId: 'kugoulive', message: 'not a Kugou Live room');
    }
    _sid = KugouliveDanmakuCodec.uuid(_random);
    _deviceNo = KugouliveDanmakuCodec.uuid(_random);
    unawaited(_start());
    return null;
  }

  /// The page's waits before the second and third scheduler request of a
  /// start (`1500 × (2^n − 1)` ms).
  static const List<Duration> _dispatchRetryDelays = [Duration(milliseconds: 1500), Duration(milliseconds: 4500)];

  /// The scheduler, then a socket. A refusal of the scheduler ends the
  /// session; three failures are retried on the page's backoff first.
  Future<void> _start() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    if (!_usable) {
      Object? failure;
      for (var attempt = 0; attempt <= _dispatchRetryDelays.length; attempt++) {
        try {
          await _renew();
          failure = null;
          break;
        } on KugouliveDispatchRefusal catch (refusal) {
          _terminate('$refusal');
          return;
        } on Object catch (error) {
          failure = error;
          if (attempt < _dispatchRetryDelays.length) {
            final done = Completer<void>();
            _timers.after(_dispatchRetryDelays[attempt], done.complete);
            await done.future;
            if (_disposed || generation != _generation) return;
          }
        }
      }
      if (_grant == null) {
        _failed('dispatch: $failure', generation);
        return;
      }
    }
    await _openSocket(generation);
  }

  /// Whether the kept token may go on a new socket: there is one, it is
  /// younger than its `age`, and the server answered the last login it went
  /// on (a join, or a refusal that was not about the token).
  bool get _usable {
    final grant = _grant;
    if (grant == null || (_sent && !_answered)) return false;
    final age = _now().difference(_grantedAt);
    return age >= Duration.zero && age < grant.age;
  }

  /// Asks the scheduler for the room.
  Future<void> _renew() async {
    final response = await site.http.get(
      KugouliveDanmakuCodec.dispatchUrl(args.roomId, now: _now()),
      headers: KugouliveDanmakuCodec.dispatchHeaders(args.roomId),
    );
    final grant = KugouliveDanmakuCodec.grant(response.text, status: response.status);
    if (_disposed) return;
    _grant = grant;
    _grantedAt = _now();
    _sent = false;
    _answered = false;
  }

  Future<void> _openSocket(int generation) async {
    final grant = _grant;
    if (grant == null || _disposed || generation != _generation) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        grant.endpoints.first,
        headers: KugouliveDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: KugouliveDanmakuCodec.silenceTimeout,
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
    _sent = true;
    _answered = false;
    _startHeartbeat();
    _startWatchdog();
    _join = _timers.after(KugouliveDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no login within ${KugouliveDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
    socket.add(
      KugouliveDanmakuCodec.login(
        roomId: args.roomId,
        token: grant.token,
        sid: _sid,
        deviceNo: _deviceNo,
        sessionId: _sessionId,
        again: _everJoined,
      ),
    );
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

  bool get _joined => _everJoined && _answered && _refusals == 0 && _socket != null;

  void _onData(Object? data) {
    _startWatchdog();
    final frame = KugouliveDanmakuCodec.decode(data, roomId: args.roomId);
    if (frame.ack case final ack?) _send(ack);
    if (frame.refusal case final refusal?) {
      _refused(refusal);
      return;
    }
    if (frame.joined) {
      _answered = true;
      _everJoined = true;
      _refusals = 0;
      _failures = 0;
      _sessionId = frame.sessionId ?? _sessionId;
      _join?.cancel();
      _join = null;
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      if (message.type == LiveMessageType.gift && !_firstGift(message.messageId)) continue;
      _report(message);
    }
  }

  /// Whether the gift [messageId] was not reported yet (and marks it); a
  /// gift without one always is.
  bool _firstGift(String messageId) {
    if (messageId.isEmpty) return true;
    if (!_gifts.add(messageId)) return false;
    if (_gifts.length > 256) _gifts.remove(_gifts.first);
    return true;
  }

  /// A refused login: the token is dropped when the server refused it, then
  /// a new socket; more than three refusals in a row end the session.
  void _refused(KugouliveChatRefusal refusal) {
    if (refusal.tokenRejected) {
      _grant = null;
    } else {
      _answered = true;
    }
    _refusals += 1;
    if (_refusals > KugouliveDanmakuCodec.maxRefusals) {
      _terminate('chat refused: $refusal');
      return;
    }
    _scheduleRetry('login refused');
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(KugouliveDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(KugouliveDanmakuCodec.heartbeat());
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(KugouliveDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
    });
  }

  void _send(Object frame) {
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

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  /// The socket is to be replaced after the backoff's step;
  /// [KugouliveDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > KugouliveDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(KugouliveDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_start());
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
