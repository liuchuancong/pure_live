import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_stt_codec.dart';
import 'package:live_sites/src/platforms/douyu/douyu_site.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for the douyu protocol.
final class DouyuDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which supplies and refreshes the gift catalogues).
  DouyuDanmakuProvider({required this.site, this.filterSuspectedAutomated});

  /// The site this capability serves: the source of the gift catalogues.
  final DouyuSite site;

  /// Read for each suspected chat, so a changed setting applies at once.
  final bool Function()? filterSuspectedAutomated;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final session = DouyuDanmakuSession(
      roomId: roomId,
      filterSuspectedAutomated: filterSuspectedAutomated,
      gifts: site.cachedGifts(roomId),
    );
    final failure = await session.connect();
    if (failure != null) {
      unawaited(session.dispose());
      return left(failure);
    }
    // The catalogue is fetched off the connect path and merged into the live
    // session as it arrives (the contract's update-methods channel); a room
    // the lists do not know still reports its gifts, just unpriced.
    unawaited(() async {
      try {
        session.addGifts(await site.giftCatalog(roomId));
      } on Object {
        // A failed catalogue fetch leaves the session reporting raw gifts.
      }
    }());
    return right(session);
  }
}

/// One live danmaku connection over douyu's WebSocket protocol.
///
/// Protocol-level recovery is the transport's job: [DanmakuSocket] sends the
/// `mrkl/` heartbeat, replaces a socket that stays silent for three heartbeat
/// periods, and reconnects with a bounded back off — the login and group
/// packets go out again on every connection. The room's broadcast-end packet
/// closes [events] after a final notice message.
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

  /// A notice message emitted when the transport gave up on the socket.
  static const String connectionLostDetail = 'Danmaku connection lost';

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// The endpoint douyu's danmaku proxy serves for the room's cluster.
  static const String _endpoint = 'wss://danmuproxy.douyu.com:8506';

  /// The `mrkl/` packet doubles as the silence watchdog: a socket that
  /// answers nothing for three periods is replaced.
  static final WebSocketConfig _transport = WebSocketConfig(
    reconnectPolicy: const ReconnectPolicy(maxAttempts: maxReconnectAttempts, initialDelay: Duration(seconds: 2)),
    heartbeat: HeartbeatConfig(
      interval: DouyuDanmakuProtocol.heartbeatInterval,
      payload: DouyuDanmakuProtocol.heartbeat,
      timeout: DouyuDanmakuProtocol.heartbeatInterval * 3,
    ),
  );

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
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
    await _teardownSocket();
    final socket = DanmakuSocket(
      uri: Uri.parse(_endpoint),
      config: _transport,
      onHandshake: (socket) => DouyuDanmakuProtocol.joinPackets(roomId).forEach(socket.send),
      onFrame: _onFrame,
      onLost: _loseConnection,
    );
    _socket = socket;
    if (!await socket.start()) {
      return const LiveSiteError.network(
        siteId: 'douyu',
        message: 'danmaku connect failed: no connection to $_endpoint',
      );
    }
    return null;
  }

  void _onFrame(Object frame) {
    if (frame is! List<int>) return;
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
