import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_endpoints.dart';
import 'package:live_sites/src/platforms/youtube/api/youtube_http.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_codec.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_failure.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_json.dart';
import 'package:live_sites/src/platforms/youtube/youtube_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for YouTube's HTTP-polled live chat.
///
/// The session joins by the broadcast's first live-chat continuation, read off
/// a fresh room detail (the `next` answer's `liveChatRenderer`) and carried on
/// the room's danmaku handle. A replay (`isReplay`) is refused — chat replay is
/// not polled here — and a room whose `next` names no continuation (offline, or
/// chat disabled) is reported content-unavailable rather than joined empty.
///
/// [allChat] (off by default, as the page) reads the "Live chat" view — every
/// message — instead of the default "Top chat"; a continuation the site will not
/// rewrite, or refuses, falls back to "Top chat" for the rest of the run.
final class YoutubeDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's continuation).
  YoutubeDanmakuProvider({required this.site, this.allChat = false});

  /// The site this capability serves: the source of the room detail and the
  /// poll transport.
  final YoutubeSite site;

  /// Whether sessions read the "Live chat" view rather than "Top chat".
  final bool allChat;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final YoutubeDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! YoutubeDanmakuArgs) {
        return left(
          const LiveSiteError.contentUnavailable(siteId: 'youtube', message: 'room names no live chat continuation'),
        );
      }
      if (handle.isReplay) {
        return left(const LiveSiteError.unsupported(siteId: 'youtube', message: 'chat replay is not supported'));
      }
      if (handle.continuation.isEmpty) {
        return left(
          const LiveSiteError.contentUnavailable(siteId: 'youtube', message: 'live chat continuation is missing'),
        );
      }
      args = handle;
    } on YouTubeFailure catch (failure) {
      return left(failure.toLiveSiteError('youtube'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'youtube', message: '$error', cause: error));
    }
    final session = YoutubeDanmakuSession(args: args, http: site.http, allChat: allChat, now: site.now);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: serial polling of `get_live_chat` over
