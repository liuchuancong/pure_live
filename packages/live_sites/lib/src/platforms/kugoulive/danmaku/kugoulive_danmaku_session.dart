import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_manifest.dart';
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
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final KugouliveDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! KugouliveDanmakuArgs) {
        return left(
          LiveSiteError.contentUnavailable(siteId: _site, message: 'room ${room.roomId} has no live session'),
        );
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
typedef KugouliveTimers = DanmakuTimers;

/// One comment connection, as the website's room page joins anonymously.
///
/// - Before the first socket it asks the scheduler for the room's hosts and
///   token (three tries, 1.5 s and 4.5 s apart, the page's backoff); a
///   refusal or three failures end the session with a terminal message.
/// - Every socket logs in (201; 2201 with the last session once the room has
///   been joined) and is joined when the status frame accepts it; a socket
///   that is not joined in [KugouliveDanmakuCodec.joinTimeout] is replaced.
///   Each replacement goes to the next of the scheduler's hosts, round and
///   round, as the page's socket wrapper moves on.
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
///
/// The run lifecycle — the generation the handshakes and their callbacks
/// guard with — is the shared base's ([DanmakuSessionBase]): every handshake
/// is one [DanmakuRun], and the base drops whatever a dead one reports.
final class KugouliveDanmakuSession extends DanmakuSessionBase {
  /// The comments of [args]' room over [site]. [timers], [now] and [random]
  /// (the login's session and device ids) are injectable for tests.
  KugouliveDanmakuSession({
    required this.args,
    required this.site,
    super.timers,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The room this session joins.
  final KugouliveDanmakuArgs args;

  /// The site its scheduler answers and sockets come from.
  final KugouliveSite site;

  final DateTime Function() _now;
  final Random _random;

  /// The `msgId`s of the last gifts reported; the server repeats an
  /// unacknowledged gift twice, about 2 s apart.
  final LinkedHashSet<String> _gifts = LinkedHashSet();
  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _retry;
  KugouliveChatGrant? _grant;
  DateTime _grantedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _sent = false;
  bool _answered = false;
  bool _everJoined = false;
  String _sessionId = '';
  String _sid = '';
  String _deviceNo = '';

  /// Which of the scheduler's hosts the next socket goes to: every
  /// reconnect moves on to the next one, so a host that is down costs one
  /// attempt rather than the whole budget.
  int _endpoint = 0;
  int _failures = 0;
  int _refusals = 0;

  /// Asks the scheduler and opens the first socket; null once it is on its
  /// way, else why the room has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) return const LiveSiteError.unsupported(siteId: kugouliveSiteId, message: 'session is disposed');
    if (KugouliveDanmakuCodec.checkedRoom(args.roomId) == null) {
      return const LiveSiteError.notFound(siteId: kugouliveSiteId, message: 'not a Kugou Live room');
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
    if (isDisposed) return;
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return;
    if (!_usable) {
      Object? failure;
      for (var attempt = 0; attempt <= _dispatchRetryDelays.length; attempt++) {
        try {
          await _renew();
          failure = null;
          break;
        } on KugouliveDispatchRefusal catch (refusal) {
          _terminate('$refusal', run);
          return;
        } on Object catch (error) {
          failure = error;
          if (attempt < _dispatchRetryDelays.length) {
            if (!await run.delay(_dispatchRetryDelays[attempt])) return;
          }
        }
      }
      if (_grant == null) {
        _failed('dispatch: $failure', run);
        return;
      }
    }
    await _openSocket(run);
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
    if (isDisposed) return;
    _grant = grant;
    _grantedAt = _now();
    _sent = false;
    _answered = false;
  }

  Future<void> _openSocket(DanmakuRun run) async {
    final grant = _grant;
    if (grant == null || !run.isActive) return;
    // The scheduler hands out several hosts (three in practice); a renewed
    // grant listing fewer keeps the turn within its own list.
    final endpoint = grant.endpoints[_endpoint % grant.endpoints.length];
    final SocketChannel socket;
    try {
      socket = await site.connect(
        endpoint,
        headers: KugouliveDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: KugouliveDanmakuCodec.silenceTimeout,
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
    _sent = true;
    _answered = false;
    run.handshakeDone();
    _startHeartbeat();
    _startWatchdog(run);
    run.armJoinTimeout(KugouliveDanmakuCodec.joinTimeout, () {
      _scheduleRetry('no login within ${KugouliveDanmakuCodec.joinTimeout.inSeconds} s', run);
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
    _startWatchdog(run);
    final frame = KugouliveDanmakuCodec.decode(data, roomId: args.roomId);
    if (frame.ack case final ack?) _send(ack);
    if (frame.refusal case final refusal?) {
      _refused(refusal, run);
      return;
    }
    if (frame.joined) {
      _answered = true;
      _everJoined = true;
      _refusals = 0;
      _failures = 0;
      _sessionId = frame.sessionId ?? _sessionId;
      if (!run.isJoined) run.joined();
    }
    for (final message in frame.messages) {
      if (!run.isActive) return;
      if (message.type == LiveMessageType.gift && !_firstGift(message.messageId)) continue;
      run.message(message);
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
  void _refused(KugouliveChatRefusal refusal, DanmakuRun run) {
    if (refusal.tokenRejected) {
      _grant = null;
    } else {
      _answered = true;
    }
    _refusals += 1;
    if (_refusals > KugouliveDanmakuCodec.maxRefusals) {
      _terminate('chat refused: $refusal', run);
      return;
    }
    _scheduleRetry('login refused', run);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = timers.every(KugouliveDanmakuCodec.heartbeatInterval, (_) {
      if (!isDisposed) _send(KugouliveDanmakuCodec.heartbeat());
    });
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(KugouliveDanmakuCodec.silenceTimeout, () {
      if (run.isActive) _scheduleRetry('socket silent', run);
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

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    _scheduleRetry(reason, run);
  }

  /// The socket is to be replaced after the backoff's step, on the next of
  /// the scheduler's hosts; [KugouliveDanmakuCodec.maxReconnects] runs
  /// without a joined one end the session.
  void _scheduleRetry(String reason, DanmakuRun run) {
    _cancelTimers();
    if (!run.isActive) return;
    _failures += 1;
    if (_failures > KugouliveDanmakuCodec.maxReconnects) {
      _terminate(reason, run);
      return;
    }
    _endpoint += 1;
    run.reconnecting(reason);
    _retry = timers.after(KugouliveDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (!run.isActive) return;
      unawaited(_start());
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
