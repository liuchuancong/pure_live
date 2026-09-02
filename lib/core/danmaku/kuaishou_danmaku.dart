import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';

class KuaishouDanmakuArgs {
  const KuaishouDanmakuArgs({required this.liveStreamId, this.cookie = ''});

  final String liveStreamId;
  final String cookie;
}

typedef KuaishouFeedFetcher = Future<dynamic> Function(
  KuaishouDanmakuArgs args,
  String cursor,
  CancelToken cancelToken,
);

class KuaishouFeedBatch {
  const KuaishouFeedBatch({
    required this.cursor,
    required this.pullDelay,
    required this.messages,
    required this.onlineViewers,
  });

  final String cursor;
  final Duration pullDelay;
  final List<LiveMessage> messages;
  final int? onlineViewers;
}

/// Anonymous Kuaishou live-chat transport backed by the platform's mobile
/// incremental feed. The current desktop WebSocket bootstrap is guarded by a
/// signed browser request; the mobile feed exposes the same public comments,
/// cursor and concurrent audience count without keeping a hidden WebView alive.
///
/// Polls are one-shot and scheduled only after the previous request finishes,
/// preventing overlapping timers, duplicate cursors and background CPU growth.
class KuaishouDanmaku implements LiveDanmaku {
  KuaishouDanmaku({KuaishouFeedFetcher? fetcher, this.minimumPollDelay = const Duration(seconds: 1)})
    : _fetcher = fetcher ?? _fetchFeed;

  static const List<String> _feedUrls = <String>[
    'https://livev.m.chenzhongtech.com/wap/live/feed',
    'https://m.gifshow.com/wap/live/feed',
  ];
  static const int _maxReconnectAttempts = 8;

  final KuaishouFeedFetcher _fetcher;
  final Duration minimumPollDelay;

  @override
  int heartbeatTime = 0;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  bool _connected = false;
  @override
  bool get isConnected => _connected;

  @override
  void markConnected() => _connected = true;

  @override
  void markDisconnected() => _connected = false;

  @override
  void heartbeat() {
    // The incremental HTTP feed is itself the liveness probe.
  }

  Timer? _pollTimer;
  CancelToken? _cancelToken;
  KuaishouDanmakuArgs? _args;
  String _cursor = '';
  int _generation = 0;
  int _reconnectAttempts = 0;

