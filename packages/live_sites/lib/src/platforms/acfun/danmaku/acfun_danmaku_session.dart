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
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for AcFun's link chat.
///
/// The room detail carries the arguments (the visitor session, the tickets and
/// the `enterRoomAttach` of the same `startPlay` that gave the streams), so a
/// session is built from a fresh detail; a room with no live broadcast has no
/// handle and is reported content-unavailable rather than joined empty.
final class AcfunDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  AcfunDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the room detail and of the
  /// session refresh.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final AcfunDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! AcfunDanmakuArgs) {
        return left(
          LiveSiteError.contentUnavailable(siteId: acfunSiteId, message: 'room $roomId names no live broadcast'),
        );
      }
      args = handle;
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
    final session = AcfunDanmakuSession(args: args);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection over AcFun's link WebSocket.
///
/// [DanmakuSocket] (the shared live_websocket transport) owns the socket
/// lifecycle — it connects, forwards every frame to the session's frame handler
/// and reports a socket that is not coming back through its lost handler. This
/// protocol drives its own reconnection rather than the transport's automatic
/// one, because a dead socket is replaced by re-running the register handshake
/// (and sometimes with fresh arguments), which the transport cannot know; its
/// automatic reconnect is therefore switched off and [silenceTimeout] and the
/// join budget are watched here, not by a transport heartbeat.
///
/// - At every open: `Basic.Register` sealed with `acSecurity`; the answer
///   brings the session key every later payload is sealed with. Then a
///   keep-alive and the enter-room command, whose answer is the join — no
///   answer within [joinTimeout] replaces the socket, and a second timeout in a
///   row refreshes the arguments as well.
/// - A room heartbeat every [heartbeatInterval], a keep-alive with every fifth
///   one, and every push acknowledged. A socket silent for
///   [silenceTimeout] is replaced.
/// - A dead ticket (`ZtLiveScTicketInvalid`, or an enter-room answer with one of
///   [AcfunDanmakuProtocol.ticketErrors]) moves to the next ticket on the same
///   socket, as the web client does. Once every ticket has failed since the
///   join, a refused register or command, or a broadcast that closed, reopened
///   or was banned, refreshes the arguments and reopens with them.
///   [maxRefreshes] refreshes without a join ends the session with a terminal
///   system message instead of retrying forever.
/// - The room's gift table is asked for once in the background; gifts before it
///   comes, or without it, carry only their ids.
final class AcfunDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args]; [connect] opens the socket.
  AcfunDanmakuSession({required this.args, DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  /// The room heartbeat the enter-room answer names.
  static const Duration heartbeatInterval = Duration(seconds: 10);

  /// How long a join may take before the socket is replaced.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// Three missed heartbeats: a socket quieter than this is replaced.
  static const Duration silenceTimeout = Duration(seconds: 90);

  /// Heartbeats per keep-alive: 5 × 10 s, the web client's own cadence.
  static const int heartbeatsPerKeepAlive = 5;

  /// Refreshes of the arguments in a row without a join before the session is
  /// abandoned.
  static const int maxRefreshes = 3;

  /// The handshake budget of one connection.
  static const Duration _connectTimeout = Duration(seconds: 10);

  /// The broadcast this session joined.
  AcfunDanmakuArgs args;

  final DateTime Function() _now;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
  Timer? _heartbeat;
  Timer? _silence;
  Timer? _join;
  AcfunDanmakuLink? _link;
  Uint8List? _key;
  int _opens = 0;
  int _heartbeats = 0;
  int _ticket = 0;
  int _ticketFailures = 0;
  int _refreshes = 0;
  int _joinTimeouts = 0;
  bool _disposed = false;
  bool _joined = false;
  bool _refreshing = false;

  /// A drop already in flight (a socket close, the join timeout and the silence
  /// watchdog all fire on the same dead socket).
  bool _reopening = false;

  /// Consecutive failed reopens; any frame means the link is healthy again.
  int _reconnectFailures = 0;

  AcfunGiftCatalog _gifts = AcfunGiftCatalog.empty;

  String get _currentTicket => args.tickets[_ticket % args.tickets.length];

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket and registers; null on a join, else why chat could not
  /// start (no usable credentials, or a socket that never came up).
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: acfunSiteId, message: 'session is disposed');
    }
    var key = AcfunDanmakuProtocol.securityKey(args.visitor.security);
    if (key == null || args.tickets.isEmpty) {
      try {
        await refresh();
      } on AcfunFailure catch (failure) {
        return failure.toLiveSiteError(acfunSiteId);
      } on Object catch (error) {
        return LiveSiteError.authentication(siteId: acfunSiteId, message: 'chat credentials failed: $error');
      }
      key = AcfunDanmakuProtocol.securityKey(args.visitor.security);
      if (key == null || args.tickets.isEmpty) {
        return const LiveSiteError.authentication(
          siteId: acfunSiteId,
          message: 'chat needs an acSecurity key and tickets, and the broadcast gave neither',
        );
      }
    }
    _key = key;
    return await _openSocket();
  }

  /// Opens one connection over the shared transport: the socket connects, the
  /// register handshake runs on every open, frames come to [_onFrame] and a
  /// socket that closed is reported to [_onLost].
  Future<LiveSiteError?> _openSocket() async {
    await _teardownSocket();
    final link = AcfunDanmakuLink(args: args, security: _key!, random: _random);
    _link = link;
    _joined = false;
    final socket = DanmakuSocket(
      uri: AcfunDanmakuProtocol.endpoint,
      config: WebSocketConfig(
        headers: args.headers,
        connectTimeout: _connectTimeout,
        // The transport's automatic reconnect would re-open on a dead socket's
        // terms; this protocol replaces the socket itself (its register
        // handshake, its tickets and, sometimes, fresh arguments).
        reconnectPolicy: const ReconnectPolicy(enabled: false),
      ),
      onHandshake: (socket) => socket.send(link.register()),
      onFrame: _onFrame,
      onLost: _onLost,
    );
    _socket = socket;
    if (!await socket.start()) {
      return LiveSiteError.network(siteId: acfunSiteId, message: 'danmaku connect failed on ${socket.uri}');
    }
    _opens += 1;
    _heartbeats = 0;
    _startJoin();
    _startHeartbeat();
    _startSilenceWatch();
    unawaited(_loadGifts());
    return null;
  }

  /// A new visitor session and broadcast, then a new socket with them. Tickets
  /// expire with their session, so every refresh is a fresh `startPlay`.
  Future<void> refresh() async {
    final next = await args.refresh!.call();
    args = next;
  }

  Future<void> _loadGifts() async {
    final load = args.gifts;
    if (load == null) return;
    try {
      _gifts = await load();
    } on Object {
      // No gift names or prices.
    }
  }

  void _onFrame(Object frame) {
    if (frame is! List<int>) return;
    _reconnectFailures = 0;
    _startSilenceWatch();
    final link = _link;
    if (link == null) return;
    final AcfunDanmakuPacket packet;
    try {
      packet = link.read(frame);
    } on FormatException {
      // A frame that does not add up or does not open is dropped on its own.
      return;
    }
    switch (packet.command) {
      case AcfunDanmakuProtocol.registerCommand:
        if (packet.errorCode != 0 || !link.registered) {
          unawaited(_refreshAndReopen('Register refused (${packet.errorCode})'));
          return;
        }
        _send([link.keepAlive(), link.enterRoom(ticket: _currentTicket, reconnects: _opens - 1)]);
      case AcfunDanmakuProtocol.roomCommand:
        if (packet.errorCode != 0) {
          unawaited(_refreshAndReopen('Command refused (${packet.errorCode})'));
          return;
        }
        final ({String type, int code, Uint8List payload}) ack;
        try {
          ack = AcfunDanmakuProtocol.ack(packet.payload);
        } on FormatException {
          return;
        }
        if (ack.code != 0) {
          if (AcfunDanmakuProtocol.ticketErrors.contains(ack.code)) {
            _nextTicket();
          } else {
            unawaited(_refreshAndReopen('Command error ${ack.code}'));
          }
        } else if (ack.type == AcfunDanmakuProtocol.enterRoomAck && !_joined) {
          _joined = true;
          _cancelJoin();
          _refreshes = 0;
          _ticketFailures = 0;
          _joinTimeouts = 0;
        }
      case AcfunDanmakuProtocol.messageCommand:
        _send([link.pushAck(packet)]);
        final push = AcfunDanmakuProtocol.push(packet.payload, gifts: _gifts);
        for (final message in push.messages) {
          if (!_disposed) _events.add(message);
        }
        if (push.ticketInvalid) {
          _nextTicket();
        } else if (AcfunDanmakuProtocol.refreshingStatuses.contains(push.statusChanged)) {
          unawaited(_refreshAndReopen('Broadcast status ${push.statusChanged}'));
        }
      default:
        if (packet.command.startsWith(AcfunDanmakuProtocol.pushPrefix)) {
          _send([link.pushAck(packet)]);
        } else if (packet.errorCode != 0) {
          unawaited(_refreshAndReopen('${packet.command} refused (${packet.errorCode})'));
        }
    }
  }

  /// The web client's answer to a dead ticket: enter again with the next one.
  /// Once every ticket has failed since the last join, the arguments are
  /// refreshed instead.
  void _nextTicket() {
    _ticketFailures += 1;
    if (_ticketFailures >= args.tickets.length) {
      unawaited(_refreshAndReopen('Every ticket failed'));
      return;
    }
    _ticket = (_ticket + 1) % args.tickets.length;
    _joined = false;
    _startJoin();
    final link = _link;
    if (link != null) _send([link.enterRoom(ticket: _currentTicket, reconnects: _opens - 1)]);
  }

  /// No enter-room answer within [joinTimeout]: the first time the socket is
  /// replaced (a stalled socket), the second time in a row the arguments are
  /// refreshed too (a register answer that does not open, a ticket the server
  /// ignores).
  void _startJoin() {
    _join?.cancel();
    _join = Timer(joinTimeout, () {
      if (_disposed || _joined) return;
      _joinTimeouts += 1;
      if (_joinTimeouts < 2) {
        _reopen('join timed out');
      } else {
        _joinTimeouts = 0;
        unawaited(_refreshAndReopen('Join timed out'));
      }
    });
  }

  void _cancelJoin() {
    _join?.cancel();
    _join = null;
  }

  /// A socket that closed, errored or went silent is reopened with the same
  /// arguments; a socket the transport gave up on is reported through its lost
  /// handler and lands here too.
  void _onLost(String cause) => _reopen(cause);

  /// Replaces the socket on the same arguments after a growing back off; once
  /// the reopens fail [maxRefreshes] × 2 times over the session terminates.
  void _reopen(String reason) {
    if (_disposed || _reopening || _refreshing) return;
    _reopening = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: _reconnectFailures + 1));
      _reopening = false;
      if (_disposed) return;
      final failure = await _openSocket();
      if (failure == null) return;
      _reconnectFailures += 1;
      if (_reconnectFailures >= maxRefreshes * 2) _terminate('$reason; ${failure.message}');
    }());
  }

  /// A new session and broadcast, then a new socket with them. One refresh at a
  /// time; [maxRefreshes] of them without a join ends the session.
  Future<void> _refreshAndReopen(String reason) async {
    if (_disposed || _refreshing) return;
    if (_refreshes >= maxRefreshes || args.refresh == null) {
      _terminate('$reason; chat credentials could not be renewed');
      return;
    }
    _refreshing = true;
    _refreshes += 1;
    try {
      await refresh();
      _key = AcfunDanmakuProtocol.securityKey(args.visitor.security);
      if (_key == null || args.tickets.isEmpty) {
        _terminate('$reason; the new session gave no acSecurity or tickets');
        return;
      }
      _ticket = 0;
      _ticketFailures = 0;
      if (_disposed) return;
      final failure = await _openSocket();
      if (failure != null) _terminate('$reason; ${failure.message}');
    } on Object catch (error) {
      if (!_disposed) _terminate('$reason; refresh failed: $error');
    } finally {
      _refreshing = false;
    }
  }

  /// The room heartbeat every [heartbeatInterval] once joined, with a
  /// keep-alive every fifth. [DanmakuSocket] carries no transport heartbeat:
  /// this protocol's own cadence (the two frames and the 5-beat keep-alive) is
  /// the web client's, so it stays here and is sent over the socket.
  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      final link = _link;
      if (link == null || !_joined || _disposed) return;
      _heartbeats += 1;
      if (_heartbeats % heartbeatsPerKeepAlive == 0) _send([link.keepAlive()]);
      _send([link.heartbeat(ticket: _currentTicket, now: _now())]);
    });
  }

  /// A socket quieter than [silenceTimeout] is replaced; every frame rearms it.
  void _startSilenceWatch() {
    _silence?.cancel();
    _silence = Timer(silenceTimeout, () {
      if (!_disposed) _reopen('socket silent');
    });
  }

  void _terminate(String reason) {
    if (_disposed) return;
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

  void _send(Iterable<List<int>> frames) {
    final socket = _socket;
    if (socket == null || !socket.isConnected) return;
    for (final frame in frames) {
      if (frame.isEmpty) continue;
      socket.send(frame);
    }
  }

  @override
  Future<void> disconnect() async {
    _joined = false;
    await _teardownSocket();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _joined = false;
    await _teardownSocket();
    unawaited(_events.close());
  }

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _silence?.cancel();
    _silence = null;
    _cancelJoin();
    _link = null;
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }
}
