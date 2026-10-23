import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for TwitCasting channels.
///
/// The session joins by the live broadcast's movie id, which the room entry
/// carries on the room's danmaku handle — so a session is built from a fresh
/// detail. A channel that is not live (or whose broadcast is
/// password-protected: it is live without being watched) has no handle and is
/// reported content-unavailable rather than joined empty.
final class TwitcastingDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the channel's broadcast).
  TwitcastingDanmakuProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final TwitcastingDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! TwitcastingDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'channel ${room.roomId} opens no chat'));
      }
      args = handle;
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = TwitcastingDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'twitcasting';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own, so that the silence watchdog and a backoff step can be read
/// out of a connection without waiting out the platform's patience.
typedef TwitcastingTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: the player's `eventpubsuburl.php` and the
/// `event.pubsub` socket its answer opens, one socket per broadcast.
///
/// - Every handshake, the first and each reconnect, first POSTs
///   `eventpubsuburl.php` for a freshly signed URL (`movie_id`), as the
///   player does; the request asks for gifts too (`withGifts`). A request
///   that fails or gives no URL counts as a failed handshake; after
///   [TwitcastingDanmakuCodec.maxReconnects] of them without a live socket a
///   terminal system message closes [events]. A handshake under way when the
///   session is closed is cancelled.
/// - The client sends nothing (there is no join frame and no ping; the
///   [TwitcastingDanmakuCodec.keepAliveInterval] only paces the watchdog),
///   so an open socket counts as joined.
/// - The server sends at least an empty array every
///   [TwitcastingDanmakuCodec.keepAliveInterval];
///   [TwitcastingDanmakuCodec.silenceTimeout] without any frame replaces the
///   socket (the player's threshold), and a socket that errors or closes
///   likewise.
/// - Failures name the socket URL without its signature.
final class TwitcastingDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [site]. [now] and [timers] are
  /// injectable for tests.
  TwitcastingDanmakuSession({
    required this.args,
    required this.site,
    TwitcastingTimers? timers,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The broadcast this session joins.
  final TwitcastingDanmakuArgs args;

  /// The site its socket URLs are asked from and its sockets come from.
  final TwitcastingSite site;

  final DateTime Function() _now;
  final TwitcastingTimers _timers;

  static const String _site = 'twitcasting';

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _watchdog;
  Timer? _retry;
  CancelToken? _resolve;
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
    if (_disposed) return const LiveSiteError.unsupported(siteId: _site, message: 'session is disposed');
    if (args.movieId <= 0) {
      return const LiveSiteError.notFound(siteId: _site, message: 'not a TwitCasting broadcast');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    final Uri socketUrl;
    try {
      final cancel = _resolve = CancelToken();
      final answer = await site.http.post(
        TwitcastingDanmakuCodec.endpoint(args.movieId),
        {'movie_id': '${args.movieId}'},
        cancel: cancel,
        timeout: TwitcastingDanmakuCodec.silenceTimeout,
      );
      if (identical(_resolve, cancel)) _resolve = null;
      socketUrl = TwitcastingDanmakuCodec.withGifts(
        TwitcastingDanmakuCodec.socketUrl(answer.text, status: answer.status),
      );
    } on CancelledFailure {
      return;
    } on Object catch (error) {
      _failed(TwitcastingDanmakuCodec.redact('$error'), generation);
      return;
    }
    if (_disposed || generation != _generation) return;
    final SocketChannel socket;
    try {
      socket = await site.connect(
        socketUrl,
        headers: TwitcastingDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: TwitcastingDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed(TwitcastingDanmakuCodec.redact('$error'), generation);
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
        if (generation == _generation && !_disposed) _scheduleRetry(TwitcastingDanmakuCodec.redact('$error'));
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
    for (final message in TwitcastingDanmakuCodec.decode(data)) {
      if (_disposed) return;
      _report(message);
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(TwitcastingDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
    });
  }

  /// The socket is to be replaced after the backoff's step;
  /// [TwitcastingDanmakuCodec.maxReconnects] of them without a live one end
  /// the session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > TwitcastingDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(TwitcastingDanmakuCodec.reconnectBaseDelay * _failures, () {
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
    _resolve?.cancel();
    _resolve = null;
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    _resolve?.cancel();
    _resolve = null;
    await _teardownSocket();
    await _events.close();
  }
}