/// [YouTubeHttp], no socket and no heartbeat, plus a slower `updated_metadata`
/// poll that keeps the live viewer count fresh.
///
/// [connect] asks for the first answer up to [YoutubeDanmakuCodec.startAttempts]
/// times (the [YoutubeDanmakuCodec.startRetryDelays] apart) and reports a start
/// failure when all attempts fail. The first answer is the recent history: its
/// chat lines are not reported, only the viewer count and the Super Chats its
/// ticker still pins (replayed). Every next request waits for the previous one
/// and then the poll interval the feed asked for; an answer to a reload
/// continuation is history again and is not reported. A failed request is retried
/// after 1, 2, 4, 8… seconds; the request after
/// [YoutubeDanmakuCodec.maxFailures] failures in a row closes [events] with a
/// terminal system message instead of retrying forever. A 401/403/404, or a chat
/// the feed reports as over, ends the session at once. Every
/// [YoutubeDanmakuCodec.viewerInterval] a `updated_metadata` request reports the
/// concurrent viewers again; a failed one is not reported and does not touch the
/// chat. [disconnect] and [dispose] stop both loops; [dispose] also closes the
/// stream.
final class YoutubeDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args] over [http]; [connect] starts the
  /// poll loop. [allChat] reads the "Live chat" view first; [now] is the clock a
  /// Super Chat without a platform time starts at.
  YoutubeDanmakuSession({required this.args, required this.http, this.allChat = false, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The room this session polls (the broadcast id and its join continuation).
  final YoutubeDanmakuArgs args;

  /// The transport the chat requests go over.
  final YouTubeHttp http;

  /// Whether the chat is read in the "Live chat" view rather than "Top chat".
  final bool allChat;

  /// Whether this run still asks for the "Live chat" view; off once the site
  /// refuses a rewritten continuation.
  late bool _allChat;

  final DateTime Function() _now;

  final _events = StreamController<LiveMessage>.broadcast();
  Timer? _timer;
  Timer? _viewerTimer;
  CancelToken _cancel = CancelToken();
  String _continuation = '';
  int _failures = 0;
  bool _reload = false;
  String? _viewerContinuation;
  bool _running = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Starts the poll loop: null on a successful join, else why the chat could
  /// not start (a first answer that never arrived). A second call is ignored
  /// (the double-start guard).
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: 'youtube', message: 'session is disposed');
    }
    if (_running) return null;
    if (args.continuation.trim().isEmpty) {
      return const LiveSiteError.contentUnavailable(siteId: 'youtube', message: 'live chat continuation is missing');
    }
    _running = true;
    _allChat = allChat;
    _continuation = args.continuation;
    _failures = 0;
    _reload = false;
    _viewerContinuation = null;
    _cancel = CancelToken();
    Object? lastError;
    for (var attempt = 0; attempt < YoutubeDanmakuCodec.startAttempts; attempt++) {
      if (attempt > 0 && !await _wait(YoutubeDanmakuCodec.startRetryDelays[attempt - 1])) return null;
      final YoutubeFeedBatch batch;
      try {
        batch = await _poll(_continuation, restart: true);
      } on Object catch (error) {
        if (!_running || _disposed) return null;
        if (_isTerminal(error)) {
          _terminal('$error');
          return error is YouTubeFailure ? error.toLiveSiteError('youtube') : null;
        }
        lastError = error;
        continue;
      }
      if (!_running || _disposed) return null;
      if (batch.over) {
        _over(batch);
        return null;
      }
      if (batch.continuation.isNotEmpty) _continuation = batch.continuation;
      _reload = batch.reload;
      // The history is not reported, but the viewers and the Super Chats the
      // ticker still pins are — on a zero-delay timer, so a caller that
      // subscribes right after this await still receives them.
      _emitJoin(batch);
      _schedule(batch.pullDelay);
      _scheduleViewers();
      return null;
    }
    return LiveSiteError.network(siteId: 'youtube', message: 'live chat failed to start: $lastError', cause: lastError);
  }

  @override
  Future<void> disconnect() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _viewerTimer?.cancel();
    _viewerTimer = null;
    _cancel.cancel();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    _timer?.cancel();
    _timer = null;
    _viewerTimer?.cancel();
    _viewerTimer = null;
    _cancel.cancel();
    unawaited(_events.close());
  }

  Future<bool> _wait(Duration delay) async {
    final completer = Completer<bool>();
    _timer = Timer(delay, () => completer.complete(_running && !_disposed));
    unawaited(
      _cancel.whenCancel.then((_) {
        if (!completer.isCompleted) completer.complete(false);
      }),
    );
    final result = await completer.future;
    _timer = null;
    return result;
  }

  void _schedule(Duration wait) {
    if (_disposed || !_running) return;
    _timer?.cancel();
    _timer = Timer(wait, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (_disposed || !_running) return;
    final restart = _reload;
    final YoutubeFeedBatch batch;
    try {
      batch = await _poll(_continuation, restart: restart);
    } on Object catch (error) {
      if (_disposed || !_running) return;
      if (_isTerminal(error)) {
        _terminal('$error');
        return;
      }
      _failures++;
      if (_failures > YoutubeDanmakuCodec.maxFailures) {
        _terminal('$error');
        return;
      }
      _schedule(YoutubeDanmakuCodec.backoff(_failures));
      return;
    }
    if (_disposed || !_running) return;
    _failures = 0;
    // An answer to a reload continuation restarts with the history: not reported.
    if (!restart) batch.reported.forEach(_emit);
    if (batch.over) {
      _over(batch);
      return;
    }
    if (batch.continuation.isNotEmpty) _continuation = batch.continuation;
    _reload = batch.reload;
    _schedule(batch.pullDelay);
  }

  /// Asks for [continuation]. One that restarts the chat ([restart]) is asked
  /// for in the "Live chat" view first when that is on; a refusal (a 4xx, or an
  /// answer without a chat) turns it off and asks for [continuation] as it came.
  Future<YoutubeFeedBatch> _poll(String continuation, {required bool restart}) async {
    if (_allChat && restart) {
      final live = YoutubeDanmakuCodec.allChatContinuation(continuation);
      if (live != null && live != continuation) {
        try {
          final batch = await _chat(live);
          if (!batch.over) return batch;
        } on Object catch (error) {
          if (error is CancelledFailure) rethrow;
          if (error is! YouTubeFailure || error.kind == YoutubeFailureKind.network) rethrow;
        }
        _allChat = false;
        if (!_running || _disposed) throw const CancelledFailure();
      }
    }
    return await _chat(continuation);
  }

  Future<YoutubeFeedBatch> _chat(String continuation) async {
    final response = await http.postJson(
      YoutubeEndpoints.api('live_chat/get_live_chat'),
      json: YoutubeEndpoints.liveChatBody(continuation),
      headers: YoutubeEndpoints.apiHeaders(referer: YoutubeEndpoints.watchUrl(args.videoId)),
      timeout: YoutubeDanmakuCodec.requestTimeout,
      cancel: _cancel,
    );
    _checkStatus(response.status);
    final decoded = decodeJson(response.text);
    if (decoded == null) {
      throw YouTubeFailure(YoutubeFailureKind.apiChanged, 'live_chat: not JSON (${jsonSnippet(response.text)})');
    }
    return YoutubeDanmakuCodec.parse(decoded, now: _now());
  }

  // Viewer count --------------------------------------------------------------

  void _scheduleViewers() {
    if (_disposed || !_running) return;
    _viewerTimer?.cancel();
    _viewerTimer = Timer(YoutubeDanmakuCodec.viewerInterval, () => unawaited(_pollViewers()));
  }

  Future<void> _pollViewers() async {
    if (_disposed || !_running) return;
    try {
      final response = await http.postJson(
        YoutubeEndpoints.api('updated_metadata'),
        json: _viewerContinuation == null
            ? YoutubeEndpoints.metadataBody(args.videoId)
            : YoutubeEndpoints.liveChatBody(_viewerContinuation!),
        headers: YoutubeEndpoints.apiHeaders(referer: YoutubeEndpoints.watchUrl(args.videoId)),
        timeout: YoutubeDanmakuCodec.requestTimeout,
        cancel: _cancel,
      );
      _checkStatus(response.status);
      final decoded = decodeJson(response.text);
      if (decoded == null) throw const YouTubeFailure(YoutubeFailureKind.apiChanged, 'updated_metadata: not JSON');
      final update = YoutubeDanmakuCodec.parseMetadata(decoded);
      if (_disposed || !_running) return;
      _viewerContinuation = update.continuation;
      if (update.viewers case final viewers?) _emit(YoutubeDanmakuCodec.audience(viewers));
    } on Object catch (error) {
      if (_disposed || !_running || error is CancelledFailure) return;
      _viewerContinuation = null;
    }
    _scheduleViewers();
  }

  // Emission ------------------------------------------------------------------

  void _emitJoin(YoutubeFeedBatch batch) {
    if (_disposed || !_running) return;
    Timer(Duration.zero, () {
      if (_disposed || !_running) return;
      if (args.viewers case final viewers?) _emit(YoutubeDanmakuCodec.audience(viewers));
      batch.pinned.forEach(_emit);
    });
  }

  void _emit(LiveMessage message) {
    if (_disposed) return;
    _events.add(message);
  }

  /// The chat answer's status mapped to a failure: 401/403 risk control, 404
  /// not-found, 429 rate-limited, 400 api-changed, 5xx network; a 2xx answer
  /// proceeds to parsing.
  static void _checkStatus(int status) {
    if (status >= 200 && status < 300) return;
    switch (status) {
      case 401:
      case 403:
        throw YouTubeFailure(YoutubeFailureKind.riskControl, 'live_chat: HTTP $status');
      case 404:
        throw const YouTubeFailure(YoutubeFailureKind.notFound, 'live_chat: HTTP 404');
      case 429:
        throw const YouTubeFailure(YoutubeFailureKind.rateLimited, 'live_chat: HTTP 429');
      case 400:
        throw const YouTubeFailure(YoutubeFailureKind.apiChanged, 'live_chat: HTTP 400');
      default:
        throw YouTubeFailure(YoutubeFailureKind.network, 'live_chat: HTTP $status');
    }
  }

  /// Whether a poll error ends the session now rather than being retried: a
  /// not-found (the broadcast is gone) or a risk-control rejection (401/403).
  static bool _isTerminal(Object error) =>
      error is YouTubeFailure &&
      (error.kind == YoutubeFailureKind.notFound || error.kind == YoutubeFailureKind.riskControl);

  void _over(YoutubeFeedBatch batch) {
    _running = false;
    _viewerTimer?.cancel();
    _viewerTimer = null;
    if (batch.notice.isNotEmpty) {
      _emit(LiveMessage.normalized(type: LiveMessageType.notice, text: batch.notice, color: LiveMessageColor.white));
    }
    _terminal('直播聊天已结束');
  }

  void _terminal(String reason) {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _viewerTimer?.cancel();
    _viewerTimer = null;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: '弹幕连接已中断 ($reason)', color: LiveMessageColor.white),
    );
    unawaited(_events.close());
  }
}
