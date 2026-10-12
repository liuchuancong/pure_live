import 'dart:async';

import 'package:live_net/live_net.dart';

import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kuaishou/danmaku/kuaishou_danmaku.dart';

/// A Kuaishou danmaku session: the comment feed, polled.
///
/// The first request is tried up to three times (the feed occasionally
/// answers a challenge page on a cold start) and its failure ends the
/// session; after that every next request waits for the previous one and then
/// the pull cycle the feed itself asked for, so the site's own pacing is
/// respected rather than guessed. Failures back off 1, 2, 4, 8 seconds and,
/// past [KuaishouDanmakuProtocol.maxFailures] in a row, end the session with
/// the error on the stream.
///
/// Cancellation is cooperative: [close] stops the loop at its next wait and
/// cancels a request already in flight, so a page the user left stops talking
/// to the site immediately.
final class KuaishouDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (the same as the other sessions).
  // ignore: unnecessary_type_name_in_constructor
  KuaishouDanmakuSession._(this._http, this._liveStreamId, this._emotes, this._headers);

  /// Opens the feed for [liveStreamId] and starts polling.
  ///
  /// A blank stream id is rejected here rather than by the feed: it means the
  /// room was not on air when it was read, and a request without an id would
  /// poll something else entirely.
  static Future<KuaishouDanmakuSession> connect({
    required LiveHttp http,
    required String liveStreamId,
    Map<String, String> emotes = const {},
    String cookie = '',
  }) async {
    if (liveStreamId.trim().isEmpty) {
      throw const SiteNotFoundError('kuaishou: no live stream id, the room is not on air');
    }
    final session = KuaishouDanmakuSession._(
      http,
      liveStreamId.trim(),
      emotes,
      KuaishouDanmakuProtocol.headers(cookie),
    );
    await session._start();
    return session;
  }

  final LiveHttp _http;
  final String _liveStreamId;
  final Map<String, String> _emotes;
  final Map<String, String> _headers;
  final _messages = StreamController<LiveMessage>.broadcast();
  final CancelToken _cancel = CancelToken();
  String _cursor = '';
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  /// The first request, with the site's cold-start retries.
  ///
  /// Its failure is fatal on purpose: a session whose first request never
  /// answered has no cursor and no audience, so there is nothing to report
  /// and the caller's supervisor should decide whether to try again.
  Future<void> _start() async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt <= KuaishouDanmakuProtocol.startRetryDelays.length; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(KuaishouDanmakuProtocol.startRetryDelays[attempt - 1]);
        if (_closed) {
          return;
        }
      }
      try {
        final batch = await _pull();
        _report(batch);
        unawaited(_follow(batch.pullDelay));
        return;
      } on Object catch (error, stack) {
        if (_closed) {
          return;
        }
        lastError = error;
        lastStack = stack;
      }
    }
    _fail(lastError ?? StateError('kuaishou feed never answered'), lastStack ?? StackTrace.current);
  }

  /// Polls until the session closes, after waiting [delay].
  Future<void> _follow(Duration delay) async {
    var wait = delay;
    var failures = 0;
    while (!_closed) {
      await Future<void>.delayed(wait);
      if (_closed) {
        return;
      }
      try {
        final batch = await _pull();
        failures = 0;
        wait = batch.pullDelay;
        _report(batch);
      } on KuaishouFeedRejected catch (error) {
        // The site answered "no": retrying it on the fallback host would be
        // evasion, so it ends the session.
        _fail(error, StackTrace.current);
        return;
      } on Object catch (error) {
        failures++;
        if (failures > KuaishouDanmakuProtocol.maxFailures) {
          _fail(error, StackTrace.current);
          return;
        }
        wait = KuaishouDanmakuProtocol.backoff(failures);
      }
    }
  }

  /// One request, from the first host that answers something usable.
  Future<KuaishouFeedBatch> _pull() async {
    Object? lastError;
    StackTrace? lastStack;
    for (final host in KuaishouDanmakuProtocol.hosts) {
      try {
        final response = await _http.send(
          LiveRequest.get(
            Uri.https(host, KuaishouDanmakuProtocol.feedPath, KuaishouDanmakuProtocol.query(_liveStreamId, _cursor)),
            headers: _headers,
            site: 'kuaishou',
            cancelToken: _cancel,
          ),
        );
        final batch = KuaishouDanmakuProtocol.parse(response.text, emotes: _emotes);
        if (batch.cursor.isNotEmpty) {
          _cursor = batch.cursor;
        }
        return batch;
      } on Object catch (error, stack) {
        lastError = error;
        lastStack = stack;
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('kuaishou feed answered nothing'),
      lastStack ?? StackTrace.current,
    );
  }

  void _report(KuaishouFeedBatch batch) {
    if (_closed) {
      return;
    }
    batch.reported.forEach(_messages.add);
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) {
      return;
    }
    _closed = true;
    _cancel.cancel(error);
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    _cancel.cancel('closed');
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
