import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/twitch/danmaku/twitch_danmaku.dart';

/// A Twitch chat session: IRC over one anonymous WebSocket.
///
/// Lifecycle: open the socket, send the `PASS`/`NICK`/`CAP REQ`/`JOIN` lines
/// (an anonymous nick — this tree stores no Twitch login), and then count as
/// joined; a `PING :tmi.twitch.tv` goes out every 40 s and a server `PING` is
/// answered with a `PONG`. Chat, cheers (as gifts), deleted or cleared
/// messages (as recalls) and subscription and raid notices are reported; a
/// community gift (`submysterygift` and the `subgift`s it gives, one
/// `msg-param-community-gift-id`) is shown once, as its announcement. A
/// `RECONNECT` (the server going down) quietly replaces the socket and joins
/// again. A dropped socket ends the session with an error on the stream;
/// reconnecting after that belongs to the caller's supervisor, which owns the
/// retry policy.
///
/// Archived from the reference and not run against the live service.
final class TwitchDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  TwitchDanmakuSession._(this._channel, this._random, this._socket) {
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
    _heartbeat = Timer.periodic(TwitchDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(TwitchDanmakuProtocol.heartbeat);
    });
  }

  /// The least time between two quiet `RECONNECT` switches.
  static const Duration switchInterval = Duration(seconds: 10);

  final String _channel;
  final Random _random;
  WebSocket _socket;
  final _messages = StreamController<LiveMessage>.broadcast();
  final _CommunityGifts _gifts = _CommunityGifts();
  late final Timer _heartbeat;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  bool _switching = false;
  DateTime? _switchedAt;

  /// Opens an anonymous session for [channel].
  static Future<TwitchDanmakuSession> connect(String channel, {Random? random}) async {
    final source = random ?? Random.secure();
    final socket = await WebSocket.connect(TwitchDanmakuProtocol.endpoint.toString());
    final session = TwitchDanmakuSession._(channel, source, socket);
    TwitchDanmakuProtocol.join(channel, source).forEach(socket.add);
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) {
      return;
    }
    final frame = TwitchDanmakuProtocol.decode(text);
    frame.replies.forEach(_socket.add);
    for (final message in frame.messages) {
      final gift = frame.communityGifts[message];
      if (gift == null) {
        _messages.add(message);
      } else {
        _gifts.add(message, gift, _messages.add, DateTime.now());
      }
    }
    if (frame.reconnect) {
      unawaited(_switch());
    }
  }

  /// Replaces the socket the server is about to drop for maintenance: the old
  /// one is closed and a new one joins again, staying quiet (no notice, no
  /// second join report). Within [switchInterval] of the last switch it is
  /// ignored, so a server that keeps asking cannot drive a tight loop.
  Future<void> _switch() async {
    if (_closed || _switching) {
      return;
    }
    final now = DateTime.now();
    if (_switchedAt != null && now.difference(_switchedAt!).abs() < switchInterval) {
      return;
    }
    _switching = true;
    _switchedAt = now;
    final old = _subscription;
    final oldSocket = _socket;
    _subscription = null;
    await old?.cancel();
    await oldSocket.close();
    try {
      final socket = await WebSocket.connect(TwitchDanmakuProtocol.endpoint.toString());
      if (_closed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
      TwitchDanmakuProtocol.join(_channel, _random).forEach(socket.add);
    } on Object {
      // A failed switch leaves the session to the caller's supervisor.
    } finally {
      _switching = false;
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    _gifts.dispose();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  void _done() {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    _gifts.dispose();
    if (!_messages.isClosed) {
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
    _gifts.dispose();
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}

/// The community gifts of one session (D07.6): an announcement is shown at
/// once and leaves out the subscriptions it gives, those held and those still
/// to come (until [_lifetime]); a subscription without its announcement waits
/// [_wait] for it, then is shown.
final class _CommunityGifts {
  static const int _capacity = 64;
  static const Duration _wait = Duration(seconds: 2);
  static const Duration _lifetime = Duration(minutes: 1);

  /// Announced gifts: when, and how many subscriptions are still to come.
  final Map<String, ({DateTime at, int left})> _announced = {};

  /// Subscriptions waiting for their announcement.
  final List<({String id, Timer timer})> _held = [];

  /// Reports [notice] (a subscription of [gift]) through [report], collapsing
  /// it under its gift's announcement when that has come or comes in time.
  void add(LiveMessage notice, TwitchCommunityGift gift, void Function(LiveMessage) report, DateTime now) {
    _announced.removeWhere((_, entry) => now.difference(entry.at) > _lifetime || entry.left <= 0);
    if (gift.announcement) {
      report(notice);
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
      return;
    }
    if (_announced[gift.id] case final entry?) {
      _announced[gift.id] = (at: entry.at, left: entry.left - 1);
      return;
    }
    late final ({String id, Timer timer}) held;
    held = (
      id: gift.id,
      timer: Timer(_wait, () {
        if (_held.remove(held)) report(notice);
      }),
    );
    _held.add(held);
  }

  void dispose() {
    for (final held in _held) {
      held.timer.cancel();
    }
    _held.clear();
    _announced.clear();
  }
}
