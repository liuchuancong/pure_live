import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/src/contracts/site_capability/site_capability.dart';
import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/models/live_status/live_status.dart';
import 'package:live_sites/src/platforms/steambroadcast/danmaku/steambroadcast_danmaku.dart';
import 'package:live_sites/src/platforms/steambroadcast/parsers/steambroadcast_parser.dart';
import 'package:live_sites/src/registry/site_ids/site_ids.dart';

/// Steam broadcast chat: HTTP polling of the chat log, read-only and
/// anonymous, no socket and no heartbeat.
///
/// - Start: the arguments' broadcast id, else `getbroadcastmpd` now; then
///   `getchatinfo` and window 0. Window 0 is the latest history and not
///   reported. An offline broadcaster, a restricted account or a
///   subscribers-only broadcast ends the stream.
/// - Then each window when the chat log's clock says it is due
///   ([SteamBroadcastChatClock]), its chat lines reported in order.
/// - A failure is retried after 500 ms; the 4th in a row reads from window 0
///   again, and from the 8th the chat is looked up again (a new
///   `getbroadcastmpd`, so a broadcaster's next broadcast is followed) after
///   1, 2, 4, 8 s; the 16th ends the stream — the caller's supervisor
///   reconnects, the same division as the baidulive session. A
///   `getchatinfo` failure forgets the broadcast id, so the next attempt asks
///   `getbroadcastmpd`. `getbroadcastmpd`'s `num_viewers` is reported whenever
///   it is asked.
///
/// Archived from the reference and not run against the live service.
final class SteamBroadcastDanmakuSession implements LiveDanmakuSession {
  // A private named constructor cannot use the `new` shorthand, so the
  // traditional form stays by design (as in the kick session).
  // ignore: unnecessary_type_name_in_constructor
  SteamBroadcastDanmakuSession._(this._http, this._args) {
    _watch.start();
    unawaited(_follow());
  }

  /// Opens a session for [args] over [http].
  static Future<SteamBroadcastDanmakuSession> connect(SteamBroadcastDanmakuArgs args, LiveHttp http) async {
    if (!SteamBroadcastParser.isSteamId(args.steamId)) {
      throw SiteNotFoundError('steambroadcast: "${args.steamId}" is not a Steam id');
    }
    return SteamBroadcastDanmakuSession._(http, args);
  }

  final LiveHttp _http;
  final SteamBroadcastDanmakuArgs _args;
  final _messages = StreamController<LiveMessage>.broadcast();
  final SteamBroadcastChatClock _clock = SteamBroadcastChatClock();
  final CancelToken _cancel = CancelToken();
  final Stopwatch _watch = Stopwatch();
  SteamBroadcastChat? _chat;
  String? _broadcastId;
  int _failures = 0;
  bool _closed = false;

  @override
  Stream<LiveMessage> get messages => _messages.stream;

  /// One step after another until the stream ends.
  Future<void> _follow() async {
    var wait = Duration.zero;
    while (!_closed && await _delay(wait)) {
      try {
        wait = await _step();
      } on _Unwatchable catch (error) {
        _failWith(error.reason);
        return;
      } on Object catch (error) {
        if (_closed) return;
        final next = _failed(error);
        if (next == null) return;
        wait = next;
      }
    }
  }

  /// Reads the window that is due (looking the chat up first when there is
  /// none) and returns the wait before the next one.
  Future<Duration> _step() async {
    final chat = _chat ??= await _lookUp();
    final time = _clock.window;
    final SteamBroadcastChatWindow answer;
    try {
      final response = await _get(chat.window(time), SteamBroadcastDanmakuProtocol.chatHeaders(_args.steamId));
      answer = SteamBroadcastDanmakuProtocol.window(response.text, time: time, status: response.statusCode);
    } on Object {
      _clock.miss();
      rethrow;
    }
    if (_closed) return Duration.zero;
    _failures = 0;
    final now = _watch.elapsed;
    // Window 0 is the latest history: it only sets the clock.
    if (time == 0) {
      return _clock.sync(answer.next, answer.initialDelay ?? Duration.zero, now);
    }
    answer.messages.forEach(_messages.add);
    return switch (answer.initialDelay) {
      final delay? when delay > Duration.zero => _clock.sync(answer.next, delay, now),
      _ => _clock.advance(answer.next, now),
    };
  }