  @override
  Future<void> start(dynamic args) async {
    final typedArgs = args is KuaishouDanmakuArgs ? args : KuaishouDanmakuArgs(liveStreamId: args?.toString() ?? '');
    if (typedArgs.liveStreamId.trim().isEmpty) {
      throw const FormatException('Kuaishou live stream id is missing');
    }

    final generation = ++_generation;
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelToken?.cancel('Kuaishou room changed');
    _cancelToken = null;
    _args = typedArgs;
    _cursor = '';
    _reconnectAttempts = 0;
    markDisconnected();

    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: attempt == 1 ? 600 : 1400));
      }
      if (generation != _generation) return;
      try {
        await _pollOnce(generation, propagateFailure: true);
        if (generation != _generation) return;
        return;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<void> _pollOnce(int generation, {bool scheduleNext = true, bool propagateFailure = false}) async {
    final args = _args;
    if (args == null || generation != _generation) return;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    try {
      final raw = await _fetcher(args, _cursor, cancelToken);
      if (generation != _generation || cancelToken.isCancelled) return;
      final batch = parseFeedPayload(raw);
      if (batch.cursor.isNotEmpty) _cursor = batch.cursor;
      _reconnectAttempts = 0;

      final wasConnected = isConnected;
      markConnected();
      if (!wasConnected) onReady?.call();

      final viewers = batch.onlineViewers;
      if (viewers != null) {
        onMessage?.call(
          LiveMessage(
            type: LiveMessageType.online,
            userName: '',
            message: '',
            data: LiveAudienceUpdate(kind: LiveAudienceMetricKind.onlineViewers, value: viewers),
            color: LiveMessageColor.white,
          ),
        );
      }
      for (final message in batch.messages) {
        if (generation != _generation) return;
        onMessage?.call(message);
      }
      if (scheduleNext) _schedulePoll(generation, batch.pullDelay);
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error) || generation != _generation) return;
      if (propagateFailure) rethrow;
      _handlePollFailure(generation, error, stackTrace);
    } catch (error, stackTrace) {
      if (generation != _generation || cancelToken.isCancelled) return;
      if (propagateFailure) rethrow;
      _handlePollFailure(generation, error, stackTrace);
    } finally {
      if (identical(_cancelToken, cancelToken)) _cancelToken = null;
    }
  }

  void _handlePollFailure(int generation, Object error, StackTrace stackTrace) {
    CoreLog.e(error.toString(), stackTrace);
    markDisconnected();
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxReconnectAttempts) {
      onClose?.call('服务器连接失败：快手弹幕重连超过最大次数');
      return;
    }
    if (_reconnectAttempts == 1) {
      onClose?.call('与服务器断开连接，正在尝试重连');
    }
    final seconds = 1 << (_reconnectAttempts - 1).clamp(0, 3);
    _schedulePoll(generation, Duration(seconds: seconds));
  }

  void _schedulePoll(int generation, Duration requestedDelay) {
    if (generation != _generation) return;
    _pollTimer?.cancel();
    final delay = requestedDelay < minimumPollDelay ? minimumPollDelay : requestedDelay;
    _pollTimer = Timer(delay, () {
      _pollTimer = null;
      if (generation == _generation) unawaited(_pollOnce(generation));
    });
  }

  @override
  Future<void> stop() async {
    _generation++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _cancelToken?.cancel('Kuaishou danmaku stopped');
    _cancelToken = null;
    _args = null;
    _cursor = '';
    _reconnectAttempts = 0;
    markDisconnected();
    onMessage = null;
    onClose = null;
    onReady = null;
  }

  static Future<dynamic> _fetchFeed(KuaishouDanmakuArgs args, String cursor, CancelToken cancelToken) async {
    final headers = <String, dynamic>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 16; Mobile) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/139.0 Mobile Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Referer': 'https://livev.m.chenzhongtech.com/',
    };
    if (args.cookie.trim().isNotEmpty) headers['cookie'] = args.cookie.trim();
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final endpoint in _feedUrls) {
      try {
        return await HttpClient.instance.getJson(
          endpoint,
          queryParameters: <String, dynamic>{
            'liveStreamId': args.liveStreamId,
            if (cursor.isNotEmpty) 'cursor': cursor,
          },
          header: headers,
          cancel: cancelToken,
        );
      } catch (error, stackTrace) {
        if (cancelToken.isCancelled) rethrow;
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static KuaishouFeedBatch parseFeedPayload(dynamic raw) {
    dynamic payload = raw;
    for (var depth = 0; depth < 3 && payload is String; depth++) {
      payload = jsonDecode(payload);
    }
    if (payload is Map && payload['data'] is Map) payload = payload['data'];
    if (payload is! Map) throw const FormatException('Kuaishou feed has an invalid shape');

    final result = _asInt(payload['result']);
    if (result != 1) {
      throw StateError('Kuaishou feed rejected the request (result: ${result ?? 'unknown'})');
    }
    final cursor = payload['cursor']?.toString() ?? '';
    final pullSeconds = (_asInt(payload['pullCycleSeconds']) ?? 3).clamp(1, 10);
    final watchingText = payload['currentWatchingCount']?.toString().trim() ?? '';
    final onlineViewers = watchingText.isEmpty ? null : LiveRoom.parseAudienceNumber(watchingText);
    final messages = <LiveMessage>[];

    final feeds = payload['liveStreamFeeds'];
    if (feeds is List) {
      for (final feed in feeds) {
        if (feed is! Map || feed['type']?.toString().toLowerCase() != 'comment') continue;
        final content = feed['content']?.toString().trim() ?? '';
        if (content.isEmpty) continue;
        final author = feed['author'] is Map ? feed['author'] as Map : const <dynamic, dynamic>{};
        final userName = author['userName']?.toString().trim() ?? '';
        final userId = author['userId']?.toString() ?? '';
        final timestamp = _asInt(feed['time']);
        final rawId = feed['id']?.toString().trim() ?? '';
        final digest = sha1.convert(utf8.encode('$timestamp\u0000$userId\u0000$content')).toString();
        messages.add(
          LiveMessage(
            type: LiveMessageType.chat,
            userName: userName.isEmpty ? '快手用户' : userName,
            userId: userId,
            message: content,
            messageId: 'kuaishou:${rawId.isEmpty ? digest : rawId}',
            sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
            color: LiveMessageColor.white,
          ),
        );
      }
    }

    return KuaishouFeedBatch(
      cursor: cursor,
      pullDelay: Duration(seconds: pullSeconds),
      messages: List<LiveMessage>.unmodifiable(messages),
      onlineViewers: onlineViewers,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
