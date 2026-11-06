import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/danmaku/xiaohongshu_danmaku_codec.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_guest.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own.
typedef XiaohongshuDanmakuTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One read-only chat connection: the RWP socket of one broadcast, over a
/// [XiaohongshuGuest] bootstrap and a [SocketChannel].
///
/// - The bootstrap asks the visitor session for a push identity once per
///   connect run; a refused answer ends the connect, and normal reconnects
///   reuse the identity they were opened with. Browser resources are
///   released before the socket starts (the guest owns them); the identity
///   is never logged or stored.
/// - Every socket runs the three-step bootstrap — guest handshake, room
///   service register, broadcast subscribe — each step answered by an
///   acknowledgement carrying the id the request sent; the whole sequence
///   must finish within [joinTimeout] or the socket is replaced. Only the
///   room JSON service is registered, and exactly one broadcast is joined;
///   no chat is ever posted.
/// - A handshake refused (`c` other than 0) renews the identity once —
///   `refresh: true` — and starts over on a fresh socket; a second refusal,
///   or a refusal of the register or subscribe step, ends the session
///   instead of bootstrapping forever. A completed bootstrap clears the
///   renewal budget again.
/// - The beat every [heartbeatInterval] while the socket is up sends the
///   transport ping, the control ping and the viewing heart (no chat
///   content); there is no silence watchdog, the push service answering the
///   pings itself.
/// - A socket that errors or closes is replaced after a one-second step per
///   failure in a row, [maxReconnectAttempts] of them ending the session.
///   Chat ids already shown are dropped across reconnects
///   ([XiaohongshuDanmakuCodec.maxSeenMessages] remembered); a new connect
///   run forgets them.
final class XiaohongshuDanmakuSession implements LiveDanmakuSession {
  /// The chat of [args]' broadcast for [guest]'s visitor identity, sockets
  /// opened by [connector]. [timers] is injectable for tests.
  XiaohongshuDanmakuSession({
    required this.args,
    required this.guest,
    SocketConnector? connector,
    XiaohongshuDanmakuTimers? timers,
  }) : _connector = connector ?? webSocketConnect,
       _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The broadcast this session subscribes to.
  final XiaohongshuDanmakuArgs args;

  /// The visitor bootstrap the identity and its renewal come from.
  final XiaohongshuGuest guest;

  /// How the chat's socket is connected.
  final SocketConnector _connector;

  final XiaohongshuDanmakuTimers _timers;

  /// Beat period (the reference's `heartbeatInterval`).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long the bootstrap may take per socket (the reference's
  /// `joinTimeout`).
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Opening one socket's budget.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Failed reconnects in a row before the session is abandoned.
  static const int maxReconnectAttempts = 8;

  final _events = StreamController<LiveMessage>.broadcast();
  final Set<String> _seen = {};

