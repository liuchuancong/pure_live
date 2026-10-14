import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
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
import 'package:live_sites/src/platforms/youtube/parsers/youtube_protobuf.dart';

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
    this.pinned = const [],
    this.reload = false,
    this.over = false,
    this.notice = '',
  });

  /// Continuation for the next request; empty keeps the previous one.
  final String continuation;

  /// Wait before the next request.
  final Duration pullDelay;

  /// The messages, in feed order.
  final List<LiveMessage> messages;

  /// The Super Chats the ticker still pins, as replayed super chats, oldest
  /// first. The session reports these from the first answer instead of its
  /// backlog of history.
  final List<LiveMessage> pinned;

  /// Whether [continuation] restarts the chat with its recent history (a
  /// `reloadContinuationData`): the session does not report such an answer.
  final bool reload;

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

  /// How often `updated_metadata` is asked for once joined. The page asks every
  /// 5 s; a number on screen needs less and each answer is a few KB, so this
  /// polls slower.
  static const Duration viewerInterval = Duration(seconds: 30);

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

  /// Parses one answer ([body] is the decoded JSON, [now] the time it came —
  /// a Super Chat without a platform time starts then). A body that is not an
  /// object throws [FormatException]. Actions become messages; an action that
  /// cannot be read is skipped without losing the others. The ticker items set
  /// how long each Super Chat shows and, in [YoutubeFeedBatch.pinned], the ones
  /// still pinned when the answer came.
  static YoutubeFeedBatch parse(Object? body, {DateTime? now}) {
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
    final actions = jsonList(chat['actions']);
    final received = now ?? DateTime.now();
    final pinned = _pinnedDurations(actions);
    final messages = [for (final action in actions) ?_action(action, pinned, received)];
    final next = jsonList(chat['continuations']);
    final entry = next.isEmpty ? null : _firstContinuation(next);
    final invalid = next.any((item) => jsonObject(item)?['invalidContinuationEndpoint'] != null);
    final token = entry?.token ?? '';
    return YoutubeFeedBatch(
      continuation: token,
      pullDelay: pullDelay(entry?.timeoutMs ?? 0),
      messages: List.unmodifiable(messages),
      pinned: List.unmodifiable(_stillPinned(actions, received)),
      reload: entry?.kind == 'reloadContinuationData',
      over: invalid || (token.isEmpty && messages.isEmpty),
    );
  }

  // Actions -------------------------------------------------------------------

  static LiveMessage? _action(Object? value, Map<String, Duration> pinned, DateTime received) {
    final action = jsonObject(value);
    if (action == null) return null;
    final add = jsonObject(action['addChatItemAction'])?['item'];
    if (add != null) return _item(add, pinned, received);
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

  static LiveMessage? _item(Object? value, Map<String, Duration> pinned, DateTime received) {
    final item = jsonObject(value);
    if (item == null) return null;
    final text = jsonObject(findFirst(item, 'liveChatTextMessageRenderer'));
    if (text != null) return _chat(text);
    final paid = jsonObject(findFirst(item, 'liveChatPaidMessageRenderer'));
    if (paid != null) return _superChat(paid, pinned, received);
    final sticker = jsonObject(findFirst(item, 'liveChatPaidStickerRenderer'));
    if (sticker != null) return _sticker(sticker, pinned, received);
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

  /// A paid message (Super Chat). Shown from its platform time (or [received]
  /// when it names none) for as long as the ticker pins it ([pinned], its
  /// `fullDurationSec`), else its colour tier, else the shortest display; or
  /// until [end] for a Super Chat still pinned on joining ([replayed]: B-22).
  /// Null without an amount and a message.
  static LiveMessage? _superChat(
    Map<String, dynamic> renderer,
    Map<String, Duration> pinned,
    DateTime received, {
    DateTime? end,
    bool replayed = false,
  }) {
    final header = jsonInt(renderer['headerBackgroundColor']);
    final body = jsonInt(renderer['bodyBackgroundColor']);
    final amount = label(renderer['purchaseAmountText']).trim();
    final text = label(renderer['message']);
    if (amount.isEmpty && text.isEmpty) return null;
    final id = jsonString(renderer['id']) ?? '';
    final time = _time(renderer['timestampUsec']);
    final start = time ?? received;
    final display = pinned[id] ?? _superChatDisplay(header);
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
        endTime: end ?? start.add(display),
        display: SuperChatDisplay(backgroundColor: _hexColor(header), backgroundBottomColor: _hexColor(body)),
      ),
      replayed: replayed,
      messageId: _id(renderer),
      sentAt: time,
    );
  }

  /// A Super Sticker, as a Super Chat: shown from its platform time (or
  /// [received]) for as long as the ticker pins it, else its colour tier, else
  /// the shortest display. Null without an amount, a message or a sticker.
  static LiveMessage? _sticker(
    Map<String, dynamic> renderer,
    Map<String, Duration> pinned,
    DateTime received,
  ) {
    final background = jsonInt(renderer['backgroundColor']);
    final amount = label(renderer['purchaseAmountText']).trim();
    final text = label(renderer['message']);
    if (amount.isEmpty && text.isEmpty) return null;
    final id = jsonString(renderer['id']) ?? '';
    final time = _time(renderer['timestampUsec']);
    final start = time ?? received;
    final display = pinned[id] ?? _superChatDisplay(background);
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
        endTime: start.add(display),
        display: SuperChatDisplay(backgroundColor: _hexColor(background)),
      ),
      messageId: _id(renderer),
      sentAt: time,
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

  /// The first continuation of `continuations`: its kind (the entry key, e.g.
  /// `timedContinuationData` or `reloadContinuationData`), its token and the
  /// `timeoutMs` it asks for (0 when it names none).
  static ({String kind, String token, int timeoutMs})? _firstContinuation(List<Object?> entries) {
    for (final entry in entries) {
      final map = jsonObject(entry);
      if (map == null) continue;
      for (final MapEntry(key: kind, value: item) in map.entries) {
        final data = jsonObject(item);
        final token = data == null ? null : jsonString(data['continuation']);
        if (token != null && token.isNotEmpty) {
          return (kind: kind, token: token, timeoutMs: jsonInt(data!['timeoutMs']) ?? 0);
        }
      }
    }
    return null;
  }

  /// How long the page pins each ticker item by its message id (`fullDurationSec`,
  /// when positive). A Super Chat's ticker item follows it in the same answer.
  static Map<String, Duration> _pinnedDurations(List<Object?> actions) => {
    for (final action in actions)
      if (jsonObject(action)?['addLiveChatTickerItemAction'] case {'item': final Map<Object?, Object?> item})
        for (final ticker in item.values)
          if (ticker case {'id': final String id, 'fullDurationSec': final int seconds}
              when id.isNotEmpty && seconds > 0)
            id: Duration(seconds: seconds),
  };

  /// The Super Chats the ticker still pins (B-22), as replayed super chats,
  /// oldest first: each `liveChatTickerPaidMessageItemRenderer` with time left
  /// (`durationSec`, positive) carries the paid message it stands for and is
  /// shown from its own time to [received] plus that time. An id seen before is
  /// left out; the session reports these from the first answer only.
  static List<LiveMessage> _stillPinned(List<Object?> actions, DateTime received) {
    final ids = <String>{};
    final found = <(DateTime, int, LiveMessage)>[];
    for (var index = 0; index < actions.length; index++) {
      final ticker = jsonObject(jsonObject(actions[index])?['addLiveChatTickerItemAction'])?['item'];
      if (jsonObject(ticker)?['liveChatTickerPaidMessageItemRenderer']
          case final Map<Object?, Object?> item) {
        final left = jsonInt(item['durationSec']);
        if (left == null || left <= 0) continue;
        final show = jsonObject(item['showItemEndpoint']);
        final renderer = jsonObject(jsonObject(show?['showLiveChatItemEndpoint'])?['renderer']);
        final paid = jsonObject(renderer?['liveChatPaidMessageRenderer']);
        if (paid == null) continue;
        final message = _superChat(paid, const {}, received, end: received.add(Duration(seconds: left)), replayed: true);
        if (message == null) continue;
        if (message.messageId.isNotEmpty && !ids.add(message.messageId)) continue;
        final start = (message.payload! as LiveSuperChatMessage).startTime!;
        found.add((start, index, message));
      }
    }
    found.sort((a, b) => a.$1.compareTo(b.$1) != 0 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final entry in found) entry.$3];
  }

  /// The concurrent viewers as an audience-update message.
  static LiveMessage audience(int viewers) => LiveMessage.normalized(
    type: LiveMessageType.audienceUpdate,
    color: LiveMessageColor.white,
    payload: LiveAudienceUpdate(kind: LiveAudienceSignalKind.onlineViewers, value: viewers),
  );

  /// A live viewer count of a `next` or `updated_metadata` answer: the digits of
  /// the first `videoViewCountRenderer` whose `isLive` is true ("1,250 watching
  /// now"), null when the answer has none (the broadcast ended: "N views").
  static int? viewers(Object? answer) {
    int? walk(Object? node) {
      if (node is Map) {
        if (jsonObject(node['videoViewCountRenderer']) case final renderer? when truthy(renderer['isLive'])) {
          final digits = label(renderer['viewCount']).replaceAll(RegExp('[^0-9]'), '');
          if (digits.isNotEmpty) return int.tryParse(digits);
        }
        for (final value in node.values) {
          if (walk(value) case final found?) return found;
        }
      } else if (node is List) {
        for (final value in node) {
          if (walk(value) case final found?) return found;
        }
      }
      return null;
    }

    return walk(answer);
  }

  /// A decoded `updated_metadata` answer (B-13): the live viewers, and the
  /// continuation of the next request (the first `continuation` entry with a text
  /// `continuation`). A body that is not an object throws [FormatException].
  static ({int? viewers, String? continuation}) parseMetadata(Object? body) {
    final map = jsonObject(body);
    if (map == null) throw const FormatException('YouTube updated_metadata has an invalid shape');
    String? token;
    if (jsonObject(map['continuation']) case final next?) {
      for (final value in next.values) {
        if (jsonString(fields(value)['continuation']) case final found? when found.isNotEmpty) {
          token = found;
          break;
        }
      }
    }
    return (viewers: viewers(map), continuation: token);
  }

  // The "Live chat" view ------------------------------------------------------

  static const int _chatField = 119693434;
  static const int _viewField = 16;
  static const int _viewKind = 1;
  static const int _topChat = 4;
  static const int _liveChat = 1;

  /// [continuation] in the page's "Live chat" view (every message) instead of the
  /// default "Top chat". The token is a base64url protobuf message (`=` written
  /// `%3D`); the view is field 1 of field 16 of its field 119693434: 4 for "Top
  /// chat", 1 for "Live chat". Returns [continuation] itself when it already
  /// names "Live chat", and null when it cannot be rewritten: not such a message,
  /// another view, the field more than once, or a fixed-width field or group on
  /// the way.
  static String? allChatContinuation(String continuation) {
    final Uint8List bytes;
    try {
      bytes = base64Url.decode(base64Url.normalize(continuation.replaceAll('%3D', '=')));
    } on FormatException {
      return null;
    }
    final chat = _single(bytes, _chatField);
    final viewMessage = chat == null ? null : _single(chat, _viewField);
    final view = viewMessage == null ? null : _viewOf(viewMessage);
    if (view == _liveChat) return continuation;
    if (view != _topChat) return null;
    final rewritten = _rewrite(bytes, const [_chatField, _viewField, _viewKind], _topChat, _liveChat);
    return rewritten == null ? null : base64Url.encode(rewritten).replaceAll('=', '%3D');
  }

  /// The only length-delimited field [number] of [bytes], or null.
  static Uint8List? _single(Uint8List bytes, int number) {
    final fields = _decode(bytes)?.fields.where((field) => field.number == number).toList();
    if (fields == null || fields.length != 1 || fields.single.wireType != youtubeProtoLengthDelimitedType) {
      return null;
    }
    return fields.single.value as Uint8List;
  }

  /// The view (field 1, a varint) of a view message, or null.
  static int? _viewOf(Uint8List view) {
    final fields = _decode(view)?.fields.where((field) => field.number == _viewKind).toList();
    if (fields == null || fields.length != 1 || fields.single.wireType != youtubeProtoVarintType) return null;
    return fields.single.value as int;
  }

  static YoutubeProtoMessage? _decode(Uint8List bytes) {
    try {
      return YoutubeProtoMessage.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  /// [bytes] with the varint at [path] (field numbers, outermost first) changed
  /// from [from] to [to]; the other fields are copied as they were. Null when a
  /// message on the path holds the field more than once, a field that is neither
  /// a varint nor length-delimited, or the varint is not [from].
  static Uint8List? _rewrite(Uint8List bytes, List<int> path, int from, int to) {
    final decoded = _decode(bytes);
    if (decoded == null) return null;
    final [number, ...rest] = path;
    if (decoded.fields.where((field) => field.number == number).length != 1) return null;
    final writer = YoutubeProtoWriter();
    for (final YoutubeProtoField(number: current, :wireType, :value) in decoded.fields) {
      switch (wireType) {
        case youtubeProtoVarintType:
          if (current == number) {
            if (rest.isNotEmpty || value != from) return null;
            writer.integer(current, to);
          } else {
            writer.integer(current, value as int);
          }
        case youtubeProtoLengthDelimitedType:
          if (current == number) {
            if (rest.isEmpty) return null;
            final inner = _rewrite(value as Uint8List, rest, from, to);
            if (inner == null) return null;
            writer.bytes(current, inner);
          } else {
            writer.bytes(current, value as Uint8List);
          }
        default:
          return null;
      }
    }
    return writer.toBytes();
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
