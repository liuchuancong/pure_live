import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What the chat connection needs to join one channel: the channel login
/// (lower case, `JOIN #<channel>`) and the chat login when the stored cookie
/// holds both `auth-token` and `login` (otherwise the socket joins as an
/// anonymous `justinfan` nick).
final class TwitchDanmakuArgs {
  /// Wraps the join arguments.
  const TwitchDanmakuArgs({required this.channel, this.chat});

  /// The channel login, lower case.
  final String channel;

  /// The user's chat login (`PASS oauth:<token>`, `NICK <login>`); null for an
  /// anonymous nick.
  final ({String login, String token})? chat;

  /// Never the token.
  @override
  String toString() => channel;
}

/// Creates danmaku sessions for Twitch's IRC-over-WebSocket chat.
///
/// The session joins by the channel login, which the room detail resolves
/// (a link, a nickname or an alias is the caller's to resolve first); the chat
/// login comes from the stored cookie when it holds both `login` and
/// `auth-token`. Twitch answers chat for an offline channel too, so an offline
/// room is joined rather than refused — only a channel the detail could not
/// resolve fails to start.
final class TwitchDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the channel and the login).
  TwitchDanmakuProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final TwitchDanmakuArgs args;
    try {
      final room = await site.detail(roomId);
      args = TwitchDanmakuArgs(channel: room.roomId.toLowerCase(), chat: site.chat());
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError('twitch'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitch', message: '$error', cause: error));
    }
    final session = TwitchDanmakuSession(args: args);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: IRC over one WebSocket, without extra headers.
///
/// - At every open it sends `PASS`, `NICK`, `CAP REQ` and `JOIN` (the user's
///   chat login when the arguments carry one, else a fresh anonymous nick) and
///   then counts as joined: Twitch confirms nothing, so there is no join
///   timer.
/// - `PING :tmi.twitch.tv` goes out every 40 s, so a socket silent for
///   [TwitchDanmakuCodec.inactivityTimeout] is replaced; server `PING`s are
///   answered with `PONG`.
/// - A refused login (an expired token) drops the login and reopens at once as
///   an anonymous nick for the rest of this session, with
///   [TwitchDanmakuCodec.cookieExpiredNotice] telling the user once.
/// - A `RECONNECT` (the server is going down for maintenance) replaces the
///   socket quietly — no lost-connection notice, no second join — but never
///   more than once per [switchInterval]; a server that keeps asking then
///   reconnects the ordinary way.
/// - Deleted messages, timeouts, bans and cleared chats are retractions,
///   subscriptions and raids notices, Bits gifts. A community gift
///   (`submysterygift` and the N `subgift`s it shares one gift id for) shows as
///   its announcement only: a subscription waits up to
///   [TwitchDanmakuCodec.communityGiftWait] for that announcement and is left
///   out once it comes; one whose announcement never comes is shown.
/// - Protocol recovery: a socket that errors, closes or stays silent is
///   replaced (the generation counted, so a stale socket's frames are
///   dropped); after [TwitchDanmakuCodec.maxReconnectAttempts] failed reconnects
///   a terminal system message closes [events] instead of retrying forever.
final class TwitchDanmakuSession implements LiveDanmakuSession {
  /// A session for the channel in [args]; [connect] opens the socket. [random]
  /// draws the anonymous nick.
  TwitchDanmakuSession({required this.args, Random? random, DateTime Function()? now})
    : _random = random ?? Random.secure(),
      _now = now ?? DateTime.now;

  /// The channel this session joined (and the login it started with).
  final TwitchDanmakuArgs args;

  /// The least time between two quiet `RECONNECT` switches.
  static const Duration switchInterval = Duration(seconds: 10);

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = TwitchDanmakuCodec.maxReconnectAttempts;

  final Random _random;
  final DateTime Function() _now;
  final _events = StreamController<LiveMessage>.broadcast();
  late final _CommunityGifts _gifts = _CommunityGifts(_report);

  ({String login, String token})? _chat;
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _heartbeat;
  Timer? _watchdog;
  int _generation = 0;
  bool _disposed = false;
  bool _joined = false;
  bool _reconnecting = false;
  int _reconnectFailures = 0;
  DateTime? _lastSwitch;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket and joins; null on success, else why chat could not
  /// start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'twitch', message: 'session is disposed');
    }
    if (args.channel.trim().isEmpty) {
      return const LiveSiteError.notFound(siteId: 'twitch', message: 'twitch channel login is missing');
    }
    _chat ??= args.chat;
    final generation = ++_generation;
    _joined = false;
    await _teardownSocket();
    final WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(TwitchDanmakuCodec.endpoint);
      await channel.ready.timeout(_connectTimeout);
    } on Object catch (error) {
      return LiveSiteError.network(siteId: 'twitch', message: 'danmaku connect failed: $error', cause: error);
    }
    _socket = channel;
    _subscription = channel.stream.listen(
      (data) {
        if (generation != _generation || _disposed) return;
        _onData(data);
      },
      onDone: () => _scheduleReconnect(generation, 'socket closed'),
      onError: (Object error) => _scheduleReconnect(generation, 'socket error: $error'),
    );
    _send(TwitchDanmakuCodec.join(args.channel, random: _random, chat: _chat));
    // Twitch confirms nothing: an open socket that joined is joined.
    _joined = true;
    _startHeartbeat();
    _startWatchdog();
    return null;
  }

  static const Duration _connectTimeout = Duration(seconds: 10);

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  void _onData(Object? data) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return;
    _reconnectFailures = 0;
    _startWatchdog();
    final frame = TwitchDanmakuCodec.decode(text);
    _send(frame.replies);
    for (final message in frame.messages) {
      final gift = frame.communityGifts[message];
      if (gift == null) {
        _report(message);
      } else {
        _gifts.add(message, gift, _now());
      }
    }
    if (frame.loginRejected && _loginRejected()) return;
    if (frame.reconnect) _switch();
  }

  /// Drops the refused login and reopens as an anonymous nick (reading chat
  /// needs no login), without a reconnect notice; tells the user once. False
  /// for an anonymous nick: there is nothing to drop.
  bool _loginRejected() {
    if (_chat == null || _disposed) return false;
    _chat = null;
    _events.add(TwitchDanmakuCodec.cookieExpiredNotice());
    unawaited(_reopen(quiet: true));
    return true;
  }

  /// Replaces the socket the server is about to drop (`RECONNECT`) with the
  /// same login; within [switchInterval] of the last switch it reconnects the
  /// ordinary way instead, so a server that keeps asking cannot drive a tight
  /// loop.
  void _switch() {
    final last = _lastSwitch;
    if (last != null && _now().difference(last).abs() < switchInterval) {
      _scheduleReconnect(_generation, 'server asked to reconnect');
      return;
    }
    _lastSwitch = _now();
    unawaited(_reopen(quiet: true));
  }

  /// Closes the current socket and opens a new one without a lost-connection
  /// notice (both paths above: the refused login and `RECONNECT`). A failed
  /// reopen falls back to the ordinary reconnect path.
  Future<void> _reopen({required bool quiet}) async {
    if (_disposed) return;
    final generation = _generation;
    await _teardownSocket();
    final failure = await connect();
    if (failure == null || _disposed || generation != _generation) return;
    _reconnectFailures++;
    if (_reconnectFailures >= maxReconnectAttempts) _terminate(failure.message);
  }

  void _send(Iterable<String> lines) {
    final sink = _socket?.sink;
    if (sink == null) return;
    for (final line in lines) {
      try {
        sink.add(line);
      } on Object {
        // The reconnect path owns a broken sink.
      }
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(TwitchDanmakuCodec.heartbeatInterval, (_) {
      if (_joined && !_disposed) _send([TwitchDanmakuCodec.heartbeat]);
    });
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(TwitchDanmakuCodec.inactivityTimeout, () {
      if (!_disposed) _scheduleReconnect(_generation, 'socket silent');
    });
  }

  void _scheduleReconnect(int staleGeneration, String reason) {
    if (_disposed || staleGeneration != _generation || _reconnecting) return;
    _reconnecting = true;
    unawaited(() async {
      final backoff = Duration(seconds: _reconnectFailures + 1);
      await Future<void>.delayed(backoff);
      if (_disposed || staleGeneration != _generation) {
        _reconnecting = false;
        return;
      }
      final failure = await connect();
      _reconnecting = false;
      if (failure == null) return;
      _reconnectFailures++;
      if (_reconnectFailures >= maxReconnectAttempts) _terminate('$reason: ${failure.message}');
    }());
  }

  void _terminate(String reason) {
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
    _heartbeat?.cancel();
    _heartbeat = null;
    _watchdog?.cancel();
    _watchdog = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _socket?.sink.close();
    } on Object {
      // Closing a dead socket must not throw.
    }
    _socket = null;
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
    _gifts.dispose();
    await _teardownSocket();
    unawaited(_events.close());
  }
}

