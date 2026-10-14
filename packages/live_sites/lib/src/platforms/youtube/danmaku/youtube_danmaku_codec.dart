import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_display/live_super_chat_display.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One answer of the live chat poll: the continuation for the next request
/// (empty keeps the previous), the wait before it ([pullDelay], the server's
/// `timeoutMs` clamped to 1–5 s), the messages in feed order, and the chat-over
/// signal ([over] with its [notice] text).
final class YoutubeFeedBatch {
  /// Creates the batch.
  const YoutubeFeedBatch({
    required this.continuation,
    required this.pullDelay,
    required this.messages,
    this.over = false,
    this.notice = '',
  });

  /// Continuation for the next request; empty keeps the previous one.
  final String continuation;

  /// Wait before the next request.
  final Duration pullDelay;

  /// The messages, in feed order.
  final List<LiveMessage> messages;

  /// Whether the chat has ended (no `liveChatContinuation` left).
  final bool over;

  /// The chat-over notice text, when [over].
  final String notice;

  /// What the session reports for this answer: the messages.
  List<LiveMessage> get reported => messages;
}

/// YouTube's live chat, without I/O: the incremental `get_live_chat` feed,
/// polled over HTTP. Text, super chats, super stickers, membership items and
/// gifts become messages; deletions become retractions. No socket, no heartbeat.
abstract final class YoutubeDanmakuCodec {
  /// Waits before the second and third try of the first request.
  static const List<Duration> startRetryDelays = [Duration(milliseconds: 600), Duration(milliseconds: 1400)];

  /// Failed requests in a row that are retried; the next one ends the feed.
  static const int maxFailures = 8;

  /// Start attempts before the feed is said not to have begun.
  static const int startAttempts = 3;

  /// The per-request timeout.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// The shortest poll interval the server may ask for.
  static const Duration minPullDelay = Duration(seconds: 1);

  /// The longest poll interval (the default when the server names none).
  static const Duration maxPullDelay = Duration(seconds: 5);

  /// The name of a commenter without one.
  static const String anonymousUserName = 'YouTube';

  /// Wait before the next request when the feed gives no interval.
  static Duration backoff(int failures) => Duration(seconds: 1 << (failures - 1).clamp(0, 3));

  /// The [timeoutMs] the server asks for, clamped to [minPullDelay]–
  /// [maxPullDelay]; [maxPullDelay] when it names none (0).
  static Duration pullDelay(int timeoutMs) {
    if (timeoutMs <= 0) return maxPullDelay;
    final seconds = Duration(milliseconds: timeoutMs);
    if (seconds < minPullDelay) return minPullDelay;
    if (seconds > maxPullDelay) return maxPullDelay;
    return seconds;
  }

  /// Parses one answer ([body] is the decoded JSON). A body that is not an
  /// object throws [FormatException]. Actions become messages; an action that
  /// cannot be read is skipped without losing the others.
  static YoutubeFeedBatch parse(Object? body) {
    final map = jsonObject(body);
    if (map == null) throw const FormatException('YouTube live chat has an invalid shape');
    final continuation = fields(map['continuationContents']);
    final chat = jsonObject(continuation['liveChatContinuation']);
    if (chat == null) {
      final renderer = jsonObject(findFirst(map, 'messageRenderer'));
      final notice = renderer == null ? '' : label(findFirst(renderer, 'text'));
      return YoutubeFeedBatch(
        continuation: '',
        pullDelay: maxPullDelay,
        messages: const [],
        over: true,
        notice: notice,
      );
    }
    final messages = [for (final action in jsonList(chat['actions'])) ?_action(action)];
    final next = jsonList(chat['continuations']);
    final continuationToken = next.isEmpty ? '' : _continuation(next);
    final timeoutMs = next.isEmpty ? 0 : _timeoutMs(next);
    final invalid = next.any((entry) => jsonObject(entry)?['invalidContinuationEndpoint'] != null);
    return YoutubeFeedBatch(
      continuation: continuationToken,
      pullDelay: pullDelay(timeoutMs),
      messages: List.unmodifiable(messages),
      over: invalid || (continuationToken.isEmpty && messages.isEmpty),
    );
  }

  // Actions -------------------------------------------------------------------

  static LiveMessage? _action(Object? value) {
    final action = jsonObject(value);
    if (action == null) return null;
    final add = jsonObject(action['addChatItemAction'])?['item'];
    if (add != null) return _item(add);
    final deleted = jsonObject(action['markChatItemAsDeletedAction']) ?? jsonObject(action['removeChatItemAction']);
    if (deleted != null) {
      final target = jsonString(deleted['targetId']) ?? jsonString(deleted['targetItemId']);
      if (target != null) return _retraction(LiveRetraction(messageId: target));
    }
    final byAuthor =
        jsonObject(action['markChatItemsByAuthorAsDeletedAction']) ??
        jsonObject(action['removeChatItemByAuthorAction']);
    if (byAuthor != null) {
      final author = jsonString(byAuthor['externalChannelId']);
      if (author != null) return _retraction(LiveRetraction(userId: author));
    }
    return null;
  }

