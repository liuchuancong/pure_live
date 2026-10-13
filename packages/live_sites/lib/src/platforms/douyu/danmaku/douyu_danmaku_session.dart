import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_stt_codec.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for the douyu protocol.
/// Creates danmaku sessions for the douyu protocol.
/// Creates danmaku sessions for the douyu protocol.
final class DouyuDanmakuProvider implements LiveDanmakuProvider {
  /// The provider; callbacks as in the session.
  /// Creates the provider; callbacks as in the session.
  DouyuDanmakuProvider({this.filterSuspectedAutomated, this.giftsFor});

  /// Read for each suspected chat, so a changed setting applies at once.
  final bool Function()? filterSuspectedAutomated;

  /// The gift catalogues of a room (`betard`'s, with the fetched lists over
  /// them); gifts before it answers are still reported.
  final DouyuGiftCatalog Function(String roomId)? giftsFor;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final session = DouyuDanmakuSession(
      roomId: roomId,
      filterSuspectedAutomated: filterSuspectedAutomated,
      gifts: giftsFor?.call(roomId) ?? DouyuGiftCatalog.empty,
    );
    final failure = await session.connect();
    if (failure != null) {
      unawaited(session.dispose());
      return left(failure);
    }
    return right(session);
  }
}

/// One live danmaku connection over douyu's WebSocket protocol.
///
/// Protocol-level recovery is this session's job: a socket that errors, or
/// stays silent for three heartbeat periods, is replaced (join packets
/// again, generation counted so a stale socket's packets are dropped). The
/// room's broadcast-end packet closes [events] after a final notice
/// message.
final class DouyuDanmakuSession implements LiveDanmakuSession {
  /// A session for [roomId]; [connect] opens the socket.
  DouyuDanmakuSession({required this.roomId, this.filterSuspectedAutomated, this.gifts = DouyuGiftCatalog.empty});

  /// The room this session joined.
  final String roomId;

  /// Read for each suspected chat.
  final bool Function()? filterSuspectedAutomated;

  /// The gifts the room's packets are priced from.
  DouyuGiftCatalog gifts;

  /// A notice message emitted when the platform says the broadcast ended.
  static const String broadcastEndedDetail = 'Broadcast ended';

  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;
  bool _disposed = false;

  /// Adds [extra] to the gift catalogue (a fetched list arriving late).
  void addGifts(DouyuGiftCatalog extra) => gifts = gifts.merge(extra);

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'douyu', message: 'session is disposed');
    }
    final generation = ++_generation;
    await _teardownSocket();
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(_endpoint));
      await channel.ready;
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'douyu', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        if (data is! List<int>) return;
        _onFrame(data);
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    DouyuDanmakuProtocol.joinPackets(roomId).forEach(channel.sink.add);
    _heartbeat = Timer.periodic(DouyuDanmakuProtocol.heartbeatInterval, (_) {
      if (generation == _generation && !_disposed) _send(DouyuDanmakuProtocol.heartbeat());
    });
    // A socket silent for three heartbeat periods is replaced.
    _watchdog = Timer.periodic(DouyuDanmakuProtocol.heartbeatInterval * 3, (_) {
      if (generation == _generation && !_disposed) _scheduleReconnect(generation, 'socket silent');
    });
    return null;
  }

  static const String _endpoint = 'wss://danmuproxy.douyu.com:8506';

  void _onFrame(List<int> frame) {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(DouyuDanmakuProtocol.heartbeatInterval * 3, (_) {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
    final (:messages, :ended) = DouyuDanmakuProtocol.read(
      frame,
      roomId: roomId,
      filterSuspectedAutomated: filterSuspectedAutomated,
      gifts: gifts,
    );
    messages.forEach(_events.add);
    if (ended) {
      _events.add(
        LiveMessage.normalized(type: LiveMessageType.system, text: broadcastEndedDetail, color: LiveMessageColor.white),
      );
      // The room is over: end delivery instead of reconnecting forever.
      _generation++;
      unawaited(_teardownSocket());
      unawaited(_events.close());
    }
  }

  void _send(List<int> packet) {
    try {
      _socket?.sink.add(packet);
    } on Object {
      // The reconnect path owns a broken sink.
    }
  }

  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation) return;
    unawaited(() async {
      // Back off briefly so a flapping endpoint is not hammered.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (_disposed || staleGeneration != _generation) return;
      await connect();
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
