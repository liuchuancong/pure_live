import 'dart:async';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/common/websocket/danmaku_socket.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_websocket/live_websocket.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for the huya protocol.
final class HuyaDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's streamer uid and
  /// headline board).
  HuyaDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the uid, the top channel id
  /// and the board fetch.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    // The streamer uid, the top channel id and the board fetch all ride in the
    // room detail's danmaku handle.
    final room = site.capability<LiveRoomProvider>()!.getRoom(roomId);
    return await (await room).match<Future<Either<LiveSiteError, LiveDanmakuSession>>>(
      (error) async => left(error),
      _openRoom,
    );
  }

  Future<Either<LiveSiteError, LiveDanmakuSession>> _openRoom(LiveRoom room) async {
    if (room.runtime.danmakuHandle case final HuyaDanmakuArgs args) {
      final session = HuyaDanmakuSession(
        roomId: room.roomId,
        uid: args.uid,
        superChats: args.topSid > 0 ? () => site.superChatBoard(args.topSid) : null,
        now: site.now,
      );
      final failure = await session.connect();
      if (failure != null) {
        unawaited(session.dispose());
        return left(failure);
      }
      return right(session);
    }
    return left(const LiveSiteError.contentUnavailable(siteId: 'huya', message: 'room names no danmaku handle'));
  }
}

/// One live danmaku connection over huya's WebSocket protocol.
///
/// Protocol-level recovery is the transport's job: [DanmakuSocket] keeps the
/// socket alive with heartbeat packets, replaces one that stays silent for
/// three periods (180 s), and reconnects with a bounded back off — the group
/// registration goes out again on every connection. A stream-end notice for
/// this room's streamer closes [events] after a final system message.
///
/// Super chats arrive two ways: a headline push that carries the board panel is
/// reported from it; a notice-only push schedules a WUP fetch of the board
/// ([superChats], from the room's top channel id). Entries are reported once
/// per run, by their event id, whether they came from a push or a fetch.
final class HuyaDanmakuSession implements LiveDanmakuSession {
  /// A session for [roomId], registering streamer [uid]'s groups. [superChats]
  /// reads the room's headline board (null when the room has no top channel id);
  /// [now] times the board entries. [connect] opens the socket.
  HuyaDanmakuSession({required this.roomId, required this.uid, this.superChats, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The room this session joined.
  final String roomId;

  /// The streamer whose `live:`/`chat:` groups are registered.
  final int uid;

  /// Reads the room's headline message board (super chats); null when there is
  /// no top channel id to ask for.
  final Future<List<LiveSuperChatMessage>> Function()? superChats;

  final DateTime Function() _now;

  /// A notice message emitted when the platform says the broadcast ended.
  static const String broadcastEndedDetail = 'Broadcast ended';

  /// A notice message emitted when the transport gave up on the socket.
  static const String connectionLostDetail = 'Danmaku connection lost';

  /// How many reconnects in a row may fail before the session is abandoned.
  static const int maxReconnectAttempts = 6;

  /// The endpoint huya's danmaku gateway serves.
  static const String _endpoint = 'wss://wsapi.huya.com';

  /// The heartbeat packet doubles as the silence watchdog: a socket that
  /// answers nothing for three periods is replaced.
  static final WebSocketConfig _transport = WebSocketConfig(
    reconnectPolicy: const ReconnectPolicy(maxAttempts: maxReconnectAttempts, initialDelay: Duration(seconds: 2)),
    heartbeat: HeartbeatConfig(
      interval: HuyaDanmakuProtocol.heartbeatInterval,
      payload: HuyaDanmakuProtocol.heartbeat,
      timeout: HuyaDanmakuProtocol.heartbeatInterval * 3,
    ),
  );

  final _events = StreamController<LiveMessage>.broadcast();
  DanmakuSocket? _socket;
  _HuyaSuperChats? _board;
  bool _disposed = false;
  bool _ended = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Opens the socket; null on success, else why it could not start.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'huya', message: 'session is disposed');
    }
    await _teardownSocket();
    _ended = false;
    _board = _HuyaSuperChats(this, superChats);
    final socket = DanmakuSocket(
      uri: Uri.parse(_endpoint),
      config: _transport,
      onHandshake: (socket) => socket
        ..send(HuyaDanmakuProtocol.register(uid))
        ..send(HuyaDanmakuProtocol.heartbeat()),
      onFrame: _onFrame,
      onLost: (_) => _loseConnection(),
    );
    _socket = socket;
    if (!await socket.start()) {
      return const LiveSiteError.network(
        siteId: 'huya',
        message: 'danmaku connect failed: no connection to $_endpoint',
      );
    }
    return null;
  }

  void _onFrame(Object frame) {
    if (frame is! List<int>) return;
    final decoded = HuyaDanmakuProtocol.decode(Uint8List.fromList(frame), now: _now());
    final board = _board;
    for (final message in decoded.messages) {
      // A super chat is reported through the board's once-only gate (by event
      // id); every other message goes out as it came.
      final payload = message.payload;
      if (board != null && payload is LiveSuperChatMessage) {
        board.report(payload);
      } else {
        _events.add(message);
      }
    }
    for (var notice = 0; notice < decoded.superChatNotices; notice++) {
      board?.schedule();
    }
    // The web client leaves the room at the stream end; a notice that names
    // another streamer is not this room's.
    if (decoded.ended.any((endedUid) => endedUid == uid || endedUid <= 0)) {
      _events.add(
        LiveMessage.normalized(type: LiveMessageType.system, text: broadcastEndedDetail, color: LiveMessageColor.white),
      );
      // The room is over: end delivery instead of reconnecting forever.
      _ended = true;
      unawaited(_teardownSocket());
      unawaited(_events.close());
    }
  }

  /// Reports the loss on the stream instead of retrying forever.
  void _loseConnection() {
    if (_disposed || _ended) return;
    _ended = true;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: connectionLostDetail, color: LiveMessageColor.white),
    );
    unawaited(_teardownSocket());
    unawaited(_events.close());
  }

  /// Whether the run has stopped: the session is disposed or its socket ended.
  bool get _stopped => _disposed || _ended;

  /// Emits one message (used by the board scheduler when a fresh entry arrives).
  void _emit(LiveMessage message) {
    if (!_stopped) _events.add(message);
  }

  /// Waits [delay], completing false if the run stops meanwhile.
  Future<bool> _wait(Duration delay) async {
    final completer = Completer<bool>();
    final timer = Timer(delay, () => completer.complete(!_stopped));
    unawaited(
      _events.done.then((_) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }),
    );
    return await completer.future;
  }

  Future<void> _teardownSocket() async {
    final socket = _socket;
    _socket = null;
    await socket?.stop();
  }

  @override
  Future<void> disconnect() => _teardownSocket();

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _teardownSocket();
    unawaited(_events.close());
  }
}

