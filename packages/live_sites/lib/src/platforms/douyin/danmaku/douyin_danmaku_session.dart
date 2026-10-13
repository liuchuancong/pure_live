import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_codec.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for Douyin's web IM protocol.
///
/// The session joins the room's current broadcast: the broadcast's room_id
/// (not the lasting web_rid) and the visitor id come from a fresh detail, and
/// a room that is off air has no danmaku to join.
final class DouyinDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  DouyinDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the broadcast arguments.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final DouyinDanmakuArgs args;
    try {
      final resolved = await site.danmakuArgs(roomId);
      if (resolved == null || resolved.roomId.isEmpty) {
        return left(
          LiveSiteError.contentUnavailable(siteId: 'douyin', message: 'room $roomId streams no broadcast to join'),
        );
      }
      args = resolved;
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError('douyin'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'douyin', message: '$error', cause: error));
    }
    final session = DouyinDanmakuSession(
      args: args,
      signature: site.signer.danmakuSignature(roomId: args.roomId, userUniqueId: args.userId),
      now: site.now,
    );
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live danmaku connection over Douyin's protobuf WebSocket protocol.
///
/// Protocol-level recovery is this session's job: a socket that errors or
/// stays silent for [DouyinDanmakuProtocol.inactivityTimeout] is replaced
/// (heartbeat sent again, generation counted so a stale socket's frames are
/// dropped), the two web IM edges alternating per attempt; the signature is
/// computed once and kept for the reconnects. After
/// [DouyinDanmakuProtocol.maxReconnectAttempts] failed reconnects a terminal
/// system message closes [events] instead of retrying forever. Text frames
/// are ignored — the protocol only speaks binary.
final class DouyinDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args], joined with the X-Bogus
  /// [signature]; [connect] opens the socket.
  DouyinDanmakuSession({required this.args, required this.signature, DateTime Function()? now})
    : now = now ?? DateTime.now;

  /// The broadcast this session joined.
  final DouyinDanmakuArgs args;

  /// The connection's `signature`: the X-Bogus of this broadcast and visitor,
  /// computed once and kept for the reconnects (as the web client keeps it).
  final String signature;

  /// Injectable clock (the connection cursor).
  final DateTime Function() now;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = DouyinDanmakuProtocol.maxReconnectAttempts;

  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;
  int _host = 0;
  bool _disposed = false;

  /// One reconnect in flight per generation (the watchdog and `onDone` both
  /// fire on a dead socket; without this they would double-open).
  bool _reconnecting = false;

  /// Consecutive failed reconnects.
  int _reconnectFailures = 0;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'douyin', message: 'session is disposed');
    }
    final generation = ++_generation;
    await _teardownSocket();
    final endpoints = DouyinDanmakuProtocol.endpoints(
      roomId: args.roomId,
      userId: args.userId,
      signature: signature,
      now: now(),
    );
    final endpoint = endpoints[_host++ % endpoints.length];
    final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(
        endpoint,
        headers: DouyinDanmakuProtocol.handshakeHeaders(args.cookie, args.webRid),
      );
      await channel.ready.timeout(_connectTimeout);
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'douyin', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        // Douyin only sends binary frames; a text frame is not the protocol.
        if (data is! List<int>) return;
        _onFrame(Uint8List.fromList(data));
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    // An open socket counts as joined: the heartbeat is the join.
    _send(DouyinDanmakuProtocol.heartbeat());
    _heartbeat = Timer.periodic(DouyinDanmakuProtocol.heartbeatInterval, (_) {
      if (generation == _generation && !_disposed) _send(DouyinDanmakuProtocol.heartbeat());
    });
    _startWatchdog();
    return null;
  }

  static const Duration _connectTimeout = Duration(seconds: 10);

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(DouyinDanmakuProtocol.inactivityTimeout, () {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
  }

  void _onFrame(Uint8List frame) {
    _reconnectFailures = 0;
    _startWatchdog();
    final decoded = DouyinDanmakuProtocol.decode(frame, roomId: args.roomId);
    if (decoded.ack case final ack?) _send(ack);
    decoded.messages.forEach(_events.add);
  }

  void _send(Uint8List packet) {
    try {
      _socket?.sink.add(packet);
    } on Object {
      // The reconnect path owns a broken sink.
    }
  }

  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      // Back off from [DouyinDanmakuProtocol.reconnectBase], once per
      // consecutive failure, so a flapping edge is not hammered.
      final backoff = DouyinDanmakuProtocol.reconnectBase * (_reconnectFailures + 1);
      await Future<void>.delayed(backoff);
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
        _events.add(
          LiveMessage.normalized(
            type: LiveMessageType.system,
            text: 'Danmaku connection lost ($reason)',
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
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    await _teardownSocket();
    unawaited(_events.close());
  }
}
