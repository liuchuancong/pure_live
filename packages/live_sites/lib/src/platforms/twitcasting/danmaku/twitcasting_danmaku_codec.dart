import 'dart:convert';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/platforms/twitcasting/api/twitcasting_endpoints.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_json.dart';
import 'package:meta/meta.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What a comment connection of a live TwitCasting room needs (M5): the
/// channel and the broadcast, whose id `eventpubsuburl.php` takes as
/// `movie_id`. A room entry hands them over on the room's danmaku handle,
/// without a request; a channel that goes live again has a new broadcast and
/// needs a new room entry.
@immutable
final class TwitcastingDanmakuArgs {
  /// Creates the arguments.
  const TwitcastingDanmakuArgs({required this.channel, required this.movieId});

  /// The lower-case channel (screen id).
  final String channel;

  /// `movie.id` of the live broadcast.
  final int movieId;

  @override
  bool operator ==(Object other) =>
      other is TwitcastingDanmakuArgs && other.channel == channel && other.movieId == movieId;

  @override
  int get hashCode => Object.hash(channel, movieId);

  @override
  String toString() => 'TwitcastingDanmakuArgs($channel, $movieId)';
}

/// TwitCasting's comment stream, without I/O: the web player's
/// `eventpubsuburl.php` and `event.pubsub` socket (the archived v4's
/// spec/sites/twitcasting.md §7, checked against the recording
/// `fixtures/twitcasting/danmaku/S08-live` and the player script), as 3.x's
/// `TwitcastingDanmakuProtocol` read it.
///
/// - A broadcast's socket URL is asked for with a form POST of its
///   `movie_id`. The answer is a JSON object whose `url` is
///   `wss://<node>.twitcasting.tv/event.pubsub/v1/streams/<movie>/events`
///   with the query `token=…&n=…`; the token is signed for about an hour.
/// - The client sends nothing. The server pushes JSON arrays of events, and
///   an empty array when nothing else went out for [keepAliveInterval].
/// - `comment` events are chat. Gifts (`gift` events) come only to a URL
///   with `gift=1`, which the player adds and so does this client
///   ([withGifts], D07.7). The event gives no price: a gift is named and
///   pictured, never valued.
abstract final class TwitcastingDanmakuCodec {
  /// Where a broadcast's socket URL is asked for.
  static final Uri pubsubUrl = Uri.parse('https://twitcasting.tv/eventpubsuburl.php');

  /// The server's keep-alive: an empty array when nothing else was sent for
  /// this long (measured 2026-09-29). No client frame answers it — the
  /// period only paces the session's silence watchdog.
  static const Duration keepAliveInterval = Duration(seconds: 10);

  /// Silence after which the player replaces the socket
  /// (`DISCONNECTION_THRESHOLD`): three missed keep-alives.
  static const Duration silenceTimeout = Duration(seconds: 30);

  /// Reconnects without a live socket before the session gives up.
  static const int maxReconnects = 8;

  /// The base of the reconnect backoff, stepped once per failed run.
  static const Duration reconnectBaseDelay = Duration(seconds: 1);

  /// Handshake headers: the site's origin and the adapter's bare user agent,
  /// as 3.x sent them (no `Referer`).
  static const Map<String, String> socketHeaders = {'origin': TwitcastingEndpoints.origin, 'user-agent': 'Mozilla/5.0'};

  static const int _maxEpochMilliseconds = 8640000000000000;
  static final RegExp _signed = RegExp(r'''(?<=[?&])(token|n)=[^&#\s'"]*''');

  /// The broadcast of an [endpoint] address, or null for any other address.
  /// Every handshake turns the address into a freshly signed socket URL, as
  /// the player does.
  static int? movieOf(Uri address) {
    if (address.scheme != pubsubUrl.scheme || address.host != pubsubUrl.host || address.path != pubsubUrl.path) {
      return null;
    }
    final movie = int.tryParse(address.queryParameters['movie_id'] ?? '');
    return movie != null && movie > 0 ? movie : null;
  }

  /// The address a socket is asked for with [movieId]:
  /// `eventpubsuburl.php?movie_id=…`.
  static Uri endpoint(int movieId) => pubsubUrl.replace(queryParameters: {'movie_id': '$movieId'});

  /// The socket URL of an `eventpubsuburl.php` [body] answered with [status]:
  /// a `wss` URL on a TwitCasting host. A status that is not 200 is what the
  /// status gate says; a body that is not that JSON, or names no such URL,
  /// is api-changed.
  static Uri socketUrl(String body, {required int status}) {
    TwitcastingJson.checkStatus(status, 'eventpubsuburl.php');
    final root = TwitcastingJson.decode(body, 'eventpubsuburl.php');
    final url = root is Map ? root['url'] : null;
    final uri = url is String ? Uri.tryParse(url.trim()) : null;
    if (uri == null || uri.scheme != 'wss' || !TwitcastingEndpoints.isSiteHost(uri.host.toLowerCase())) {
      throw const TwitcastingFailure(TwitcastingFailureKind.apiChanged, 'eventpubsuburl.php answered no socket URL');
    }
    return uri;
  }

