import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kick/kick_manifest.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for Kick's Pusher chat.
///
/// The session subscribes by the chatroom and channel ids the channel answer
/// names, so creating one reads the channel first (the ids are never
/// guessed); a channel whose answer carries no chatroom cannot be joined.
final class KickDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the channel and its ids).
  KickDanmakuProvider({required this.site});

  /// The site this capability serves.
  final KickSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final KickDanmakuArgs args;
    try {
      final channel = await site.channel(room.roomId);
      final chatroom = channel.chatroomId;
      // The three subscription ids must all be real, or the socket would
      // subscribe `chatrooms.0.v2` / `channel_0` and join nothing.
      if (chatroom == null || chatroom <= 0) {
        return left(const LiveSiteError.unsupported(siteId: kickSiteId, message: 'no chatroom to subscribe to'));
      }
      if (channel.channelId <= 0) {
        return left(const LiveSiteError.contentUnavailable(siteId: kickSiteId, message: 'channel has no id'));
      }
      final slug = channel.room.roomId.trim();
      if (slug.isEmpty) {
        return left(const LiveSiteError.contentUnavailable(siteId: kickSiteId, message: 'channel has no slug'));
      }
      args = KickDanmakuArgs(chatroomId: chatroom, channelId: channel.channelId, slug: slug);
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError(kickSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kickSiteId, message: '$error', cause: error));
    }
    final session = KickDanmakuSession(args: args);
    final failure = await session.connect();
    if (failure != null) {
      unawaited(session.dispose());
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection over Kick's Pusher protocol, carried by the shared
/// [DanmakuSocket] transport.
///
/// Protocol-level recovery is this session's job:
/// - At open the socket subscribes to the chat, broadcast and Kicks
///   channels; the chat channel's `pusher_internal:subscription_succeeded`
///   is the join, which must come within [KickDanmakuCodec.joinTimeout] or
///   the socket is replaced.
/// - `pusher:ping` goes out every 30 s once joined, server pings are answered
///   `pusher:pong`, and a socket silent past [inactivityTimeout] is replaced (the
///   server's own activity timeout is 120 s). The ping starts only after the
///   join and the pong must be sent on a specific frame, so both stay protocol
///   timers here rather than a transport heartbeat; the transport's automatic
///   reconnect is off because a Pusher socket must re-subscribe through this
///   session's generation guard, so a loss is reported and reconnected here —
///   after [maxReconnectAttempts] failed reconnects a terminal system message
///   closes [events] rather than retrying in silence.
/// - `pusher:error` and a refused subscription reconnect. The broadcast's end
///   (`StopStreamBroadcast`) is only a notice: the socket stays subscribed,
///   so a broadcast restarted under the same chatroom resumes here, and the
///   silence that follows is the watchdog's business like any other.
///
/// The run lifecycle — the generation the opens and their callbacks guard
/// with — is the shared base's ([DanmakuSessionBase]): every open is one
/// [DanmakuRun], and the base drops whatever a dead one reports.
final class KickDanmakuSession extends DanmakuSessionBase {
  /// A session for the channel in [args]; [connect] opens the socket.
  KickDanmakuSession({required this.args});

  /// The ids this session subscribes by (chatroom, channel and slug).
  final KickDanmakuArgs args;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// A socket silent this long is replaced (the server's own activity
  /// timeout is 120 s; this is the local backstop).
  static const Duration inactivityTimeout = Duration(seconds: 150);

  /// The handshake budget of one connection.
  static const Duration _connectTimeout = Duration(seconds: 10);

  /// The transport settings of one socket: the handshake headers, the connect
  /// budget, and no automatic reconnect (a Pusher socket re-subscribes through
  /// this session, so a loss is reported and reconnected here). The ping and the
  /// silence watchdog are protocol timers, not this transport heartbeat, because
  /// the ping starts only once the subscription succeeded.
  static const WebSocketConfig _transport = WebSocketConfig(
    headers: KickDanmakuCodec.socketHeaders,
    connectTimeout: _connectTimeout,
    reconnectPolicy: ReconnectPolicy(enabled: false),
  );

  DanmakuSocket? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _joinTimer;

  /// One reconnect in flight per run (the watchdog and `onDone` both fire on
  /// a dead socket; without this they would double-open).
  bool _reconnecting = false;

  /// Consecutive failed reconnects; a run that reaches [maxReconnectAttempts]
  /// gives up and closes [events] instead of retrying forever in silence.
  int _reconnectFailures = 0;

  /// Opens the socket and subscribes; null on success, else why the session
  /// could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) {
      return const LiveSiteError.unsupported(siteId: kickSiteId, message: 'session is disposed');
    }
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return null;
    // The Pusher handshake is server-driven (it opens with
    // `pusher:connection_established`), so nothing is sent on open; the
    // subscription goes out from that frame in [_onFrame].
    final socket = DanmakuSocket(
      uri: KickDanmakuCodec.endpoint,
      config: _transport,
      onHandshake: (_) {},
      onFrame: (data) => _onFrame(data, run),
      onLost: (cause) => _scheduleReconnect(run, cause),
    );
    _socket = socket;
    if (!await socket.start()) {
      return const LiveSiteError.network(siteId: kickSiteId, message: 'danmaku connect failed');
    }
    _heartbeat = timers.every(KickDanmakuCodec.heartbeatInterval, (_) {
      if (run.isJoined && run.isActive) _send(KickDanmakuCodec.ping);
    });
    _startWatchdog(run);
    _joinTimer = timers.after(KickDanmakuCodec.joinTimeout, () {
      if (!run.isJoined && run.isActive) _scheduleReconnect(run, 'join timeout');
    });
    return null;
  }

  void _onFrame(Object data, DanmakuRun run) {
    if (!run.isActive) return;
    _reconnectFailures = 0;
    _startWatchdog(run);
    final frame = KickDanmakuCodec.read(data, args);
    if (frame.established) {
      KickDanmakuCodec.subscribeAll(args).forEach(_send);
    }
    if (frame.ping) _send(KickDanmakuCodec.pong);
    for (final message in frame.messages) {
      if (!run.isActive) return;
      run.message(message);
    }
    if (frame.joined && !run.isJoined) {
      run.joined();
      _joinTimer?.cancel();
      _joinTimer = null;
    }
    if (frame.error != null) {
      _scheduleReconnect(run, frame.error!);
      return;
    }
    // `StopStreamBroadcast` is only a notice (as in the reference): the socket
    // stays subscribed, so a broadcast restarted under the same chatroom
    // resumes on this session. Silence afterwards is the watchdog's job.
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(inactivityTimeout, () {
      if (run.isActive) _scheduleReconnect(run, 'socket silent');
    });
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || !socket.isConnected) return;
    socket.send(frame);
  }

  void _scheduleReconnect(DanmakuRun run, String reason) {
    if (!run.isActive || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      // Back off briefly so a flapping endpoint is not hammered.
      if (!await run.delay(const Duration(seconds: 2))) {
        _reconnecting = false;
        return;
      }
      final failure = await connect();
      _reconnecting = false;
      if (failure == null) return;
      _reconnectFailures++;
      if (_reconnectFailures >= maxReconnectAttempts) {
        // Give up: report the loss on the stream instead of retrying forever,
        // and stop so a stale socket's reconnect is not scheduled again.
        final current = this.run;
        if (current != null) {
          current
            ..exhausted('Danmaku connection lost')
            ..message(
              LiveMessage.normalized(
                type: LiveMessageType.system,
                text: 'Danmaku connection lost',
                color: LiveMessageColor.white,
              ),
            );
          unawaited(dispose());
        }
      }
    }());
  }

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _joinTimer?.cancel();
    _joinTimer = null;
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }

  /// Releases the transport and the protocol timers; safe when nothing is
  /// open.
  @override
  Future<void> stop() async {
    await _teardownSocket();
  }
}
