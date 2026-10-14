import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
        return left(LiveSiteError.contentUnavailable(siteId: 'acfun', message: 'room $roomId names no live broadcast'));
      }
      args = handle;
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError('acfun'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'acfun', message: '$error', cause: error));
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

  /// The broadcast this session joined.
  AcfunDanmakuArgs args;

  final DateTime Function() _now;
  final Random _random;

  final _events = StreamController<LiveMessage>.broadcast();
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  Timer? _join;
  AcfunDanmakuLink? _link;
  Uint8List? _key;
  int _generation = 0;
  int _opens = 0;
  int _heartbeats = 0;
  int _ticket = 0;
  int _ticketFailures = 0;
  int _refreshes = 0;
  int _joinTimeouts = 0;
  bool _disposed = false;
  bool _joined = false;
  bool _refreshing = false;
  bool _reconnecting = false;
  AcfunGiftCatalog _gifts = AcfunGiftCatalog.empty;

  String get _currentTicket => args.tickets[_ticket % args.tickets.length];

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket and registers; null on a join, else why chat could not
  /// start (no usable credentials, or a socket that never came up).
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'acfun', message: 'session is disposed');
    }
    var key = AcfunDanmakuProtocol.securityKey(args.visitor.security);
    if (key == null || args.tickets.isEmpty) {
      try {
        await refresh();
      } on AcfunFailure catch (failure) {
        return failure.toLiveSiteError('acfun');
      } on Object catch (error) {
        return LiveSiteError.authentication(siteId: 'acfun', message: 'chat credentials failed: $error');
      }
      key = AcfunDanmakuProtocol.securityKey(args.visitor.security);
      if (key == null || args.tickets.isEmpty) {
        return const LiveSiteError.authentication(
          siteId: 'acfun',
          message: 'chat needs an acSecurity key and tickets, and the broadcast gave neither',
        );
      }
    }
    _key = key;
    return await _openSocket();
  }

  Future<LiveSiteError?> _openSocket() async {
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(AcfunDanmakuProtocol.endpoint, headers: args.headers);
      await channel.ready.timeout(_connectTimeout);
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'acfun', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        if (data is! List<int>) return;
        _onFrame(Uint8List.fromList(data));
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    final link = AcfunDanmakuLink(args: args, security: _key!, random: _random);
    _link = link;
    _opens += 1;
    _heartbeats = 0;
    _send([link.register()]);
    _join = Timer(joinTimeout, () {
      if (generation == _generation && !_disposed && !_joined) _onJoinTimeout(generation);
    });
    _startHeartbeat();
    _startWatchdog();
    unawaited(_loadGifts());
    return null;
  }

  static const Duration _connectTimeout = Duration(seconds: 10);

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
      final catalog = await load();
      _gifts = catalog;
    } on Object {
      // No gift names or prices.
    }
  }

  void _onFrame(Uint8List frame) {
    _reconnectFailures = 0;
    _startWatchdog();
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
          _join?.cancel();
          _join = null;
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
    _join?.cancel();
    _join = Timer(joinTimeout, () {
      if (!_disposed && !_joined) _onJoinTimeout(_generation);
    });
    final link = _link;
    if (link != null) _send([link.enterRoom(ticket: _currentTicket, reconnects: _opens - 1)]);
  }

  /// No enter-room answer within [joinTimeout]: the first time the socket is
  /// replaced (a stalled socket), the second time in a row the arguments are
  /// refreshed too (a register answer that does not open, a ticket the server
  /// ignores).
  void _onJoinTimeout(int generation) {
    if (_disposed || generation != _generation) return;
    _joinTimeouts += 1;
    if (_joinTimeouts < 2) {
      _scheduleReconnect(generation, 'join timed out');
    } else {
      _joinTimeouts = 0;
      unawaited(_refreshAndReopen('Join timed out'));
    }
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

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(silenceTimeout, () {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
  }

  int _reconnectFailures = 0;

  /// A socket that closed, errored or went silent is replaced with the same
  /// arguments; the generation guard keeps one dead socket from opening a
  /// second live one.
  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting || _refreshing) return;
    _reconnecting = true;
    unawaited(() async {
      await Future<void>.delayed(Duration(seconds: _reconnectFailures + 1));
      if (_disposed || staleGeneration != _generation) {
        _reconnecting = false;
        return;
      }
      final failure = await _openSocket();
      _reconnecting = false;
      if (failure == null) return;
      _reconnectFailures += 1;
      if (_reconnectFailures >= maxRefreshes * 2) _terminate('$reason; ${failure.message}');
    }());
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

  void _send(Iterable<List<int>> frames) {
    final sink = _socket?.sink;
    if (sink == null) return;
    for (final frame in frames) {
      if (frame.isEmpty) continue;
      try {
        sink.add(frame);
      } on Object {
        // The reconnect path owns a broken sink.
      }
    }
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

  Future<void> _teardownSocket() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    _join?.cancel();
    _join = null;
    _link = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _socket?.sink.close();
    } on Object {
      // Closing a dead socket must not throw.
    }
    _socket = null;
  }
}
