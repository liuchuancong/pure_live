import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/api/fc2live_endpoints.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_control.dart';
import 'package:live_sites/src/platforms/fc2live/danmaku/fc2live_danmaku_codec.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_play_parser.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_room_parser.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for FC2 Live channels.
///
/// Comments travel on a media-control socket of their own, so a session is
/// built from a room that names its channel: the room's danmaku handle is that
/// number, and every handshake the session makes takes its own fresh grant for
/// it. A room id that is not a channel is not-found, and a channel the site
/// will not grant — gone, offline, restricted, or answering what cannot be read
/// — is reported rather than joined empty.
final class Fc2LiveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site], which resolves the room and its grants.
  Fc2LiveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final Fc2LiveDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! Fc2LiveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: _site, message: 'room ${room.roomId} names no channel'));
      }
      args = handle;
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = Fc2LiveDanmakuSession(args: args, site: site);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }

  static const String _site = 'fc2live';
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a test's
/// own, so that a heartbeat, a join timeout and a backoff step can be read out
/// of a connection without waiting for the site's minute-long patience.
typedef Fc2LiveTimers = ({
  Timer Function(Duration delay, void Function() callback) after,
  Timer Function(Duration period, void Function(Timer timer) callback) every,
});

/// One comment connection: a fresh grant and the control socket it authorizes.
///
/// - The first grant decides whether the session starts at all: a channel that
///   does not exist, is not on air, is restricted, or answers something that
///   cannot be read ends it there (asking again would not mend it), while a
///   network breakdown or a throttle only fails this handshake and is retried —
///   a streamer who drops out briefly is joined again.
/// - Every handshake takes its own grant: one grant is good for one socket, for
///   about [Fc2LiveEndpoints.controlLife]. The socket keeps the site's own
///   WebSocket ping.
/// - The room is joined at `connect_complete`, and a socket that never says it
///   within [Fc2LiveDanmakuCodec.joinTimeout] is replaced.
/// - The page's heartbeat goes out every
///   [Fc2LiveDanmakuCodec.heartbeatInterval] from each open, with ids counting
///   up through the connection; an answered heartbeat is the proof that the
///   socket is really the site's, and it restarts the count of replacements.
/// - `control_disconnection` (4500 is a grant that expired) and a socket that
///   errors, closes or goes silent are replaced after the backoff's step;
///   `move_server`, which the site uses to hand a viewer to another node, is
///   followed at once and quietly, as the page follows it. After
///   [Fc2LiveDanmakuCodec.maxReconnects] replacements without an answered
///   heartbeat a terminal system message closes [events].
/// - The filters the site pushes (`ng_comment`) hide the comments it would hide
///   itself, and are kept across the run's sockets, each of which sends them
///   again.
/// - Nothing reported names a grant's token or cookie.
final class Fc2LiveDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' channel over [site].
  Fc2LiveDanmakuSession({required this.args, required this.site, Fc2LiveTimers? timers, DateTime Function()? now})
    : _now = now ?? DateTime.now,
      _timers = timers ?? (after: Timer.new, every: Timer.periodic);

  /// The channel this session joins.
  final Fc2LiveDanmakuArgs args;

  /// The site its grants come from.
  final Fc2LiveSite site;

  final DateTime Function() _now;
  final Fc2LiveTimers _timers;

  final _events = StreamController<LiveMessage>.broadcast();
  final Fc2LiveAudience _audience = Fc2LiveAudience();
  final Fc2LiveNgList _ng = Fc2LiveNgList();

  Fc2LiveSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  Timer? _retry;
  CancelToken? _grant;
  int _generation = 0;
  int _nextHeartbeatId = 1;
  int _unconfirmed = 0;
  bool _joined = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Takes the first grant and opens the first socket; null once one of them is
  /// on its way to being joined, else why the channel has no chat to join.
  ///
  /// A grant that fails for a reason asking again will not mend ends the
  /// session; a network breakdown or a throttle starts the background retries
  /// instead, and this returns null, because the reference's runtime retried
  /// the first handshake exactly like any later one.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: fc2LiveSiteId, message: 'session is disposed');
    if (!Fc2LiveEndpoints.isChannelId(args.channelId)) {
      return const LiveSiteError.notFound(siteId: fc2LiveSiteId, message: 'not an FC2 channel');
    }
    final Fc2LiveGrant grant;
    try {
      grant = await _grantRequest();
    } on CancelledFailure {
      // Torn down while asking: the closer owns the goodbye.
      return null;
    } on Fc2LiveFailure catch (failure) {
      if (!failure.isTransient) return failure.toLiveSiteError(fc2LiveSiteId);
      _scheduleRetry(failure.message);
      return null;
    }
    return await _openSocket(grant);
  }

  Future<LiveSiteError?> _openSocket(Fc2LiveGrant grant) async {
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    if (_disposed) return null;
    final Fc2LiveSocket socket;
    try {
      socket = await site.connect(
        grant.endpoint,
        headers: grant.handshakeHeaders,
        protocols: null,
        connectTimeout: Fc2LiveEndpoints.connectTimeout,
      );
    } on Object catch (error) {
      final reason = Fc2LiveDanmakuCodec.redact('$error');
      if (generation != _generation || _disposed) return null;
      _scheduleRetry(reason);
      return null;
    }
    if (_disposed || generation != _generation) {
      // Disposed or replaced while the handshake was in flight: close what we
      // just opened instead of parking it on a dead generation.
      try {
        await socket.close();
      } on Object {
        // Already closed or broken.
      }
      return null;
    }
    _socket = socket;
    _subscription = socket.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        _onData(data, generation);
      },
      onDone: () {
        if (generation == _generation && !_disposed) _scheduleRetry('socket closed${_closeOf(socket)}');
      },
      onError: (Object error) {
        if (generation == _generation && !_disposed) _scheduleRetry(Fc2LiveDanmakuCodec.redact('$error'));
      },
    );
    _join = _timers.after(Fc2LiveDanmakuCodec.joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) _scheduleRetry('no connect_complete in time');
    });
    _startHeartbeat();
    _startWatchdog();
    return null;
  }

  String _closeOf(Fc2LiveSocket socket) => socket.closeCode == null ? '' : ' (${socket.closeCode})';

  void _onData(Object? data, int generation) {
    if (generation != _generation || _disposed) return;
    _startWatchdog();
    final frame = Fc2LiveDanmakuCodec.decode(data);
    if (frame == null) return;
    switch (frame.name) {
      case 'connect_complete':
        if (!_joined) {
          _joined = true;
          _join?.cancel();
          _join = null;
        }
      case 'ng_comment':
        _ng.apply(frame.arguments);
      case 'comment':
        Fc2LiveDanmakuCodec.comments(frame.arguments, ng: _ng).forEach(_report);
      case 'user_count':
        _audience.update(frame.arguments).forEach(_report);
      case '_response_' when frame.arguments['status'] == 0:
        // The page's heartbeat was answered: this socket is the site's own.
        _unconfirmed = 0;
      case 'control_disconnection':
        final code = frame.arguments['code'];
        _scheduleRetry('control_disconnection${code is int ? ' $code' : ''}');
      case 'move_server':
        // The site hands the viewer to another node; the page follows at once.
        _renewNow();
      // `initial_connect`, `connect_data`, `video_information`,
      // `point_information` and the rest carry nothing to show.
    }
  }

  /// A socket to be replaced after the backoff's step: [Fc2LiveDanmakuCodec.maxReconnects]
  /// of them without an answered heartbeat end the session.
  void _scheduleRetry(String reason) {
    _cancelTimers();
    if (_disposed) return;
    _unconfirmed += 1;
    if (_unconfirmed > Fc2LiveDanmakuCodec.maxReconnects) {
      _terminate('Chat connection lost ($reason)');
      return;
    }
    final generation = _generation;
    _retry = _timers.after(Fc2LiveDanmakuCodec.reconnectBaseDelay * _unconfirmed, () {
      if (generation != _generation || _disposed) return;
      unawaited(_handshake());
    });
  }

  /// A socket to be replaced at once (the site's own `move_server`): no
  /// backoff wait, but still counted against the reconnect budget — a node that
  /// ping-pongs this session between servers would otherwise reopen forever.
  void _renewNow() {
    _cancelTimers();
    if (_disposed) return;
    _unconfirmed += 1;
    if (_unconfirmed > Fc2LiveDanmakuCodec.maxReconnects) {
      _terminate('Chat connection lost (the site kept moving this session)');
      return;
    }
    unawaited(_handshake());
  }

  Future<void> _handshake() async {
    if (_disposed) return;
    final Fc2LiveGrant grant;
    try {
      grant = await _grantRequest();
    } on CancelledFailure {
      return;
    } on Fc2LiveFailure catch (failure) {
      // A channel that has become unplayable mid-run is not worth asking about
      // again; a breakdown is retried on the next step.
      if (!failure.isTransient) {
        _terminate(failure.message);
        return;
      }
      _scheduleRetry(failure.message);
      return;
    }
    await _openSocket(grant);
  }

  /// Takes the grant of the handshake under way: a request the session can
  /// cancel when it is closed while its two calls are still in flight, instead
  /// of leaving them to answer into a dead generation.
  Future<Fc2LiveGrant> _grantRequest() {
    final cancel = CancelToken();
    _grant = cancel;
    return site.controlGrant(args.channelId, cancel: cancel).whenComplete(() {
      if (identical(_grant, cancel)) _grant = null;
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = _timers.every(Fc2LiveDanmakuCodec.heartbeatInterval, (_) {
      if (!_disposed) _send(Fc2LiveDanmakuCodec.heartbeat(_nextHeartbeatId++));
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = _timers.after(Fc2LiveDanmakuCodec.inactivityTimeout, () {
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

  /// The session is over: the reason is told once, as a system message, and the
  /// stream closes; nothing reconnects afterwards.
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

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _generation += 1;
    _cancelTimers();
    _grant?.cancel();
    _grant = null;
    await _teardownSocket();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _cancelTimers();
    _grant?.cancel();
    _grant = null;
    await _teardownSocket();
    await _events.close();
  }
}
