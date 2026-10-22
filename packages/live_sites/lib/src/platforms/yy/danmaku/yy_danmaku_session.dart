import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/yy/danmaku/yy_danmaku_codec.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for YY channels.
///
/// The session joins by the canonical channel's top and sub channel, which
/// the room detail carries on the room's danmaku handle — so a session is
/// built from a fresh detail. A room whose page names no channel has no
/// handle and is reported content-unavailable rather than joined empty. A
/// channel that is not broadcasting is joined the same way: the chat channel
/// stays open while nobody broadcasts.
final class YyDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's canonical channel).
  YyDanmakuProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final YyDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! YyDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: yySiteId, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
    final session = YyDanmakuSession(args: args, site: site);
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
typedef YyTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: one WebSocket per channel, anonymous (3.x's
/// `YyDanmaku` over the shared socket seam).
///
/// - Every opened socket starts the anonymous handshake of a
///   [YyProtocolSession]; the room is joined when the channel join is
///   confirmed, within [YyDanmakuProtocol.handshakeTimeout], or the socket
///   is replaced. A step refused: a reconnect with the reason.
/// - The AP ping goes out every [YyDanmakuProtocol.heartbeatInterval] once
///   the AP login was sent ([YyProtocolSession.heartbeat] tells when); a
///   socket silent for [YyDanmakuProtocol.inactivityTimeout] is replaced.
/// - Attempts that open a socket but do not join (refused, timed out, or
///   the connect failing) end the session with a terminal system message
///   once more than [YyDanmakuProtocol.maxReconnects] come in a row; the
///   join clears the count.
/// - The chat (with the anonymous sender's name) and the channel's heat
///   (popularity) are reported.
final class YyDanmakuSession implements LiveDanmakuSession {
  /// A session for the channels in [args] whose sockets [site] makes.
  /// [timers], [now] and [random] (the connection's uuid) are injectable for
  /// tests.
  YyDanmakuSession({required this.args, required this.site, YyTimers? timers, DateTime Function()? now, Random? random})
    : _timers = timers ?? (after: Timer.new, every: Timer.periodic),
      _now = now ?? DateTime.now,
      _uuid = YyDanmakuProtocol.uuid(random ?? Random.secure());

  /// The channels this session joins.
  final YyDanmakuArgs args;

  /// The site its socket connections come from.
  final YySite site;

  /// The connection's UUID, kept for every reconnect (3.x: one per
  /// `YyDanmaku`).
  final String _uuid;

  final YyTimers _timers;

  final DateTime Function() _now;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  YyProtocolSession? _protocol;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _generation = 0;

  /// Attempts in a row that opened a socket but did not join.
  int _unjoined = 0;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the
  /// channel has no chat to join.
  ///
  /// The reference's runtime retries a failed first handshake like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: yySiteId, message: 'session is disposed');
    if (args.topSid <= 0) {
      return LiveSiteError.contentUnavailable(siteId: yySiteId, message: 'channel ${args.topSid} opens no chat');
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
    _protocol = YyProtocolSession(topSid: args.topSid, subSid: args.subSid, uuid: _uuid);
    final SocketChannel socket;
    try {
      socket = await site.connect(
        YyDanmakuProtocol.endpoint(_uuid),
        headers: YyDanmakuProtocol.headers,
        protocols: null,
        connectTimeout: YyDanmakuProtocol.handshakeTimeout,
      );
    } on Object catch (error) {
      _retryAttempt('$error', generation);
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
    _join = _timers.after(YyDanmakuProtocol.handshakeTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _retryAttempt('no join within ${YyDanmakuProtocol.handshakeTimeout.inSeconds} s', generation);
      }
    });
    _send(_protocol!.beginHandshake());
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

  void _onData(Object? data) {
    // YY only sends binary frames.
    final protocol = _protocol;
    if (data is! List<int> || protocol == null) return;
    _startWatchdog();
    final batch = protocol.consume(data);
    batch.outbound.forEach(_send);
    if (batch.becameReady && !_joined) {
      _joined = true;
      _unjoined = 0;
      _join?.cancel();
      _join = null;
    }
    for (final message in batch.messages) {
      if (_disposed) return;
      _events.add(message);
    }
    if (batch.failure case final failure?) _retryAttempt(failure, _generation);
  }

  /// An attempt that did not join: counted, and retried after the backoff's
  /// step; the budget's end is told once and closes the stream.
  void _retryAttempt(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _unjoined += 1;
    if (_unjoined > YyDanmakuProtocol.maxReconnects) {
      _terminate(
        'YY danmaku gave up after ${YyDanmakuProtocol.maxReconnects} attempts: ${YyDanmakuProtocol.compactFailure(reason)}',
      );
      return;
    }
    _scheduleRetry(reason);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(YyDanmakuProtocol.heartbeatInterval, (_) {
      if (_disposed) return;
      // The protocol sends no heartbeat before its AP login.
      final frame = _protocol?.heartbeat();
      if (frame != null) _send(frame);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(YyDanmakuProtocol.inactivityTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
    });
  }

  void _send(Uint8List frame) {
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

  /// The socket is to be replaced after the backoff's step.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    final generation = _generation;
    _retry = _timers.after(YyDanmakuProtocol.reconnectBaseDelay * _unjoined, () {
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
    _protocol = null;
    _cancelTimers();
    await _teardownSocket();
    await _events.close();
  }
}
