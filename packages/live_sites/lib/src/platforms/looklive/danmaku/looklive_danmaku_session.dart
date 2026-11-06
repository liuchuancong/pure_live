import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
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
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room.dart';
import 'package:live_sites/src/platforms/looklive/parsers/looklive_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates chat sessions for LOOK rooms.
///
/// The session joins the room's Yunxin chatroom anonymously, by the
/// `LookLiveDanmakuArgs` the room entry carries on the room's danmaku
/// handle (a live room answer's `roomInfo.roomId`); a room without one — a
/// card, an ended or banned room — gets a fresh detail, and one that still
/// names no chatroom is reported content-unavailable rather than joined
/// empty.
final class LookliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose transport asks for the chat servers
  /// and the socket.io sessions).
  LookliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final LookliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final LookLiveDanmakuArgs args;
    try {
      final handle = room.runtime.danmakuHandle;
      args = switch (handle) {
        final LookLiveDanmakuArgs args => args,
        _ => switch ((await site.detail(room.roomId)).runtime.danmakuHandle) {
          final LookLiveDanmakuArgs args => args,
          _ => throw LookliveFailure(LookliveFailureKind.streamUnavailable, 'room ${room.roomId} has no chatroom'),
        },
      };
    } on LookliveFailure catch (failure) {
      return left(failure.toLiveSiteError(lookliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: lookliveSiteId, message: '$error', cause: error));
    }
    final session = LookliveDanmakuSession(args: args, site: site);
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
typedef LookliveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One chat connection: an anonymous guest in the room's Yunxin chatroom,
/// as LOOK's website joins it.
///
/// - At every [connect] the room's chat servers are asked once
///   ([LookliveEndpoints.chatAddressPath]), and once more
///   [LookliveDanmakuCodec.addressRetryDelay] after a failure, as the
///   website does. A room that is not live (`code` 404 "无资源") ends the
///   session at once; so does a second failure.
/// - Every handshake first asks the server for a socket.io session (a GET,
///   through the site's transport), then opens its WebSocket; a failed GET
///   counts as a failed handshake (the backoff and
///   [LookliveDanmakuCodec.maxReconnects] attempts). The servers are tried
///   in the answer's order, and the next handshake starts with the server
///   after the one that worked.
/// - When the session opens (`1::`) the guest logs in; the login's answer
///   joins. A refused login reconnects when the code may pass,
///   [LookliveDanmakuCodec.maxRefusals] times in a row at most, else ends
///   the session with a terminal system message; a kick ends it too,
///   unless silent. A server that drops the session (`0::`, `7:::`) and a
///   socket that closes, errors or goes silent for 90 s is reconnected.
/// - The server's `2::` every 25 s is echoed, the link heartbeat goes out
///   every 3 minutes once joined ([LookliveDanmakuSession.heartbeat] sends
///   it at once), and nothing is sent before the session opened.
/// - Chat is reported: text lines, emoji and gifts. The chat has no
///   audience figure LOOK shows.
final class LookliveDanmakuSession implements LiveDanmakuSession {
  /// The chat of [args] over [site]. [timers], [now], [random] and
  /// [_addressRetryDelay] are injectable for tests.
  LookliveDanmakuSession({
    required this.args,
    required this.site,
    LookliveTimers? timers,
    DateTime Function()? now,
    Random? random,
    this._addressRetryDelay = LookliveDanmakuCodec.addressRetryDelay,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The room and chatroom this session joins.
  final LookLiveDanmakuArgs args;

  /// The site its requests and socket connections come from.
  final LookliveSite site;

  final DateTime Function() _now;
  final LookliveTimers _timers;
  final Random _random;
  final Duration _addressRetryDelay;

  final _events = StreamController<LiveMessage>.broadcast();

  /// The guest of this run: one identity for every socket of it.
  late final LookliveGuest _guest = LookliveGuest.random(_random);

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;

  /// The chat servers, as socket endpoints, asked once per [connect].
  List<Uri>? _endpoints;

  /// The endpoint the next handshake starts with (the servers rotate).
  int _endpoint = 0;

  /// The last command serial (the SDK counts from 1 across sockets).
  int _serial = 0;

  /// Joins so far: a later login is a reconnect's.
  int _joins = 0;

  /// Watchdog ticks since the last link heartbeat.
  int _ticks = 0;

  /// Whether the current socket sent its login.
  bool _loggedIn = false;

  /// Whether the current socket's login was accepted.
  bool _joined = false;

  /// Whether the next tick must send the link heartbeat ([heartbeat]).
  bool _forced = false;

  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the room
  /// has no chat to join.
  ///
  /// The chat servers are asked before the answer, so unusable arguments
  /// are the only answer this reports: every later failure is retried in
  /// the background and told as a terminal system message.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: lookliveSiteId, message: 'session is disposed');
    if (LookliveDanmakuCodec.checked(args) == null) {
      return const LiveSiteError.contentUnavailable(siteId: lookliveSiteId, message: 'No usable room or chatroom');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    _socketReset();
    final endpoints = _endpoints ??= await _chatServers(generation);
    if (endpoints.isEmpty || _disposed || generation != _generation) return;
    Object? failure;
    for (var attempt = 0; attempt < endpoints.length; attempt++) {
      final index = (_endpoint + attempt) % endpoints.length;
      final endpoint = endpoints[index];
      final String session;
      try {
        final request = LookliveDanmakuCodec.handshakeRequest(
          endpoint,
          roomId: args.roomId,
          now: _now(),
          timeout: LookliveDanmakuCodec.joinTimeout,
        );
        final response = await site.http.get(request.url, headers: request.headers, cancel: request.cancelToken);
        session = LookliveDanmakuCodec.sessionOf(response);
      } on Object catch (error) {
        failure = error;
        continue;
      }
      final SocketChannel socket;
      try {
        socket = await site.connect(
          LookliveDanmakuCodec.socketUrl(endpoint, session),
          headers: LookliveDanmakuCodec.socketHeaders,
          protocols: null,
          connectTimeout: LookliveDanmakuCodec.joinTimeout,
        );
      } on Object catch (error) {
        failure = error;
        continue;
      }
      if (_disposed || generation != _generation) {
        try {
          await socket.close();
        } on Object {
          // Already closed or broken.
        }
        return;
      }
      _endpoint = (index + 1) % endpoints.length;
      _socket = socket;
      _startWatches(generation);
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
      return;
    }
    _scheduleRetry('$failure');
  }

  /// The chat servers of the room, as socket endpoints: at most
  /// [LookliveDanmakuCodec.addressAttempts] requests; an ended session, a
  /// room that is not live, or two failures answer none (and tell why).
  Future<List<Uri>> _chatServers(int generation) async {
    Object? failure;
    for (var attempt = 0; attempt < LookliveDanmakuCodec.addressAttempts; attempt++) {
      if (attempt > 0) {
        final waited = Completer<void>();
        _retry = _timers.after(_addressRetryDelay, waited.complete);
        await waited.future;
        _retry = null;
        if (_disposed || generation != _generation) return const [];
      }
      try {
        final response = await site.http.post(
          LookliveEndpoints.chatAddressPath,
          LookliveEndpoints.chatAddressPayload(args.roomId),
        );
        if (_disposed || generation != _generation) return const [];
        return LookliveDanmakuCodec.endpoints(LookliveRoomParser.chatAddresses(response.text, status: response.status));
      } on LookliveFailure catch (error) {
        if (_disposed || generation != _generation) return const [];
        if (error.kind == LookliveFailureKind.notFound) {
          _terminate('No chat: ${error.message}');
          return const [];
        }
        failure = error;
      } on Object catch (error) {
        if (_disposed || generation != _generation) return const [];
        failure = error;
      }
    }
    _terminate('Chat servers: $failure');
    return const [];
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = LookliveDanmakuCodec.decode(data, anonymousMode: args.anonymousMode);
    frame.replies.forEach(_send);
    if (frame.opened && !_loggedIn) {
      _loggedIn = true;
      _send(
        LookliveDanmakuCodec.login(chatroomId: args.chatroomId, guest: _guest, serial: ++_serial, again: _joins > 0),
      );
      _join = _timers.after(LookliveDanmakuCodec.joinTimeout, () {
        if (!_disposed && !_joined) {
          _scheduleRetry('no join within ${LookliveDanmakuCodec.joinTimeout.inSeconds} s');
        }
      });
    }
    if (frame.refusal case final code?) {
      _refused(code);
      return;
    }
    if (frame.joined && !_joined) {
      _joined = true;
      _joins += 1;
      _refusals = 0;
      _failures = 0;
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

  /// A refused login: the socket is replaced when the code may pass and the
  /// budget is not spent; the refusal after the last retry ends the
  /// session.
  void _refused(int code) {
    _join?.cancel();
    _join = null;
    if (LookliveDanmakuCodec.retriedRefusals.contains(code) && ++_refusals <= LookliveDanmakuCodec.maxRefusals) {
      _scheduleRetry('login refused: $code');
      return;
    }
    _terminate('Login refused: $code');
  }

  /// A kick: the silent one reconnects; any other ends the session with
  /// the SDK's name for it.
  void _kicked(int reason) {
    if (reason == LookliveDanmakuCodec.silentKick) {
      _scheduleRetry('kicked silently');
      return;
    }
    const reasons = LookliveDanmakuCodec.kickReasons;
    final name = reason > 0 && reason < reasons.length ? reasons[reason] : '$reason';
    _terminate('Kicked: $name');
  }

  void _startWatches(int generation) {
    _startWatchdog();
    _heartbeat?.cancel();
    _heartbeat = _timers.every(LookliveDanmakuCodec.heartbeatInterval, (_) {
      if (generation == _generation && !_disposed) _tick();
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(LookliveDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
    });
  }

  /// The link heartbeat every sixth tick after the login, and at once on
  /// demand; nothing before the login's answer.
  void _tick() {
    final socket = _socket;
    if (socket == null || !_joined) return;
    if (!_forced && ++_ticks < LookliveDanmakuCodec.ticksPerHeartbeat) return;
    _ticks = 0;
    _send(LookliveDanmakuCodec.heartbeat);
  }

  /// Sends the link heartbeat now (when joined).
  void heartbeat() {
    _forced = true;
    try {
      _tick();
    } finally {
      _forced = false;
    }
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

  /// A new socket: nothing sent, nothing joined.
  void _socketReset() {
    _loggedIn = false;
    _joined = false;
    _ticks = 0;
  }

  /// The socket is to be replaced after the backoff's step;
  /// [LookliveDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
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
