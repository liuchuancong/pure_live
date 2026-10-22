import 'dart:async';
import 'dart:collection';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/baidulive/api/baidulive_http.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_manifest.dart';
import 'package:live_sites/src/platforms/baidulive/baidulive_site.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku_codec.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_failure.dart';
import 'package:live_sites/src/platforms/baidulive/parsers/baidulive_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates comment sessions for Baidu Live rooms.
///
/// Baidu Live has no socket: the room command names three HLS-style message
/// lists (the room's danmaku handle, [BaiduliveDanmakuArgs]) that are polled
/// for JSON segments. The handle comes off a fresh detail, so a session is
/// built from one; a room that is not live, or whose answer names no chat
/// list, has no handle and is reported content-unavailable rather than
/// joined empty.
///
/// The lists' signatures run out (recorded: 182.5 days). A session whose
/// chat list is refused after its signature expired ends rather than
/// retrying: the caller's next `createSession` asks a new room command, which
/// hands over new lists (E05.4) — the v2 contract keeps one session per room
/// and has no in-place list refresh.
final class BaiduliveDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (whose transport asks for the room command and
  /// the message lists).
  BaiduliveDanmakuProvider({required this.site});

  /// The site this capability serves.
  final BaiduliveSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final BaiduliveDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! BaiduliveDanmakuArgs) {
        return left(LiveSiteError.contentUnavailable(siteId: baiduliveSiteId, message: 'room $roomId opens no chat'));
      }
      args = handle;
    } on BaiduliveFailure catch (failure) {
      return left(failure.toLiveSiteError(baiduliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: baiduliveSiteId, message: '$error', cause: error));
    }
    final session = BaiduliveDanmakuSession(args: args, http: site.http, now: site.now);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// How a session sets its one watch: the clock a real [Timer] keeps, or a
/// test's own, so the poll interval, the start retry and a backoff step can be
/// read out of a connection without waiting out the platform's patience.
typedef BaiduliveSchedule = Timer Function(Duration delay, void Function() callback);

/// One live chat connection: the room's message lists ([BaiduliveDanmakuArgs])
/// polled over [BaiduliveHttp]; no socket, no heartbeat.
///
/// - [connect] joins with the first chat list answer, whose segments (the last
///   few, however old) are history and are not fetched; a 404 is a list
///   without messages yet. A failed request is tried again
///   [BaiduliveDanmakuProtocol.startRetryDelay] later; the third failure ends
///   the start with a network left, and arguments whose signature ran out
///   (by the clock `now`) end it without a request — as does a chat list
///   refused (401/403) after it ran out: the room detail brings new lists.
/// - Every `pullInterval` after the previous poll (5 s), the chat list is
///   asked again, then the reliable and host lists; each segment not seen
///   before is fetched once, in order, and its messages reported. The first
///   answer of the reliable and host lists is history too.
/// - A failed chat list request (no answer, a status that is not 2xx or 404,
///   not a playlist) is tried again after 1, 2, 4, 8, 8… s; the ninth ends the
///   run with a terminal system message. A failing reliable or host list (the
///   host list answered 404 whenever recorded) only skips 1, 2, 4, 8, then 12
///   polls. A segment answered with 4xx, or not a JSON object, is skipped; one
///   without an answer (or with 5xx) is tried in the next polls, three times
///   in all.
/// - The room's "broadcast stopped" notice (102) ends the run with a terminal
///   system message of [BaiduliveDanmakuProtocol.endedDetail]: a room is one
///   broadcast, and its replay has no new chat.
///
/// Unlike the reference, the run reports no interruption and no ready again:
/// the v2 session's stream carries messages only, so a lost poll is retried
/// quietly and only the end is told.
final class BaiduliveDanmakuSession implements LiveDanmakuSession {
  /// A session for the room in [args] over [http]; [now] is the clock the
  /// signature's expiry is compared with and [schedule] sets the watches.
  BaiduliveDanmakuSession({
    required this.args,
    required this.http,
    DateTime Function()? now,
    BaiduliveSchedule? schedule,
  }) : _now = now ?? DateTime.now,
       _schedule = schedule ?? Timer.new,
       _interval = args.pullInterval,
       _headers = BaiduliveDanmakuProtocol.headers(args.roomId),
       _chat = _BaiduliveList(args.chatList),
       _others = [
         if (args.reliableList case final reliable?) _BaiduliveList(reliable),
         if (args.hostList case final host?) _BaiduliveList(host),
       ];

