import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_danmaku_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_http.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_manifest.dart';
import 'package:live_sites/src/platforms/kuaishou/kuaishou_site.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Creates danmaku sessions for Kuaishou's HTTP comment feed.
///
/// The session joins by the broadcast's `liveStreamId` and the cookie in
/// effect when the room was read (the user's, else the anonymous session's,
/// else empty), both carried on the room's danmaku handle — so a session is
/// built from a fresh room detail. A room that names no broadcast (offline)
/// has no handle and is reported content-unavailable rather than joined empty.
final class KuaishouDanmakuProvider implements LiveDanmakuProvider {
  /// The provider over [site] (which resolves the room's broadcast).
  KuaishouDanmakuProvider({required this.site});

  /// The site this capability serves: the source of the room detail and the
  /// feed transport.
  final KuaishouSite site;

  @override
  Future<Either<LiveSiteError, LiveDanmakuSession>> createSession({required String roomId}) async {
    final KuaishouDanmakuArgs args;
    try {
      final handle = (await site.detail(roomId)).runtime.danmakuHandle;
      if (handle is! KuaishouDanmakuArgs || handle.liveStreamId.isEmpty) {
        return left(
          LiveSiteError.contentUnavailable(siteId: kuaishouSiteId, message: 'room $roomId names no broadcast'),
        );
      }
      args = handle;
    } on KuaishouFailure catch (failure) {
      return left(failure.toLiveSiteError(kuaishouSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kuaishouSiteId, message: '$error', cause: error));
    }
    final session = KuaishouDanmakuSession(args: args, http: site.http);
    final failure = await session.connect();
    if (failure != null) {
      await session.dispose();
      return left(failure);
    }
    return right(session);
  }
}

/// One live danmaku connection: serial polling of the comment feed over
/// [KuaishouHttp], no socket and no heartbeat.
///
/// [connect] asks for the first answer up to three times (0.6 s and 1.4 s
/// apart) and reports a start failure when all three fail; the first answer
/// joins. Every next request waits for the previous one and then the pull
/// cycle the feed asked for. A failed request is retried after 1, 2, 4, 8…
/// seconds, and the request after [KuaishouDanmakuCodec.maxFailures] failures
/// in a row closes [events] with a terminal system message instead of retrying
/// forever. [disconnect] and [dispose] stop the loop; [dispose] also closes the
/// stream.
final class KuaishouDanmakuSession implements LiveDanmakuSession {
  /// A session for the broadcast in [args] over [http]; [connect] starts the
  /// poll loop.
  KuaishouDanmakuSession({required this.args, required this.http});

  /// The room this session polls (the broadcast id and the feed cookie).
  final KuaishouDanmakuArgs args;

  /// The transport the feed requests go over.
  final KuaishouHttp http;

  final _events = StreamController<LiveMessage>.broadcast();
  Timer? _timer;
  CancelToken _cancel = CancelToken();
  String _cursor = '';
  int _failures = 0;
  bool _running = false;
  bool _disposed = false;

  @override
  Stream<LiveMessage> get events => _events.stream;

  /// Starts the poll loop: null on a successful join, else why the feed could
  /// not start (a first answer that never arrived).
  @override
  Future<LiveSiteError?> connect() async {
    if (_disposed) {
      return const LiveSiteError.unsupported(siteId: kuaishouSiteId, message: 'session is disposed');
    }
    if (args.liveStreamId.trim().isEmpty) {
      return const LiveSiteError.contentUnavailable(
        siteId: kuaishouSiteId,
        message: 'kuaishou live stream id is missing',
      );
    }
    _running = true;
    _cursor = '';
    _failures = 0;
    _cancel = CancelToken();
    Object? lastError;
    for (var attempt = 0; attempt <= KuaishouDanmakuCodec.startRetryDelays.length; attempt++) {
      if (attempt > 0 && !await _wait(KuaishouDanmakuCodec.startRetryDelays[attempt - 1])) return null;
      final KuaishouFeedBatch batch;
      try {
        batch = await _pull();
      } on Object catch (error) {
        if (!_running || _disposed) return null;
        lastError = error;
        continue;
      }
      if (!_running || _disposed) return null;
      _report(batch);
      _schedule(batch.pullDelay);
      return null;
    }
    return LiveSiteError.network(
      siteId: kuaishouSiteId,
      message: 'danmaku feed failed to start: $lastError',
      cause: lastError,
    );
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
    final KuaishouFeedBatch batch;
    try {
      batch = await _pull();
    } on Object catch (error) {
      if (_disposed || !_running) return;
      _failures++;
      if (_failures > KuaishouDanmakuCodec.maxFailures) {
        _terminal('$error');
        return;
      }
      _schedule(KuaishouDanmakuCodec.backoff(_failures));
      return;
    }
    if (_disposed || !_running) return;
    _failures = 0;
    _report(batch);
    _schedule(batch.pullDelay);
  }

  Future<KuaishouFeedBatch> _pull() async {
    final batch = KuaishouDanmakuCodec.parse(await _fetch(), emotes: args.emotes);
    if (batch.cursor.isNotEmpty) _cursor = batch.cursor;
    return batch;
  }

  /// The body of one answer: the primary endpoint, then the fallback when the
  /// primary gave no usable answer. Throws the fallback's failure.
  Future<Object?> _fetch() async {
    final headers = KuaishouDanmakuCodec.headers(args.cookie);
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final endpoint in KuaishouDanmakuCodec.endpoints) {
      final url = endpoint.replace(queryParameters: KuaishouDanmakuCodec.query(args.liveStreamId, _cursor));
      try {
        return await http.feedJson(url, headers: headers, cancel: _cancel);
      } on Object catch (error, stackTrace) {
        if (_cancel.isCancelled) rethrow;
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void _report(KuaishouFeedBatch batch) {
    if (_disposed) return;
    batch.reported.forEach(_events.add);
  }

  void _terminal(String reason) {
    _running = false;
    _events.add(
      LiveMessage.normalized(type: LiveMessageType.system, text: '弹幕连接已中断 ($reason)', color: LiveMessageColor.white),
    );
    unawaited(_events.close());
  }
}
