import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/bigo/api/bigo_http.dart';
import 'package:live_sites/src/platforms/bigo/bigo_manifest.dart';
import 'package:live_sites/src/platforms/bigo/bigo_site.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_chat_visitor.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_failure.dart';
import 'package:live_sites/src/platforms/bigo/parsers/bigo_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for bigo's web chat.
///
/// The session joins by the studio answer's room id, the streamer's account and
/// the room's identity, which the room detail carries on the room's danmaku
/// handle — so a session is built from a fresh detail. A studio the website
/// would not open its chat for (not live, behind the login gate, a password
/// room, `roomType` "1", or one with no room id) has no handle and is reported
/// content-unavailable rather than joined empty.
final class BigoDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  BigoDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the room detail and of the
  /// visitor account's transport.
  final BigoSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final BigoDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! BigoDanmakuArgs || !BigoDanmakuCodec.checks(handle)) {
        return left(LiveSiteError.contentUnavailable(siteId: bigoSiteId, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on BigoFailure catch (failure) {
      return left(failure.toLiveSiteError(bigoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bigoSiteId, message: '$error', cause: error));
    }
    final session = BigoDanmakuSession(args: args, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: one WebSocket as an anonymous visitor, the way the
/// website's player joins a room.
///
/// [DanmakuSocket] (the shared live_websocket transport) owns the socket
/// lifecycle — it connects, forwards every frame to [_onData] and reports a
/// socket that is not coming back. Bigo re-runs its own data-driven handshake on
/// each open (the challenge answer, login and entry the server drives), so its
/// automatic reconnect is switched off and a loss reopens through [_scheduleReconnect].
/// The ping carries the current time and starts only after login, so the 10 s
/// heartbeat and the silence watchdog stay as protocol timers here, not as a
/// transport heartbeat.
///
/// - The first handshake asks `getWebSocketLink` for a visitor account (one
///   request, as the page does once per player); later handshakes reuse it, as
///   the page's reconnect does. A refused or unanswered join drops it, so the
///   next handshake asks for a new one; a request that fails counts as a failed
///   handshake.
/// - On every socket: the challenge is answered, the login follows a second
///   later, then the room is entered; the entry's answer joins and the audience
///   is asked for. A room without a broadcast ends the session with a terminal
///   system message.
/// - Pings every 10 s once logged in, which the server answers; a socket silent
///   for [BigoDanmakuCodec.silenceTimeout] is replaced. A refused or unanswered
///   entry, or no entry within 10 s, reconnects — the fourth in a row ends the
///   session, as does a socket that keeps failing to come back.
/// - Chat (comments and paid bullet comments), the concurrent audience and gifts
///   are reported: a gift waits up to [BigoDanmakuCodec.giftSenderWait] for the
///   gift line that names its sender, and is reported with the name and level
///   then, or without them once the wait is over.
final class BigoDanmakuSession implements LiveDanmakuSession {
  /// A session for the room in [args] over [http]; [connect] asks for the
  /// visitor and opens the socket. [now] and [random] (the device id) are
  /// injectable for tests.
  BigoDanmakuSession({
    required this.args,
    required this.http,
    Duration? loginDelay,
    DateTime Function()? now,
    Random? random,
  }) : _loginDelay = loginDelay ?? BigoDanmakuCodec.loginDelay,
       _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  /// The room this session joined.
  final BigoDanmakuArgs args;

  /// The transport the visitor account is asked over.
  final BigoHttp http;

  /// The least time between the challenge's answer and the login (the page's
  /// own second).
  final Duration _loginDelay;

  final DateTime Function() _now;
  final Random _random;

  static const Duration _connectTimeout = Duration(seconds: 10);

  /// The transport settings of one socket: the page's handshake headers and the
  /// connect budget. The transport's automatic reconnect is off because bigo
  /// re-runs its own data-driven handshake on each open; a loss is reported and
  /// reopened here. The ping carries the current time and starts only after
  /// login, so the heartbeat and silence watchdog stay as protocol timers.
  static const WebSocketConfig _transport = WebSocketConfig(
    headers: BigoDanmakuCodec.socketHeaders,
    connectTimeout: _connectTimeout,
    reconnectPolicy: ReconnectPolicy(enabled: false),
  );

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _login;
  final List<_HeldGift> _heldGifts = [];
  BigoChatVisitor? _visitor;
  String _deviceId = '';
  int _refusals = 0;
  int _reconnectFailures = 0;
  bool _disposed = false;
  bool _joined = false;
  bool _answered = false;
  bool _loginSent = false;
  bool _entering = false;
  bool _reconnecting = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Asks for a visitor when none is kept, opens the socket and joins; null on
  /// a join, else why chat could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: bigoSiteId, message: 'session is disposed');
    }
    if (!BigoDanmakuCodec.checks(args)) {
      return const LiveSiteError.contentUnavailable(siteId: bigoSiteId, message: 'the studio names no chat room');
    }
    return await _openSocket();
  }

  /// Opens one connection over the shared transport: the visitor is asked for
  /// when none is kept, the socket connects, frames come to [_onData] and a
  /// socket that is not coming back is reported through [_onLost].
  Future<LiveSiteError?> _openSocket() async {
    try {
      await _ensureVisitor();
    } on Object catch (error) {
      return LiveSiteError.network(siteId: bigoSiteId, message: 'chat visitor failed: $error', cause: error);
    }
    await _teardownSocket();
    _resetSocket();
    final socket = DanmakuSocket(
      uri: BigoDanmakuCodec.endpoint,
      config: _transport,
      // The handshake is server-driven (it opens with the challenge), so nothing
      // is sent here; the join budget and silence watchdog start with the socket.
      onHandshake: (_) => _startJoinAndWatch(),
      onFrame: _onData,
      onLost: _onLost,
    );
    _socket = socket;
    if (!await socket.start()) {
      return LiveSiteError.network(siteId: bigoSiteId, message: 'danmaku connect failed on ${socket.uri}');
    }
    return null;
  }

  /// The visitor of the next login, asked for once and kept across sockets
  /// until a join is refused.
  Future<void> _ensureVisitor() async {
    if (_visitor != null) return;
    if (_deviceId.isEmpty) _deviceId = BigoDanmakuCodec.deviceId(_random, _now());
    final response = await http.post(BigoDanmakuCodec.linkUrl, fields: BigoDanmakuCodec.linkFields(_deviceId));
    _visitor = BigoDanmakuCodec.visitor(response.text, status: response.status, deviceId: _deviceId);
  }

  void _onData(Object data) {
    _reconnectFailures = 0;
    _startWatchdog();
    final decoded = BigoDanmakuCodec.decode(data, roomId: args.roomId);
    if (decoded.refusal case final refusal?) {
      _refused(refusal);
      return;
    }
    if (decoded.challenge case final challenge? when !_answered) {
      _answered = true;
      _send(BigoDanmakuCodec.answer(challenge, _now()));
      _login = Timer(_loginDelay, () {
        _login = null;
        final visitor = _visitor;
        if (_disposed || visitor == null) return;
        _loginSent = true;
        _send(BigoDanmakuCodec.login(visitor));
        // The page pings every 10 s from the login on, whether or not the room
        // has been entered yet.
        _startHeartbeat();
      });
    }
    if (decoded.loggedIn && _loginSent && !_entering) {
      final visitor = _visitor;
      if (visitor == null) return;
      _entering = true;
      _send(BigoDanmakuCodec.enter(args.roomId, visitor, _now()));
    }
    if (decoded.idle) {
      _terminate('no broadcast in room ${args.roomId}');
      return;
    }
    if (decoded.entered && !_joined) {
      _joined = true;
      _refusals = 0;
      _join?.cancel();
      _join = null;
      _send(BigoDanmakuCodec.users(args, _now()));
    }
    if (decoded.giftSender case final sender?) _named(sender);
    for (final message in decoded.messages) {
      if (_disposed) return;
      final gift = message.giftOrNull;
      if (message.type == LiveMessageType.gift && gift is LiveGift && message.effectiveSender.userId.isNotEmpty) {
        _waitForSender(message);
      } else {
        _report(message);
      }
    }
  }

  /// A refused or unanswered join: the visitor is dropped (the next handshake
  /// asks for a new one) and the socket replaced; the fourth in a row ends the
  /// session.
  void _refused(String refusal) {
    _visitor = null;
    _resetSocket();
    if (++_refusals > BigoDanmakuCodec.maxRefusals) {
      _terminate('chat refused: $refusal');
      return;
    }
    unawaited(_reopen(refusal));
  }

  /// Starts the join budget and the silence watchdog for one socket; re-run on
  /// every open (including a transport reconnect, which is disabled here).
  void _startJoinAndWatch() {
    _join?.cancel();
    _join = Timer(BigoDanmakuCodec.joinTimeout, () {
      if (!_disposed && !_joined) _refused(_loginSent ? 'login or entry unanswered' : 'no challenge or login');
    });
    _startWatchdog();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(BigoDanmakuCodec.heartbeatInterval, (_) {
      if (_loginSent && !_disposed) _send(BigoDanmakuCodec.ping(_now()));
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(BigoDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleReconnect('socket silent');
    });
  }

  /// The transport gave up on the socket; replace it as any other loss.
  void _onLost(String cause) => _scheduleReconnect(cause);

  /// A socket that closed, errored or went silent is replaced; one reconnect at
  /// a time, and [BigoDanmakuCodec.maxReconnectAttempts] failed reconnects end
  /// the session with a terminal system message instead of retrying forever.
  void _scheduleReconnect(String reason) {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: _reconnectFailures + 1));
      if (_disposed) {
        _reconnecting = false;
        return;
      }
      final failure = await connect();
      _reconnecting = false;
      if (failure == null) return;
      _reconnectFailures += 1;
      if (_reconnectFailures >= BigoDanmakuCodec.maxReconnectAttempts) _terminate('$reason: ${failure.message}');
    }());
  }

  /// The same room over a new socket (a refused join), without a lost-connection
  /// notice. A failed reopen falls back to the ordinary reconnect path.
  Future<void> _reopen(String reason) async {
    if (_disposed) return;
    final failure = await connect();
    if (failure == null) return;
    _reconnectFailures++;
    if (_reconnectFailures >= BigoDanmakuCodec.maxReconnectAttempts) _terminate('$reason: ${failure.message}');
  }

  /// A gift waits for the line that names its sender; the oldest gift of that
  /// account is the one the line belongs to.
  void _waitForSender(LiveMessage gift) {
    late final _HeldGift held;
    held = _HeldGift(
      gift: gift,
      timer: Timer(BigoDanmakuCodec.giftSenderWait, () {
        if (_heldGifts.remove(held)) _report(gift);
      }),
    );
    _heldGifts.add(held);
  }

  void _named(BigoGiftSender sender) {
    final index = _heldGifts.indexWhere((held) => held.gift.effectiveSender.userId == sender.userId);
    if (index < 0) return;
    final held = _heldGifts.removeAt(index);
    held.timer.cancel();
    if (_disposed) return;
    final gift = held.gift;
    _report(
      LiveMessage.normalized(
        type: gift.type,
        sender: (gift.sender ?? const MessageSender()).copyWith(userName: sender.name, userLevel: sender.level),
        text: gift.text,
        color: gift.color,
        messageId: gift.messageId,
        payload: gift.payload,
      ),
    );
  }

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  /// The frames of one socket: nothing answered, nothing sent, nothing joined.
  void _resetSocket() {
    _answered = false;
    _loginSent = false;
    _entering = false;
    _joined = false;
    _heartbeat?.cancel();
    _heartbeat = null;
    _login?.cancel();
    _login = null;
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || !socket.isConnected) return;
    socket.send(frame);
  }

  void _terminate(String reason) {
    if (_disposed) return;
    _resetSocket();
    _releaseHeldGifts();
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

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _join?.cancel();
    _join = null;
    _login?.cancel();
    _login = null;
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }

  void _releaseHeldGifts() {
    for (final held in _heldGifts) {
      held.timer.cancel();
    }
    _heldGifts.clear();
  }

  @override
  Future<void> disconnect() async {
    _resetSocket();
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _resetSocket();
    _releaseHeldGifts();
    await _teardownSocket();
    unawaited(_events.close());
  }
}

/// One gift waiting for the line that names its sender.
final class _HeldGift {
  /// Wraps the gift and its wait.
  _HeldGift({required this.gift, required this.timer});

  /// The gift as the animation reported it (no name).
  final LiveMessage gift;

  /// The wait after which it is reported without the name.
  final Timer timer;
}
