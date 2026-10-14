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
final class YoutubeDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's continuation).
  YoutubeDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the room detail and the
  /// poll transport.
  final YoutubeSite site;

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
    final session = YoutubeDanmakuSession(args: args, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live chat connection: serial polling of `get_live_chat` over
/// [YouTubeHttp], no socket and no heartbeat.
///
/// [connect] asks for the first answer up to [YoutubeDanmakuCodec.startAttempts]
/// times (the [YoutubeDanmakuCodec.startRetryDelays] apart) and reports a start
/// failure when all attempts fail. Every next request waits for the previous
/// one and then the poll interval the feed asked for. A failed request is
/// retried after 1, 2, 4, 8… seconds; the request after
/// [YoutubeDanmakuCodec.maxFailures] failures in a row closes [events] with a
/// terminal system message instead of retrying forever. A 401/403/404, or a
/// chat the feed reports as over, ends the session at once. [disconnect] and
/// [dispose] stop the loop; [dispose] also closes the stream.
final class YoutubeDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args] over [http]; [connect] starts the
  /// poll loop.
  YoutubeDanmakuSession({required this.args, required this.http});

  /// The room this session polls (the broadcast id and its join continuation).
  final YoutubeDanmakuArgs args;

  /// The transport the chat requests go over.
  final YouTubeHttp http;

  final _events = StreamController<LiveMessage>.broadcast();
  Timer? _timer;
  CancelToken _cancel = CancelToken();
  String _continuation = '';
  int _failures = 0;
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
    _continuation = args.continuation;
    _failures = 0;
    _cancel = CancelToken();
    Object? lastError;
    for (var attempt = 0; attempt < YoutubeDanmakuCodec.startAttempts; attempt++) {
      if (attempt > 0 && !await _wait(YoutubeDanmakuCodec.startRetryDelays[attempt - 1])) return null;
      final YoutubeFeedBatch batch;
      try {
        batch = await _pull(_continuation);
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
      _report(batch);
      if (batch.over) {
        _over(batch);
        return null;
      }
      if (batch.continuation.isNotEmpty) _continuation = batch.continuation;
      _schedule(batch.pullDelay);
      return null;
    }
    return LiveSiteError.network(siteId: 'youtube', message: 'live chat failed to start: $lastError', cause: lastError);
  }

  @override
  Future<void> disconnect() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _cancel.cancel();
  }

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
    final YoutubeFeedBatch batch;
    try {
      batch = await _pull(_continuation);
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
    _report(batch);
    if (batch.over) {
      _over(batch);
      return;
    }
    if (batch.continuation.isNotEmpty) _continuation = batch.continuation;
    _schedule(batch.pullDelay);
  }

  Future<YoutubeFeedBatch> _pull(String continuation) async {
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
    return YoutubeDanmakuCodec.parse(decoded);
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

  void _report(YoutubeFeedBatch batch) {
    if (_disposed) return;
    batch.reported.forEach(_events.add);
  }

  void _over(YoutubeFeedBatch batch) {
    _running = false;
    if (batch.notice.isNotEmpty) {
      _events.add(
        LiveMessage.normalized(type: LiveMessageType.notice, text: batch.notice, color: LiveMessageColor.white),
      );
    }
    _terminal('直播聊天已结束');
  }

  void _terminal(String reason) {
    _running = false;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: '弹幕连接已中断 ($reason)', color: LiveMessageColor.white),
    );
    unawaited(_events.close());
  }
}