/// The headline board of one run: one fetch sequence at a time, a notice during
/// it queues one more, and entries — fetched or carried by a push — are reported
/// once per run by their event id. Everything stops when the session ends.
final class _HuyaSuperChats {
  _HuyaSuperChats(this._session, this._fetch);

  final HuyaDanmakuSession _session;
  final Future<List<LiveSuperChatMessage>> Function()? _fetch;
  // Insertion ordered, so the oldest entry is forgotten first.
  final Set<LiveSuperChatMessage> _reported = {};
  Future<void>? _refreshing;
  bool _queued = false;

  /// Starts a board fetch unless one is running (then queues a single follow-up
  /// for the notice that arrived). No board is asked for without a fetcher.
  void schedule() {
    final fetch = _fetch;
    if (fetch == null || _session._stopped) return;
    if (_refreshing != null) {
      _queued = true;
      return;
    }
    _queued = false;
    final refreshing = _refreshing = _refresh(fetch);
    unawaited(
      refreshing.whenComplete(() {
        if (identical(_refreshing, refreshing)) _refreshing = null;
        if (_queued && !_session._stopped) schedule();
      }),
    );
  }

  /// Fetches the board after each retry delay. Once this run has reported an
  /// entry, a fetch that brings a new one ends the sequence (the board caught
  /// up). A failed or slow fetch waits for the next attempt.
  Future<void> _refresh(Future<List<LiveSuperChatMessage>> Function() fetch) async {
    for (final delay in HuyaDanmakuProtocol.superChatRetryDelays) {
      if (delay > Duration.zero && !await _session._wait(delay)) return;
      if (_session._stopped) return;
      try {
        final entries = await fetch().timeout(HuyaDanmakuProtocol.superChatTimeout);
        if (_session._stopped) return;
        final hadReported = _reported.isNotEmpty;
        var reportedNew = false;
        for (final entry in entries) {
          if (report(entry)) reportedNew = true;
        }
        if (hadReported && reportedNew) return;
      } on Object {
        // The last failure is logged upstream only; the next notice tries again.
      }
    }
  }

  /// Reports [entry] unless this run already did; whether it did now.
  bool report(LiveSuperChatMessage entry) {
    if (_session._stopped || !_reported.add(entry)) return false;
    _session._emit(HuyaDanmakuProtocol.superChatMessage(entry));
    while (_reported.length > HuyaDanmakuProtocol.maxRememberedSuperChats) {
      _reported.remove(_reported.first);
    }
    return true;
  }
}
