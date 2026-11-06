import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_endpoints.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

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
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    BilibiliDanmakuArgs args;
    try {
      final longId = site.longId(room.roomId);
      try {
        args = await site.danmakuArgs(longId);
      } on BilibiliFailure {
        args = await site.emptyDanmakuArgs(longId);
      }
      if (args.token.isEmpty) {
        return left(
          LiveSiteError.contentUnavailable(
            siteId: bilibiliSiteId,
            message: 'room ${room.roomId} hands out no danmaku token',
          ),
        );
      }
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
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
/// The transport ([DanmakuSocket]) owns the socket lifecycle; the 30 s beat is
/// the silence watchdog too — a socket that answers nothing for
/// [BilibiliDanmakuProtocol.inactivityTimeout] is dropped. What the transport
/// cannot know is this protocol's own join: the auth packet goes out when the
/// socket opens and [BilibiliDanmakuProtocol.joinTimeout] later without a
/// `code 0` reply counts as a loss, as does a rejection. A transport loss
/// re-opens on the next gateway of the credential list after a growing back
/// off (the transport's automatic reconnect stays on the dead gateway). An
/// auth rejection is the token being refused, so re-opening with it would only
/// be refused again: fresh credentials are fetched ([BilibiliDanmakuArgs.
/// refresh], at most [maxCredentialRefreshes] per [connect]) and the new
/// endpoint list joined from its start; none coming ends the session. A
/// transport loss that survives [BilibiliDanmakuProtocol.maxReconnectAttempts]
/// attempts ends it too, with a terminal system message on [events]. Text
/// frames are ignored: the protocol only speaks binary.
final class BilibiliDanmakuSession implements LiveDanmakuSession {
  /// A session for the room in [args]; [connect] opens the socket. [gifts] is
  /// the platform's gift table, asked for once without holding the join back
  /// (D07.4: it fills in what a gift packet leaves out).
  BilibiliDanmakuSession({required BilibiliDanmakuArgs args, this.gifts, Random? random})
    : args = args,
      _current = args,
      _random = random ?? Random.secure();

  /// The room this session joined.
  final BilibiliDanmakuArgs args;

  /// The platform's gift table, asked for once at the start of a connection;
  /// null when the caller has none.
  final Future<BilibiliGiftCatalog> Function()? gifts;

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = BilibiliDanmakuProtocol.maxReconnectAttempts;

  /// How often a rejected auth may ask for fresh credentials per [connect]
  /// (the reference's budget; the refresh carries the site's own retry
  /// schedule, so these are cheap rounds).
  static const int maxCredentialRefreshes = 3;

  /// The handshake budget of one attempt.
  static const Duration _connectTimeout = Duration(seconds: 10);

  final Random _random;
  final _events = StreamController<LiveMessage>.broadcast();

  /// The credentials in use; [args] until a rejected auth brought fresh ones.
  BilibiliDanmakuArgs _current;
  DanmakuSocket? _socket;
  Timer? _join;
  int _server = 0;
  bool _disposed = false;
  bool _joined = false;

  /// A drop already in flight (the join timeout, the watchdog and a rejection
  /// all fire on the same dead socket).
  bool _dropping = false;

  /// A credential round already in flight (the reply of a rejected socket and
  /// a second packet in the same message both report the rejection).
  bool _rejoining = false;

  /// Credential refreshes spent since [connect].
  int _credentialRefreshes = 0;

  /// Consecutive failed attempts; any frame means the connection is healthy
  /// again and resets the run.
  int _reconnectFailures = 0;

  /// The gift table, once [gifts] gave it; until then, and when it fails,
  /// gifts go without what only the table has.
  BilibiliGiftCatalog _catalog = BilibiliGiftCatalog.empty;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket, sends the auth packet and waits for the reply; null on
  /// success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() {
    _credentialRefreshes = 0;
    return _open();
  }

  /// Opens one connection, on the next gateway of the credential list.
  Future<LiveSiteError?> _open() async {
    await _teardownSocket();
    final servers = _current.servers.isEmpty ? [Uri.parse(BilibiliEndpoints.danmakuGateway)] : _current.servers;
    final endpoint = servers[_server++ % servers.length];
    final socket = DanmakuSocket(
      uri: endpoint,
      config: WebSocketConfig(
        headers: _current.headers,
        connectTimeout: _connectTimeout,
        // A retry here would reconnect to the same gateway; the rotation of
        // the credential list and the re-auth are this session's to run.
        reconnectPolicy: const ReconnectPolicy(enabled: false),
        heartbeat: HeartbeatConfig(
          interval: BilibiliDanmakuProtocol.heartbeatInterval,
          // The beat starts once the room is joined; until then the socket is
          // waiting on its auth reply, not on traffic.
          payload: () => _joined ? BilibiliDanmakuProtocol.heartbeat() : null,
          timeout: BilibiliDanmakuProtocol.inactivityTimeout,
        ),
      ),
      onHandshake: _sendAuth,
      onFrame: _onFrame,
      onLost: _drop,
    );
    _socket = socket;
    if (!await socket.start()) {
      return LiveSiteError.network(siteId: bilibiliSiteId, message: 'danmaku connect failed on $endpoint');
    }
    _joined = false;
    _join = Timer(BilibiliDanmakuProtocol.joinTimeout, () {
      if (!_joined && !_disposed) _drop('no auth reply');
    });
    unawaited(_loadGifts());
    return null;
  }

  /// The auth packet of one connection: a fresh queue uuid per attempt.
  void _sendAuth(DanmakuSocket socket) {
    socket.send(
      BilibiliDanmakuProtocol.auth(
        uid: _current.uid,
        roomId: _current.roomId,
        buvid: _current.buvid,
        token: _current.token,
        queueUuid: BilibiliDanmakuProtocol.queueUuid(_random),
      ),
    );
  }

  Future<void> _loadGifts() async {
    final load = gifts;
    if (load == null) return;
    try {
      _catalog = await load();
    } on Object {
      // Soft: the gifts are still reported, just without the table's fill-in.
    }
  }

  void _onFrame(Object frame) {
    // Bilibili only sends binary frames; a text frame is not the protocol.
    if (frame is! List<int>) return;
    _reconnectFailures = 0;
    final decoded = BilibiliDanmakuProtocol.decode(Uint8List.fromList(frame), gifts: _catalog);
    decoded.sends.forEach(_send);
    decoded.messages.forEach(_events.add);
    if (decoded.authCode case final code?) _authReply(code);
  }

  void _send(Uint8List packet) => _socket?.send(packet);

  /// The auth reply: `code 0` accepts (join complete — heartbeat now, then
  /// every 30 s), anything else rejects the credentials and asks for fresh
  /// ones before the socket is replaced.
  void _authReply(int code) {
    if (code == 0) {
      if (_joined) return;
      _joined = true;
      _join?.cancel();
      _join = null;
      _send(BilibiliDanmakuProtocol.heartbeat());
      return;
    }
    _joined = false;
    _join?.cancel();
    _join = null;
    unawaited(_rejoin(code));
  }

  /// Answers a rejected auth: fresh credentials, joined from their first
  /// endpoint; none coming (the refresh failed, handed out no token, or the
  /// budget of [maxCredentialRefreshes] is spent) ends the session — the
  /// platform has refused this room's chat, and reopening with the refused
  /// token would only be refused again. A fresh socket that cannot even be
  /// opened is a transport loss, not a credential one: the gateway schedule
  /// takes the fresh token from there.
  Future<void> _rejoin(int code) async {
    if (_disposed || _rejoining || _dropping) return;
    _rejoining = true;
    try {
      await _teardownSocket();
      BilibiliDanmakuArgs? refreshed;
      if (_credentialRefreshes < maxCredentialRefreshes) {
        _credentialRefreshes += 1;
        try {
          refreshed = await _current.refresh?.call();
        } on Object {
          // Reported as unavailable below.
        }
      }
      if (_disposed) return;
      if (refreshed != null && refreshed.token.isNotEmpty) {
        _current = refreshed;
        _server = 0;
        if (await _open() == null) return;
        await _retry('danmaku connect failed');
        return;
      }
      _loseConnection('auth rejected (code $code): credentials unavailable');
    } finally {
      _rejoining = false;
    }
  }

  /// Drops the current socket and re-opens it on the next gateway.
  void _drop(String cause) {
    if (_disposed || _dropping || _rejoining) return;
    _dropping = true;
    unawaited(() async {
      await _teardownSocket();
      _dropping = false;
      await _retry(cause);
    }());
  }

  Future<void> _retry(String cause) async {
    while (!_disposed) {
      // A rejected auth owns the socket while it brings fresh credentials.
      if (_rejoining) return;
      _reconnectFailures++;
      if (_reconnectFailures > maxReconnectAttempts) {
        _loseConnection(cause);
        return;
      }
      // Grow the back off with the run so a flapping gateway is not hammered.
      await Future<void>.delayed(BilibiliDanmakuProtocol.reconnectBase * _reconnectFailures);
      if (_disposed || _rejoining) return;
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
    _joined = false;
    _join?.cancel();
    _join = null;
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
