import 'dart:convert';

import 'package:live_sites/src/models/live_gift.dart';
import 'package:live_sites/src/models/live_message.dart';
import 'package:meta/meta.dart';

/// One answer of Kuaishou's comment feed.
@immutable
final class KuaishouFeedBatch {
  /// A feed answer.
  const new({required this.cursor, required this.pullDelay, required this.messages, this.onlineViewers});

  /// The cursor for the next request; empty keeps the previous one.
  final String cursor;

  /// How long the feed asks the client to wait before asking again.
  final Duration pullDelay;

  /// The comments, in feed order.
  final List<LiveMessage> messages;

  /// The concurrent audience the feed reported, when it did.
  final int? onlineViewers;

  /// What a session reports for this answer: the audience reading first (when
  /// there is one), then the comments.
  List<LiveMessage> get reported => [if (onlineViewers case final viewers?) audience(watchers: viewers), ...messages];

  /// The audience figure as a message, so a viewer count travels the same
  /// stream as the comments and the UI has one thing to listen to.
  static LiveMessage audience({required int watchers}) => LiveMessage(
    type: LiveMessageType.audienceUpdate,
    userName: '',
    message: '',
    data: LiveAudienceUpdate(onlineViewers: watchers),
  );
}

/// The feed refused the request: its `result` is not 1.
///
/// A refusal is *not* retried against the fallback host: the site is
/// answering, it just says no, and asking the other endpoint would look like
/// evasion rather than recovery.
@immutable
final class KuaishouFeedRejected implements Exception {
  /// A refusal carrying the feed's `result`.
  const new(this.result);

  /// The `result` the feed sent, or null when it sent none.
  final int? result;

  @override
  String toString() => 'KuaishouFeedRejected(result: ${result ?? 'unknown'})';
}

/// Kuaishou's comment feed: an incremental HTTP endpoint, polled.
///
/// Deliberately not a socket. The desktop WebSocket needs a signed browser
/// bootstrap, while this feed — the one the mobile site itself uses — carries
/// the same public comments and the concurrent audience behind a plain GET.
/// That is why the session that follows has no handshake and no heartbeat: it
/// asks, waits as long as the answer asks it to, and asks again.
abstract final class KuaishouDanmakuProtocol {
  /// The feed hosts, primary first.
  ///
  /// A request that answers nothing usable is tried against the second host
  /// before it counts as a failure, because the two are the same feed behind
  /// different CDN edges.
  static const List<String> hosts = ['livev.m.chenzhongtech.com', 'm.gifshow.com'];

  /// The feed path on both hosts.
  static const String feedPath = '/wap/live/feed';

  /// The mobile browser the feed expects. A desktop agent gets pages, not
  /// feed answers.
  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 16; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/139.0 Mobile Safari/537.36';

  /// Waits before the second and third try of a session's first request.
  static const List<Duration> startRetryDelays = [Duration(milliseconds: 600), Duration(milliseconds: 1400)];

  /// Consecutive failures after which the session gives up and reports the
  /// error to its listener.
  static const int maxFailures = 8;

  /// How long to wait when the feed does not ask for a particular delay.
  static const Duration defaultPullDelay = Duration(seconds: 3);

  /// The name shown for a commenter the site names nobody.
  static const String anonymousUserName = '快手用户';

  /// The largest time `DateTime` holds, in milliseconds either side of the
  /// epoch.
  static const int _maxMilliseconds = 8640000000000000;

  static final RegExp _code = RegExp(r'\[[^\[\]\n]{1,16}\]');

  /// Request headers; the cookie only when there is one.
  static Map<String, String> headers(String cookie) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'referer': 'https://livev.m.chenzhongtech.com/',
    if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// The query of a request for [liveStreamId] after [cursor] (empty on a
  /// session's first request).
  static Map<String, String> query(String liveStreamId, String cursor) => {
    'liveStreamId': liveStreamId,
    if (cursor.isNotEmpty) 'cursor': cursor,
  };

