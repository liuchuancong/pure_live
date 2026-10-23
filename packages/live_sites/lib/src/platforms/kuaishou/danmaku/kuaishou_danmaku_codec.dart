import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/kuaishou/api/kuaishou_endpoints.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The comment feed refused the request: its `result` is not 1. A refused
/// answer is not asked again on the fallback endpoint.
final class KuaishouFeedRejected implements Exception {
  /// Creates the failure.
  const KuaishouFeedRejected(this.result);

  /// The feed's `result`, or null when it was missing or not a number.
  final int? result;

  @override
  String toString() => 'KuaishouFeedRejected(result: ${result ?? 'unknown'})';
}

/// One answer of the comment feed: the cursor for the next request (empty
/// keeps the previous), the wait before it ([pullDelay], the feed's
/// `pullCycleSeconds` clamped to 1–10 s), the comments in feed order, and the
/// concurrent audience when the feed carried one.
final class KuaishouFeedBatch {
  /// Creates the batch.
  const KuaishouFeedBatch({required this.cursor, required this.pullDelay, required this.messages, this.onlineViewers});

  /// Cursor for the next request; empty keeps the previous one.
  final String cursor;

  /// Wait before the next request.
  final Duration pullDelay;

  /// The comments, in feed order.
  final List<LiveMessage> messages;

  /// `currentWatchingCount` as a number; null when the feed left it empty.
  final int? onlineViewers;

  /// What the session reports for this answer, in order: the audience figure
  /// (when there is one), then the comments.
  List<LiveMessage> get reported => [
    if (onlineViewers case final viewers?) KuaishouDanmakuCodec.audience(viewers),
    ...messages,
  ];
}

/// Kuaishou's comment feed, without I/O: the mobile site's incremental feed,
/// polled over HTTP. It carries the same public comments and the concurrent
/// audience anonymously (no gift line in this protocol).
abstract final class KuaishouDanmakuCodec {
  /// Waits before the second and third try of the first request.
  static const List<Duration> startRetryDelays = [Duration(milliseconds: 600), Duration(milliseconds: 1400)];

  /// Failed requests in a row that are retried; the next one ends the feed.
  static const int maxFailures = 8;

  /// Wait before the next request when the feed gives no pull cycle.
  static const Duration defaultPullDelay = Duration(seconds: 3);

  /// The name of a commenter without one.
  static const String anonymousUserName = '快手用户';

  /// The feed endpoints, primary first; every request tries the primary and
  /// falls back to the second when it gets no usable answer.
  static final List<Uri> endpoints = [for (final url in KuaishouEndpoints.feedEndpoints) Uri.parse(url)];

  /// Request headers; the cookie (trimmed) only when there is one.
  static Map<String, String> headers(String cookie) => {
    'User-Agent': KuaishouEndpoints.feedUserAgent,
    'Accept': KuaishouEndpoints.feedAccept,
    'Referer': KuaishouEndpoints.feedReferer,
    if (cookie.trim().isNotEmpty) 'cookie': cookie.trim(),
  };

  /// Query of a request for [liveStreamId] after [cursor] (none for the first
  /// request).
  static Map<String, String> query(String liveStreamId, String cursor) => {
    'liveStreamId': liveStreamId,
    if (cursor.isNotEmpty) 'cursor': cursor,
  };