  /// [socket] with `gift=1` added to its query, as the player asks for it
  /// (`eventpubsuburl.php`'s answer `+ "&gift=1"`), so `gift` events come
  /// too (D07.7). The signature (`token`, `n`) is kept as signed.
  static Uri withGifts(Uri socket) {
    final query = socket.query;
    return socket.replace(query: query.isEmpty ? 'gift=1' : '$query&gift=1');
  }

  /// [text] with the values of the socket URL's signature (`token`, `n`)
  /// left out: a failed handshake names the whole URL.
  static String redact(String text) => text.replaceAllMapped(_signed, (match) => '${match[1]}=…');

  /// The chat and gifts of one pushed frame (text, or UTF-8 bytes): every
  /// `comment` event ([comment]) and `gift` event ([gift]) in order. A frame
  /// that is not JSON, the keep-alive `[]` and every other event give
  /// nothing; a single event outside an array is read like a one-event array
  /// (as the archived v4 did).
  static List<LiveMessage> decode(Object? data) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null) return const [];
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

  /// A `gift` event (アイテム, D07.7) as a gift message, then its words as
  /// chat; nothing for any other event, for a notice the player draws
  /// without a sender (`item.showsSenderInfo` false: the campaign's score
  /// notices) or an item without a name.
  ///
  /// - [LiveGift.name] `item.name` as the platform writes it (`お茶ｘ10`:
  ///   the number is part of the item), [LiveGift.count] 1;
  ///   [LiveGift.iconUrl] `item.image` when https; no price or value (the
  ///   event has none; the 🍡 of `score_items` is the broadcast's score, not
  ///   money) and no combo (the platform has none);
  /// - the sender as a [comment]'s author (`sender`), the id `id` (text),
  ///   the time `createdAt`;
  /// - the sender's words (`plainMessage`, which no `comment` repeats) are a
  ///   white chat line after the gift, with the id `<id>:words`.
  static List<LiveMessage> gift(Object? event) {
    if (event is! Map || event['type'] != 'gift') return const [];
    final item = event['item'] is Map ? event['item'] as Map<Object?, Object?> : const <Object?, Object?>{};
    final name = TwitcastingJson.text(item['name']);
    if (name.isEmpty || item['showsSenderInfo'] == false) return const [];
    final sender = event['sender'] is Map ? event['sender'] as Map<Object?, Object?> : const <Object?, Object?>{};
    final image = Uri.tryParse(TwitcastingJson.text(item['image']));
    final gift = LiveGift.of(
      name: name,
      iconUrl: image != null && image.isScheme('https') && image.host.isNotEmpty ? '$image' : null,
    );
    final created = event['createdAt'];
    final sentAt = _time(created);
    final id = _id(event['id']);
    final userName = _text(sender['name']).isNotEmpty ? _text(sender['name']) : _text(sender['screenName']);
    final words = TwitcastingJson.text(event['plainMessage']);
    return [
      LiveMessage.normalized(
        type: LiveMessageType.gift,
        sender: MessageSender.normalized(userId: _id(sender['id']), userName: userName),
        text: '${gift.name} ×${gift.count}',
        color: LiveMessageColor.white,
        messageId: id,
        sentAt: sentAt,
        payload: gift,
      ),
      if (words.isNotEmpty)
        LiveMessage.normalized(
          sender: MessageSender.normalized(userId: _id(sender['id']), userName: userName),
          text: words,
          color: LiveMessageColor.white,
          messageId: id.isEmpty ? '' : '$id:words',
          sentAt: sentAt,
        ),
    ];
  }

  /// A `comment` event as white chat, or null for any other event:
  ///
  /// - the text is `message`, trimmed; blank or not a string: null;
  /// - the name is the author's `name`, else `screenName`; the user id is
  ///   the author's `id` (anonymous comments have ids like `c:tw123`);
  /// - the message id is `id` (a number), the time `createdAt` (ms); a
  ///   time that is not positive or out of `DateTime`'s range is left out.
  ///
  /// `numComments`, `isAnonymous` and the author's picture and `grade` are
  /// not read.
  static LiveMessage? comment(Object? event) {
    if (event is! Map || event['type'] != 'comment') return null;
    final text = event['message'];
    if (text is! String || text.trim().isEmpty) return null;
    final author = event['author'] is Map ? event['author'] as Map<Object?, Object?> : const <Object?, Object?>{};
    final name = TwitcastingJson.text(author['name']);
    final created = event['createdAt'];
    return LiveMessage.normalized(
      sender: MessageSender.normalized(
        userId: _id(author['id']),
        userName: name.isNotEmpty ? name : TwitcastingJson.text(author['screenName']),
      ),
      text: text.trim(),
      color: LiveMessageColor.white,
      messageId: _id(event['id']),
      sentAt: _time(created),
    );
  }

  static DateTime? _time(Object? created) => created is int && created > 0 && created <= _maxEpochMilliseconds
      ? DateTime.fromMillisecondsSinceEpoch(created)
      : null;

  static String _text(Object? value) => value is String ? value.trim() : '';

  static String _id(Object? value) => switch (value) {
    final int number => '$number',
    final String text => text.trim(),
    _ => '',
  };
}
