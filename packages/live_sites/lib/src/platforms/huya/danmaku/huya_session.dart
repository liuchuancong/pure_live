import 'dart:async';
import 'dart:io';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku.dart';

/// A Huya danmaku session over one anonymous WebSocket.
///
/// Lifecycle: open the socket (it counts as joined), register the streamer's
/// chat groups (command 16) and send a heartbeat, then a heartbeat every 60 s;
/// the server pushes binary Tars frames, decoded into chat, popularity and gift
/// messages. A stream-end notice for this streamer (or one naming nobody) ends
/// the session — the room is one broadcast and its replay has no live chat. A
/// dropped socket ends the session with an error on the stream; reconnecting
/// belongs to the caller's supervisor, which owns the retry policy — the same
/// division as the soop and showroom sessions. The headline (super chat) board
/// is not read yet.
///
/// Archived from the reference and not run against the live service.
final class HuyaDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the showroom session).
  // ignore: unnecessary_type_name_in_constructor
  HuyaDanmakuSession._(this._uid, this._socket, this._board) {
    _superChats = _HuyaSuperChats(_board, _messages.add, () => !_closed);
    _socket
      ..add(HuyaDanmakuProtocol.register(_uid))
      ..add(HuyaDanmakuProtocol.heartbeat());
    _heartbeat = Timer.periodic(HuyaDanmakuProtocol.heartbeatInterval, (_) {
      if (!_closed) _socket.add(HuyaDanmakuProtocol.heartbeat());
    });
    _subscription = _socket.listen(_onData, onError: _fail, onDone: _done, cancelOnError: true);
  }

  final int _uid;
  final WebSocket _socket;
  final Future<List<LiveMessage>> Function()? _board;
  final _messages = StreamController<LiveMessage>.broadcast();
  late final _HuyaSuperChats _superChats;
  late final Timer _heartbeat;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  /// Opens a session for streamer [uid]'s room. [board] reads the room's
  /// headline (super chat) board over HTTP; null (a room with no board channel
  /// id) leaves the board unfetched, so only inline panels are reported.
  static Future<HuyaDanmakuSession> connect(int uid, {Future<List<LiveMessage>> Function()? board}) async {
    final socket = await WebSocket.connect(HuyaDanmakuProtocol.endpoint.toString());
    return HuyaDanmakuSession._(uid, socket, board);
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  void _onData(dynamic data) {
    if (_closed) {
      return;
    }
    // Huya only sends binary frames.
    if (data is! List<int>) {
      return;
    }
    final frame = HuyaDanmakuProtocol.decode(data, now: DateTime.now());
    for (final message in frame.messages) {
      if (message.type == LiveMessageType.superChat) {
        _superChats.report(message);
      } else {
        _messages.add(message);
      }
    }
    for (var notice = 0; notice < frame.superChatNotices; notice++) {
      _superChats.schedule();
    }
    if (frame.ended.any((uid) => uid == _uid || uid <= 0)) {
      _fail(const SiteNotFoundError('huya: ${HuyaDanmakuProtocol.broadcastEnded}'), StackTrace.current);
    }
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _heartbeat.cancel();
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
    await _subscription?.cancel();
    await _socket.close();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}

/// The headline board of one run: one fetch sequence at a time, a notice during
/// it queues one more, and entries — fetched or carried inline by a notice —
/// are reported once per run by their id. Everything stops with the session.
final class _HuyaSuperChats {
  new(this._fetch, this._report, this._isLive);

  final Future<List<LiveMessage>> Function()? _fetch;
  final void Function(LiveMessage) _report;
  final bool Function() _isLive;
  final Set<String> _reported = <String>{};
  Future<void>? _refreshing;
  bool _queued = false;

  /// Queues a board refresh, unless there is no board to fetch. One refresh
  /// runs at a time; a notice during it queues exactly one more.
  void schedule() {
    final fetch = _fetch;
    if (fetch == null || !_isLive()) return;
    if (_refreshing != null) {
      _queued = true;
      return;
    }
    _queued = false;
    final refreshing = _refreshing = _refresh(fetch);
    unawaited(
      refreshing.whenComplete(() {
        if (identical(_refreshing, refreshing)) _refreshing = null;
        if (_queued && _isLive()) schedule();
      }),
    );
  }

  /// Fetches the board after each retry delay. Once this run has reported an
  /// entry, a fetch that brings a new one ends the sequence: the board caught
  /// up. A failed or slow fetch waits for the next attempt.
  Future<void> _refresh(Future<List<LiveMessage>> Function() fetch) async {
    for (final delay in HuyaDanmakuProtocol.superChatRetryDelays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
        if (!_isLive()) return;
      }
      try {
        final entries = await fetch().timeout(HuyaDanmakuProtocol.superChatTimeout);
        if (!_isLive()) return;
        final hadReported = _reported.isNotEmpty;
        var reportedNew = false;
        for (final entry in entries) {
          if (report(entry)) reportedNew = true;
        }
        if (hadReported && reportedNew) return;
      } on Object {
        // The next notice tries again.
      }
    }
  }

  /// Reports [entry] unless this run already did (by its id); whether it did
  /// now. An entry with no id is always reported (it cannot be deduped).
  bool report(LiveMessage entry) {
    if (!_isLive()) return false;
    final id = entry.id;
    if (id != null && id.isNotEmpty && !_reported.add(id)) return false;
    _report(entry);
    while (_reported.length > HuyaDanmakuProtocol.maxRememberedSuperChats) {
      _reported.remove(_reported.first);
    }
    return true;
  }
}
