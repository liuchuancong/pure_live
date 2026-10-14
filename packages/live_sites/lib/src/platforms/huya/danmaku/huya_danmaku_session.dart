import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for the huya protocol.
final class HuyaDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves a room's streamer uid).
  HuyaDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the streamer uid.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final int uid;
    try {
      uid = await site.presenterUid(roomId);
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError('huya'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'huya', message: '$error', cause: error));
    }
    final session = HuyaDanmakuSession(roomId: roomId, uid: uid);
    final failure = await session.connect();
    if (failure != null) {
      unawaited(session.dispose());
      return left(failure);
    }
    return right(session);
  }
}

/// One live danmaku connection over huya's WebSocket protocol.
///
/// Protocol-level recovery is the transport's job: [DanmakuSocket] keeps the
/// socket alive with heartbeat packets, replaces one that stays silent for
/// three periods (180 s), and reconnects with a bounded back off — the group
/// registration goes out again on every connection. A stream-end notice for
/// this room's streamer closes [events] after a final system message.
final class HuyaDanmakuSession implements LiveDanmakuSession {
  /// A session for [roomId], registering streamer [uid]'s groups; [connect]
  /// opens the socket.
  HuyaDanmakuSession({required this.roomId, required this.uid});

  /// The room this session joined.
  final String roomId;

  /// The streamer whose `live:`/`chat:` groups are registered.
  final int uid;

  /// A notice message emitted when the platform says the broadcast ended.
  static const String broadcastEndedDetail = 'Broadcast ended';

  /// A notice message emitted when the transport gave up on the socket.
  static const String connectionLostDetail = 'Danmaku connection lost';

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// The endpoint huya's danmaku gateway serves.
  static const String _endpoint = 'wss://wsapi.huya.com';

  /// The heartbeat packet doubles as the silence watchdog: a socket that
  /// answers nothing for three periods is replaced.
  static final WebSocketConfig _transport = WebSocketConfig(
    reconnectPolicy: const ReconnectPolicy(maxAttempts: maxReconnectAttempts, initialDelay: Duration(seconds: 2)),
    heartbeat: HeartbeatConfig(
      interval: HuyaDanmakuProtocol.heartbeatInterval,
      payload: HuyaDanmakuProtocol.heartbeat,
      timeout: HuyaDanmakuProtocol.heartbeatInterval * 3,
    ),
  );

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'huya', message: 'session is disposed');
    }
    await _teardownSocket();
    final socket = DanmakuSocket(
      uri: Uri.parse(_endpoint),
      config: _transport,
      onHandshake: (socket) => socket
        ..send(HuyaDanmakuProtocol.register(uid))
        ..send(HuyaDanmakuProtocol.heartbeat()),
      onFrame: _onFrame,
      onLost: (_) => _loseConnection(),
    );
    _socket = socket;
    if (!await socket.start()) {
      return const LiveSiteError.network(
        siteId: 'huya',
        message: 'danmaku connect failed: no connection to $_endpoint',
      );
    }
    return null;
  }

  void _onFrame(Object frame) {
    if (frame is! List<int>) return;
    final (:messages, :ended) = HuyaDanmakuProtocol.decode(Uint8List.fromList(frame));
    messages.forEach(_events.add);
    // The web client leaves the room at the stream end; a notice that names
    // another streamer is not this room's.
    if (ended.any((endedUid) => endedUid == uid || endedUid <= 0)) {
      _events.add(
        LiveMessage.normalized(type: LiveMessageType.system, text: broadcastEndedDetail, color: LiveMessageColor.white),
      );
      // The room is over: end delivery instead of reconnecting forever.
      unawaited(_teardownSocket());
      unawaited(_events.close());
    }
  }

  /// Reports the loss on the stream instead of retrying forever.
  void _loseConnection() {
    if (_disposed) return;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: connectionLostDetail, color: LiveMessageColor.white),
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
