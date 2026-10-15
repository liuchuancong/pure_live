import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/sixroom/danmaku/sixroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_failure.dart';
import 'package:live_sites/src/platforms/sixroom/parsers/sixroom_room_parser.dart';
import 'package:live_sites/src/platforms/sixroom/sixroom_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates chat sessions for Six Rooms' rooms.
///
/// The session joins by the room number and the broadcaster's user id, which
/// the room detail carries on the room's danmaku handle — so a session is
/// built from a fresh detail. A room id that is no room number, or one whose
/// broadcaster the entry could not name, has no handle and is reported
/// content-unavailable rather than joined empty.
final class SixroomDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which reads the room's broadcaster).
  SixroomDanmakuProvider({required this.site});

  /// The site this capability serves.
  final SixroomSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final SixroomDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! SixroomDanmakuArgs || SixroomDanmakuCodec.checked(handle) == null) {
        return left(LiveSiteError.contentUnavailable(siteId: 'sixroom', message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on SixroomFailure catch (failure) {
      return left(failure.toLiveSiteError('sixroom'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'sixroom', message: '$error', cause: error));
    }
    final session = SixroomDanmakuSession(args: args, site: site);
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
typedef SixroomTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One chat connection: one WebSocket as an anonymous guest, the way the
/// room page joins a room's chat.
///
/// - Every handshake asks `getChat.php` for the room's chat servers (again
///   once each was used), then opens the next one; a request that fails or
///   gives no server counts as a failed handshake.
/// - At every open it logs in with the run's guest id; `login.success`
///   joins and sends a heartbeat at once, as the page does. The login has
///   6 s; a refused login reconnects, more than three in a row end the
///   session. A flag on which the page stops its socket ends it too.
/// - The page's `noop` heartbeat every 16 s; the server answers each, and a
///   socket silent for 90 s is replaced.
/// - Public chat, fly-screen messages as super chats and gifts are
///   reported.
///
/// Eight reconnects without a joined run end the session with a terminal
/// system message.
final class SixroomDanmakuSession implements LiveDanmakuSession {
  /// The chat of [args]' room over [site]. [timers] and [now] are
  /// injectable for tests; [random] picks the guest id.
  SixroomDanmakuSession({
    required this.args,
    required this.site,
    SixroomTimers? timers,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic),
       _random = random ?? Random.secure();

  /// The room this session joined.
  final SixroomDanmakuArgs args;

  /// The site its socket connections and server lists come from.
  final SixroomSite site;

  final DateTime Function() _now;
  final SixroomTimers _timers;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  List<Uri> _servers = const [];
  int _nextServer = 0;
  late final int _guestId = SixroomDanmakuCodec.guestId(_random);
  int _generation = 0;
  int _failures = 0;
  int _refusals = 0;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the room
  /// has no chat to join.
  ///
  /// Like the page, a failed first handshake is retried in the background,
  /// so a failure starts the retries instead of ending the session, and
  /// this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: 'sixroom', message: 'session is disposed');
    if (SixroomDanmakuCodec.checked(args) == null) {
      return const LiveSiteError.notFound(siteId: 'sixroom', message: 'not a Six Rooms chat room');
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
    final List<Uri> servers;
    try {
      servers = await _serverList();
    } on Object catch (error) {
      _failed(generation, '$error');
      return;
    }
    if (_disposed || generation != _generation) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        servers[_nextServer++],
        headers: SixroomDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: SixroomDanmakuCodec.connectTimeout,
      );
    } on Object catch (error) {
      _failed(generation, '$error');
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
    _startWatchdog();
    _join = _timers.after(SixroomDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no login answer within ${SixroomDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
    // The login goes out as soon as the socket opens.
    _send(SixroomDanmakuCodec.login(_guestId, args.userId));
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

  /// The room's chat servers: the list asked for once and reused while it
  /// has an unused server left, then asked for again, as the page moves to
  /// the next server at every new login.
  Future<List<Uri>> _serverList() async {
    if (_nextServer < _servers.length) return _servers;
    final response = await site.http.getChat(SixroomDanmakuCodec.serversUrl(args), roomId: args.roomId);
    final servers = SixroomDanmakuCodec.servers(response);
    _nextServer = 0;
    return _servers = servers;
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = SixroomDanmakuCodec.decode(data, now: _now());
    if (frame.refusal case final refusal?) {
      _terminate('chat refused: $refusal');
      return;
    }
    if (frame.loginFailed) {
      _joined = false;
      if (++_refusals > SixroomDanmakuCodec.maxRefusals) {
        _terminate('chat refused: login.failed');
        return;
      }
      _scheduleRetry('login refused');
      return;
    }
    if (frame.joined && !_joined) {
      _joined = true;
      _refusals = 0;
      _failures = 0;
      _join?.cancel();
      _join = null;
      // The page sends a heartbeat a second after the login.
      _send(SixroomDanmakuCodec.heartbeat);
      _startHeartbeat();
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      _report(message);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(SixroomDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(SixroomDanmakuCodec.heartbeat);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(SixroomDanmakuCodec.silenceTimeout, () {
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

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(int generation, String reason) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  /// The socket is to be replaced after the backoff's step;
  /// [SixroomDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > SixroomDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(SixroomDanmakuCodec.reconnectBaseDelay * _failures, () {
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
