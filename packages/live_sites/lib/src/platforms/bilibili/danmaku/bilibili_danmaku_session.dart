import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for Bilibili's classic JSON broadcast protocol.
///
/// The session joins the room by its canonical long id: the auth token, the
/// gateway list and the buvid come from a fresh `getDanmuInfo`, and a room
/// whose credentials could not be obtained at all is reported as
/// content-unavailable rather than joined without a token.
final class BilibiliDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's credentials).
  BilibiliDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the token and the gift
  /// table.
  final BilibiliSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    BilibiliDanmakuArgs args;
    try {
      final longId = site.longId(roomId);
      try {
        args = await site.danmakuArgs(longId);
      } on BilibiliFailure {
        args = await site.emptyDanmakuArgs(longId);
      }
      if (args.token.isEmpty) {
        return left(
          LiveSiteError.contentUnavailable(siteId: 'bilibili', message: 'room $roomId hands out no danmaku token'),
        );
      }
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError('bilibili'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'bilibili', message: '$error', cause: error));
    }
    final session = BilibiliDanmakuSession(args: args, gifts: site.giftCatalog, random: site.random);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live danmaku connection over Bilibili's JSON broadcast WebSocket.
///
/// The socket opens on the credentials' first endpoint (the general gateway),
/// sends the auth packet at once and counts as joined when the reply says
/// `code 0` — then it sends a heartbeat and starts the 30 s beat. Without a
/// reply within [BilibiliDanmakuProtocol.joinTimeout] the socket is replaced.
/// Protocol-level recovery is this session's job: a socket that errors, closes
/// or stays silent for [BilibiliDanmakuProtocol.inactivityTimeout] is replaced
/// (auth sent again, the generation counted so a stale socket's frames are
/// dropped), the endpoints of the credential list alternating per attempt.
/// After [BilibiliDanmakuProtocol.maxReconnectAttempts] failed reconnects a
/// terminal system message closes [events] instead of retrying forever. An
/// auth rejection reconnects with the same credentials — a token that stays
/// rejected therefore ends the session through that cap rather than through a
/// credential refresh of its own. Text frames are ignored: the protocol only
/// speaks binary.
final class BilibiliDanmakuSession implements LiveDanmakuSession {
  /// A session for the room in [args]; [connect] opens the socket. [gifts] is
  /// the platform's gift table, asked for once without holding the join back
  /// (D07.4: it fills in what a gift packet leaves out).
  BilibiliDanmakuSession({required this.args, this.gifts, Random? random}) : _random = random ?? Random.secure();

  /// The room this session joined.
  final BilibiliDanmakuArgs args;

  /// The platform's gift table, asked for once at the start of a connection;
  /// null when the caller has none.
  final Future<BilibiliGiftCatalog> Function()? gifts;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = BilibiliDanmakuProtocol.maxReconnectAttempts;

  final Random _random;
  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  StreamSubscription<dynamic>? _subscription;
  int _generation = 0;
  int _server = 0;
  bool _disposed = false;
  bool _joined = false;

  /// The gift table, once [gifts] gave it; until then, and when it fails,
  /// gifts go without what only the table has.
  BilibiliGiftCatalog _catalog = BilibiliGiftCatalog.empty;

  /// One reconnect in flight per generation (the watchdog and `onDone` both
  /// fire on a dead socket; without this they would double-open).
  bool _reconnecting = false;

  /// Consecutive failed reconnects.
  int _reconnectFailures = 0;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket, sends the auth packet and waits for the reply; null on
  /// success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'bilibili', message: 'session is disposed');
    }
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    final servers = args.servers.isEmpty ? [Uri.parse(BilibiliEndpoints.danmakuGateway)] : args.servers;
    final endpoint = servers[_server++ % servers.length];
    final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(endpoint, headers: args.headers);
      await channel.ready.timeout(_connectTimeout);
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'bilibili', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        // Bilibili only sends binary frames; a text frame is not the protocol.
        if (data is! List<int>) return;
        _onFrame(Uint8List.fromList(data));
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    _send(
      BilibiliDanmakuProtocol.auth(
        uid: args.uid,
        roomId: args.roomId,
        buvid: args.buvid,
        token: args.token,
        queueUuid: BilibiliDanmakuProtocol.queueUuid(_random),
      ),
    );
    _join = Timer(BilibiliDanmakuProtocol.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleReconnect(generation, 'no auth reply');
      }
    });
    _startWatchdog();
    unawaited(_loadGifts());
    return null;
  }

  static const Duration _connectTimeout = Duration(seconds: 10);

  Future<void> _loadGifts() async {
    final load = gifts;
    if (load == null) return;
    try {
      _catalog = await load();
    } on Object {
      // Soft: the gifts are still reported, just without the table's fill-in.
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(BilibiliDanmakuProtocol.inactivityTimeout, () {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
  }

  void _onFrame(Uint8List frame) {
    _reconnectFailures = 0;
    _startWatchdog();
    final decoded = BilibiliDanmakuProtocol.decode(frame, gifts: _catalog);
    decoded.sends.forEach(_send);
    decoded.messages.forEach(_events.add);
    if (decoded.authCode case final code?) _authReply(code);
  }

  /// The auth reply: `code 0` accepts (join complete — heartbeat now, then
  /// every 30 s), anything else rejects and replaces the socket.
  void _authReply(int code) {
    if (code == 0) {
      if (_joined) return;
      _joined = true;
      _join?.cancel();
      _join = null;
      _send(BilibiliDanmakuProtocol.heartbeat());
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(BilibiliDanmakuProtocol.heartbeatInterval, (_) {
        if (_joined && !_disposed) _send(BilibiliDanmakuProtocol.heartbeat());
      });
      return;
    }
    _joined = false;
    _scheduleReconnect(_generation, 'auth rejected (code $code)');
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
      // Back off from [BilibiliDanmakuProtocol.reconnectBase], once per
      // consecutive failure, so a flapping edge is not hammered.
      final backoff = BilibiliDanmakuProtocol.reconnectBase * (_reconnectFailures + 1);
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
    _join?.cancel();
    _join = null;
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
    _joined = false;
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _joined = false;
    await _teardownSocket();
    unawaited(_events.close());
  }
}