/// The community gifts of one session: an announcement is shown at once and
/// leaves out the subscriptions it gives — those held and those still to come
/// (until [TwitchDanmakuCodec.communityGiftLifetime]). A subscription without
/// its announcement waits [TwitchDanmakuCodec.communityGiftWait] for it, then
/// is shown on its own.
final class _CommunityGifts {
  /// Reports the messages that are shown, as they are decided.
  _CommunityGifts(this._report);

  /// Gifts remembered; the oldest goes first.
  static const int _capacity = 64;

  final void Function(LiveMessage message) _report;

  /// Announced gifts: when, and how many subscriptions are still to come.
  final Map<String, ({DateTime at, int left})> _announced = {};

  /// Subscriptions waiting for their announcement.
  final List<({String id, LiveMessage message, Timer timer})> _held = [];

  /// Records [notice] as part of gift [gift]: an announcement is shown at once
  /// and drops the subscriptions of that gift it already holds; a subscription
  /// of an announced gift is left out; one whose announcement has not come yet
  /// is held.
  void add(LiveMessage notice, TwitchCommunityGift gift, DateTime now) {
    _announced.removeWhere(
      (_, entry) => now.difference(entry.at) > TwitchDanmakuCodec.communityGiftLifetime || entry.left <= 0,
    );
    if (gift.announcement) {
      var left = gift.count;
      for (final held in _held.where((held) => held.id == gift.id).toList()) {
        held.timer.cancel();
        _held.remove(held);
        left--;
      }
      _announced[gift.id] = (at: now, left: left);
      while (_announced.length > _capacity) {
        _announced.remove(_announced.keys.first);
      }
      _report(notice);
      return;
    }
    if (_announced[gift.id] case final entry?) {
      _announced[gift.id] = (at: entry.at, left: entry.left - 1);
      return;
    }
    late final ({String id, LiveMessage message, Timer timer}) held;
    held = (
      id: gift.id,
      message: notice,
      timer: Timer(TwitchDanmakuCodec.communityGiftWait, () {
        if (_held.remove(held)) _report(held.message);
      }),
    );
    _held.add(held);
  }

  /// Cancels every hold; a held subscription that never saw its announcement
  /// is not shown after the session is gone.
  void dispose() {
    for (final held in _held) {
      held.timer.cancel();
    }
    _held.clear();
  }
}