  /// The room this session polls (its id and its message lists).
  final BaiduliveDanmakuArgs args;

  /// The transport the lists go over.
  final BaiduliveHttp http;

  final DateTime Function() _now;
  final BaiduliveSchedule _schedule;
  final Duration _interval;
  final Map<String, String> _headers;
  final _BaiduliveList _chat;
  final List<_BaiduliveList> _others;

  final _events = StreamController<LiveMessage>.broadcast();
  CancelToken _cancel = CancelToken();
  Timer? _timer;
  bool _running = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Joins the chat list and starts polling: null on a join (the polls run in
  /// the background), else why chat could not start — expired lists, or a
  /// first answer that never arrived. A second call is ignored.
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: baiduliveSiteId, message: 'session is disposed');
    }
    if (_running) return null;
    if (args.isExpiredAt(_now())) return _expired();
    _running = true;
    _cancel = CancelToken();
    Object? lastError;
    for (var failures = 0; failures < BaiduliveDanmakuProtocol.startAttempts; failures++) {
      if (failures > 0 && !await _wait(BaiduliveDanmakuProtocol.startRetryDelay)) return null;
      try {
        await _join();
        if (!_running || _disposed) return null;
        unawaited(_follow());
        return null;
      } on Object catch (error) {
        if (!_running || _disposed) return null;
        lastError = error;
      }
    }
    _running = false;
    return LiveSiteError.network(
      siteId: baiduliveSiteId,
      message: 'chat list: ${BaiduliveDanmakuProtocol.startAttempts} tries without an answer: $lastError',
      cause: lastError,
    );
  }

  /// Stops delivery, leaving the session able to [connect] again.
  @override
  Future<void> disconnect() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _cancel.cancel();
  }

  /// Releases everything the session owns; not reusable afterwards.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _cancel.cancel();
    unawaited(_events.close());
  }

  /// The first chat list answer: its segments are history.
  Future<void> _join() async => _prime(_chat, await _playlist(_chat));

  /// Polls until the broadcast stops, the failures run out or the run ends.
  Future<void> _follow() async {
    var wait = _interval;
    var failures = 0;
    while (await _wait(wait)) {
      final BaidulivePlaylist? playlist;
      try {
        playlist = await _playlist(_chat);
      } on Object catch (error) {
        if (!_running || _disposed) return;
        // A refused list whose signature ran out stays refused: the room
        // detail brings new lists.
        if (error is BaiduliveFailure && error.kind == BaiduliveFailureKind.riskControl && args.isExpiredAt(_now())) {
          _terminate(_expired().message);
          return;
        }
        if (++failures > BaiduliveDanmakuProtocol.maxFailures) {
          _terminate('chat list failed $failures times in a row: $error');
          return;
        }
        wait = BaiduliveDanmakuProtocol.backoff(failures);
        continue;
      }
      if (!_running || _disposed) return;
      failures = 0;
      if (!await _drain(_chat, playlist)) return;
      for (final list in _others) {
        if (!await _poll(list)) return;
      }
      wait = _interval;
    }
  }

  /// One poll of a reliable or host list; false when the run is over.
  Future<bool> _poll(_BaiduliveList list) async {
    if (list.skip > 0) {
      list.skip--;
      return true;
    }
    final BaidulivePlaylist? playlist;
    try {
      playlist = await _playlist(list);
    } on Object {
      if (!_running || _disposed) return false;
      list.skip = BaiduliveDanmakuProtocol.skippedPolls(++list.failures);
      return true;
    }
    if (!_running || _disposed) return false;
    if (playlist == null) {
      // A list that does not exist (404) has no history, and is asked less
      // often too.
      list
        ..primed = true
        ..skip = BaiduliveDanmakuProtocol.skippedPolls(++list.failures);
      return true;
    }
    list.failures = 0;
    if (!list.primed) {
      _prime(list, playlist);
      return true;
    }
    return await _drain(list, playlist);
  }

  void _prime(_BaiduliveList list, BaidulivePlaylist? playlist) {
    list.primed = true;
    for (final segment in playlist?.segments ?? const <Uri>[]) {
      list.remember(BaiduliveDanmakuProtocol.segmentKey(segment));
    }
  }

  /// Fetches and reports the segments of [playlist] not seen before; false
  /// when the run is over (closed, or the broadcast stopped).
  Future<bool> _drain(_BaiduliveList list, BaidulivePlaylist? playlist) async {
    for (final segment in playlist?.segments ?? const <Uri>[]) {
      final key = BaiduliveDanmakuProtocol.segmentKey(segment);
      if (list.seen.contains(key)) continue;
      final List<int> bytes;
      try {
        bytes = await _segment(segment);
      } on BaiduliveFailure catch (failure) {
        if (!_running || _disposed) return false;
        // A 4xx answer will not come; one without an answer, or a 5xx, may.
        if (failure.kind != BaiduliveFailureKind.network || _failed(list, key)) list.remember(key);
        continue;
      } on Object {
        if (!_running || _disposed) return false;
        if (_failed(list, key)) list.remember(key);
        continue;
      }
      if (!_running || _disposed) return false;
      list.remember(key);
      final BaiduliveSegment decoded;
      try {
        decoded = BaiduliveDanmakuProtocol.segment(bytes, roomId: args.roomId);
      } on FormatException {
        continue;
      }
      decoded.messages.forEach(_emit);
      if (decoded.ended) {
        _terminate(BaiduliveDanmakuProtocol.endedDetail);
        return false;
      }
    }
    return _running && !_disposed;
  }

  /// Counts a failed try of segment [key]; true when it is given up.
  bool _failed(_BaiduliveList list, String key) {
    final tries = (list.attempts[key] ?? 0) + 1;
    list.attempts[key] = tries;
    return tries >= BaiduliveDanmakuProtocol.segmentAttempts;
  }

  /// The playlist of [list], or null when the list does not exist (404).
  /// Throws [BaiduliveFailure] or [FormatException].
  Future<BaidulivePlaylist?> _playlist(_BaiduliveList list) async {
    final response = await _send(list.url);
    if (response.status == 404) return null;
    if (BaiduliveJson.statusError(response.status, 'message list') case final error?) throw error;
    return BaiduliveDanmakuProtocol.playlist(response.text, list.url);
  }

  /// The body of [segment]; throws [BaiduliveFailure].
  Future<List<int>> _segment(Uri segment) async {
    final response = await _send(segment);
    if (BaiduliveJson.statusError(response.status, 'message segment') case final error?) throw error;
    return response.bytes;
  }

  Future<BaiduliveResponse> _send(Uri url) =>
      http.get(url, headers: _headers, timeout: BaiduliveDanmakuProtocol.requestTimeout, cancel: _cancel);

  /// [delay] under the run's cancellation; false when the run ended, was
  /// disposed, or the wait was cancelled.
  Future<bool> _wait(Duration delay) async {
    if (_disposed || !_running) return false;
    final done = Completer<bool>();
    final cancel = _cancel;
    final timer = _schedule(delay, () {
      if (!done.isCompleted) done.complete(_running && !_disposed);
    });
    _timer = timer;
    unawaited(
      cancel.whenCancel.then((_) {
        if (!done.isCompleted) done.complete(false);
      }),
    );
    final result = await done.future;
    if (identical(_timer, timer)) _timer = null;
    timer.cancel();
    return result && _running && !_disposed;
  }

  void _emit(LiveMessage message) {
    if (!_disposed) _events.add(message);
  }

  /// The run is over: the reason is told once as a system message and the
  /// stream closes; nothing polls afterwards.
  void _terminate(String reason) {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _cancel.cancel();
    if (_disposed) return;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: reason, color: LiveMessageColor.white, sentAt: _now()),
    );
    unawaited(dispose());
  }

  LiveSiteError _expired() => LiveSiteError.authentication(
    siteId: baiduliveSiteId,
    message: 'Chat list signature expired at ${args.expiresAt?.toUtc().toIso8601String()}',
  );
}

/// One message list of a run: the segments seen, the failures.
final class _BaiduliveList {
  _BaiduliveList(this.url);

  final Uri url;

  /// Whether its history was set aside (its first answer after joining, or a
  /// 404: a list that does not exist yet has none).
  bool primed = false;

  /// Keys of the segments fetched or given up, oldest first.
  final LinkedHashSet<String> seen = LinkedHashSet();

  /// Failed tries of segments not answered yet.
  final Map<String, int> attempts = {};

  /// Failed requests in a row (reliable and host lists).
  int failures = 0;

  /// Polls to skip before asking again (reliable and host lists).
  int skip = 0;

  void remember(String key) {
    attempts.remove(key);
    seen.add(key);
    while (seen.length > BaiduliveDanmakuProtocol.rememberedSegments) {
      seen.remove(seen.first);
    }
  }
}
