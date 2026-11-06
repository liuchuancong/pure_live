import 'dart:async';
import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_session_base.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/picarto/api/picarto_endpoints.dart';
import 'package:live_sites/src/platforms/picarto/danmaku/picarto_danmaku_codec.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for Picarto channels.
///
/// The session joins by the channel's name and numeric id, which the room
/// detail carries on the room's danmaku handle — so a session is built from
/// a fresh detail. Chat exists for offline channels too (it is only silent
/// there), so the handle is not the live state's business; a room id that is
/// no channel is reported not-found rather than joined empty.
final class PicartoDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the channel and asks for the
  /// chat tokens).
  PicartoDanmakuProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final PicartoDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! PicartoDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'channel ${room.roomId} opens no chat'));
      }
      args = handle;
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = PicartoDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'picarto';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef PicartoTimers = DanmakuTimers;

/// One comment connection: a chat token from the GraphQL API, then the chat
/// socket.
///
/// - A token is asked at every handshake, up to
///   [PicartoDanmakuCodec.tokenAttempts] times ([PicartoDanmakuCodec.tokenRetryDelay]
///   steps apart); without one the handshake is retried like any other
///   failed one. Tokens do not expire, so reconnects ask again, as the
///   site's client does.
/// - An open socket counts as joined (the server sends no welcome) within
///   [PicartoDanmakuCodec.joinTimeout]; the keep-alive goes out every
///   [PicartoDanmakuCodec.heartbeatInterval] and the server answers it, so a
///   socket silent for [PicartoDanmakuCodec.silenceTimeout] is replaced.
/// - A refused token (`JWT_TOKEN`) is replaced by a new one and the socket
///   reopened without a notice, at most
///   [PicartoDanmakuCodec.maxTokenRefreshes] times before the chat proves
///   itself (any other frame); a refusal that finds the budget spent ends
///   the session with a terminal system message.
/// - Chat, chip tips (as super chats), system, raid and subscription
///   notices, deleted and cleared messages (as retractions) and the audience
///   are reported ([PicartoDanmakuCodec.decode]).
/// - A socket that errors, closes or goes silent is reconnected;
///   [PicartoDanmakuCodec.maxReconnects] runs without an opened one end the
///   session with a terminal system message.
///
/// The run lifecycle — the generation the handshakes and their callbacks
/// guard with — is the shared base's ([DanmakuSessionBase]): every handshake
/// is one [DanmakuRun], and the base drops whatever a dead one reports.
final class PicartoDanmakuSession extends DanmakuSessionBase {
  /// The comments of [args]' channel over [site]. [timers] and [now] (the
  /// clock that dates a chip tip without a time) are injectable for tests.
  PicartoDanmakuSession({required this.args, required this.site, super.timers, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The channel this session joins.
  final PicartoDanmakuArgs args;

  /// The site its token requests and socket connections come from.
  final PicartoSite site;

  final DateTime Function() _now;

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  int _failures = 0;
  int _refreshes = 0;
  String _lastFailure = '';

  /// Opens the first socket; null once it is on its way, else why the
  /// channel has no chat to join.
  ///
  /// A failed handshake is retried like any later one (the reference's
  /// runtime did the same), so a failure starts the background retries
  /// instead of ending the session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (isDisposed) return const LiveSiteError.unsupported(siteId: picartoSiteId, message: 'session is disposed');
    if (!PicartoEndpoints.isChannelName(args.channelName.trim())) {
      return const LiveSiteError.notFound(siteId: picartoSiteId, message: 'not a Picarto channel');
    }
    unawaited(_handshake());
    return null;
  }

  Future<void> _handshake() async {
    if (isDisposed) return;
    final run = beginRun();
    await _teardownSocket();
    if (!run.isActive) return;
    final token = await _token(run);
    if (!run.isActive) return;
    if (token == null) {
      // The reference's runtime retried a run that got no token like any
      // other failed run.
      _scheduleRetry('chat token unavailable: $_lastFailure', run);
      return;
    }
    // The join budget bounds the handshake: an open socket counts as
    // joined, so a socket that never opens is replaced within it.
    _join = timers.after(PicartoDanmakuCodec.joinTimeout, () {
      if (!run.isActive || run.isJoined) return;
      _scheduleRetry('no chat within ${PicartoDanmakuCodec.joinTimeout.inSeconds} s', run);
    });
    final SocketChannel socket;
    try {
      socket = await site.connect(
        PicartoDanmakuCodec.endpoint(token),
        headers: PicartoDanmakuCodec.handshakeHeaders,
        protocols: null,
        connectTimeout: PicartoDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed('$error', run);
      return;
    }
    if (!run.isActive) {
      try {
        await socket.close();
      } on Object {
        // Already closed or broken.
      }
      return;
    }
    _socket = socket;
    run.joined();
    _join?.cancel();
    _join = null;
    _failures = 0;
    _startHeartbeat();
    _startWatchdog(run);
    _subscription = socket.stream.listen(
      (data) {
        if (run.isActive) _onData(data, run);
      },
      onDone: () {
        if (run.isActive) _scheduleRetry('socket closed', run);
      },
      onError: (Object error) {
        if (run.isActive) _scheduleRetry('$error', run);
      },
    );
  }

  /// A token for the channel: up to [PicartoDanmakuCodec.tokenAttempts]
  /// requests, or null when none gave one or the session moved on.
  Future<String?> _token(DanmakuRun run) async {
    for (var attempt = 0; attempt < PicartoDanmakuCodec.tokenAttempts; attempt++) {
      if (attempt > 0) {
        await _delay(PicartoDanmakuCodec.tokenRetryDelay * attempt);
        if (!run.isActive) return null;
      }
      try {
        final answer = await site.http.postJson(
          PicartoEndpoints.tokenUrl(),
          body: PicartoDanmakuCodec.tokenBody(args.channelName.trim()),
          timeout: PicartoDanmakuCodec.tokenTimeout,
        );
        final token = PicartoDanmakuCodec.token(answer.json);
        if (token != null) return token;
        _lastFailure = 'no chat token (HTTP ${answer.status})';
      } on Object catch (error) {
        if (!run.isActive) return null;
        _lastFailure = '$error';
      }
    }
    return null;
  }

  /// A pause the test's clock keeps: the completer completes when its timer
  /// is fired, and a disposed session's timer never fires.
  Future<void> _delay(Duration delay) async {
    final done = Completer<void>();
    timers.after(delay, done.complete);
    await done.future;
  }

  void _onData(Object? data, DanmakuRun run) {
    _startWatchdog(run);
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return;
    final frame = PicartoDanmakuCodec.decode(
      text,
      channelId: args.channelId,
      channelName: args.channelName,
      now: _now(),
    );
    if (frame.tokenRefused) {
      _refused(run);
      return;
    }
    // The server answered a frame it only answers for a good token: the
    // refresh budget starts over.
    _refreshes = 0;
    for (final message in frame.messages) {
      if (!run.isActive) return;
      run.message(message);
    }
  }

  /// A refused token: the socket is replaced with a fresh token's, without a
  /// notice; the refusal after the last refresh ends the session.
  void _refused(DanmakuRun run) {
    if (_refreshes >= PicartoDanmakuCodec.maxTokenRefreshes) {
      _terminate('chat token refused', run);
      return;
    }
    _refreshes += 1;
    unawaited(_handshake());
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = timers.every(PicartoDanmakuCodec.heartbeatInterval, (_) {
      if (!isDisposed) _send(PicartoDanmakuCodec.heartbeat);
    });
  }

  void _startWatchdog(DanmakuRun run) {
    _watchdog?.cancel();
    _watchdog = timers.after(PicartoDanmakuCodec.silenceTimeout, () {
      if (run.isActive) _scheduleRetry('socket silent', run);
    });
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(frame);
    } on Object {
      // The retry path owns a broken socket.
    }
  }

  /// A handshake that did not come to a socket: counted, and retried after
  /// the backoff's step; the budget's end is told once and closes the
  /// stream.
  void _failed(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    _scheduleRetry(reason, run);
  }

  /// The socket is to be replaced after the backoff's step;
  /// [PicartoDanmakuCodec.maxReconnects] runs without an opened one end the
  /// session.
  void _scheduleRetry(String reason, DanmakuRun run) {
    _cancelTimers();
    if (!run.isActive) return;
    _failures += 1;
    if (_failures > PicartoDanmakuCodec.maxReconnects) {
      _terminate(reason, run);
      return;
    }
    run.reconnecting(reason);
    _retry = timers.after(PicartoDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (!run.isActive) return;
      unawaited(_handshake());
    });
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason, DanmakuRun run) {
    if (!run.isActive) return;
    run
      ..exhausted(reason)
      ..message(
        LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white, sentAt: _now()),
      );
    unawaited(dispose());
  }

  void _cancelTimers() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _join?.cancel();
    _join = null;
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    await _subscription?.cancel();
    _subscription = null;
    _socket = null;
    try {
      await socket?.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// Releases the transport and the protocol timers; safe when nothing is
  /// open.
  @override
  Future<void> stop() async {
    _cancelTimers();
    await _teardownSocket();
  }
}