  /// The wait after the [failures]-th failure in a row: 1, 2, 4, then 8 s.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// Parses one feed answer.
  ///
  /// The feed wraps its payload as a JSON *string* holding the JSON object —
  /// up to three levels, which is what the site's own client tolerates — so
  /// it is unwrapped first; an object under `data` is unwrapped too.
  ///
  /// Throws a [FormatException] when nothing object-shaped comes out, and a
  /// [KuaishouFeedRejected] when the feed's `result` is not 1. An entry that
  /// cannot be read is skipped rather than failing the answer: one malformed
  /// comment must not cost the viewer the rest of the page.
  static KuaishouFeedBatch parse(Object? body, {Map<String, String> emotes = const {}}) {
    var payload = body;
    for (var depth = 0; depth < 3 && payload is String; depth++) {
      payload = jsonDecode(payload);
    }
    if (payload case {'data': final Map<Object?, Object?> data}) {
      payload = data;
    }
    if (payload is! Map<Object?, Object?>) {
      throw const FormatException('kuaishou feed: answer is not an object');
    }
    final result = _int(payload['result']);
    if (result != 1) {
      throw KuaishouFeedRejected(result);
    }
    final watching = payload['currentWatchingCount']?.toString().trim() ?? '';
    final feeds = payload['liveStreamFeeds'];
    return KuaishouFeedBatch(
      cursor: payload['cursor']?.toString() ?? '',
      pullDelay: Duration(seconds: (_int(payload['pullCycleSeconds']) ?? defaultPullDelay.inSeconds).clamp(1, 10)),
      messages: List.unmodifiable([
        if (feeds is List<Object?>)
          for (final feed in feeds) ?comment(feed, emotes),
      ]),
      onlineViewers: watching.isEmpty ? null : _int(watching),
    );
  }

  /// One feed entry as a chat message, or null when it is not a comment, has
  /// no text, or carries a time no `DateTime` can hold.
  ///
  /// The feed names an id only sometimes, so a missing one is derived from
  /// the comment's own parts: the upstream gate dedupes by id, and a comment
  /// without one would otherwise be re-reported on every poll of the same
  /// page.
  static LiveMessage? comment(Object? feed, Map<String, String> emotes) {
    if (feed is! Map<Object?, Object?> || feed['type']?.toString().toLowerCase() != 'comment') {
      return null;
    }
    final content = feed['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      return null;
    }
    final timestamp = _int(feed['time']);
    if (timestamp != null && (timestamp < -_maxMilliseconds || timestamp > _maxMilliseconds)) {
      return null;
    }
    final author = feed['author'] is Map<Object?, Object?>
        ? feed['author']! as Map<Object?, Object?>
        : const <Object?, Object?>{};
    final userName = author['userName']?.toString().trim() ?? '';
    final userId = author['userId']?.toString() ?? '';
    final rawId = feed['id']?.toString().trim() ?? '';
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: userName.isEmpty ? anonymousUserName : userName,
      userId: userId,
      message: content,
      id: rawId.isNotEmpty ? 'kuaishou:$rawId' : _derivedId(timestamp, userId, content),
      sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
      emotes: emotes.isEmpty ? const [] : codeEmotes(content, emotes),
    );
  }

  /// The `[…]` codes of [text] the room's table knows, each once, in order.
  ///
  /// The feed carries no pictures: the codes are Kuaishou's own emote syntax
  /// and the table comes from the room page, so a message shows its emotes
  /// only when that table was read.
  static List<LiveEmote> codeEmotes(String text, Map<String, String> table) {
    final seen = <String>{};
    return [
      for (final match in _code.allMatches(text))
        if (table[match.group(0)!] case final url? when seen.add(match.group(0)!))
          LiveEmote(code: match.group(0)!, url: url),
    ];
  }

  /// A stable id for a comment the feed did not name, built from the parts
  /// that identify it.
  static String _derivedId(int? timestamp, String userId, String content) =>
      'kuaishou:${timestamp ?? 0}:$userId:${content.hashCode.toRadixString(16)}';

  static int? _int(Object? value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
