import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_restriction.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_endpoints.dart';
import 'package:live_sites/src/platforms/steambroadcast/api/steambroadcast_http.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku_codec.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_failure.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_room_parser.dart'
    show SteambroadcastRoomParser, SteambroadcastState, siteId;
import 'package:live_sites/src/platforms/steambroadcast/steambroadcast_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for Steam broadcasts.
///
/// The session follows the chat log of the current broadcast, whose id the
/// room entry carries on the room's danmaku handle — so a session is built
/// from a fresh detail. A broadcaster that is offline, one whose account may
/// not broadcast, or one without a current broadcast has no handle (or none
/// that answers) and is reported content-unavailable rather than joined
/// empty.
const String _site = siteId;

/// See [_site].

final class SteambroadcastDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the broadcaster's broadcast).
  SteambroadcastDanmakuProvider({required this.site});

  /// The site this capability serves.
  final SteambroadcastSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required LiveRoom room}) async {
    final SteambroadcastDanmakuArgs args;
    try {
      final handle = (await site.detail(room.roomId)).runtime.danmakuHandle;
      if (handle is! SteambroadcastDanmakuArgs) {
        return left(
          LiveSiteError.contentUnavailable(siteId: _site, message: 'broadcaster ${room.roomId} opens no chat'),
        );
      }
      args = handle;
    } on SteambroadcastFailure catch (failure) {
      return left(failure.toLiveSiteError(_site));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: _site, message: '$error', cause: error));
    }
    final session = SteambroadcastDanmakuSession(args: args, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// How a session sets its watches: the clock a real [Timer] keeps, or a
/// test's own, so the chat log's pacing and the retry ladder can be driven
/// without waiting them out.
typedef SteambroadcastTimers = ({Timer Function(Duration delay, void Function() callback) after});

/// One comment connection: HTTP polling of the chat log
/// ([SteambroadcastDanmakuCodec]), read only and anonymous, no socket and no
/// heartbeat.
///
/// - Start: the arguments' broadcast id (room entry's `getbroadcastmpd`),
///   else `getbroadcastmpd` now; then `getchatinfo` and window 0. Window 0
///   joins; its history is not reported. An offline broadcaster, one whose
///   account may not broadcast, or a broadcast for subscribers only ends the
///   session with a terminal system message.
/// - Then each window when the chat log's clock says it is due
///   ([SteambroadcastChatClock]), its chat lines reported in order.
/// - A failure is retried after 500 ms; the 4th in a row reads from window 0
///   again; from the 8th the chat is looked up again (a new
///   `getbroadcastmpd`, so a broadcaster's next broadcast is followed, and an
///   offline one ends the session) after 1, 2, 4, 8… s; the 16th ends with a
///   terminal system message. Any answer resets the count.
/// - A `getchatinfo` failure forgets the broadcast id, so the next attempt
///   asks `getbroadcastmpd` (Steam refuses an id that is no longer the
///   broadcaster's current one).
/// - `getbroadcastmpd`'s `num_viewers` is reported whenever it is asked.
final class SteambroadcastDanmakuSession implements LiveDanmakuSession {
  /// The comments of [args]' broadcast over [http]. [timers] and [elapsed]
  /// (the monotonic clock the chat log is followed by) are injectable for
  /// tests.
  SteambroadcastDanmakuSession({
    required this.args,
    required this.http,
    SteambroadcastTimers? timers,
    Duration Function()? elapsed,
  }) : _timers = timers ?? (after: Timer.new),
       _elapsed = elapsed ?? _stopwatch();

  /// The broadcast this session follows.
  final SteambroadcastDanmakuArgs args;

  /// The transport the chat log is read over.
  final SteambroadcastHttp http;

  final SteambroadcastTimers _timers;
  final Duration Function() _elapsed;

  static Duration Function() _stopwatch() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  final _events = StreamController<LiveMessage>.broadcast();
  final SteambroadcastChatClock _clock = SteambroadcastChatClock();

  CancelToken? _cancel;
  Timer? _wait;
  Completer<bool>? _waiting;
  String? _broadcastId;
  SteambroadcastChat? _chat;
  int _generation = 0;
  int _failures = 0;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Starts following the chat log; null once it is on its way, else why the
  /// broadcast has no chat to join.
  ///
  /// The reference's runtime retries a failed first window like any later
  /// one, so a failure starts the background retries instead of ending the
  /// session, and this returns null.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) return const LiveSiteError.unsupported(siteId: _site, message: 'session is disposed');
    final steamId = args.steamId.trim();
    if (!SteambroadcastEndpoints.isSteamId(steamId)) {
      return const LiveSiteError.notFound(siteId: _site, message: 'not a Steam id');
    }
    _cancel = CancelToken();
    _broadcastId = SteambroadcastDanmakuCodec.broadcastIdOf(args.broadcastId);
    unawaited(_follow());
    return null;
  }

  /// One step after another until the session is disposed.
  Future<void> _follow() async {
    final steamId = args.steamId.trim();
    var wait = Duration.zero;
    while (await _delay(wait)) {
      try {
        wait = await _step(steamId);
      } on SteambroadcastFailure catch (failure) {
        if (failure.kind == SteambroadcastFailureKind.streamUnavailable) {
          _terminate(failure.message);
          return;
        }
        final next = _failed('$failure');
        if (next == null) return;
        wait = next;
      } on Object catch (error) {
        final next = _failed('$error');
        if (next == null) return;
        wait = next;
      }
    }
  }

  /// Reads the window that is due (looking the chat up first when there is
  /// none) and returns the wait before the next one.
  Future<Duration> _step(String steamId) async {
    final chat = _chat ??= await _lookUp(steamId);
    final time = _clock.window;
    final cancel = _cancel;
    final SteambroadcastChatWindow answer;
    try {
      final response = await http.get(
        chat.window(time),
        headers: SteambroadcastDanmakuCodec.chatHeaders(steamId),
        cancel: cancel,
        timeout: SteambroadcastDanmakuCodec.requestTimeout,
      );
      answer = SteambroadcastDanmakuCodec.window(response.text, time: time, status: response.status);
    } on Object {
      _clock.miss();
      rethrow;
    }
    if (_disposed || (cancel?.isCancelled ?? false)) return Duration.zero;
    _failures = 0;
    final now = _elapsed();
    // Window 0 is the latest history: it only sets the clock.
    if (time == 0) return _clock.sync(answer.next, answer.initialDelay ?? Duration.zero, now);
    for (final message in answer.messages) {
      if (_disposed) return Duration.zero;
      _report(message);
    }
    return switch (answer.initialDelay) {
      final delay? when delay > Duration.zero => _clock.sync(answer.next, delay, now),
      _ => _clock.advance(answer.next, now),
    };
  }

  /// The chat log of the current broadcast: `getchatinfo` of the known
  /// broadcast id, else of the one `getbroadcastmpd` names now.
  Future<SteambroadcastChat> _lookUp(String steamId) async {
    final broadcastId = _broadcastId ?? await _currentBroadcast(steamId);
    try {
      final response = await http.get(
        SteambroadcastDanmakuCodec.chatInfoUrl(steamId, broadcastId),
        headers: SteambroadcastDanmakuCodec.headers(steamId),
        cancel: _cancel,
        timeout: SteambroadcastDanmakuCodec.requestTimeout,
      );
      final chat = SteambroadcastDanmakuCodec.chat(response.text, broadcastId: broadcastId, status: response.status);
      _clock.resync();
      return chat;
    } on Object {
      // Steam refuses an id that is not the current broadcast: the next
      // look-up asks getbroadcastmpd.
      _broadcastId = null;
      rethrow;
    }
  }

  /// The id of the broadcaster's current broadcast (`getbroadcastmpd`),
  /// reporting its viewers. Offline, a restricted account or a broadcast for
  /// subscribers only is stream-unavailable (the session ends); no id
  /// otherwise is a failure like any other (waiting for the broadcast, say).
  Future<String> _currentBroadcast(String steamId) async {
    final response = await http.get(
      SteambroadcastEndpoints.mpdUrl(steamId),
      headers: SteambroadcastDanmakuCodec.headers(steamId),
      cancel: _cancel,
      timeout: SteambroadcastDanmakuCodec.requestTimeout,
    );
    final broadcast = SteambroadcastRoomParser.broadcast(response.text, steamId: steamId, status: response.status);
    if (broadcast.viewers case final viewers?) {
      _report(SteambroadcastDanmakuCodec.audience(viewers));
    }
    if (broadcast.state == SteambroadcastState.offline) {
      throw const SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'Offline');
    }
    if (broadcast.state == SteambroadcastState.accountRestricted) {
      throw const SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'The account may not broadcast');
    }
    final id = broadcast.broadcastId;
    if (id == null) {
      if (broadcast.restriction == LiveRestriction.subscribersOnly) {
        throw const SteambroadcastFailure(SteambroadcastFailureKind.streamUnavailable, 'Subscribers only');
      }
      throw SteambroadcastFailure(
        SteambroadcastFailureKind.streamUnavailable,
        'getbroadcastmpd: no broadcast id (${broadcast.state.name})',
      );
    }
    return _broadcastId = id;
  }

  /// Waits [duration] (driven by the session's timers); false once the
  /// session is disposed or restarted.
  Future<bool> _delay(Duration duration) {
    final done = _waiting = Completer<bool>();
    final generation = _generation;
    _wait = _timers.after(duration, () {
      if (!done.isCompleted) done.complete(generation == _generation && !_disposed);
    });
    return done.future;
  }

  /// Counts a failure: ends the session after too many in a row, reads from
  /// window 0 again at the fourth and looks the chat up again from the
  /// eighth. Returns the wait, or null when the session ended.
  Duration? _failed(String detail) {
    if (_disposed) return null;
    _failures++;
    if (_failures > SteambroadcastDanmakuCodec.maxFailures) {
      _terminate(detail);
      return null;
    }
    if (_failures >= SteambroadcastDanmakuCodec.resyncAfter) _clock.resync();
    if (_failures >= SteambroadcastDanmakuCodec.lookUpAfter) {
      _chat = null;
      _broadcastId = null;
    }
    return SteambroadcastDanmakuCodec.wait(_failures);
  }

  void _report(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  /// The session is over: the reason is told once, as a system message, and
  /// the stream closes; nothing retries afterwards.
  void _terminate(String reason) {
    if (_disposed) return;
    _breakWait();
    _events.add(LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white));
    unawaited(dispose());
  }

  /// Stops the pacing timer and ends the current wait.
  void _breakWait() {
    _wait?.cancel();
    _wait = null;
    final waiting = _waiting;
    if (waiting != null && !waiting.isCompleted) waiting.complete(false);
  }

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _generation += 1;
    _breakWait();
    _cancel?.cancel();
    _cancel = null;
    _chat = null;
    _broadcastId = null;
    _failures = 0;
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation += 1;
    _breakWait();
    _cancel?.cancel();
    _cancel = null;
    await _events.close();
  }
}
