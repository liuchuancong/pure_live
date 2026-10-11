import 'dart:convert';

import 'package:live_sites/src/models/live_gift.dart';
import 'package:live_sites/src/models/live_message.dart';

/// TwitCasting's comment stream: an event socket handed out per broadcast.
///
/// The client asks `eventpubsuburl.php` for a socket URL with a form POST of
/// the broadcast's movie id, and the answer is a `wss://…/event.pubsub/…`
/// address signed for about an hour — which is why a session re-asks for it
/// on every connect and a reconnect after an hour gets a fresh signature
/// rather than a rejection. Nothing is sent after the handshake; the server
/// pushes JSON arrays of events, and an empty array when nothing else went
/// out for ten seconds.
///
/// [withGifts] appends `gift=1` to the socket URL, as the site's own player
/// does, so gift events arrive as well as comments.
abstract final class TwitcastingDanmakuProtocol {
  /// Where a broadcast's socket URL is asked for.
  static final Uri pubsubUrl = Uri.parse('https://twitcasting.tv/eventpubsuburl.php');

  /// The server's keep-alive: an empty array after this much silence.
  static const Duration keepAliveInterval = Duration(seconds: 10);

  /// Silence after which the site's player replaces the socket: three missed
  /// keep-alives.
  static const Duration silenceTimeout = Duration(seconds: 30);

  /// Handshake headers: the site's origin.
  static const Map<String, String> socketHeaders = {'origin': 'https://twitcasting.tv'};

  /// The largest `createdAt` a `DateTime` can hold, in milliseconds.
  static const int _maxEpochMilliseconds = 8640000000000000;

  /// The socket URL an `eventpubsuburl.php` answer carries, if it was one.
  ///
  /// The URL is validated because it is a WebSocket address taken from a
  /// response body: a `wss` on the site's own domain, with a signature.
  /// Anything else becomes "no danmaku" rather than a connection somewhere
  /// unintended.
  static Uri? socketUrl(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      return null;
    }
    final Object? root;
    try {
      root = jsonDecode(body);
    } on FormatException {
      return null;
    }
    final url = root is Map<String, Object?> ? root['url'] : null;
    final uri = url is String ? Uri.tryParse(url.trim()) : null;
    if (uri == null || uri.scheme != 'wss' || !_isSiteHost(uri.host)) {
      return null;
    }
    return withGifts(uri);
  }

  /// `socket` with `gift=1` added, as the player asks for it, so gift events
  /// arrive as well.
  static Uri withGifts(Uri socket) {
    final query = socket.query;
    return socket.replace(query: query.isEmpty ? 'gift=1' : '$query&gift=1');
  }

  static bool _isSiteHost(String host) => host == 'twitcasting.tv' || host.endsWith('.twitcasting.tv');

  /// The messages one pushed frame carries.
  ///
  /// A frame that is not JSON, the keep-alive `[]` and every event kind this
  /// build does not model give nothing — a busy broadcast pushes kinds nobody
  /// maps, and dropping them is not a failure. A single event outside an
  /// array is read like a one-event array, which is what the site's own
  /// player tolerates.
  static List<LiveMessage> decode(Object? data) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) {
      return const [];
    }
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const [];
    }
    return [
      for (final event in root is List ? root : [root]) ...[?comment(event), ...gift(event)],
    ];
  }

  /// A `comment` event as a chat message, or null for anything else.
  ///
  /// Anonymous comments are ordinary comments here: their author id is a
  /// token like `c:tw123` and their name is whatever the site shows, which is
  /// the name a viewer sees on the site itself.
  static LiveMessage? comment(Object? event) {
    if (event is! Map<String, Object?> || event['type'] != 'comment') {
      return null;
    }
    final text = event['message'];
    if (text is! String || text.trim().isEmpty) {
      return null;
    }
    final author = event['author'] is Map<String, Object?>
        ? event['author']! as Map<String, Object?>
        : const <String, Object?>{};
    final name = _text(author['name']);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name.isNotEmpty ? name : _text(author['screenName']),
      userId: _id(author['id']),
      message: text.trim(),
      id: _id(event['id']),
      sentAt: _sentAt(event['createdAt']),
    );
  }

  /// A `gift` event as a gift message, then the giver's words as a chat
  /// message.
  ///
  /// Two messages, because the site sends the item and the words together
  /// and no `comment` event repeats the words: dropping them would lose what
  /// the viewer actually said while donating. A notice the site draws
  /// without a sender (a campaign's score update) is skipped — it has no one
  /// to attribute it to.
  static List<LiveMessage> gift(Object? event) {
    if (event is! Map<String, Object?> || event['type'] != 'gift') {
      return const [];
    }
    final item = event['item'] is Map<String, Object?>
        ? event['item']! as Map<String, Object?>
        : const <String, Object?>{};
    final name = _text(item['name']);
    if (name.isEmpty || item['showsSenderInfo'] == false) {
      return const [];
    }
    final sender = event['sender'] is Map<String, Object?>
        ? event['sender']! as Map<String, Object?>
        : const <String, Object?>{};
    final senderName = _text(sender['name']);
    final userName = senderName.isNotEmpty ? senderName : _text(sender['screenName']);
    final userId = _id(sender['id']);
    final id = _id(event['id']);
    final sentAt = _sentAt(event['createdAt']);
    // The item's name carries its own count (`お茶ｘ10`), so the count field
    // stays 1 and the total is whatever the platform put in the name; the
    // event carries no price at all.
    final gift = LiveGift(name: name, count: 1);
    final words = _text(event['plainMessage']);
    final giftId = id;
    return [
      LiveMessage(
        type: LiveMessageType.gift,
        userName: userName,
        userId: userId,
        message: name,
        id: giftId,
        sentAt: sentAt,
        data: gift,
      ),
      if (words.isNotEmpty)
        LiveMessage(
          type: LiveMessageType.chat,
          userName: userName,
          userId: userId,
          message: words,
          id: giftId == null ? null : '$giftId:words',
          sentAt: sentAt,
        ),
    ];
  }

  static DateTime? _sentAt(Object? value) {
    if (value is! int || value <= 0 || value > _maxEpochMilliseconds) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  /// A numeric id as text; the site's anonymous ids are tokens and pass
  /// through unchanged.
  static String? _id(Object? value) => switch (value) {
    final int number => '$number',
    final String text when text.trim().isNotEmpty => text.trim(),
    _ => null,
  };
}
