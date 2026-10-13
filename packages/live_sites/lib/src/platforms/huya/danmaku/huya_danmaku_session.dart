import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
/// Protocol-level recovery is this session's job: a socket that errors, or
/// stays silent for three heartbeat periods (180 s), is replaced (registration
/// sent again, generation counted so a stale socket's frames are dropped). A
/// stream-end notice for this room's streamer closes [events] after a final
/// system message.
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

  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  /// One reconnect in flight per generation (the watchdog and `onDone` both
  /// fire on a dead socket; without this they would double-open).
  bool _reconnecting = false;

  /// Consecutive failed reconnects; a run that reaches [maxReconnectAttempts]
  /// gives up and closes [events] instead of retrying forever in silence.
  int _reconnectFailures = 0;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'huya', message: 'session is disposed');
    }
    final generation = ++_generation;
    await _teardownSocket();
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(_endpoint));
      await channel.ready;
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'huya', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        if (data is! List<int>) return;
        _onFrame(Uint8List.fromList(data));
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    channel.sink
      ..add(HuyaDanmakuProtocol.register(uid))
      ..add(HuyaDanmakuProtocol.heartbeat());
    _heartbeat = Timer.periodic(HuyaDanmakuProtocol.heartbeatInterval, (_) {
      if (generation == _generation && !_disposed) _send(HuyaDanmakuProtocol.heartbeat());
    });
    // A socket silent for three heartbeat periods (180 s) is replaced.
    _watchdog = Timer.periodic(HuyaDanmakuProtocol.heartbeatInterval * 3, (_) {
      if (generation == _generation && !_disposed) _scheduleReconnect(generation, 'socket silent');
    });
    return null;
  }

  static const String _endpoint = 'wss://wsapi.huya.com';

  void _onFrame(Uint8List frame) {
    _reconnectFailures = 0;
    _watchdog?.cancel();
    _watchdog = Timer.periodic(HuyaDanmakuProtocol.heartbeatInterval * 3, (_) {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
    final (:messages, :ended) = HuyaDanmakuProtocol.decode(frame);
    messages.forEach(_events.add);
    // The web client leaves the room at the stream end; a notice that names
    // another streamer is not this room's.
    if (ended.any((endedUid) => endedUid == uid || endedUid <= 0)) {
      _events.add(
        LiveMessage.normalized(type: LiveMessageType.system, text: broadcastEndedDetail, color: LiveMessageColor.white),
      );
      // The room is over: end delivery instead of reconnecting forever.
      _generation++;
      unawaited(_teardownSocket());
      unawaited(_events.close());
    }
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
