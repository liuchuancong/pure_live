import 'dart:async';
import 'dart:collection';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_endpoints.dart';
import 'package:live_sites/src/platforms/seventeenlive/api/seventeenlive_http.dart';
import 'package:live_sites/src/platforms/seventeenlive/danmaku/seventeenlive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_room_parser.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The detail of the session's end at the stream end.
const String seventeenLiveBroadcastEnded = 'Broadcast ended';

/// Creates danmaku sessions for 17LIVE's Ably chat.
///
/// The channel is the room id itself — `subscribeChatRoom(roomID)` is what the
/// website joins — and the token is anonymous, asked by the chat, so a session is
/// built from the room id alone and costs no room request. An id that is not a
/// room id (1 to 12 digits) starts nothing. The token is asked when the session
/// connects: a run that `messenger/auth` hands to another push service than Ably
/// is reported unsupported, never joined empty.
final class SeventeenLiveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose transport asks the chat token).
  SeventeenLiveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final id = SeventeenLiveRoomParser.normalizeRoomId(roomId);
    if (id == null) {
      return left(LiveSiteError.invalidArgument(siteId: seventeenliveSiteId, message: 'not a room id: $roomId'));
    }
    final session = SeventeenLiveDanmakuSession(
      args: SeventeenLiveDanmakuArgs(roomId: id),
      http: site.http,
    );
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: an anonymous Ably token over [SeventeenLiveHttp],
/// then Ably's JSON realtime protocol over the shared [DanmakuSocket] transport.
///
/// - The token is asked in the handshake: the first socket of a session asks
///   `messenger/auth`, later ones reuse the token until the server refuses it. A
///   failed request fails that attempt ([SeventeenLiveDanmakuSession.maxReconnectAttempts]
///   of them end the session); a run `messenger/auth` gave to another provider
///   ends it at once.
/// - The sockets are the primary host and the website's three fallback hosts,
///   rotated on failure. At `CONNECTED` the room's channel is attached; `ATTACHED`
///   joins it, and an attach unanswered for [SeventeenLiveDanmakuCodec.joinTimeout]
///   drops the socket.
/// - A later socket of the session resumes as ably-js does: its handshake has
///   `resume` with the last `CONNECTED`'s key and its `ATTACH` the last
///   `channelSerial` and the `ATTACH_RESUME` flag, so the server sends the
///   messages missed meanwhile. A resume that fails (a new connection id, 80018)
///   or a channel that cannot go on from the serial (90003) is attached all the
///   same. A message whose Ably id was already reported is not reported again.
///   After more than `connectionStateTtl` + `maxIdleInterval` (135 s) without a
///   frame the key and the serial are forgotten, as ably-js forgets a stale
///   connection, and the next socket starts afresh; an attach unanswered in time
///   forgets the serial (ably-js suspends the channel).
/// - The server sends heartbeats every 15 s and the client none, so the
///   transport's receive-only watchdog is the silence check: a socket silent for
///   [SeventeenLiveDanmakuCodec.inactivityTimeout] is replaced.
/// - A token error (`ERROR` or `DISCONNECTED`, 40140 to 40149) drops the token and
///   the socket; the next handshake asks a new one. More than
///   [SeventeenLiveDanmakuCodec.maxRefusals] in a row without an attach between
///   ends the session. Any other connection `ERROR` or a channel `ERROR` ends it
///   as well (ably-js fails the connection or the channel); another `DISCONNECTED`
///   reconnects.
/// - A server-sent `DETACHED` attaches the channel again on the same socket, from
///   the last serial; a second one before it is attached, or no answer within the
///   join limit, drops the socket and the serial. It counts as a refusal like a
///   token error. A server-sent `AUTH` asks a new token and sends it on the same
///   socket.
/// - The stream end (5) ends the session with [seventeenLiveBroadcastEnded], as
///   the website leaves the channel then. The live figures' `liveinfo.mute`
///   turning true (the streamer paused the stream), or false again after that, is
///   a system notice. While paused, and in the figures that end the pause, a count
///   of 0 viewers is not reported: the last count stays (B-25).
/// - The messages of a backlog an `ATTACHED` announces (`HAS_BACKLOG`) are marked
///   replayed, up to the first message Ably published at the attach or later, so
///   the duplicate gate shows them for as long as a resume reaches back (B-26).
final class SeventeenLiveDanmakuSession implements LiveDanmakuSession {
  /// A session for the chat of [args] over [http]. [now] is the clock the
  /// super chats, the backlog cut and the resume staleness are read at (tests).
  SeventeenLiveDanmakuSession({required this.args, required this.http, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The channel this session joined: the room id, the Ably channel name.
  final SeventeenLiveDanmakuArgs args;

  /// The transport the token request goes over.
  final SeventeenLiveHttp http;

  /// Ably message ids remembered, so a message sent again after a resume is
  /// reported once (the oldest goes first).
  static const int maxSeen = 4096;

  /// Failed sockets in a row before the session is abandoned.
  static const int maxReconnectAttempts = SeventeenLiveDanmakuCodec.maxReconnectAttempts;

  /// The transport settings of one socket: the website's handshake headers, the
  /// connect budget, and the server's 15 s beat as the tick of a receive-only
  /// watchdog (the client sends no heartbeat, so [HeartbeatConfig.payload] stays
  /// null and only [HeartbeatConfig.timeout] replaces a silent socket). The
  /// transport's own automatic reconnect is off because every attempt needs a new
  /// handshake URL — a token, and a `resume` key this session owns.
  static const WebSocketConfig _transport = WebSocketConfig(
    headers: SeventeenLiveDanmakuCodec.handshakeHeaders,
    connectTimeout: SeventeenLiveDanmakuCodec.connectTimeout,
    reconnectPolicy: ReconnectPolicy(enabled: false),
    heartbeat: HeartbeatConfig(
      interval: SeventeenLiveDanmakuCodec.heartbeatInterval,
      timeout: SeventeenLiveDanmakuCodec.inactivityTimeout,
    ),
  );

  final DateTime Function() _now;

  final _events = StreamController<LiveMessage>.broadcast();
  final CancelToken _cancel = CancelToken();
  final LinkedHashSet<String> _seen = LinkedHashSet<String>();

  DanmakuSocket? _socket;
  Timer? _join;
  Timer? _reattachWatch;
  String? _token;
  SeventeenLiveConnectionDetails? _connection;
  String? _channelSerial;
  DateTime? _lastActivity;
  DateTime? _backlogBefore;
  bool? _muted;
  bool _attachedBefore = false;
  bool _attachPending = false;
  bool _reattaching = false;
  bool _joined = false;
  bool _reconnecting = false;
  bool _disposed = false;
  int _refusals = 0;
  int _sockets = 0;
  int _endpoint = 0;
  int _generation = 0;
  int _reconnectFailures = 0;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Asks a token when the session holds none, opens a socket and attaches the
  /// room's channel; null once the socket is open, else why the session could not
  /// start. The `ATTACHED` that joins is what ends the join timer.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: seventeenliveSiteId, message: 'session is disposed');
    }
    return await _openSocket();
  }

