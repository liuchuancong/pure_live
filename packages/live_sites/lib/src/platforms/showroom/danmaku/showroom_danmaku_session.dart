import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_failure.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/showroom_manifest.dart';
import 'package:live_sites/src/platforms/showroom/showroom_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for SHOWROOM broadcasts.
///
/// The session joins by the broadcast server and key of `live/live_info`,
/// which the room detail carries on the room's danmaku handle — so a session
/// is built from a fresh detail. A room without a usable comment server (an
/// offline one, or one whose answer named none) is reported
/// content-unavailable rather than joined empty.
final class ShowroomDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's comment server).
  ShowroomDanmakuProvider({required this.site});

  /// The site this capability serves.
  final ShowroomSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final ShowroomDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! ShowroomDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room $roomId has no comment server'));
      }
      args = handle;
    } on ShowroomFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = ShowroomDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'showroom';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef ShowroomTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: one WebSocket per broadcast, subscribed once.
///
/// - `SUB\t<key>` goes out as soon as the socket opens, and the room counts
///   as joined: the server confirms nothing, as for the web client, so there
///   is no join timer.
/// - `PING\tshowroom` goes out every
///   [ShowroomDanmakuCodec.heartbeatInterval]; the `ACK` and every broadcast
///   frame keep the room from looking silent, so a socket without any frame
///   for [ShowroomDanmakuCodec.silenceTimeout] is replaced.
/// - Comments and gifts are reported; the room's gift table is asked for
///   once per session in the background, and gifts before it comes, or
///   without it, have their ids and pictures only.
/// - A socket that errors, closes or goes silent is reconnected;
///   [ShowroomDanmakuCodec.maxReconnects] runs without a joined one end the
///   session with a terminal system message.
final class ShowroomDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [site]. [now] and [timers] are
  /// injectable for tests.
  ShowroomDanmakuSession({required this.args, required this.site, ShowroomTimers? timers, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The broadcast this session subscribes to.
  final ShowroomDanmakuArgs args;

  /// The site its socket connections and gift table come from.
  final ShowroomSite site;

  final DateTime Function() _now;
  final ShowroomTimers _timers;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _retry;
  ShowroomGiftCatalog _gifts = ShowroomGiftCatalog.empty;
  var _giftsAsked = false;
  int _generation = 0;
  int _failures = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the
  /// broadcast has no chat to join.
  ///
  /// The reference retries a failed first connection like any later one, so
  /// a failure starts the background retries instead of ending the session,
  /// and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: showroomSiteId, message: 'session is disposed');
    final checked = ShowroomDanmakuCodec.checked(args);
    if (checked == null) {
      return const LiveSiteError.notFound(siteId: showroomSiteId, message: 'not a SHOWROOM broadcast server or key');
    }
    unawaited(_handshake());
    unawaited(_loadGifts());
    return null;
  }

  /// The room's gift table, asked for once per session in the background;
  /// gifts before it comes, or without it, have their ids and pictures.
  Future<void> _loadGifts() async {
    if (_giftsAsked || _disposed) return;
    _giftsAsked = true;
    try {
      final catalog = await site.giftCatalog(args.roomId);
      if (!_disposed) _gifts = catalog;
    } on Object {
      // No table: gifts keep their ids and pictures.
    }
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        ShowroomDanmakuCodec.endpoint(args.host),
        headers: ShowroomDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: ShowroomDanmakuCodec.silenceTimeout,
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
    // An open socket counts as joined, so this run came to live: the
    // reconnect budget is about runs that never did.
    _failures = 0;
    _startHeartbeat();
    _startWatchdog();
    // The subscription goes out as soon as the socket opens; the server
    // confirms nothing, so the room counts as joined now.
    _send(ShowroomDanmakuCodec.subscribe(args.key));
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
    for (final message in ShowroomDanmakuCodec.decode(data, key: args.key, gifts: _gifts)) {
      if (_disposed) return;
      _events.add(message);
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(ShowroomDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(ShowroomDanmakuCodec.ping);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(ShowroomDanmakuCodec.silenceTimeout, () {
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
  /// [ShowroomDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > ShowroomDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(ShowroomDanmakuCodec.reconnectBaseDelay * _failures, () {
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
