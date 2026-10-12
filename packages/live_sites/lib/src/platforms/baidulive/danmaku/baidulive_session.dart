import 'dart:async';
import 'dart:typed_data';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/baidulive/danmaku/baidulive_danmaku.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// Baidu Live's danmaku session: the room's message lists
/// ([BaiduLiveDanmakuArgs]), polled over [LiveHttp]; no socket, no heartbeat.
///
/// - It joins with the first chat list answer, whose segments (the last few,
///   however old) are history and not fetched; a 404 is a list without
///   messages yet. Arguments whose signature ran out end the run without a
///   request, as does a chat list refused (403) after it ran out — the room
///   detail brings new ones.
/// - Every `pullInterval` after the previous poll, the chat list is asked
///   again, then the reliable and host lists; each segment not seen before is
///   fetched once, in order, and its messages reported. The first answer of
///   the reliable and host lists is history too.
/// - Unlike the reference, which folds the runtime's reconnect ladder into the
///   connection, this build ends the stream once the chat list has failed
///   [BaiduLiveDanmakuProtocol.maxFailures] times in a row (after backing off),
///   on a signature expiry, or on the room's "broadcast stopped" notice — the
///   caller's supervisor reconnects, which takes fresh lists. A failing reliable
///   or host list only skips polls; a segment answered 4xx, or not a JSON
///   object, is skipped.
///
/// Archived from the reference and not run against the live service.
final class BaiduLiveDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  BaiduLiveDanmakuSession._(this._http, this._args)
    : _headers = BaiduLiveDanmakuProtocol.headers(_args.roomId),
      _chat = _BaiduLiveList(_args.chatList),
      _others = [
        if (_args.reliableList case final reliable?) _BaiduLiveList(reliable),
        if (_args.hostList case final host?) _BaiduLiveList(host),
      ];

  final LiveHttp _http;
  final BaiduLiveDanmakuArgs _args;
  final Map<String, String> _headers;
  final _BaiduLiveList _chat;
  final List<_BaiduLiveList> _others;
  final _messages = StreamController<LiveMessage>.broadcast();
  final CancelToken _cancel = CancelToken();
  bool _closed = false;

  /// Opens a session for [args] over [http] and starts polling in the
  /// background.
  static Future<BaiduLiveDanmakuSession> connect(BaiduLiveDanmakuArgs args, LiveHttp http) async {
    final session = BaiduLiveDanmakuSession._(http, args);
    unawaited(session._run());
    return session;
  }

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  Future<void> _run() async {
    if (_args.isExpiredAt(DateTime.now())) {
      _fail(SiteApiChangedError('baidulive danmaku: ${_expired()}'), StackTrace.current);
      return;
    }
    for (var failures = 0; !_closed;) {
      try {
        await _prime(_chat);
        break;
      } on Object {
        if (_closed) return;
        if (++failures >= BaiduLiveDanmakuProtocol.startAttempts) {
          _fail(const SiteApiChangedError('baidulive danmaku: chat list unreachable'), StackTrace.current);
          return;
        }
        if (!await _delay(BaiduLiveDanmakuProtocol.startRetryDelay)) return;
      }
    }
    if (_closed) return;
    var wait = _args.pullInterval;
    var failures = 0;
    while (!_closed) {
      if (!await _delay(wait)) return;
      final BaiduLivePlaylist? playlist;
      try {
        playlist = await _playlist(_chat);
      } on Object catch (error) {
        if (_closed) return;
        // A refused list whose signature ran out stays refused: the room
        // detail brings new lists.
        if (error is _HttpStatus && error.status == 403 && _args.isExpiredAt(DateTime.now())) {
          _fail(SiteApiChangedError('baidulive danmaku: ${_expired()}'), StackTrace.current);
          return;
        }
        if (++failures > BaiduLiveDanmakuProtocol.maxFailures) {
          _fail(const SiteApiChangedError('baidulive danmaku: chat list failed too many times'), StackTrace.current);
          return;
        }
        wait = BaiduLiveDanmakuProtocol.backoff(failures);
        continue;
      }
      if (_closed) return;
      if (failures > 0) failures = 0;
      if (!await _drain(_chat, playlist)) return;
      for (final list in _others) {
        if (!await _poll(list)) return;
      }
      wait = _args.pullInterval;
    }
  }

  /// One poll of a reliable or host list; false when the run is over.
  Future<bool> _poll(_BaiduLiveList list) async {
    if (list.skip > 0) {
      list.skip--;
      return !_closed;
    }
    final BaiduLivePlaylist? playlist;
    try {
      playlist = await _playlist(list);
    } on Object {
      if (_closed) return false;
      list.skip = BaiduLiveDanmakuProtocol.skippedPolls(++list.failures);
      return true;
    }
    if (_closed) return false;
    if (playlist == null) {
      // A list that does not exist (404) has no history, and is asked less
      // often too.
      list
        ..primed = true
        ..skip = BaiduLiveDanmakuProtocol.skippedPolls(++list.failures);
      return true;
    }
    list.failures = 0;
    if (!list.primed) {
      await _prime(list, playlist);
      return true;
    }
    return await _drain(list, playlist);
  }

  /// The first [list] answer (fetched when not given): its segments are
  /// history.
  Future<void> _prime(_BaiduLiveList list, [BaiduLivePlaylist? given]) async {
    final playlist = given ?? await _playlist(list);
    list.primed = true;
    for (final segment in playlist?.segments ?? const <Uri>[]) {
      list.remember(BaiduLiveDanmakuProtocol.segmentKey(segment));
    }
  }

  /// Fetches and reports the segments of [playlist] not seen before; false
  /// when the run is over (closed, or the broadcast stopped).
  Future<bool> _drain(_BaiduLiveList list, BaiduLivePlaylist? playlist) async {
    for (final segment in playlist?.segments ?? const <Uri>[]) {
      final key = BaiduLiveDanmakuProtocol.segmentKey(segment);
      if (list.seen.contains(key)) continue;
      final Uint8List bytes;
      try {
        bytes = await _bytes(segment);
      } on Object {
        if (_closed) return false;
        if (_failed(list, key)) list.remember(key);
        continue;
      }
      if (_closed) return false;
      list.remember(key);
      final BaiduLiveSegment decoded;
      try {
        decoded = BaiduLiveDanmakuProtocol.segment(bytes, roomId: _args.roomId);
      } on FormatException {
        continue;
      }
      decoded.messages.forEach(_messages.add);
      if (decoded.ended) {
        _fail(const SiteNotFoundError('baidulive: ${BaiduLiveDanmakuProtocol.endedDetail}'), StackTrace.current);
        return false;
      }
    }
    return !_closed;
  }

  /// Counts a failed try of segment [key]; true when it is given up.
  bool _failed(_BaiduLiveList list, String key) {
    final tries = (list.attempts[key] ?? 0) + 1;
    list.attempts[key] = tries;
    return tries >= BaiduLiveDanmakuProtocol.segmentAttempts;
  }

  /// The playlist of [list], or null when the list does not exist (404).
  /// Throws [FormatException] (not a playlist) or [_HttpStatus] (a failure).
  Future<BaiduLivePlaylist?> _playlist(_BaiduLiveList list) async {
    final response = await _send(list.url);
    if (response.statusCode == 404) return null;
    if (!response.isOk) throw _HttpStatus(response.statusCode);
    return BaiduLiveDanmakuProtocol.playlist(response.text, list.url);
  }

  /// The body of [segment]; throws [_HttpStatus] on a failure.
  Future<Uint8List> _bytes(Uri segment) async {
    final response = await _send(segment);
    if (!response.isOk) throw _HttpStatus(response.statusCode);
    return response.bodyBytes;
  }

  Future<LiveResponse> _send(Uri url) => _http.send(
    LiveRequest.get(
      url,
      headers: _headers,
      timeout: BaiduLiveDanmakuProtocol.requestTimeout,
      cancelToken: _cancel,
      site: SiteIds.baiduLive,
    ),
  );

  /// Waits [duration] unless closed first; false when the run ended during the
  /// wait.
  Future<bool> _delay(Duration duration) async {
    if (_closed) return false;
    await Future<void>.delayed(duration);
    return !_closed;
  }

  String _expired() => 'chat list signature expired at ${_args.expiresAt?.toUtc().toIso8601String()}';

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

/// A non-2xx, non-404 status of a list or segment request.
final class _HttpStatus implements Exception {
  new(this.status);

  final int status;

  @override
  String toString() => 'baidulive HTTP $status';
}

/// One message list of a run: the segments seen, the failures.
final class _BaiduLiveList {
  new(this.url);

  final Uri url;

  /// Whether its history was set aside (its first answer after joining, or a
  /// 404: a list that does not exist yet has none).
  bool primed = false;

  /// Keys of the segments fetched or given up, oldest first.
  final Set<String> seen = {};

  /// Failed tries of segments not answered yet.
  final Map<String, int> attempts = {};

  /// Failed requests in a row (reliable and host lists).
  int failures = 0;

  /// Polls to skip before asking again (reliable and host lists).
  int skip = 0;

  void remember(String key) {
    attempts.remove(key);
    seen.add(key);
    while (seen.length > BaiduLiveDanmakuProtocol.rememberedSegments) {
      seen.remove(seen.first);
    }
  }
}
