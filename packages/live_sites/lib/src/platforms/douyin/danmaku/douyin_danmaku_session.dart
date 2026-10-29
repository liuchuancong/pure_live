import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_danmaku_codec.dart';
import 'package:live_sites/src/platforms/douyin/douyin_manifest.dart';
import 'package:live_sites/src/platforms/douyin/douyin_site.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for Douyin's web IM protocol.
///
/// The session joins the room's current broadcast: the broadcast's room_id
/// (not the lasting web_rid) and the visitor id come from the detail that
/// produced the room — the room's own handle, or a fresh detail when the room
/// carries none — and a room that is off air has no danmaku to join.
final class DouyinDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  DouyinDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the broadcast arguments.
  final DouyinSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final DouyinDanmakuArgs args;
    try {
      final resolved = await joinArgs(room);
      if (resolved == null || resolved.roomId.isEmpty) {
        return left(
          LiveSiteError.contentUnavailable(
            siteId: douyinSiteId,
            message: 'room ${room.roomId} streams no broadcast to join',
          ),
        );
      }
      args = resolved;
    } on DouyinFailure catch (failure) {
      return left(failure.toLiveSiteError(douyinSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: douyinSiteId, message: '$error', cause: error));
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

  /// The broadcast this room's chat lives in: the detail that produced [room]
  /// already named it, so its own handle is what the session joins with and
  /// nothing is asked again (an open used to sign a second enter just to learn
  /// what it had just read). A room that carries no handle for this room — a
  /// refresh read, or one whose broadcast was unknown — asks the room.
  Future<DouyinDanmakuArgs?> joinArgs(LiveRoom room) {
    final handle = room.runtime.danmakuHandle;
    if (handle is DouyinDanmakuArgs && handle.roomId.isNotEmpty && handle.webRid == room.roomId) {
      return Future<DouyinDanmakuArgs?>.value(handle);
    }
    return site.danmakuArgs(room.roomId);
  }
}

/// One live danmaku connection over Douyin's protobuf WebSocket protocol.
///
/// The transport ([DanmakuSocket]) keeps the connection alive: the heartbeat
/// frame doubles as the join, and a socket silent for
/// [DouyinDanmakuProtocol.inactivityTimeout] is dropped. Which edge to drop
/// *onto* is this session's own choice — the two web IM edges alternate per
/// attempt, so the transport's automatic reconnect is off and each loss
/// re-opens on the other host after a growing back off. After
/// [DouyinDanmakuProtocol.maxReconnectAttempts] failed attempts a terminal
/// system message closes [events] instead of retrying forever. Text frames are
/// ignored — the protocol only speaks binary.
final class DouyinDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args], joined with the X-Bogus
  /// [signature]; [connect] opens the socket.
  DouyinDanmakuSession({required this.args, required this.signature, DateTime Function()? now})
    : now = now ?? DateTime.now,
      _headers = DouyinDanmakuProtocol.handshakeHeaders(args.cookie, args.webRid);

  /// The broadcast this session joined.
  final DouyinDanmakuArgs args;

  /// The connection's `signature`: the X-Bogus of this broadcast and visitor,
  /// computed once and kept for the reconnects (as the web client keeps it).
  final String signature;

  /// Injectable clock (the connection cursor).
  final DateTime Function() now;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = DouyinDanmakuProtocol.maxReconnectAttempts;

  /// The handshake budget of one attempt.
  static const Duration _connectTimeout = Duration(seconds: 10);

  /// The `hb` heartbeat is also the silence watchdog: a socket that answers
  /// nothing for the protocol's inactivity window is dropped.
  static const HeartbeatConfig _heartbeat = HeartbeatConfig(
    interval: DouyinDanmakuProtocol.heartbeatInterval,
    payload: DouyinDanmakuProtocol.heartbeat,
    timeout: DouyinDanmakuProtocol.inactivityTimeout,
  );

  /// The handshake headers, the same for every edge of this broadcast.
  final Map<String, String> _headers;

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
  int _host = 0;

  /// Consecutive failed attempts; any frame means the connection is healthy
  /// again and resets the run.
  int _reconnectFailures = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() => _open();

  /// Opens one connection, on the next web IM edge in the rotation.
  Future<LiveSiteError?> _open() async {
    await _teardownSocket();
    final endpoints = DouyinDanmakuProtocol.endpoints(
      roomId: args.roomId,
      userId: args.userId,
      signature: signature,
      now: now(),
    );
    final endpoint = endpoints[_host++ % endpoints.length];
    final socket = DanmakuSocket(
      uri: endpoint,
      config: WebSocketConfig(
        headers: _headers,
        connectTimeout: _connectTimeout,
        // A retry here would reconnect to the same edge; the rotation belongs
        // to this session, so a loss is reported instead of retried.
        reconnectPolicy: const ReconnectPolicy(enabled: false),
        heartbeat: _heartbeat,
      ),
      onHandshake: (socket) => socket.send(DouyinDanmakuProtocol.heartbeat()),
      onFrame: _onFrame,
      onLost: _onLost,
    );
    _socket = socket;
    if (await socket.start()) return null;
    return LiveSiteError.network(siteId: douyinSiteId, message: 'danmaku connect failed on $endpoint');
  }

  void _onFrame(Object frame) {
    // Douyin only sends binary frames; a text frame is not the protocol.
    if (frame is! List<int>) return;
    _reconnectFailures = 0;
    final decoded = DouyinDanmakuProtocol.decode(Uint8List.fromList(frame), roomId: args.roomId);
    if (decoded.ack case final ack?) _socket?.send(ack);
    decoded.messages.forEach(_events.add);
  }

  /// Re-opens the socket on the other edge until the attempts run out.
  void _onLost(String cause) {
    if (_disposed) return;
    unawaited(_retry(cause));
  }

  Future<void> _retry(String cause) async {
    while (!_disposed) {
      _reconnectFailures++;
      if (_reconnectFailures > maxReconnectAttempts) {
        _loseConnection(cause);
        return;
      }
      // Grow the back off with the run so a flapping edge is not hammered.
      await Future<void>.delayed(DouyinDanmakuProtocol.reconnectBase * _reconnectFailures);
      if (_disposed) return;
      if (await _open() == null) return;
    }
  }

  void _loseConnection(String cause) {
    if (_disposed) return;
    _events.add(
      LiveMessage.normalized(
        type: LiveMessageType.system,
        text: 'Danmaku connection lost ($cause)',
        color: LiveMessageColor.white,
      ),
    );
    unawaited(_teardownSocket());
    unawaited(_events.close());
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }

  @override
  Future<void> disconnect() => _teardownSocket();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardownSocket();
    unawaited(_events.close());
  }
}
