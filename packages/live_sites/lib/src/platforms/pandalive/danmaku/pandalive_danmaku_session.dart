import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/pandalive/danmaku/pandalive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/pandalive/pandalive_site.dart';
import 'package:live_sites/src/platforms/pandalive/parsers/pandalive_failure.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for PandaTV broadcasts.
///
/// The session joins with the guest token of the broadcast's `live/play`,
/// which the room detail carries on the room's danmaku handle — so a session
/// is built from a fresh detail. A room that is not live (ended, adult,
/// password, fans only, offline) has no handle and is reported
/// content-unavailable rather than joined empty.
final class PandaliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which re-asks `live/play` for tokens).
  PandaliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final PandaliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final PandaliveDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! PandaliveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on PandaliveFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = PandaliveDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'pandalive';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef PandaliveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: one socket to the Centrifugo server per broadcast.
///
/// - The first handshake uses the token room entry brought
///   ([PandaliveDanmakuArgs.token]) unless it lapses within a minute; every
///   other handshake first asks `live/play` again for a new token and
///   channel, as the website does on every visit. A request that fails counts
///   as a failed handshake; a refusal (the broadcast ended, adult, password,
///   fans only) ends the session with a terminal system message.
/// - At every open it sends connect and subscribe; the subscription's reply
///   joins, within [PandaliveDanmakuCodec.joinTimeout], or the socket is
///   replaced. A refused connect or subscription reconnects,
///   [PandaliveDanmakuCodec.maxRefusals] refusals in a row end the session.
/// - A joined socket is renewed quietly a minute before its token lapses
///   (the connect reply's `ttl`, 30 minutes): a new token, then a new
///   socket, with no second join notice. A renewal failure counts like any
///   other broken run.
/// - Command 7 pings every [PandaliveDanmakuCodec.heartbeatInterval]; the
///   server answers each, so a socket silent for
///   [PandaliveDanmakuCodec.silenceTimeout] is replaced.
/// - [PandaliveDanmakuCodec.maxReconnects] runs without a joined one end the
///   session the same way, with a terminal system message.
/// - Chat and hearts are reported.
final class PandaliveDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [site]. [timers] and [now] are
  /// injectable for tests.
  PandaliveDanmakuSession({required this.args, required this.site, PandaliveTimers? timers, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The broadcast this session joins.
  final PandaliveDanmakuArgs args;

  /// The site its sockets come from and which re-asks `live/play` for
  /// tokens.
  final PandaliveSite site;

  static const String _site = 'pandalive';

  final DateTime Function() _now;
  final PandaliveTimers _timers;

  final _events = StreamController<LiveMessage>.broadcast();

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  Timer? _renewal;
  String _channel = '';
  String? _token;
  bool _fresh = false;
  bool _joined = false;
  int _commandId = PandaliveDanmakuCodec.subscribeId;
  int _refusals = 0;
  int _failures = 0;
  int _generation = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the first socket; null once it is on its way, else why the
  /// broadcast has no chat to join.
  ///
  /// A failed first handshake is retried like any later one, so a failure
  /// starts the background retries instead of ending the session, and this
  /// returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: _site, message: 'session is disposed');
    }
    final checked = PandaliveDanmakuCodec.checked(args);
    if (checked == null) {
      return LiveSiteError.notFound(siteId: _site, message: 'not a PandaTV broadcast: ${args.userId}');
    }
    _channel = checked.channel;
    _token = checked.token;
    _fresh = checked.token != null;
    unawaited(_handshake());
    return null;
  }

  /// Whether [_token] has not been sent yet and does not lapse within
  /// [PandaliveDanmakuCodec.renewalLead].
  bool get _tokenUsable {
    final token = _token;
    if (token == null || !_fresh) return false;
    final expiry = PandaliveDanmakuCodec.tokenExpiry(token);
    return expiry == null || expiry.difference(_now()) > PandaliveDanmakuCodec.renewalLead;
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final generation = ++_generation;
    await _teardownSocket();
    if (_disposed || generation != _generation) return;
    _joined = false;
    if (!_tokenUsable) {
      try {
        final grant = await site.chatGrant(args.userId);
        if (_disposed || generation != _generation) return;
        _channel = grant.channel;
        _token = grant.token;
        _fresh = true;
      } on PandaliveChatRefusal catch (refusal) {
        _terminate('live/play refused the chat: $refusal');
        return;
      } on PandaliveFailure catch (failure) {
        _failed('$failure', generation);
        return;
      } on Object catch (error) {
        _failed('$error', generation);
        return;
      }
    }
    final SocketChannel socket;
    try {
      socket = await site.connect(
        PandaliveDanmakuCodec.endpoint,
        headers: PandaliveDanmakuCodec.socketHeaders,
        protocols: null,
        connectTimeout: PandaliveDanmakuCodec.silenceTimeout,
      );
    } on Object catch (error) {
      _failed('$error', generation);
      return;
    }
    if (_disposed || generation != _generation) {
      await _closeSocket(socket);
      return;
    }
    _socket = socket;
    _fresh = false;
    _commandId = PandaliveDanmakuCodec.subscribeId;
    _startHeartbeat();
    _startWatchdog();
    _join = _timers.after(PandaliveDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) {
        _scheduleRetry('no join within ${PandaliveDanmakuCodec.joinTimeout.inSeconds} s');
      }
    });
    _send(PandaliveDanmakuCodec.connect(_token!));
    _send(PandaliveDanmakuCodec.subscribe(_channel));
    _subscription = socket.stream.listen(
      (data) {
        if (generation == _generation && !_disposed) _onData(data);
      },
      onDone: () {
        if (generation == _generation && !_disposed) _scheduleRetry('socket closed');
      },
      onError: (Object error) {
        if (generation == _generation && !_disposed) _scheduleRetry('$error');
      },
    );
  }

  /// A handshake that did not come to live: counted, and retried after the
  /// backoff's step; the budget's end is told once and closes the stream.
  void _failed(String reason, int generation) {
    if (generation != _generation || _disposed) return;
    _scheduleRetry(reason);
  }

  void _onData(Object? data) {
    _startWatchdog();
    final frame = PandaliveDanmakuCodec.decode(data, channel: _channel);
    if (frame.refusal case final refusal?) {
      _refused(refusal);
      return;
    }
    if (frame.expiresIn case final ttl?) {
      _renewal?.cancel();
      _renewal = _timers.after(PandaliveDanmakuCodec.renewalDelay(ttl), () {
        if (!_disposed) unawaited(_handshake());
      });
    }
    if (frame.joined && !_joined) {
      _joined = true;
      _join?.cancel();
      _join = null;
      _refusals = 0;
      _failures = 0;
    }
    for (final message in frame.messages) {
      if (_disposed) return;
      _report(message);
    }
  }

  /// A refused join: the socket is replaced; the refusal after the last
  /// retry ends the session.
  void _refused(String refusal) {
    _refusals += 1;
    if (_refusals > PandaliveDanmakuCodec.maxRefusals) {
      _terminate('chat refused: $refusal');
      return;
    }
    _scheduleRetry('chat refused: $refusal');
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(PandaliveDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(PandaliveDanmakuCodec.ping(++_commandId));
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(PandaliveDanmakuCodec.silenceTimeout, () {
      if (!_disposed) _scheduleRetry('socket silent');
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

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _events.add(
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
    _renewal?.cancel();
    _renewal = null;
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    await _subscription?.cancel();
    _subscription = null;
    _socket = null;
    await _closeSocket(socket);
  }

  Future<void> _closeSocket(SocketChannel? socket) async {
    try {
      await socket?.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// The socket is to be replaced after the backoff's step;
  /// [PandaliveDanmakuCodec.maxReconnects] runs without a joined one end the
  /// session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _failures += 1;
    if (_failures > PandaliveDanmakuCodec.maxReconnects) {
      _terminate(reason);
      return;
    }
    final generation = _generation;
    _retry = _timers.after(PandaliveDanmakuCodec.reconnectBaseDelay * _failures, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
  }

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _generation += 1;
    _cancelTimers();
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    await _teardownSocket();
    await _events.close();
  }
}
