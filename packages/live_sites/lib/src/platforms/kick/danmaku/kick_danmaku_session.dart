import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_failure.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final KickDanmakuArgs args;
    try {
      final channel = await site.channel(roomId);
      final chatroom = channel.chatroomId;
      if (chatroom == null) {
        return left(const LiveSiteError.unsupported(siteId: 'kick', message: 'no chatroom to subscribe to'));
      }
      args = KickDanmakuArgs(chatroomId: chatroom, channelId: channel.channelId, slug: channel.room.roomId);
    } on KickFailure catch (failure) {
      return left(failure.toLiveSiteError('kick'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kick', message: '$error', cause: error));
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

/// One live chat connection over Kick's Pusher protocol.
///
/// Protocol-level recovery is this session's job:
/// - At open the socket subscribes to the chat, broadcast and Kicks
///   channels; the chat channel's `pusher_internal:subscription_succeeded`
///   is the join, which must come within [KickDanmakuCodec.joinTimeout] or
///   the socket is replaced.
/// - `pusher:ping` goes out every 30 s, server pings are answered
///   `pusher:pong`, and the server's 120 s activity timeout (or a socket
///   silent past the watchdog) replaces the socket — the generation is
///   counted, so a stale socket's frames are dropped.
/// - `pusher:error` and a refused subscription reconnect; the broadcast's
///   end (`StopStreamBroadcast`) closes [events] after a final notice
///   message instead of reconnecting forever.
/// - After [maxReconnectAttempts] failed reconnects a terminal system
///   message closes [events] rather than retrying in silence.
final class KickDanmakuSession implements LiveDanmakuSession {
  /// A session for the channel in [args]; [connect] opens the socket.
  KickDanmakuSession({required this.args});

  /// The ids this session subscribes by (chatroom, channel and slug).
  final KickDanmakuArgs args;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// A socket silent this long is replaced (the server's own activity
  /// timeout is 120 s; this is the local backstop).
  static const Duration inactivityTimeout = Duration(seconds: 150);

  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _joinTimer;
  int _generation = 0;
  bool _disposed = false;
  bool _joined = false;

  /// One reconnect in flight per generation (the watchdog and `onDone` both
  /// fire on a dead socket; without this they would double-open).
  bool _reconnecting = false;

  /// Consecutive failed reconnects; a run that reaches [maxReconnectAttempts]
  /// gives up and closes [events] instead of retrying forever in silence.
  int _reconnectFailures = 0;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket and subscribes; null on success, else why the session
  /// could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'kick', message: 'session is disposed');
    }
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(KickDanmakuCodec.endpoint, headers: KickDanmakuCodec.socketHeaders);
      await channel.ready.timeout(const Duration(seconds: 10));
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'kick', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        _onFrame(data, generation);
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    _heartbeat = Timer.periodic(KickDanmakuCodec.heartbeatInterval, (_) {
      if (_joined && generation == _generation && !_disposed) _send(KickDanmakuCodec.ping);
    });
    _startWatchdog();
    _joinTimer = Timer(KickDanmakuCodec.joinTimeout, () {
      if (!_joined && generation == _generation && !_disposed) _scheduleReconnect(generation, 'join timeout');
    });
    return null;
  }

  void _onFrame(Object? data, int generation) {
    _reconnectFailures = 0;
    _startWatchdog();
    final frame = KickDanmakuCodec.read(data, args);
    if (frame.established) {
      KickDanmakuCodec.subscribeAll(args).forEach(_send);
    }
    if (frame.ping) _send(KickDanmakuCodec.pong);
    frame.messages.forEach(_events.add);
    if (frame.joined) {
      _joined = true;
      _joinTimer?.cancel();
      _joinTimer = null;
    }
    if (frame.error != null) {
      _scheduleReconnect(generation, frame.error!);
      return;
    }
    if (frame.ended) {
      // The broadcast is over: end delivery instead of reconnecting forever.
      _generation++;
      _joinTimer?.cancel();
      _joinTimer = null;
      unawaited(_teardownSocket());
      unawaited(_events.close());
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(inactivityTimeout, () {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
  }

  void _send(String frame) {
    try {
      _socket?.sink.add(frame);
    } on Object {
      // The reconnect path owns a broken sink.
    }
  }

  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      // Back off briefly so a flapping endpoint is not hammered.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_disposed || staleGeneration != _generation) {
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
        _generation++;
        _joinTimer?.cancel();
        _joinTimer = null;
        _events.add(
          LiveMessage.normalized(
            type: LiveMessageType.system,
            text: 'Danmaku connection lost',
            color: LiveMessageColor.white,
          ),
        );
        unawaited(_teardownSocket());
        unawaited(_events.close());
      }
    }());
  }

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _socket?.sink.close();
    } on Object {
      // Closing a dead socket must not throw.
    }
    _socket = null;
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    _joinTimer?.cancel();
    _joinTimer = null;
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _joinTimer?.cancel();
    _joinTimer = null;
    await _teardownSocket();
    unawaited(_events.close());
  }
}
