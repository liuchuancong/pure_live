import 'dart:async';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_endpoints.dart';
import 'package:live_sites/src/platforms/chzzk/api/chzzk_http.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/danmaku/chzzk_danmaku_codec.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_json.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for chzzk's game chat.
///
/// The session joins by the live's `chatChannelId`, which the room read carries
/// on the room's danmaku handle — so a session is built from a fresh detail. A
/// room with no live, or a live the platform gives no chat channel to (a closed,
/// region-locked or adult broadcast), has no handle and is reported
/// content-unavailable rather than joined empty.
final class ChzzkDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's live and its chat).
  ChzzkDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the room detail and of the
  /// token, routing and live-state requests.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final ChzzkDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! ChzzkDanmakuArgs || !ChzzkDanmakuCodec.isChatChannelId(handle.chatChannelId)) {
        return left(LiveSiteError.contentUnavailable(siteId: 'chzzk', message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError('chzzk'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'chzzk', message: '$error', cause: error));
    }
    final session = ChzzkDanmakuSession(args: args, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: an access token and the session servers over
/// [ChzzkHttp], then one WebSocket to the chat over the shared [DanmakuSocket]
/// transport.
///
/// - [connect] asks for the token up to [tokenAttempts] times (0.5 s and 1 s
///   apart) while the routing is asked once in parallel; without a token the
///   session cannot start, and without a routing answer the SDK's own five
///   servers are used. Both are kept for the rest of this session, as the
///   site's client keeps its token across its own reconnects — and, as the
///   recordings of 2026-09-28 showed, a read-only join is not checked against
///   the token at all, so a refusal is never answered by asking for a new one.
/// - The socket starts at a random server and goes round the others. Every open
///   sends the read-only join; an accepted join asks the recent 50 lines, and a
///   join unanswered within [ChzzkDanmakuCodec.joinTimeout] drops the socket. A
///   refused join ends the session, except [ChzzkDanmakuCodec.retryCodes]
///   (302–304), on which the site also reconnects; `cmd` 90102 ends it the same
///   way.
/// - The ping every [ChzzkDanmakuCodec.heartbeatInterval] and the 30 s silence
///   watchdog are the transport heartbeat (the server answers the ping, so the
///   timeout marks a dead socket); a server ping is still answered at once. The
///   transport's own automatic reconnect is off because a dead socket is replaced
///   on the *next* session server, which only this session can decide; a socket
///   that errors, closes or goes silent is replaced through its loss handler, and
///   after [maxReconnectAttempts] failed reconnects a terminal system message
///   closes [events] instead of retrying forever.
/// - The recent chat of every join repeats lines already shown: chat is left to
///   the app's duplicate gate, while a super chat or notice already reported in
///   this session is reported once.
/// - After [quietPeriod] without a line pushed live, the channel's live state is
///   read once. A restarted broadcast gets a new chat channel and the old one
///   falls silent at once, so when the open live names another channel the
///   session takes a token for it and moves its socket there. The site polls
///   this every 30 s; asking only while the chat is quiet costs one request per
///   three minutes on a small live instead of six.
final class ChzzkDanmakuSession implements LiveDanmakuSession {
  /// A session for the chat in [args] over [http]. [random] picks the first
  /// server and [now] is the clock a donation without its own time is
  /// received at (tests).
  ChzzkDanmakuSession({required this.args, required this.http, Random? random, DateTime Function()? now})
    : _random = random ?? Random.secure(),
      _now = now ?? DateTime.now;

  /// The chat this session joined; [ChzzkDanmakuArgs.chatChannelId] changes when
  /// the broadcast moves to a new one.
  ChzzkDanmakuArgs args;

  /// The transport the token, routing and live-state requests go over.
  final ChzzkHttp http;

  /// How long the chat may go without a line pushed live before the live's
  /// state is read once.
  static const Duration quietPeriod = Duration(minutes: 3);

  /// Requests per attempt to get an access token.
  static const int tokenAttempts = 3;

  /// Longest wait for one token answer.
  static const Duration tokenTimeout = Duration(seconds: 5);

  /// Longest wait for the routing answer: the SDK's `callTimeoutMillis`.
  static const Duration routingTimeout = Duration(milliseconds: 1500);

  /// Longest wait for the live-status answer.
  static const Duration liveStatusTimeout = Duration(seconds: 5);

  /// Failed reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  /// Most ids of super chats and notices remembered per session.
  static const int maxRemembered = 512;

  /// The step between token attempts (0.5 s, then 1 s).
  static const Duration _tokenRetryDelay = Duration(milliseconds: 500);

  static const Duration _connectTimeout = Duration(seconds: 10);

  /// The heartbeat payload — a tear-off so the config stays a const.
  static Object _heartbeatPayload() => ChzzkDanmakuCodec.ping;

  /// The transport settings of one socket: the handshake headers, the connect
  /// budget, and the ping every 20 s whose unanswered-for-30 s silence marks the
  /// socket dead. The transport's own automatic reconnect is off because a dead
  /// socket is replaced on the *next* session server, which only this session can
  /// decide.
  static const WebSocketConfig _transport = WebSocketConfig(
    headers: ChzzkDanmakuCodec.handshakeHeaders,
    connectTimeout: _connectTimeout,
    reconnectPolicy: ReconnectPolicy(enabled: false),
    heartbeat: HeartbeatConfig(
      interval: ChzzkDanmakuCodec.heartbeatInterval,
      payload: _heartbeatPayload,
      timeout: ChzzkDanmakuCodec.inactivityTimeout,
    ),
  );

  final Random _random;
  final DateTime Function() _now;

  final _events = StreamController<LiveMessage>.broadcast();
  final Set<String> _reported = {};
  DanmakuSocket? _socket;
  Timer? _join;
  Timer? _quiet;
  List<String> _servers = ChzzkDanmakuCodec.defaultServers;
  String _token = '';
  int _generation = 0;
  int _server = 0;
  int _reconnectFailures = 0;
  bool _disposed = false;
  bool _joined = false;
  bool _reconnecting = false;
  bool _checking = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Asks for the servers and the token, opens the socket and joins; null on a
  /// join, else why chat could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'chzzk', message: 'session is disposed');
    }
    final channel = args.chatChannelId.trim();
    if (!ChzzkDanmakuCodec.isChatChannelId(channel)) {
      return const LiveSiteError.contentUnavailable(siteId: 'chzzk', message: 'the live names no chat channel');
    }
    final routing = _askServers();
    final token = await _askToken(channel);
    _servers = await routing;
    if (token == null) {
      return const LiveSiteError.authentication(siteId: 'chzzk', message: 'chzzk gave no chat access token');
    }
    _token = token;
    _server = _random.nextInt(_servers.length);
    return await _openSocket();
  }

  /// Opens one connection on the current server over the shared transport: the
  /// socket connects, the read-only join goes out on every open, [_transport]
  /// carries the ping and its silence watchdog, frames come to [_onData] and a
  /// socket that closed is reported to [_scheduleReconnect].
  Future<LiveSiteError?> _openSocket() async {
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    final endpoint = ChzzkDanmakuCodec.endpoints(_servers, _server).first;
    final socket = DanmakuSocket(
      uri: endpoint,
      config: _transport,
      onHandshake: (socket) => socket.send(ChzzkDanmakuCodec.join(args.chatChannelId, _token)),
      onFrame: _onData,
      onLost: (cause) => _scheduleReconnect(generation, cause),
    );
    _socket = socket;
    if (!await socket.start()) {
      return LiveSiteError.network(siteId: 'chzzk', message: 'danmaku connect failed on $endpoint');
    }
    _join = Timer(ChzzkDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) _scheduleReconnect(generation, 'join timed out');
    });
    return null;
  }

  /// The session servers: one routing request, else the SDK's built-in list.
  Future<List<String>> _askServers() async {
    try {
      final response = await http.get(ChzzkEndpoints.routing(), timeout: routingTimeout);
      if (response.status != 200) return ChzzkDanmakuCodec.defaultServers;
      final routed = ChzzkDanmakuCodec.servers(ChzzkHttp.json(response.text));
      if (routed != null) return routed;
    } on Object {
      // The SDK falls back to its own list as well.
    }
    return ChzzkDanmakuCodec.defaultServers;
  }

  /// An access token for [channel]: up to [tokenAttempts] requests, or null
  /// when none gave one.
  Future<String?> _askToken(String channel) async {
    for (var attempt = 0; attempt < tokenAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_tokenRetryDelay * attempt);
        if (_disposed) return null;
      }
      try {
        final response = await http.get(ChzzkEndpoints.accessToken(channel), timeout: tokenTimeout);
        if (_disposed) return null;
        if (response.status != 200) continue;
        if (ChzzkDanmakuCodec.accessToken(ChzzkHttp.json(response.text)) case final token?) return token;
      } on Object {
        if (_disposed) return null;
      }
    }
    return null;
  }

  void _onData(Object data) {
    _reconnectFailures = 0;
    final frame = ChzzkDanmakuCodec.decode(data, receivedAt: _now());
    if (frame.ping) _send(ChzzkDanmakuCodec.pong);
    for (final message in frame.messages) {
      if (_isNew(message)) _report(message);
    }
    if (frame.pushed) _restartQuiet();
    switch (frame.joined) {
      case true:
        _joined = true;
        _join?.cancel();
        _join = null;
        _restartQuiet();
        if (frame.sessionId.isNotEmpty) _send(ChzzkDanmakuCodec.recent(args.chatChannelId, frame.sessionId));
      case false:
        _terminate('Join refused: ${frame.refusal ?? ''}');
      case null:
        break;
    }
    if (frame.closed) _terminate('Closed by the server');
  }

  /// Whether [message] is to be reported: chat (the app's duplicate gate sees
  /// it) and messages without an id always; a super chat or notice once per
  /// session, since the recent chat of every join repeats them.
  bool _isNew(LiveMessage message) {
    if (message.type == LiveMessageType.chat || message.messageId.isEmpty) return true;
    if (!_reported.add(message.messageId)) return false;
    if (_reported.length > maxRemembered) _reported.remove(_reported.first);
    return true;
  }

  void _restartQuiet() {
    _quiet?.cancel();
    _quiet = null;
    // Only a joined chat of a known channel has a live state worth asking for.
    if (_disposed || !_joined || !isChannelId(args.channelId)) return;
    _quiet = Timer(quietPeriod, () => unawaited(_checkLive()));
  }

  /// The chat was quiet for [quietPeriod]: read the live's state once and move
  /// to its chat channel when that changed; otherwise wait again.
  Future<void> _checkLive() async {
    _quiet = null;
    if (_disposed || _checking || _socket == null) return;
    _checking = true;
    try {
      String? next;
      try {
        final response = await http.get(ChzzkEndpoints.liveStatus(args.channelId), timeout: liveStatusTimeout);
        if (response.status == 200) next = ChzzkDanmakuCodec.liveChatChannel(ChzzkHttp.json(response.text));
      } on Object {
        // Asked again after the next quiet period.
      }
      if (_disposed) return;
      if (next == null || next == args.chatChannelId) {
        _restartQuiet();
        return;
      }
      final token = await _askToken(next);
      if (_disposed || token == null) {
        _restartQuiet();
        return;
      }
      args = ChzzkDanmakuArgs(channelId: args.channelId, chatChannelId: next);
      _token = token;
      final generation = _generation;
      await _teardownSocket();
      final failure = await _openSocket();
      if (failure != null && generation == _generation) _terminate(failure.message);
    } finally {
      _checking = false;
    }
  }

  /// A socket that closed, errored, was refused or went silent is replaced on
  /// the next server; [maxReconnectAttempts] failures in a row end the session.
  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: _reconnectFailures + 1));
      if (_disposed || staleGeneration != _generation) {
        _reconnecting = false;
        return;
      }
      _server = (_server + 1) % _servers.length;
      final failure = await _openSocket();
      _reconnecting = false;
      if (failure == null) return;
      _reconnectFailures += 1;
      if (_reconnectFailures >= maxReconnectAttempts) _terminate('$reason: ${failure.message}');
    }());
  }

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || !socket.isConnected) return;
    socket.send(frame);
  }

  void _terminate(String reason) {
    if (_disposed) return;
    _generation++;
    _joined = false;
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
    _join?.cancel();
    _join = null;
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }

  @override
  Future<void> disconnect() async {
    _generation++;
    _joined = false;
    _quiet?.cancel();
    _quiet = null;
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _joined = false;
    _quiet?.cancel();
    _quiet = null;
    await _teardownSocket();
    unawaited(_events.close());
  }
}