  SocketChannel? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _beat;
  Timer? _join;
  Timer? _retry;
  XiaohongshuPushIdentity? _identity;
  CancelToken? _cancel;
  int _generation = 0;
  int _socketEpoch = 0;
  int _serial = 0;
  int _step = 0;
  int _renewals = 0;
  int _reconnectFailures = 0;
  String _expected = '';
  bool _channelLive = false;
  bool _disposed = false;
  bool _joined = false;
  bool _reconnecting = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Asks for the visitor identity and opens the first socket; null once it
  /// is on its way, else why chat could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: xiaohongshuSiteId, message: 'session is disposed');
    }
    if (!XiaohongshuEndpoints.isRoomId(args.roomId)) {
      return LiveSiteError.notFound(
        siteId: xiaohongshuSiteId,
        message: 'room "${args.roomId}" is not a Xiaohongshu room',
      );
    }
    _seen.clear();
    _reconnectFailures = 0;
    final generation = ++_generation;
    final cancel = _cancel = CancelToken();
    final XiaohongshuPushIdentity identity;
    try {
      identity = await guest.pushIdentity(args.roomId, cancel: cancel);
    } on Object catch (error) {
      return LiveSiteError.authentication(
        siteId: xiaohongshuSiteId,
        message: 'the visitor bootstrap gave no push identity (${_causeOf(error)})',
      );
    }
    if (generation != _generation || _disposed || cancel.isCancelled) {
      return const LiveSiteError.unsupported(siteId: xiaohongshuSiteId, message: 'session is disposed');
    }
    _identity = identity;
    return await _open(generation, identity);
  }

  /// Opens one socket for [identity]: the channel, its subscriptions, the
  /// beat, the bootstrap watch, and the handshake as soon as it is up; null
  /// when the socket came up, else why it did not. Each open is one socket
  /// epoch, so a retry armed for a superseded socket finds itself stale.
  Future<LiveSiteError?> _open(int generation, XiaohongshuPushIdentity identity) async {
    final epoch = ++_socketEpoch;
    _joined = false;
    _step = 0;
    _channelLive = false;
    await _teardownSocket();
    if (generation != _generation || _disposed) return null;
    final SocketChannel socket;
    try {
      socket = await _connector(
        XiaohongshuDanmakuCodec.endpoint,
        headers: XiaohongshuDanmakuCodec.handshakeHeaders(identity),
        protocols: null,
        connectTimeout: connectTimeout,
      );
    } on Object catch (error) {
      return LiveSiteError.network(
        siteId: xiaohongshuSiteId,
        message: 'push socket failed on ${XiaohongshuDanmakuCodec.endpoint}: $error',
        cause: error,
      );
    }
    if (generation != _generation || epoch != _socketEpoch || _disposed) {
      unawaited(socket.close());
      return null;
    }
    _socket = socket;
    _channelLive = true;
    _startBeat();
    _subscription = socket.stream.listen(
      (data) {
        if (epoch == _socketEpoch && !_disposed) _onData(data);
      },
      onDone: () {
        _channelLive = false;
        if (epoch == _socketEpoch && generation == _generation && !_disposed) _scheduleReconnect('socket closed');
      },
      onError: (Object error) {
        _channelLive = false;
        if (epoch == _socketEpoch && generation == _generation && !_disposed) _scheduleReconnect('$error');
      },
    );
    _expected = _nextId();
    _join = _timers.after(joinTimeout, () {
      if (epoch == _socketEpoch && generation == _generation && !_disposed && !_joined) {
        _scheduleReconnect('bootstrap did not finish');
      }
    });
    _send(XiaohongshuDanmakuCodec.handshake(_expected, identity));
    return null;
  }

  void _onData(Object? data) {
    final frame = XiaohongshuDanmakuCodec.envelope(data);
    if (frame == null) return;
    if (frame['t'] == 2 && frame['m'] == _expected) {
      final code = XiaohongshuDanmakuCodec.ackCode(frame);
      if (code == null) return;
      if (code != 0) {
        _refused();
        return;
      }
      _expected = _nextId();
      if (_step == 0) {
        _step = 1;
        _send(XiaohongshuDanmakuCodec.register(_expected));
      } else if (_step == 1) {
        _step = 2;
        _send(XiaohongshuDanmakuCodec.join(_expected, args.roomId));
      } else if (_step == 2) {
        _step = 3;
        _renewals = 0;
        _reconnectFailures = 0;
        _joined = true;
        _join?.cancel();
        _join = null;
        _send(XiaohongshuDanmakuCodec.viewerHeart(_nextId(), args.roomId, _identity?.uid ?? ''));
      }
      return;
    }
    for (final message in XiaohongshuDanmakuCodec.messages(frame, args.roomId)) {
      if (message.type == LiveMessageType.chat && message.messageId.isNotEmpty) {
        if (!_seen.add(message.messageId)) continue;
        if (_seen.length > XiaohongshuDanmakuCodec.maxSeenMessages) _seen.remove(_seen.first);
      }
      _report(message);
    }
  }

  /// A refused step: the handshake's first refusal renews the identity once
  /// and starts over; anything else ends the session.
  void _refused() {
    _join?.cancel();
    _join = null;
    if (_step == 0 && _renewals++ == 0) {
      _step = -1;
      _expected = '';
      unawaited(_renew());
      return;
    }
    _terminate('push credentials unavailable');
  }

  /// A fresh identity (`refresh: true`) and a fresh socket, within the same
  /// session; a refused renewal ends it.
  Future<void> _renew() async {
    final generation = _generation;
    final cancel = _cancel;
    final XiaohongshuPushIdentity identity;
    try {
      identity = await guest.pushIdentity(args.roomId, refresh: true, cancel: cancel);
    } on Object catch (error) {
      _terminate('push credentials unavailable (${_causeOf(error)})');
      return;
    }
    if (generation != _generation || _disposed || (cancel?.isCancelled ?? false)) return;
    _identity = identity;
    final failure = await _open(generation, identity);
    if (failure != null && generation == _generation && !_disposed) _terminate(failure.message);
  }

  void _startBeat() {
    _beat?.cancel();
    _beat = _timers.every(heartbeatInterval, (_) {
      if (_disposed || !_channelLive) return;
      _send(XiaohongshuDanmakuCodec.control(_nextId(), 6, {}));
      _send(XiaohongshuDanmakuCodec.viewerHeart(_nextId(), args.roomId, _identity?.uid ?? ''));
      _send(XiaohongshuDanmakuCodec.transportHeartbeat);
    });
  }

  /// The socket is replaced after a one-second step per failure in a row;
  /// [maxReconnectAttempts] runs without a joined one end the session. The
  /// visitor identity in use is kept, as the reference's normal reconnects
  /// keep theirs. A retry armed for a socket that has since been superseded
  /// finds itself stale and does nothing.
  void _scheduleReconnect(String reason) {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    final generation = _generation;
    final epoch = _socketEpoch;
    _retry = _timers.after(Duration(seconds: _reconnectFailures + 1), () {
      _retry = null;
      unawaited(() async {
        if (_disposed || generation != _generation || epoch != _socketEpoch) {
          _reconnecting = false;
          return;
        }
        final identity = _identity;
        if (identity == null) {
          _reconnecting = false;
          return;
        }
        final failure = await _open(generation, identity);
        _reconnecting = false;
        if (_disposed || generation != _generation) return;
        if (failure == null) return;
        _reconnectFailures += 1;
        if (_reconnectFailures >= maxReconnectAttempts) {
          _terminate('$reason: ${failure.message}');
          return;
        }
        _scheduleReconnect(reason);
      }());
    });
  }

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  void _send(String frame) {
    final socket = _socket;
    if (socket == null || !_channelLive) return;
    try {
      socket.add(frame);
    } on Object {
      // The reconnect path owns a broken socket.
    }
  }

  String _nextId() => 'pl-${DateTime.now().microsecondsSinceEpoch}-${_serial++}';

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing reconnects afterwards.
  void _terminate(String reason) {
    _cancelTimers();
    _generation++;
    _joined = false;
    _cancel?.cancel();
    unawaited(_teardownSocket());
    if (_disposed) return;
    _events.add(
      LiveMessage.normalized(
        type: LiveMessageType.system,
        text: 'Danmaku connection lost ($reason)',
        color: LiveMessageColor.white,
      ),
    );
    unawaited(_events.close());
  }

  void _cancelTimers() {
    _beat?.cancel();
    _beat = null;
    _join?.cancel();
    _join = null;
    _retry?.cancel();
    _retry = null;
  }

  Future<void> _teardownSocket() async {
    _channelLive = false;
    await _subscription?.cancel();
    _subscription = null;
    final socket = _socket;
    _socket = null;
    try {
      await socket?.close();
    } on Object {
      // Already closed or broken.
    }
  }

  /// Stops delivery, leaving the session able to [connect] again; an
  /// in-flight bootstrap request is cancelled with the run it belonged to.
  @override
  Future<void> disconnect() async {
    _generation++;
    _joined = false;
    _cancelTimers();
    _cancel?.cancel();
    _cancel = null;
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _joined = false;
    _cancelTimers();
    _cancel?.cancel();
    _cancel = null;
    await _teardownSocket();
    await _events.close();
  }

  /// What a swallowed bootstrap failure may say: the fixed failure texts
  /// carry no page content or credentials, and an unexpected error names
  /// its type alone.
  static String _causeOf(Object error) => switch (error) {
    TransportFailure() || XiaohongshuFailure() => error.toString(),
    _ => error.runtimeType.toString(),
  };
}
