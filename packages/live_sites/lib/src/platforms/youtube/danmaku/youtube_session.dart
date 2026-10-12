import 'dart:async';
import 'dart:convert';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_parser.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// A YouTube live-chat session: the broadcast's InnerTube chat, polled over
/// [LiveHttp]; no socket, no heartbeat.
///
/// - It joins: `next` for the first continuation and the viewer count, then the
///   first poll, whose answer (the recent history) is not reported — only the
///   Super Chats its ticker still pins, and the viewers. A broadcast without a
///   live chat (not live, chat off, a replay) or an argument that is not a video
///   id ends the stream, as do [YouTubeDanmakuProtocol.startAttempts] join
///   failures.
/// - Each poll waits for the answer's `timeoutMs` (within 1–5 s, 5 s when none).
///   An answer to a reload continuation is history again and is not reported.
///   A failed poll is retried [YouTubeDanmakuProtocol.retryDelay] later;
///   [YouTubeDanmakuProtocol.maxFailures] in a row, or an answer without a
///   continuation (the chat is over), ends the stream.
/// - Every [YouTubeDanmakuProtocol.viewerInterval] it asks `updated_metadata`
///   for the live viewer count; a failed request is not reported (the next turn
///   asks by video id again).
/// - Unlike the reference, which folds a reconnect ladder into the connection,
///   this build ends the stream on those conditions — the caller's supervisor
///   reconnects (the same division as the baidulive session).
///
/// Archived from the reference and not run against the live service.
final class YouTubeDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the baidulive session).
  // ignore: unnecessary_type_name_in_constructor
  YouTubeDanmakuSession._(this._http, this._args, this._now, this._allChat);

  /// Opens a session for [args] over [http] and starts polling in the
  /// background. [allChat] reads the page's "Live chat" view (every message)
  /// instead of "Top chat" (default off, as the page).
  static Future<YouTubeDanmakuSession> connect(
    LiveHttp http,
    YouTubeDanmakuArgs args, {
    bool allChat = false,
    DateTime Function()? now,
  }) async {
    final session = YouTubeDanmakuSession._(http, args, now ?? DateTime.now, allChat);
    unawaited(session._run());
    return session;
  }

  final LiveHttp _http;
  final YouTubeDanmakuArgs _args;
  final DateTime Function() _now;
  bool _allChat;
  final _messages = StreamController<LiveMessage>.broadcast();
  final CancelToken _cancel = CancelToken();
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  Future<void> _run() async {
    final videoId = _args.videoId.trim();
    if (YouTubeParser.normalizeVideoId(videoId) == null) {
      _fail(SiteNotFoundError('youtube chat: "$videoId" is not a video id'), StackTrace.current);
      return;
    }
    YouTubeChatEntry? entry;
    YouTubeChatPoll? history;
    for (var failures = 0; history == null && !_closed;) {
      try {
        entry ??= YouTubeDanmakuProtocol.watch(
          await _post(YouTubeDanmakuProtocol.nextEndpoint, YouTubeDanmakuProtocol.nextBody(videoId)),
        );
        if (!entry.live) {
          _fail(
            SiteNotFoundError('youtube chat: ${entry.replay ? 'replay only' : 'no live chat'}'),
            StackTrace.current,
          );
          return;
        }
        history = await _poll(entry.continuation!, restart: true);
      } on Object {
        if (_closed) return;
        if (++failures >= YouTubeDanmakuProtocol.startAttempts) {
          _fail(const SiteApiChangedError('youtube chat: join failed'), StackTrace.current);
          return;
        }
        if (!await _delay(YouTubeDanmakuProtocol.retryDelay)) return;
      }
    }
    if (_closed || history == null) return;
    if (history.ended) {
      _fail(SiteNotFoundError('youtube chat: ${_ended(history)}'), StackTrace.current);
      return;
    }
    if (entry!.viewers case final viewers?) _messages.add(YouTubeDanmakuProtocol.audience(viewers));
    history.pinned.forEach(_messages.add);
    unawaited(_follow(history));
    unawaited(_viewers());
  }

  /// Polls after [previous] until the chat is over, the failures run out or the
  /// session closes.
  Future<void> _follow(YouTubeChatPoll previous) async {
    var last = previous;
    var wait = YouTubeDanmakuProtocol.pollDelay(last.timeout);
    var failures = 0;
    while (!_closed) {
      if (!await _delay(wait)) return;
      final YouTubeChatPoll poll;
      try {
        poll = await _poll(last.continuation!, restart: last.reload);
      } on Object {
        if (_closed) return;
        if (++failures >= YouTubeDanmakuProtocol.maxFailures) {
          _fail(const SiteApiChangedError('youtube chat: polls failed too many times'), StackTrace.current);
          return;
        }
        wait = YouTubeDanmakuProtocol.retryDelay;
        continue;
      }
      if (_closed) return;
      if (failures > 0) failures = 0;
      // The answer to a reload continuation starts over with the history.
      if (!last.reload) poll.messages.forEach(_messages.add);
      if (poll.ended) {
        _fail(SiteNotFoundError('youtube chat: ${_ended(poll)}'), StackTrace.current);
        return;
      }
      last = poll;
      wait = YouTubeDanmakuProtocol.pollDelay(poll.timeout);
    }
  }

  /// Every [YouTubeDanmakuProtocol.viewerInterval] until the session closes, the
  /// live viewer count of `updated_metadata`: first by video id, then with the
  /// previous answer's continuation.
  Future<void> _viewers() async {
    final videoId = _args.videoId.trim();
    String? continuation;
    while (!_closed) {
      if (!await _delay(YouTubeDanmakuProtocol.viewerInterval)) return;
      try {
        final update = YouTubeDanmakuProtocol.metadata(
          await _post(
            YouTubeDanmakuProtocol.metadataEndpoint,
            continuation == null
                ? YouTubeDanmakuProtocol.metadataBody(videoId)
                : YouTubeDanmakuProtocol.metadataContinuationBody(continuation),
          ),
        );
        if (_closed) return;
        continuation = update.continuation;
        if (update.viewers case final viewers?) _messages.add(YouTubeDanmakuProtocol.audience(viewers));
      } on Object {
        if (_closed) return;
        continuation = null;
      }
    }
  }

  /// Asks for [continuation]; one that starts the chat over ([restart]) is first
  /// asked for in the "Live chat" view when that is on; an answer without a chat
  /// turns it off and asks for [continuation] as it came.
  Future<YouTubeChatPoll> _poll(String continuation, {required bool restart}) async {
    if (_allChat && restart) {
      final live = YouTubeDanmakuProtocol.allChatContinuation(continuation);
      if (live != null && live != continuation) {
        final answer = await _chat(live);
        if (!answer.ended) return answer;
        _allChat = false;
      }
    }
    return await _chat(continuation);
  }

  Future<YouTubeChatPoll> _chat(String continuation) async {
    final answer = await _post(YouTubeDanmakuProtocol.chatEndpoint, YouTubeDanmakuProtocol.chatBody(continuation));
    return YouTubeDanmakuProtocol.chat(answer, now: _now());
  }

  /// Sends [body] to [url] and returns the answer decoded.
  Future<Object?> _post(Uri url, Map<String, Object?> body) async {
    final response = await _http.send(
      LiveRequest.json(
        url,
        body: body,
        headers: YouTubeDanmakuProtocol.headers,
        timeout: YouTubeDanmakuProtocol.requestTimeout,
        cancelToken: _cancel,
        site: SiteIds.youtube,
      ),
    );
    YouTubeParser.checkStatus(response.statusCode, response.text, 'chat');
    return jsonDecode(response.text);
  }

  static String _ended(YouTubeChatPoll poll) => poll.notice.isEmpty ? 'chat ended' : 'chat ended: ${poll.notice}';

  /// Waits [duration] unless closed first; false when the run ended during it.
  Future<bool> _delay(Duration duration) async {
    if (_closed) return false;
    await Future<void>.delayed(duration);
    return !_closed;
  }

  void _fail(Object error, StackTrace stack) {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    if (!_messages.isClosed) {
      _messages.addError(error, stack);
      unawaited(_messages.close());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancel.cancel();
    if (!_messages.isClosed) {
      await _messages.close();
    }
  }
}