  static LiveMessage? _item(Object? value) {
    final item = jsonObject(value);
    if (item == null) return null;
    final text = jsonObject(findFirst(item, 'liveChatTextMessageRenderer'));
    if (text != null) return _chat(text);
    final paid = jsonObject(findFirst(item, 'liveChatPaidMessageRenderer'));
    if (paid != null) return _superChat(paid);
    final sticker = jsonObject(findFirst(item, 'liveChatPaidStickerRenderer'));
    if (sticker != null) return _sticker(sticker);
    final membership = jsonObject(findFirst(item, 'liveChatMembershipItemRenderer'));
    if (membership != null) return _membership(membership);
    final gift = jsonObject(findFirst(item, 'giftMessageViewModel'));
    if (gift != null) return _gift(gift);
    return null;
  }

  static LiveMessage _chat(Map<String, dynamic> renderer) {
    return LiveMessage.normalized(
      text: label(renderer['message']),
      sender: _sender(renderer),
      color: LiveMessageColor.white,
      emotes: _emotes(renderer['message']),
      messageId: _id(renderer),
      sentAt: _time(renderer['timestampUsec']),
    );
  }

  static LiveMessage _superChat(Map<String, dynamic> renderer) {
    final header = jsonInt(renderer['headerBackgroundColor']);
    final body = jsonInt(renderer['bodyBackgroundColor']);
    final amount = label(renderer['purchaseAmountText']).trim();
    final text = label(renderer['message']);
    final start = _time(renderer['timestampUsec']);
    final end = start?.add(_superChatDisplay(header));
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      text: text,
      sender: _sender(renderer),
      color: header == null ? LiveMessageColor.white : LiveMessageColor.numberToColor(header),
      payload: LiveSuperChatMessage(
        messageId: _id(renderer),
        userName: label(renderer['authorName']),
        faceUrl: thumbnailUrl(renderer['authorPhoto']),
        text: text,
        price: SuperChatPrice(amount: _priceAmount(amount), displayText: amount),
        startTime: start,
        endTime: end,
        display: SuperChatDisplay(backgroundColor: _hexColor(header), backgroundBottomColor: _hexColor(body)),
      ),
      messageId: _id(renderer),
      sentAt: start,
    );
  }

  static LiveMessage _sticker(Map<String, dynamic> renderer) {
    final background = jsonInt(renderer['backgroundColor']);
    final amount = label(renderer['purchaseAmountText']).trim();
    final text = label(renderer['message']);
    final start = _time(renderer['timestampUsec']);
    final end = start?.add(_superChatDisplay(background));
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      text: text.isEmpty ? amount : text,
      sender: _sender(renderer),
      color: LiveMessageColor.white,
      payload: LiveSuperChatMessage(
        messageId: _id(renderer),
        userName: label(renderer['authorName']),
        faceUrl: thumbnailUrl(renderer['authorPhoto']),
        text: text,
        price: SuperChatPrice(amount: _priceAmount(amount), displayText: amount),
        startTime: start,
        endTime: end,
        display: SuperChatDisplay(backgroundColor: _hexColor(background)),
      ),
      messageId: _id(renderer),
      sentAt: start,
    );
  }

  static LiveMessage _membership(Map<String, dynamic> renderer) {
    final parts = [label(renderer['headerPrimaryText']), label(renderer['headerSubtext']), label(renderer['message'])];
    return LiveMessage.normalized(
      type: LiveMessageType.membershipJoin,
      text: parts.where((part) => part.isNotEmpty).join(' · '),
      sender: _sender(renderer),
      color: LiveMessageColor.white,
      messageId: _id(renderer),
      sentAt: _time(renderer['timestampUsec']),
    );
  }

  static LiveMessage _gift(Map<String, dynamic> model) {
    final text = _viewContent(model['text']);
    final author = _viewContent(model['authorName']);
    final giftId = jsonString(model['id']) ?? '';
    return LiveMessage.normalized(
      type: LiveMessageType.gift,
      text: text,
      sender: MessageSender.normalized(userName: author.isEmpty ? anonymousUserName : author),
      color: LiveMessageColor.white,
      payload: LiveGift(giftId: giftId, name: text, iconUrl: _firstSource(model['giftImage'])),
      messageId: giftId.isEmpty ? '' : 'youtube:$giftId',
    );
  }

  static LiveMessage _retraction(LiveRetraction target) =>
      LiveMessage.normalized(type: LiveMessageType.retraction, color: LiveMessageColor.white, payload: target);

  // Fields --------------------------------------------------------------------

  static MessageSender _sender(Map<String, dynamic> renderer) {
    final name = label(renderer['authorName']);
    final id = jsonString(renderer['authorExternalChannelId']) ?? '';
    final avatar = thumbnailUrl(renderer['authorPhoto']);
    return MessageSender.normalized(
      userId: id,
      userName: name.isEmpty ? anonymousUserName : name,
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }

  /// The emoji of a message's runs: one [LiveEmote] per run carrying an
  /// `emoji`, keyed by its first shortcut (else its id) and pointing at its
  /// image.
  static List<LiveEmote> _emotes(Object? message) {
    final runs = jsonList(jsonObject(message)?['runs']);
    final emotes = <LiveEmote>[];
    for (final run in runs) {
      final emoji = jsonObject(jsonObject(run)?['emoji']);
      if (emoji == null) continue;
      final shortcuts = jsonList(emoji['shortcuts']).map(jsonString).nonNulls.toList();
      final code = shortcuts.isNotEmpty ? shortcuts.first : (jsonString(emoji['emojiId']) ?? '');
      final url = lastThumbnail(emoji['image']);
      if (code.isEmpty || url.isEmpty) continue;
      emotes.add(LiveEmote(code: code, url: url));
    }
    return emotes;
  }

  static String _id(Map<String, dynamic> renderer) {
    final id = jsonString(renderer['id']);
    return id == null ? '' : 'youtube:$id';
  }

  static DateTime? _time(Object? usec) {
    final micros = jsonInt(usec);
    if (micros == null || micros <= 0 || micros > _maxMicroseconds) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }

  /// How long the page pins a Super Chat, by the tier its header colour names
  /// (YouTube's table): the two lowest tiers are not pinned (a minute, shorter
  /// than any pin, so the app still lists them briefly); the rest from 2 minutes
  /// (green) up to 1 hour (red, ≥100 USD). An unknown colour reads as unpinned.
  static Duration _superChatDisplay(int? argb) => switch (argb) {
    0xFF00BFA5 => const Duration(minutes: 2),
    0xFFFFB300 => const Duration(minutes: 5),
    0xFFE65100 => const Duration(minutes: 10),
    0xFFC2185B => const Duration(minutes: 30),
    0xFFD00000 => const Duration(hours: 1),
    _ => const Duration(minutes: 1),
  };

  /// The whole number in a purchase-amount text, for ordering and comparing;
  /// null when the text names none. The leading digit run (with its thousands
  /// commas) is the amount: `$5.00` → `5` (the cents are a separate run),
  /// `₩10,000` → `10000`. The answer carries no number of its own.
  static int? _priceAmount(String text) {
    final run = RegExp(r'\d[\d,]*').firstMatch(text)?.group(0)?.replaceAll(',', '');
    return run == null ? null : int.tryParse(run);
  }

  /// An ARGB int as the `#RRGGBB` a [SuperChatDisplay] names; empty when there
  /// is no colour.
  static String _hexColor(int? argb) {
    if (argb == null) return '';
    final color = LiveMessageColor.numberToColor(argb);
    String two(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${two(color.r)}${two(color.g)}${two(color.b)}';
  }

  static String _continuation(List<Object?> entries) {
    for (final entry in entries) {
      final map = jsonObject(entry);
      if (map == null) continue;
      for (final value in map.values) {
        final data = jsonObject(value);
        final token = data == null ? null : jsonString(data['continuation']);
        if (token != null && token.isNotEmpty) return token;
      }
    }
    return '';
  }

  static int _timeoutMs(List<Object?> entries) {
    for (final entry in entries) {
      final map = jsonObject(entry);
      if (map == null) continue;
      for (final value in map.values) {
        final data = jsonObject(value);
        final timeout = data == null ? null : jsonInt(data['timeoutMs']);
        if (timeout != null) return timeout;
      }
    }
    return 0;
  }

  static String _firstSource(Object? image) {
    final sources = jsonList(findFirst(image, 'sources'));
    for (final source in sources) {
      final url = imageUrl(jsonObject(source)?['url']);
      if (url.isNotEmpty) return url;
    }
    return thumbnailUrl(image);
  }

  /// The text of a view-model string node: either an InnerTube label
  /// (`simpleText`/`runs`) or the view-model `{content: "…"}` shape.
  static String _viewContent(Object? node) {
    final direct = label(node);
    if (direct.isNotEmpty) return direct;
    return jsonString(fields(node)['content'])?.trim() ?? '';
  }

  static const int _maxMicroseconds = 8640000000000000;
}
