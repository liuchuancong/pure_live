import 'dart:convert';

import 'package:live_sites/src/contracts/site_error/site_error.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:meta/meta.dart';

/// What Steam broadcast chat needs to follow one broadcaster: their Steam id
/// and, when room entry already asked `getbroadcastmpd`, the current
/// broadcast id (otherwise the session looks it up).
@immutable
final class SteamBroadcastDanmakuArgs {
  /// A chat follow target.
  const new({required this.steamId, this.broadcastId});

  /// The broadcaster (`steamid`, a 64-bit id).
  final String steamId;

  /// The broadcast (`broadcastid`), when known; null asks `getbroadcastmpd`.
  final String? broadcastId;

  @override
  String toString() => 'SteamBroadcastDanmakuArgs($steamId, $broadcastId)';
}

/// The chat log of one broadcast, as `getchatinfo` names it.
@immutable
final class SteamBroadcastChat {
  /// Creates the chat; [template] holds `{0}` where a window's time goes.
  const new({required this.broadcastId, required this.template});

  /// The broadcast whose chat this is.
  final String broadcastId;

  /// `view_url_template`: `https://steambroadcastchat.akamaized.net/chat/<id>/messages/{0}?chat_origin=…`.
  final String template;

  /// The address of the window at [time] (the chat log's clock, in
  /// milliseconds; 0 asks for the latest history). Like Steam's web client,
  /// only the first `{0}` is replaced.
  Uri window(int time) => Uri.parse(template.replaceFirst('{0}', '$time'));

  @override
  bool operator ==(Object other) =>
      other is SteamBroadcastChat && other.broadcastId == broadcastId && other.template == template;

  @override
  int get hashCode => Object.hash(broadcastId, template);

  @override
  String toString() => 'SteamBroadcastChat($broadcastId, $template)';
}

/// One answer of the chat log: a window's chat lines and the next window.
@immutable
final class SteamBroadcastChatWindow {
  /// Creates the answer.
  new({required this.next, required Iterable<LiveMessage> messages, this.initialDelay})
    : messages = List.unmodifiable(messages);

  /// `next_request`: the time of the next window.
  final int next;

  /// `initial_delay`: how long to wait before asking for [next], given with
  /// window 0 and whenever Steam wants the reader to set its clock again; null
  /// when absent.
  final Duration? initialDelay;

  /// The chat lines (`messages`), in order.
  final List<LiveMessage> messages;
}

/// When to ask for the next window of the chat log, as Steam's web client
/// (`broadcast_chat.js`) times it: an answer that sets the clock (window 0, or
/// one with `initial_delay`) makes its `next_request` due `initial_delay` from
/// now; every later window is due as much later as its time is past that
/// window's, plus a nudge that grows by 10 ms with every failed window (up to
/// 1 s). A reader that fell behind asks at once until it caught up.
///
/// Times are the connection's monotonic clock; waits are clamped to 0–60 s.
final class SteamBroadcastChatClock {
  /// Creates a clock that is not set: the next window asked is 0.
  new();

  int? _firstAt;
  int _first = 0;
  int _next = 0;
  int _nudge = 0;

  /// Whether an answer set the clock (since the last [resync]).
  bool get isSynced => _firstAt != null;

  /// The time of the window to ask for next: 0 until the clock is set.
  int get window => _firstAt == null ? 0 : _next;

  /// What is added to every wait: 10 ms per failed window so far.
  Duration get nudge => Duration(milliseconds: _nudge);

  /// Sets the clock from an answer: window [next] is due [initialDelay] from
  /// [now]. Returns the wait.
  Duration sync(int next, Duration initialDelay, Duration now) {
    final delay = _clamp(initialDelay.inMilliseconds);
    _firstAt = now.inMilliseconds + delay;
    _first = next;
    _next = next;
    return Duration(milliseconds: delay);
  }

  /// The next window is [next]: returns the wait until it is due at [now].
  Duration advance(int next, Duration now) {
    final firstAt = _firstAt;
    if (firstAt == null) return sync(next, Duration.zero, now);
    _next = next;
    return Duration(milliseconds: _clamp(firstAt + (next - _first) + _nudge - now.inMilliseconds));
  }