  /// One socket: a token (kept from the last refusal), the handshake URL with the
  /// `resume` of a connection that is still fresh, and the channel attach from the
  /// last serial. The endpoint is never named in a failure: its query carries the
  /// token and the key.
  Future<LiveSiteError?> _openSocket() async {
    final generation = ++_generation;
    _joined = false;
    _socketReset();
    await _teardownSocket();
    final token = _token;
    if (token == null) {
      final asked = await _renew(generation);
      if (asked case final failure?) return failure;
    }
    if (_disposed || generation != _generation) {
      return const LiveSiteError.unsupported(siteId: seventeenliveSiteId, message: 'session is closed');
    }
    final endpoint = SeventeenLiveDanmakuCodec.withToken(
      SeventeenLiveDanmakuCodec.endpoints[_endpoint % SeventeenLiveDanmakuCodec.endpoints.length],
      _token!,
      resume: _resumeKey(_now()),
    );
    final socket = DanmakuSocket(
      // The attach goes out when `CONNECTED` names the connection, not on open:
      // Ably answers nothing before it.
      uri: endpoint,
      config: _transport,
      onHandshake: (_) {},
      onFrame: (data) => _onData(data, generation),
      onLost: (cause) => _scheduleReconnect(generation, cause),
    );
    _socket = socket;
    if (!await socket.start()) {
      return const LiveSiteError.network(siteId: seventeenliveSiteId, message: 'danmaku connect failed');
    }
    _sockets += 1;
    _join = Timer(SeventeenLiveDanmakuCodec.joinTimeout, () {
      if (_disposed || generation != _generation || _joined) return;
      // An attach sent and not answered: the channel is suspended, so its serial
      // goes (ably-js's own rule) and the socket is replaced.
      if (_attachPending) _channelSerial = null;
      _scheduleReconnect(generation, 'attach timed out');
    });
    return null;
  }

