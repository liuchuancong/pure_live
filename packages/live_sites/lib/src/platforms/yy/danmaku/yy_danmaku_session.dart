import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
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
/// the room detail carries on the room's danmaku handle — so a session
/// is built from a fresh detail. A room whose page names no channel has no
/// handle and is reported content-unavailable rather than joined empty. A
/// channel that is not broadcasting is joined the same way: the chat channel
/// stays open while nobody broadcasts.
final class YyDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's canonical channel).
  YyDanmakuProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final YyDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! YyDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: yySiteId, message: 'room ${room.roomId} opens no chat'));
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
typedef YyTimers = DanmakuTimers;

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
///
/// The run lifecycle — the generation the handshakes and their callbacks
/// guard with — is the shared base's ([DanmakuSessionBase]): every handshake
/// is one [DanmakuRun], and the base drops whatever a dead one reports.
final class YyDanmakuSession extends DanmakuSessionBase {
  /// A session for the channels in [args] whose sockets [site] makes.
  /// [timers], [now] and [random] (the connection's uuid) are injectable for
  /// tests.
  YyDanmakuSession({required this.args, required this.site, super.timers, DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _uuid = YyDanmakuProtocol.uuid(random ?? Random.secure());

  /// The channels this session joins.
  final YyDanmakuArgs args;

  /// The site its socket connections come from.
  final YySite site;

  /// The connection's UUID, kept for every reconnect (3.x: one per
  /// `YyDanmaku`).
  final String _uuid;

  final DateTime Function() _now;

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  YyProtocolSession? _protocol;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;

  /// Attempts in a row that opened a socket but did not join.
  int _unjoined = 0;

  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) return const LiveSiteError.unsupported(siteId: yySiteId, message: 'session is disposed');
    if (args.topSid <= 0) {
      return LiveSiteError.contentUnavailable(siteId: yySiteId, message: 'channel ${args.topSid} opens no chat');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (isDisposed) return;
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return;
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
      _retryAttempt('$error', run);
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
    run.handshakeDone();
    _startHeartbeat();
    _startWatchdog(run);
    _join = timers.after(YyDanmakuProtocol.handshakeTimeout, () {
      if (run.isActive && !run.isJoined) {
        _retryAttempt('no join within ${YyDanmakuProtocol.handshakeTimeout.inSeconds} s', run);
      }
    });
    _send(_protocol!.beginHandshake());
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
    // YY only sends binary frames.
    final protocol = _protocol;
    if (data is! List<int> || protocol == null) return;
    _startWatchdog(run);
    final batch = protocol.consume(data);
    batch.outbound.forEach(_send);
    if (batch.becameReady && !run.isJoined) {
      run.joined();
      _unjoined = 0;
      _join?.cancel();
      _join = null;
    }
    for (final message in batch.messages) {
      if (!run.isActive) return;
      run.message(message);
    }
    if (batch.failure case final failure?) _retryAttempt(failure, run);
  }

  /// An attempt that did not join: counted, and retried after the backoff's
  /// step; the budget's end is told once and closes the stream.
  void _retryAttempt(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    _unjoined += 1;
    if (_unjoined > YyDanmakuProtocol.maxReconnects) {
      _terminate(
        'YY danmaku gave up after ${YyDanmakuProtocol.maxReconnects} attempts: ${YyDanmakuProtocol.compactFailure(reason)}',
        run,
      );
      return;
    }
    _scheduleRetry(reason, run);
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = timers.every(YyDanmakuProtocol.heartbeatInterval, (_) {
      if (isDisposed) return;
      // The protocol sends no heartbeat before its AP login.
      final frame = _protocol?.heartbeat();
      if (frame != null) _send(frame);
    });
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(YyDanmakuProtocol.inactivityTimeout, () {
      if (run.isActive) _scheduleRetry('socket silent', run);
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
  void _terminate(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    run
      ..exhausted(reason)
      ..message(
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
  void _scheduleRetry(String reason, DanmakuRun run) {
    _cancelTimers();
    if (!run.isActive) return;
    run.reconnecting(reason);
    _retry = timers.after(YyDanmakuProtocol.reconnectBaseDelay * _unjoined, () {
      if (!run.isActive) return;
      unawaited(_handshake());
    });
  }

  /// Releases the transport, the protocol session and the protocol timers;
  /// safe when nothing is open.
  @override
  Future<void> stop() async {
    _protocol = null;
    _cancelTimers();
    await _teardownSocket();
  }
}