  /// A window request failed: later windows are asked 10 ms later.
  void miss() {
    final step = SteamBroadcastDanmakuProtocol.nudgeStep.inMilliseconds;
    final most = SteamBroadcastDanmakuProtocol.maxNudge.inMilliseconds;
    _nudge = _nudge + step > most ? most : _nudge + step;
  }

  /// Starts over from window 0 (the nudge stays, as in the web client).
  void resync() {
    _firstAt = null;
    _first = 0;
    _next = 0;
  }

  static int _clamp(int milliseconds) => milliseconds.clamp(0, SteamBroadcastDanmakuProtocol.maxWait.inMilliseconds);
}

/// Steam broadcast chat (the watch page's `broadcast_chat.js`), without I/O:
/// read-only and anonymous.
///
/// - `getchatinfo` of the current broadcast gives the chat log's address
///   template ([chat]); Steam answers 500 (`success != 1`) for any other id.
/// - the chat log is read window by window along its own clock
///   ([SteamBroadcastChatClock]): window 0 is the latest history (not
///   reported), each answer names the next window.
///
/// Chat lines (`msg`, `persona_name`, `steamid`) become white chat messages.
/// Archived from the reference and mapped onto this tree's models (a chat
/// colour is the int white default).
abstract final class SteamBroadcastDanmakuProtocol {
  /// Longest wait for one answer.
  static const Duration requestTimeout = Duration(seconds: 10);

  /// Wait after a failure (the web client's `s_MessageRetryDelay`).
  static const Duration retryDelay = Duration(milliseconds: 500);

  /// Failures in a row after which the chat log is read from window 0 again
  /// (the web client's `s_MessageRetryMax`).
  static const int resyncAfter = 4;

  /// Failures in a row after which the chat is looked up again:
  /// `getbroadcastmpd`, `getchatinfo`, window 0.
  static const int lookUpAfter = 8;

  /// Failures in a row that are retried; the next one ends the connection.
  static const int maxFailures = 15;

  /// What every failed window adds to later waits.
  static const Duration nudgeStep = Duration(milliseconds: 10);

  /// The most the nudge grows to.
  static const Duration maxNudge = Duration(seconds: 1);

  /// The longest wait for a window: a window is served for about 70 s.
  static const Duration maxWait = Duration(seconds: 60);

  /// The website origin and watch-page host.
  static const String origin = 'https://steamcommunity.com';

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// The wait after the [failures]-th failure in a row: 500 ms, then from
  /// [lookUpAfter] on 1, 2, 4, 8, 8… s.
  static Duration wait(int failures) =>
      failures < lookUpAfter ? retryDelay : Duration(seconds: 1 << (failures - lookUpAfter).clamp(0, 3));

  /// The watch page URL of [steamId].
  static String watchUrl(String steamId) => '$origin/broadcast/watch/$steamId';

  /// The request headers of `getbroadcastmpd` and `getchatinfo`.
  static Map<String, String> headers(String steamId) => {
    'user-agent': _userAgent,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'referer': watchUrl(steamId),
  };

  /// The request headers of the chat log: the watch page's cross-origin
  /// request (jQuery's JSON accept, the page's origin and referer).
  static Map<String, String> chatHeaders(String steamId) => {
    'user-agent': _userAgent,
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': watchUrl(steamId),
  };

  /// `getchatinfo` of [broadcastId], the broadcast of [steamId].
  static Uri chatInfoUrl(String steamId, String broadcastId) => Uri.https(
    'steamcommunity.com',
    '/broadcast/getchatinfo/',
    {'steamid': steamId, 'broadcastid': broadcastId, 'viewertoken': '0', 'sessionid': ''},
  );

  static final RegExp _broadcastId = RegExp(r'^[1-9][0-9]{0,19}$');

  /// [value] trimmed when it is a broadcast id (digits, not 0), else null.
  static String? broadcastIdOf(String? value) {
    final id = value?.trim() ?? '';
    return _broadcastId.hasMatch(id) ? id : null;
  }

  static final RegExp _chatCdn = RegExp(r'^steambroadcast[a-z0-9-]*\.akamaized\.net$');

  static const List<String> _steamDomains = [
    'steamcommunity.com',
    'steamcontent.com',
    'steamserver.net',
    'steamstatic.com',
  ];

