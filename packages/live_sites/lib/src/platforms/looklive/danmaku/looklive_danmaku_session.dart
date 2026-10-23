import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart';
import 'package:live_sites/src/platforms/looklive/danmaku/looklive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/looklive/looklive_manifest.dart';
import 'package:live_sites/src/platforms/looklive/looklive_site.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_failure.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for LOOK Live rooms.
///
/// The session joins the room's Yunxin chatroom, which the room answer
/// carries on the room's danmaku handle — so a session is built from a fresh
/// detail. A room that is not live, or whose answer names no chatroom, has
/// no handle and is reported content-unavailable rather than joined empty.
final class LookliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose transport asks for the chat servers and
  /// the socket.io sessions).
  LookliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final LookliveDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! LookliveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room ${room.roomId} opens no chat'));
      }
      args = handle;
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = LookliveDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'looklive';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own, so that the join budget, the silence watchdog, the link
/// heartbeat and a backoff step can be read out of a connection without
/// waiting out the platform's patience.
typedef LookliveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One live chat connection: an anonymous guest in the room's Yunxin
/// chatroom, as LOOK's website joins it.
///
/// - At every handshake the room's chat servers are asked once, and once
///   more [LookliveDanmakuCodec.addressRetryDelay] later when that fails, as
///   the website does. A room that is not live (the answer's `code` 404
///   "无资源") ends the session with a terminal system message at once. The
///   servers are tried in the answer's order, one per handshake.
/// - Every handshake first asks the server for a socket.io session (a GET,
///   through the site's transport), then opens its WebSocket; a failed GET
///   counts as a failed handshake.
/// - When the session opens (`1::`) the guest logs in; the login's answer
///   joins. A refused login reconnects when the code may pass,
///   [LookliveDanmakuCodec.maxRefusals] times in a row at most, else ends
///   the session; a kick ends it too, unless silent.
/// - The server's `2::` is echoed, the link heartbeat goes out every
///   [LookliveDanmakuCodec.ticksPerHeartbeat] ticks of
///   [LookliveDanmakuCodec.heartbeatInterval] after the join, and a socket
///   silent for [LookliveDanmakuCodec.silenceTimeout] is replaced. A socket
///   that errors, closes or is dropped by the server is replaced;
///   [LookliveDanmakuCodec.maxReconnects] runs without a joined one end the
///   session with a terminal system message.
/// - Only chat is reported: text lines, emoji and gifts. The chat has no
///   audience figure LOOK shows.
final class LookliveDanmakuSession implements LiveDanmakuSession {
  /// A session for the room in [args] over [site]. [now], [timers] and
  /// [random] (the guest identity) are injectable for tests.
  LookliveDanmakuSession({
    required this.args,
    required this.site,
    LookliveTimers? timers,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The room this session joins.
  final LookliveDanmakuArgs args;

  /// The site its chat server answers and sockets come from.
  final LookliveSite site;

  final DateTime Function() _now;
  final LookliveTimers _timers;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  CancelToken? _request;
  int _rotation = 0;
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;
  int _joins = 0;
  int _serial = 0;
  int _ticks = 0;
  bool _loggedIn = false;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Runs the first handshake; null once the socket is on its way, else why
  /// the room has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: lookliveSiteId, message: 'session is disposed');
    if (LookliveDanmakuCodec.checked(args) == null) {
      return const LiveSiteError.contentUnavailable(siteId: lookliveSiteId, message: 'not a LOOK room with a chatroom');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    _loggedIn = false;
    _joined = false;
    _ticks = 0;
    final endpoints = await _chatEndpoints(generation);
    if (endpoints == null || _disposed || generation != _generation) return;
    final endpoint = endpoints[_rotation++ % endpoints.length];
    final String sessionId;
    final cancel = _request = CancelToken();
    try {
      final response = await site.http.get(
        LookliveDanmakuCodec.handshakeUrl(endpoint, roomId: args.roomId, now: _now()),
        headers: LookliveDanmakuCodec.handshakeHeaders(args.roomId),
        cancel: cancel,
        timeout: LookliveDanmakuCodec.connectTimeout,
      );
      sessionId = LookliveDanmakuCodec.sessionOf(response.text, status: response.status);
    } on CancelledFailure {
      return;
    } on Object catch (error) {
      _failed('$error', generation);
      return;
    }
    if (identical(_request, cancel)) _request = null;
    if (_disposed || generation != _generation) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        LookliveDanmakuCodec.socketUrl(endpoint, sessionId),
        headers: LookliveDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: LookliveDanmakuCodec.connectTimeout,
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
    _failures = 0;
    _startHeartbeat();
    _startWatchdog();
    _join = _timers.after(LookliveDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no join within ${LookliveDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
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

  /// The chat servers of the room: at most
  /// [LookliveDanmakuCodec.addressAttempts] requests, the second after
  /// [LookliveDanmakuCodec.addressRetryDelay]; null when the generation was
  /// replaced or the failure was handed on. A room that is not live ends the
  /// session at once.
  Future<List<Uri>?> _chatEndpoints(int generation) async {
    var failure = '';
    for (var attempt = 0; attempt < LookliveDanmakuCodec.addressAttempts; attempt++) {
      if (attempt > 0 && !await _wait(LookliveDanmakuCodec.addressRetryDelay, generation)) return null;
      try {
        final response = await site.http.post(
          LookliveEndpoints.chatAddressPath,
          LookliveEndpoints.chatAddressPayload(args.roomId),
          timeout: site.deadline,
        );
        if (_disposed || generation != _generation) return null;
        return LookliveDanmakuCodec.endpoints(LookliveRoomParser.chatAddresses(response.text, status: response.status));
      } on LookliveFailure catch (error) {
        if (error.kind == LookliveFailureKind.notFound) {
          _terminate('no chat: ${error.message}');
          return null;
        }
        if (_disposed || generation != _generation) return null;
        failure = '$error';
      } on Object catch (error) {
        if (_disposed || generation != _generation) return null;
        failure = '$error';
      }
    }
    _failed('chat servers: $failure', generation);
    return null;
  }

  /// [delay] with the session's timers; false when the session was disposed
  /// or the generation replaced meanwhile.
  Future<bool> _wait(Duration delay, int generation) {
    final done = Completer<bool>();
    _timers.after(delay, () {
      if (!done.isCompleted) done.complete(!_disposed && generation == _generation);
    });
    return done.future;
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = LookliveDanmakuCodec.decode(data, anonymousMode: args.anonymousMode);
    frame.replies.forEach(_send);
    if (frame.opened && !_loggedIn) {
      _loggedIn = true;
      _send(
        LookliveDanmakuCodec.login(
          chatroomId: args.chatroomId,
          guest: LookliveGuest.random(_random),
          serial: ++_serial,
          again: _joins > 0,
        ),
      );
    }
    if (frame.refusal case final code?) {
      _refused(code);
      return;
    }
    if (frame.joined && !_joined) {
      _joined = true;
      _joins += 1;
      _refusals = 0;
      _join?.cancel();
      _join = null;
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      _report(message);
    }
    if (frame.kicked case final reason?) {
      _kicked(reason);
      return;
    }
    if (frame.dropped) _scheduleRetry('the server ended the session');
  }

  /// A refused login: the socket is replaced while the code may pass, at
  /// most [LookliveDanmakuCodec.maxRefusals] times in a row; the next
  /// refusal ends the session.
  void _refused(int code) {
    _join?.cancel();
    _join = null;
    if (LookliveDanmakuCodec.retriedRefusals.contains(code) && ++_refusals <= LookliveDanmakuCodec.maxRefusals) {
      _scheduleRetry('login refused: $code');
      return;
    }
    _terminate('login refused: $code');
  }

  /// A kick: the silent one reconnects, the others end the session.
  void _kicked(int reason) {
    if (reason == LookliveDanmakuCodec.silentKick) {
      _scheduleRetry('kicked silently');
      return;
    }
    const reasons = LookliveDanmakuCodec.kickReasons;
    final name = reason > 0 && reason < reasons.length ? reasons[reason] : '$reason';
    _terminate('kicked: $name');
  }

  /// The heartbeat timer's tick: the link heartbeat goes out every
  /// [LookliveDanmakuCodec.ticksPerHeartbeat] ticks, and nothing before the
  /// join.
  void _tick() {
    if (_disposed || !_joined) return;
    if (++_ticks < LookliveDanmakuCodec.ticksPerHeartbeat) return;
    _ticks = 0;
    _send(LookliveDanmakuCodec.heartbeat);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(LookliveDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _tick();
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(LookliveDanmakuCodec.silenceTimeout, () {
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

  /// A handshake or socket that did not come to live: counted, and retried
  /// after the backoff's step; [LookliveDanmakuCodec.maxReconnects] runs
  /// without a joined one end the session.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > LookliveDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(LookliveDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
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

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _generation += 1;
    _cancelTimers();
    _request?.cancel();
    _request = null;
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    _request?.cancel();
    _request = null;
    await _teardownSocket();
    await _events.close();
  }
}