  /// Wait after the [failures]-th failed request in a row: 1, 2, 4, then 8 s.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// The audience figure as a message.
  static LiveMessage audience(int viewers) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    color: LiveMessageColor.white,
    payload: LiveAudienceUpdate.of(kind: LiveAudienceSignalKind.onlineViewers, value: viewers),
  );

  /// Parses one answer: [body] is the response decoded once; text is decoded up
  /// to three more times (the feed sends a JSON string holding the JSON object)
  /// and an object under `data` is unwrapped.
  ///
  /// Throws [FormatException] when no object results and [KuaishouFeedRejected]
  /// when `result` is not 1. Only `comment` entries (any case) with text become
  /// messages; an entry that cannot be read (a time out of range) is skipped
  /// without losing the others. A comment's codes found in [emotes] (the room
  /// page's emoji table, `[笑哭]` → its picture) are its [LiveMessage.emotes]
  /// (the feed itself has no pictures).
  static KuaishouFeedBatch parse(Object? body, {Map<String, String> emotes = const {}}) {
    var payload = body;
    for (var depth = 0; depth < 3 && payload is String; depth++) {
      payload = jsonDecode(payload);
    }
    if (payload case {'data': final Map<Object?, Object?> data}) payload = data;
    if (payload is! Map<Object?, Object?>) throw const FormatException('Kuaishou feed has an invalid shape');
    final result = _int(payload['result']);
    if (result != 1) throw KuaishouFeedRejected(result);
    final watching = payload['currentWatchingCount']?.toString().trim() ?? '';
    final feeds = payload['liveStreamFeeds'];
    return KuaishouFeedBatch(
      cursor: payload['cursor']?.toString() ?? '',
      pullDelay: Duration(seconds: (_int(payload['pullCycleSeconds']) ?? defaultPullDelay.inSeconds).clamp(1, 10)),
      messages: List.unmodifiable([
        if (feeds is List<Object?>)
          for (final feed in feeds) ?_comment(feed, emotes),
      ]),
      onlineViewers: watching.isEmpty ? null : parseAudienceNumberOrNull(watching),
    );
  }

  /// The largest time `DateTime` holds, in milliseconds either side of the
  /// epoch.
  static const int _maxMilliseconds = 8640000000000000;

  /// One feed entry as a chat message; null when it is not a comment, has no
  /// text, or has a time no `DateTime` can hold. The id is the entry's `id`,
  /// else a SHA-1 of `time`, the user id and the content joined by NULs; the
  /// message id is `kuaishou:` and that id. Its [LiveMessage.emotes] are the
  /// `[…]` codes [emotes] has.
  static LiveMessage? _comment(Object? feed, Map<String, String> emotes) {
    if (feed is! Map<Object?, Object?> || feed['type']?.toString().toLowerCase() != 'comment') return null;
    final content = feed['content']?.toString().trim() ?? '';
    if (content.isEmpty) return null;
    final time = feed['time'];
    if (time is double && !time.isFinite) return null;
    final timestamp = _int(time);
    if (timestamp != null && (timestamp < -_maxMilliseconds || timestamp > _maxMilliseconds)) return null;
    final author = feed['author'] is Map<Object?, Object?>
        ? feed['author']! as Map<Object?, Object?>
        : const <Object?, Object?>{};
    final userName = author['userName']?.toString().trim() ?? '';
    final userId = author['userId']?.toString() ?? '';
    final rawId = feed['id']?.toString().trim() ?? '';
    final nul = String.fromCharCode(0);
    final id = rawId.isNotEmpty ? rawId : sha1.convert(utf8.encode('$timestamp$nul$userId$nul$content')).toString();
    return LiveMessage.normalized(
      text: content,
      sender: MessageSender.normalized(userId: userId, userName: userName.isEmpty ? anonymousUserName : userName),
      color: LiveMessageColor.white,
      messageId: 'kuaishou:$id',
      sentAt: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
      emotes: emotes.isEmpty ? const [] : codeEmotes(content, emotes),
    );
  }

  /// The `[…]` codes of [text] that [table] has, each once, in order.
  static List<LiveEmote> codeEmotes(String text, Map<String, String> table) {
    final seen = <String>{};
    return [
      for (final match in _code.allMatches(text))
        if (table[match.group(0)!] case final url? when seen.add(match.group(0)!))
          LiveEmote(code: match.group(0)!, url: url),
    ];
  }

  static final RegExp _code = RegExp(r'\[[^\[\]\n]{1,16}\]');

  /// Numbers truncated, text parsed, anything else null.
  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