  /// Whether [uri] may be read as a chat log: https, no user info, fragment or
  /// port other than 443, on Steam's chat CDN or a Steam domain.
  static bool isChatLog(Uri uri) {
    if (!uri.isScheme('https') || uri.userInfo.isNotEmpty || uri.hasFragment) return false;
    if (uri.hasPort && uri.port != 443) return false;
    final host = uri.host.toLowerCase();
    return _chatCdn.hasMatch(host) || _steamDomains.any((domain) => host == domain || host.endsWith('.$domain'));
  }

  /// `getchatinfo` of [broadcastId]: `success` 1 and a `view_url_template`
  /// holding `{0}` whose address is a chat log ([isChatLog]). Throws a
  /// [SiteError]: for the status (Steam answers 500 for an id that is not the
  /// current broadcast) or a changed shape.
  static SteamBroadcastChat chat(String body, {required String broadcastId, int status = 200}) {
    const what = 'getchatinfo';
    final json = _object(body, status, what);
    final success = json['success'];
    if (success != 1 && success != '1') throw SiteApiChangedError('steambroadcast $what: success $success');
    final template = json['view_url_template'];
    if (template is! String || !template.contains('{0}')) {
      throw const SiteApiChangedError('steambroadcast $what: no view_url_template with {0}');
    }
    final first = Uri.tryParse(template.replaceFirst('{0}', '0'));
    if (first == null || !isChatLog(first)) {
      throw SiteApiChangedError('steambroadcast $what: unexpected chat log ${first?.origin ?? template}');
    }
    return SteamBroadcastChat(broadcastId: broadcastId, template: template);
  }

  /// The answer for the window at [time]: `next_request` (a positive integer,
  /// past [time] after window 0), `initial_delay` (null when absent or
  /// negative) and the chat lines of `messages` ([message]). Throws a
  /// [SiteError] for a bad status or shape.
  static SteamBroadcastChatWindow window(String body, {required int time, int status = 200}) {
    final what = 'chat window $time';
    final json = _object(body, status, what);
    final next = _integer(json['next_request']);
    if (next == null || next <= 0 || (time > 0 && next <= time)) {
      throw SiteApiChangedError('steambroadcast $what: next_request ${json['next_request']}');
    }
    final delay = _integer(json['initial_delay']);
    final messages = json['messages'];
    return SteamBroadcastChatWindow(
      next: next,
      initialDelay: delay == null || delay < 0 ? null : Duration(milliseconds: delay),
      messages: [
        if (messages is List<Object?>)
          for (final entry in messages) ?message(entry),
      ],
    );
  }

  /// One entry of `messages` as a white chat message: the text is `msg`
  /// trimmed, the name `persona_name` trimmed, the user id `steamid`. Null when
  /// it is not an object or has no text. Steam gives no id and no time.
  static LiveMessage? message(Object? entry) {
    if (entry is! Map<Object?, Object?>) return null;
    final text = entry['msg'];
    if (text is! String || text.trim().isEmpty) return null;
    final name = entry['persona_name'];
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name is String ? name.trim() : '',
      userId: switch (entry['steamid']) {
        final String id => id.trim(),
        final int id => '$id',
        _ => '',
      },
      message: text.trim(),
      color: 0xFFFFFF,
    );
  }

  /// `getbroadcastmpd`'s concurrent viewers as a message.
  static LiveMessage audience(int viewers) => LiveMessage(
    type: LiveMessageType.audienceUpdate,
    userName: '',
    message: '',
    data: LiveAudienceUpdate(onlineViewers: viewers),
  );

  static final RegExp _digits = RegExp(r'^[0-9]{1,15}$');

  static int? _integer(Object? value) => switch (value) {
    final int number => number,
    final String text when _digits.hasMatch(text) => int.parse(text),
    _ => null,
  };

  static Map<Object?, Object?> _object(String body, int status, String what) {
    if (status != 200) {
      final trimmed = body.trim();
      final shown = trimmed.startsWith('{') && trimmed.length <= 64 ? ' $trimmed' : '';
      final detail = 'steambroadcast $what: HTTP $status$shown';
      return switch (status) {
        401 || 403 => throw SiteRiskControlError(detail),
        404 => throw SiteNotFoundError(detail),
        429 => throw SiteRateLimitedError(detail),
        _ => throw SiteApiChangedError(detail),
      };
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('steambroadcast $what: not JSON');
    }
    if (decoded is! Map<Object?, Object?>) throw SiteApiChangedError('steambroadcast $what: not an object');
    return decoded;
  }
}