  /// The chat log of the current broadcast: `getchatinfo` of the known
  /// broadcast id, else of the one `getbroadcastmpd` names now.
  Future<SteamBroadcastChat> _lookUp() async {
    final broadcastId = _broadcastId ?? await _currentBroadcast();
    try {
      final response = await _get(
        SteamBroadcastDanmakuProtocol.chatInfoUrl(_args.steamId, broadcastId),
        SteamBroadcastDanmakuProtocol.headers(_args.steamId),
      );
      final chat = SteamBroadcastDanmakuProtocol.chat(
        response.text,
        broadcastId: broadcastId,
        status: response.statusCode,
      );
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
  /// reporting its viewers. Offline, a restricted account or a subscribers-only
  /// broadcast is [_Unwatchable]; no id otherwise is a failure.
  Future<String> _currentBroadcast() async {
    final response = await _get(
      SteamBroadcastParser.mpdUrl(_args.steamId),
      SteamBroadcastDanmakuProtocol.headers(_args.steamId),
    );
    final broadcast = SteamBroadcastParser.broadcast(response.text, status: response.statusCode);
    if (broadcast.viewers case final viewers?) _messages.add(SteamBroadcastDanmakuProtocol.audience(viewers));
    if (broadcast.status == LiveStatus.offline) throw const _Unwatchable('Offline');
    if (broadcast.status == LiveStatus.banned) throw const _Unwatchable('The account may not broadcast');
    final id = SteamBroadcastDanmakuProtocol.broadcastIdOf(broadcast.broadcastId);
    if (id == null) {
      if (broadcast.restriction == LiveRestriction.subscribersOnly) {
        throw const _Unwatchable('Subscribers only');
      }
      throw const SiteApiChangedError('steambroadcast getbroadcastmpd: no broadcast id');
    }
    return _broadcastId = id;
  }

  /// Counts a failure: ends the stream after too many in a row, reads from
  /// window 0 again at the 4th and looks the chat up again from the 8th.
  /// Returns the wait, or null when the stream ended.
  Duration? _failed(Object error) {
    final detail = '$error';
    _failures++;
    if (_failures > SteamBroadcastDanmakuProtocol.maxFailures) {
      _failWith(detail);
      return null;
    }
    if (_failures == SteamBroadcastDanmakuProtocol.resyncAfter) _clock.resync();
    if (_failures >= SteamBroadcastDanmakuProtocol.lookUpAfter) {
      _chat = null;
      _broadcastId = null;
    }
    return SteamBroadcastDanmakuProtocol.wait(_failures);
  }

  /// Sends a GET; nothing is sent once the stream ended.
  Future<LiveResponse> _get(Uri url, Map<String, String> headers) {
    if (_cancel.isCancelled) throw const SiteApiChangedError('steambroadcast: cancelled');
    return _http.send(
      LiveRequest.get(
        url,
        headers: headers,
        timeout: SteamBroadcastDanmakuProtocol.requestTimeout,
        cancelToken: _cancel,
        site: SiteIds.steamBroadcast,
      ),
    );
  }

  Future<bool> _delay(Duration duration) async {
    if (_closed) return false;
    if (duration > Duration.zero) await Future<void>.delayed(duration);
    return !_closed;
  }

  void _failWith(String reason) => _fail(SiteApiChangedError('steambroadcast danmaku: $reason'), StackTrace.current);

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

/// The broadcaster cannot be watched now; retrying does not help.
final class _Unwatchable implements Exception {
  const new(this.reason);

  final String reason;

  @override
  String toString() => reason;
}