  /// Asks `messenger/auth` and keeps its token. Another provider ends the
  /// session; every other failure is returned for the caller to retry.
  Future<LiveSiteError?> _renew(int generation) async {
    final String token;
    try {
      final response = await http.post(
        SeventeenLiveEndpoints.authUrl,
        headers: SeventeenLiveDanmakuCodec.authHeaders,
        cancel: _cancel,
      );
      token = SeventeenLiveDanmakuCodec.grant(response.text, status: response.status);
    } on SeventeenLiveFailure catch (failure) {
      if (failure.kind == SeventeenLiveFailureKind.chatRefused) {
        _terminate(failure.message);
        return failure.toLiveSiteError(seventeenliveSiteId);
      }
      return failure.toLiveSiteError(seventeenliveSiteId);
    } on Object catch (error) {
      return LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error);
    }
    if (_disposed || generation != _generation) {
      return const LiveSiteError.unsupported(siteId: seventeenliveSiteId, message: 'session is closed');
    }
    _token = token;
    return null;
  }

  void _onData(Object data, int generation) {
    if (generation != _generation || _disposed) return;
    _reconnectFailures = 0;
    final now = _now();
    _lastActivity = now;
    final frame = SeventeenLiveDanmakuCodec.decode(data, roomId: args.roomId, now: now, backlogBefore: _backlogBefore);
    if (frame.channelSerial case final serial?) _channelSerial = serial;
    switch (frame.signal) {
      case SeventeenLiveSignal.none:
        break;
      case SeventeenLiveSignal.connected:
        if (frame.connection case final connection?) _connection = connection;
        _attach();
      case SeventeenLiveSignal.attached:
        _refusals = 0;
        _attachPending = false;
        _attachedBefore = true;
        _reattaching = false;
        // A backlog follows: what Ably published before now.
        _backlogBefore = frame.backlog ? now : null;
        _reattachWatch?.cancel();
        _reattachWatch = null;
        _joined = true;
        _join?.cancel();
        _join = null;
      case SeventeenLiveSignal.detached:
        _detached(frame.error);
      case SeventeenLiveSignal.disconnected:
        if (frame.error case final error? when error.isTokenError) {
          _tokenRefused(error);
        } else {
          _scheduleReconnect(generation, 'server disconnected');
        }
      case SeventeenLiveSignal.connectionError:
        final error = frame.error!;
        if (error.isTokenError) {
          _tokenRefused(error);
        } else {
          _terminate('Ably error $error');
          return;
        }
      case SeventeenLiveSignal.channelError:
        _terminate('Channel refused: ${frame.error}');
        return;
      case SeventeenLiveSignal.reauthorize:
        unawaited(_reauthorize(generation));
    }
    // The backlog is over once a message published at the attach or later came.
    if (frame.entries.any((entry) => entry.publishedAt != null && !entry.replayed)) _backlogBefore = null;
    for (final entry in frame.entries) {
      if (_disposed || generation != _generation) return;
      // A message sent again after a resume, or twice: reported once.
      if (entry.id.isNotEmpty && !_firstSight(entry.id)) continue;
      // While the stream is paused (and in the figures that end the pause) the
      // viewers are 0; the last count stays (B-25).
      final paused = _muted == true || entry.muted == true;
      for (final message in entry.messages) {
        if (_disposed || generation != _generation) return;
        if (message.payload case final LiveAudienceUpdate update when update.value == 0 && paused) continue;
        _report(message);
      }
      if (entry.muted case final muted?) {
        if (_muteNotice(muted: muted, id: entry.id, replayed: entry.replayed) case final notice?) _report(notice);
      }
      if (entry.ended) {
        _terminate(seventeenLiveBroadcastEnded);
        return;
      }
    }
  }

  /// Attaches the room's channel: after an earlier attach of the session, from
  /// the last serial with the `ATTACH_RESUME` flag (ably-js).
  void _attach() {
    _attachPending = true;
    _send(SeventeenLiveDanmakuCodec.attach(args.roomId, channelSerial: _channelSerial, resume: _attachedBefore));
  }

  /// The server detached the channel: attach it again on this socket, as ably-js
  /// does; a detach while that attach is pending, or no answer within the join
  /// limit, drops the socket and the serial. A detach is a refusal: one too many
  /// ends the session.
  void _detached(SeventeenLiveAblyError? error) {
    if (++_refusals > SeventeenLiveDanmakuCodec.maxRefusals) {
      _terminate(error == null ? 'Channel detached' : 'Channel detached: $error');
      return;
    }
    if (_reattaching) {
      _channelSerial = null;
      _scheduleReconnect(_generation, 'channel detached again');
      return;
    }
    _reattaching = true;
    final sockets = _sockets;
    final generation = _generation;
    _reattachWatch = Timer(SeventeenLiveDanmakuCodec.joinTimeout, () {
      if ((_socket?.isConnected ?? false) && _generation == generation && _reattaching && _sockets == sockets) {
        _channelSerial = null;
        _scheduleReconnect(generation, 'reattach timed out');
      }
    });
    _attach();
  }

  /// The server refused the token: drop it (the next handshake asks a new one)
  /// and the socket, unless this is one refusal too many.
  void _tokenRefused(SeventeenLiveAblyError error) {
    _token = null;
    if (++_refusals > SeventeenLiveDanmakuCodec.maxRefusals) {
      _terminate('Token refused: $error');
      return;
    }
    _scheduleReconnect(_generation, 'token refused');
  }

  /// The server asked for a new token: ask `messenger/auth` and send it on the
  /// same socket. A failure is left to the server, which drops the socket with a
  /// token error when the old token lapses.
  Future<void> _reauthorize(int generation) async {
    final sockets = _sockets;
    final asked = await _renew(generation);
    if (asked != null) return;
    if (_disposed || generation != _generation || _sockets != sockets) return;
    _send(SeventeenLiveDanmakuCodec.reauthorize(_token!));
  }

  /// The key the next handshake resumes at [now], or null. A connection silent
  /// for longer than its `connectionStateTtl` + `maxIdleInterval` is forgotten
  /// with the channel's serial, as ably-js discards stale state and suspends the
  /// channel.
  String? _resumeKey(DateTime now) {
    final connection = _connection;
    final last = _lastActivity;
    if (connection == null || last == null) return null;
    if (now.difference(last) > connection.stateTtl + connection.maxIdleInterval) {
      _connection = null;
      _channelSerial = null;
      return null;
    }
    return connection.key;
  }

  /// Whether the message [id] is new in this session; remembers it.
  bool _firstSight(String id) {
    if (!_seen.add(id)) return false;
    if (_seen.length > maxSeen) _seen.remove(_seen.first);
    return true;
  }

  /// The notice for the live figures' `liveinfo.mute` being [muted], or null when
  /// it did not change (or is false the first time, which says nothing new).
  LiveMessage? _muteNotice({required bool muted, required String id, bool replayed = false}) {
    final before = _muted;
    _muted = muted;
    if (before == muted || (before == null && !muted)) return null;
    return SeventeenLiveDanmakuCodec.muteNotice(muted: muted, id: id, replayed: replayed);
  }

  /// A new socket: nothing attached, no attach pending, no backlog.
  void _socketReset() {
    _attachPending = false;
    _reattaching = false;
    _backlogBefore = null;
    _reattachWatch?.cancel();
    _reattachWatch = null;
  }

  /// A socket that closed, errored or went silent is replaced on the next host;
  /// [maxReconnectAttempts] failures in a row end the session.
  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: _reconnectFailures + 1));
      if (_disposed || staleGeneration != _generation) {
        _reconnecting = false;
        return;
      }
      _endpoint += 1;
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

  /// The chat is over: one system line says why, then the stream ends. Protocol
  /// refusals (an Ably error, a channel that will not attach, a stream that
  /// ended) are terminal here the way the reference's `run.closed` was.
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

  /// Stops delivery and leaves the token, the resume key and the channel serial
  /// for the next [connect].
  @override
  Future<void> disconnect() async {
    _generation++;
    _joined = false;
    _socketReset();
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _joined = false;
    _socketReset();
    _cancel.cancel();
    await _teardownSocket();
    unawaited(_events.close());
  }
}
