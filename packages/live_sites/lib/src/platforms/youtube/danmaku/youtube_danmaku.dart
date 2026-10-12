import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/common/protobuf/protobuf.dart';
import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_parser.dart';
import 'package:meta/meta.dart';

/// What the youtube chat connection polls: the broadcast's video id.
@immutable
final class YouTubeDanmakuArgs {
  /// Creates the arguments.
  const new(this.videoId);

  /// The broadcast on air (the room id in this adapter).
  final String videoId;
}

/// What a watch page's `next` answer says about the broadcast's chat.
@immutable
final class YouTubeChatEntry {
  /// Creates the entry.
  const new({this.continuation, this.replay = false, this.viewers});

  /// The first continuation of the chat, or null when the answer names none.
  final String? continuation;

  /// Whether the chat is a replay (the broadcast is over).
  final bool replay;

  /// Concurrent viewers, or null when the answer has no live count.
  final int? viewers;

  /// Whether the broadcast has a live chat to poll.
  bool get live => continuation != null && !replay;
}

/// One `live_chat/get_live_chat` answer.
@immutable
final class YouTubeChatPoll {
  /// Creates the answer.
  const new({
    this.messages = const [],
    this.pinned = const [],
    this.continuation,
    this.reload = false,
    this.timeout,
    this.notice = '',
  });

  /// Chat lines, super chats, notices, gifts and retractions, in the order of
  /// the actions.
  final List<LiveMessage> messages;

  /// The super chats the ticker still pins, oldest first; reported only from
  /// the first answer.
  final List<LiveMessage> pinned;

  /// The continuation of the next request; null when the chat is over.
  final String? continuation;

  /// Whether [continuation] is a `reloadContinuationData` (its answer starts
  /// the chat over with the recent history).
  final bool reload;

  /// The wait the server asks for (`timeoutMs`), or null.
  final Duration? timeout;

  /// When the chat is over: the site's message, or empty.
  final String notice;

  /// Whether the chat is over: no continuation follows.
  bool get ended => continuation == null;
}

/// YouTube's live chat (the web client's InnerTube calls, anonymous), without
/// I/O:
///
/// 1. `next` for the broadcast names the chat's first continuation and the
///    live viewer count;
/// 2. `live_chat/get_live_chat` is polled with the continuation of the previous
///    answer; each answer names the next continuation and the wait, and one
///    without a continuation ends the chat;
/// 3. `updated_metadata` gives the viewer count again.
///
/// Archived from the reference and mapped onto this tree's models: the audience
/// is a [LiveAudienceUpdate], a super chat is the reduced [LiveSuperChat], a
/// gift is a [LiveGift] of one, a removal is a `recall` and a membership a
/// `notice` with a string `data`; a colour is the int white and custom emoji
/// keep their [LiveEmote]. The header/body colours, the sender face, the sticker
/// picture and the replay mark have no field here.
abstract final class YouTubeDanmakuProtocol {
  /// The watch page's `next`.
  static Uri get nextEndpoint => YouTubeParser.apiUrl('next');

  /// The chat's `live_chat/get_live_chat`.
  static Uri get chatEndpoint => YouTubeParser.apiUrl('live_chat/get_live_chat');

  /// The watch page's `updated_metadata`.
  static Uri get metadataEndpoint => YouTubeParser.apiUrl('updated_metadata');

  /// Request headers: the web client's InnerTube headers.
  static Map<String, String> get headers => YouTubeParser.apiHeaders;

  /// Longest wait for one answer.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Wait after a failed request.
  static const Duration retryDelay = Duration(seconds: 2);

  /// Shortest wait between two polls.
  static const Duration minimumDelay = Duration(seconds: 1);

  /// Longest wait between two polls, also when the server names none.
  static const Duration maximumDelay = Duration(seconds: 5);

  /// Failed requests while joining before the connection ends.
  static const int startAttempts = 3;

  /// Failed polls in a row, once joined, before the connection ends.
  static const int maxFailures = 8;

  /// How often `updated_metadata` is asked for once joined.
  static const Duration viewerInterval = Duration(seconds: 30);

  /// How long a super chat the page does not pin stays highlighted.
  static const Duration unpinnedDisplay = Duration(minutes: 1);

  /// How long the page pins a super chat by its tier colour.
  static const Map<int, Duration> tierDisplay = {
    0xFF1565C0: Duration.zero,
    0xFF00B8D4: Duration.zero,
    0xFF00BFA5: Duration(minutes: 2),
    0xFFFFB300: Duration(minutes: 5),
    0xFFE65100: Duration(minutes: 10),
    0xFFC2185B: Duration(minutes: 30),
    0xFFD00000: Duration(hours: 1),
  };

  static const int _maxMicros = 8640000000000000000;
  static final RegExp _digits = RegExp(r'^\d+$');

  /// The `next` request body for [videoId].
  static Map<String, Object?> nextBody(String videoId) => YouTubeParser.nextBody(videoId);

  /// The `get_live_chat` request body for [continuation].
  static Map<String, Object?> chatBody(String continuation) => YouTubeParser.chatBody(continuation);

  /// The first `updated_metadata` request body for [videoId].
  static Map<String, Object?> metadataBody(String videoId) => YouTubeParser.nextBody(videoId);

  /// A later `updated_metadata` request body for the previous [continuation].
  static Map<String, Object?> metadataContinuationBody(String continuation) => YouTubeParser.chatBody(continuation);

  /// The wait before the next poll: [timeout] within [minimumDelay] and
  /// [maximumDelay], and [maximumDelay] when there is none.
  static Duration pollDelay(Duration? timeout) => switch (timeout) {
    null => maximumDelay,
    final wait when wait > maximumDelay => maximumDelay,
    final wait when wait < minimumDelay => minimumDelay,
    final wait => wait,
  };

  /// The concurrent viewers as a message.
  static LiveMessage audience(int viewers) => LiveMessage(
    type: LiveMessageType.audienceUpdate,
    userName: '',
    message: '',
    color: white,
    data: LiveAudienceUpdate(onlineViewers: viewers),
  );

  // The chat's view ----------------------------------------------------------

  static const int _chatField = 119693434;
  static const int _viewField = 16;
  static const int _viewKind = 1;
  static const int _topChat = 4;
  static const int _liveChat = 1;

  /// [continuation] in the "Live chat" view (every message) instead of the
  /// default "Top chat". The token is a protobuf message in base64url; the view
  /// is field 1 of field 16 of its field 119693434. Returns [continuation] when
  /// it already names "Live chat", and null when it cannot be rewritten.
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

  static int? _viewOf(Uint8List view) {
    final fields = _decode(view)?.where((field) => field.number == _viewKind).toList();
    if (fields == null || fields.length != 1 || fields.single.wireType != ProtoMessage.varintType) return null;
    return fields.single.value as int;
  }

  static Uint8List? _single(Uint8List bytes, int number) {
    final fields = _decode(bytes)?.where((field) => field.number == number).toList();
    if (fields == null || fields.length != 1 || fields.single.wireType != ProtoMessage.lengthDelimitedType) {
      return null;
    }
    return fields.single.value as Uint8List;
  }

  static List<ProtoField>? _decode(Uint8List bytes) {
    try {
      return ProtoMessage.decode(bytes).fields;
    } on FormatException {
      return null;
    }
  }

  static Uint8List? _rewrite(Uint8List bytes, List<int> path, int from, int to) {
    final fields = _decode(bytes);
    if (fields == null) return null;
    final [number, ...rest] = path;
    if (fields.where((field) => field.number == number).length != 1) return null;
    final writer = ProtoWriter();
    for (final ProtoField(number: current, :wireType, :value) in fields) {
      switch (wireType) {
        case ProtoMessage.varintType:
          if (current == number) {
            if (rest.isNotEmpty || value != from) return null;
            writer.integer(current, to);
          } else {
            writer.integer(current, value as int);
          }
        case ProtoMessage.lengthDelimitedType:
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

  // Answers ------------------------------------------------------------------

  /// Reads a decoded `next` answer: the first `liveChatRenderer` (its
  /// `isReplay` and its first continuation) and the first live viewer count.
  static YouTubeChatEntry watch(Object? answer) {
    if (answer is! Map<String, Object?>) throw const FormatException('youtube next: not a JSON object');
    Map<Object?, Object?>? chat;
    void walk(Object? node) {
      if (chat != null) return;
      if (node is Map) {
        if (node['liveChatRenderer'] case final Map<Object?, Object?> renderer) {
          chat = renderer;
          return;
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    walk(answer);
    final renderer = chat;
    return YouTubeChatEntry(
      continuation: renderer == null ? null : _continuation(renderer['continuations'])?.token,
      replay: renderer?['isReplay'] == true,
      viewers: _liveViewers(answer),
    );
  }

  /// Reads a decoded `updated_metadata` answer: the live viewers and the next
  /// continuation.
  static ({int? viewers, String? continuation}) metadata(Object? answer) {
    if (answer is! Map<String, Object?>) throw const FormatException('youtube updated_metadata: not a JSON object');
    String? token;
    if (answer['continuation'] case final Map<Object?, Object?> next) {
      for (final value in next.values) {
        if (value case {'continuation': final String continuation}) {
          token = continuation;
          break;
        }
      }
    }
    return (viewers: _liveViewers(answer), continuation: token);
  }

  static int? _liveViewers(Object? root) {
    int? walk(Object? node) {
      if (node is Map) {
        if (node['videoViewCountRenderer'] case final Map<Object?, Object?> count when count['isLive'] == true) {
          if (_viewers(count['viewCount']) case final viewers?) return viewers;
        }
        for (final value in node.values) {
          if (walk(value) case final viewers?) return viewers;
        }
      } else if (node is List) {
        for (final value in node) {
          if (walk(value) case final viewers?) return viewers;
        }
      }
      return null;
    }

    return walk(root);
  }

  static int? _viewers(Object? text) {
    final digits = _plain(text).replaceAll(RegExp('[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Reads a decoded `get_live_chat` answer.
  static YouTubeChatPoll chat(Object? answer, {DateTime? now}) {
    if (answer is! Map<String, Object?>) throw const FormatException('youtube get_live_chat: not a JSON object');
    final contents = answer['continuationContents'];
    final chat = contents is Map ? contents['liveChatContinuation'] : null;
    if (chat is! Map) {
      final message = answer['contents'];
      return YouTubeChatPoll(notice: message is Map ? _plain(_map(message['messageRenderer'])['text']) : '');
    }
    final actions = chat['actions'] is List ? chat['actions'] as List : const <Object?>[];
    final pinned = _pinned(actions);
    final received = now ?? DateTime.now();
    final next = _continuation(chat['continuations']);
    return YouTubeChatPoll(
      messages: List.unmodifiable([for (final action in actions) ?_message(action, pinned, received)]),
      pinned: List.unmodifiable(_stillPinned(actions, received)),
      continuation: next?.token,
      reload: next?.kind == 'reloadContinuationData',
      timeout: next?.timeout,
    );
  }

  /// The super chats the ticker items still pin, oldest first (a replayed super
  /// chat from its own time to `durationSec` after [received]).
  static List<LiveMessage> _stillPinned(List<Object?> actions, DateTime received) {
    final ids = <String>{};
    final found = <LiveMessage>[];
    for (final action in actions) {
      if (action case {
        'addLiveChatTickerItemAction': {
          'item': {'liveChatTickerPaidMessageItemRenderer': final Map<Object?, Object?> item},
        },
      }) {
        final left = item['durationSec'];
        if (left is! int || left <= 0) continue;
        if (item['showItemEndpoint'] case {
          'showLiveChatItemEndpoint': {'renderer': {'liveChatPaidMessageRenderer': final Map<Object?, Object?> paid}},
        }) {
          final message = _superChat(paid, const {}, received, end: received.add(Duration(seconds: left)));
          final id = message?.id ?? '';
          if (message == null || (id.isNotEmpty && !ids.add(id))) continue;
          found.add(message);
        }
      }
    }
    DateTime start(LiveMessage message) => (message.data! as LiveSuperChat).startTime ?? received;
    final order = [...found.indexed]
      ..sort((a, b) {
        final by = start(a.$2).compareTo(start(b.$2));
        return by != 0 ? by : a.$1.compareTo(b.$1);
      });
    return [for (final (_, message) in order) message];
  }

  static ({String kind, String token, Duration? timeout})? _continuation(Object? continuations) {
    if (continuations is! List || continuations.isEmpty) return null;
    final first = continuations.first;
    if (first is! Map) return null;
    for (final MapEntry(:key, :value) in first.entries) {
      if (value case {'continuation': final String token}) {
        final timeout = value['timeoutMs'];
        return (
          kind: '$key',
          token: token,
          timeout: timeout is int && timeout >= 0 ? Duration(milliseconds: timeout) : null,
        );
      }
    }
    return null;
  }

  static Map<String, Duration> _pinned(List<Object?> actions) => {
    for (final action in actions)
      if (action case {'addLiveChatTickerItemAction': {'item': final Map<Object?, Object?> item}})
        for (final ticker in item.values)
          if (ticker case {'id': final String id, 'fullDurationSec': final int seconds}
              when id.isNotEmpty && seconds > 0)
            id: Duration(seconds: seconds),
  };

  static LiveMessage? _message(Object? action, Map<String, Duration> pinned, DateTime received) {
    if (action is! Map) return null;
    if (action['addChatItemAction'] case {'item': final Map<Object?, Object?> item}) {
      return _item(item, pinned, received);
    }
    for (final kind in const ['removeChatItemAction', 'markChatItemAsDeletedAction']) {
      if (action[kind] case {'targetItemId': final String id} when id.isNotEmpty) {
        return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', color: white, id: id);
      }
    }
    for (final kind in const ['removeChatItemByAuthorAction', 'markChatItemsByAuthorAsDeletedAction']) {
      if (action[kind] case {'externalChannelId': final String id} when id.isNotEmpty) {
        return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', color: white, userId: id);
      }
    }
    return null;
  }

  static LiveMessage? _item(Map<Object?, Object?> item, Map<String, Duration> pinned, DateTime received) {
    if (item['liveChatTextMessageRenderer'] case final Map<Object?, Object?> text) return _chatLine(text);
    if (item['liveChatPaidMessageRenderer'] case final Map<Object?, Object?> paid) {
      return _superChat(paid, pinned, received);
    }
    if (item['giftMessageViewModel'] case final Map<Object?, Object?> gift) return _gift(gift);
    if (item['liveChatPaidStickerRenderer'] case final Map<Object?, Object?> sticker) {
      return _sticker(sticker, pinned, received);
    }
    if (item['liveChatMembershipItemRenderer'] case final Map<Object?, Object?> member) return _membership(member);
    if (item['liveChatSponsorshipsGiftPurchaseAnnouncementRenderer'] case final Map<Object?, Object?> gift) {
      final header = _map(_map(gift['header'])['liveChatSponsorshipsHeaderRenderer']);
      return _notice(gift, _plain(header['authorName']), _plain(header['primaryText']).trim());
    }
    if (item['liveChatSponsorshipsGiftRedemptionAnnouncementRenderer'] case final Map<Object?, Object?> gift) {
      return _notice(gift, _plain(gift['authorName']), _runs(gift['message']), kind: 'gifted_subscription');
    }
    return null;
  }

  static LiveMessage? _chatLine(Map<Object?, Object?> renderer) {
    final text = _runs(renderer['message']);
    if (text.isEmpty) return null;
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: _plain(renderer['authorName']),
      userId: _string(renderer['authorExternalChannelId']),
      message: text,
      id: _string(renderer['id']),
      sentAt: _time(renderer['timestampUsec']),
      color: white,
      emotes: customEmoji(renderer['message']),
    );
  }

  static LiveMessage? _superChat(
    Map<Object?, Object?> paid,
    Map<String, Duration> pinned,
    DateTime received, {
    DateTime? end,
  }) {
    final amount = _plain(paid['purchaseAmountText']).trim();
    final text = _runs(paid['message']);
    if (amount.isEmpty && text.isEmpty) return null;
    final id = _string(paid['id']);
    final time = _time(paid['timestampUsec']);
    final start = time ?? received;
    final tier = tierDisplay[paid['headerBackgroundColor']] ?? Duration.zero;
    final display = pinned[id] ?? (tier > Duration.zero ? tier : unpinnedDisplay);
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: _plain(paid['authorName']),
      userId: _string(paid['authorExternalChannelId']),
      message: text,
      id: id,
      sentAt: time,
      color: white,
      emotes: customEmoji(paid['message']),
      data: LiveSuperChat(
        message: text,
        price: _amountOf(amount),
        priceText: amount,
        startTime: start,
        endTime: end ?? start.add(display),
      ),
    );
  }

  static LiveMessage? _sticker(Map<Object?, Object?> sticker, Map<String, Duration> pinned, DateTime received) {
    final amount = _plain(sticker['purchaseAmountText']).trim();
    final label = _accessibility(_map(sticker['sticker']));
    if (amount.isEmpty && label.isEmpty) return null;
    final id = _string(sticker['id']);
    final time = _time(sticker['timestampUsec']);
    final start = time ?? received;
    final tier = tierDisplay[sticker['backgroundColor']] ?? Duration.zero;
    final display = pinned[id] ?? (tier > Duration.zero ? tier : unpinnedDisplay);
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: _plain(sticker['authorName']),
      userId: _string(sticker['authorExternalChannelId']),
      message: label,
      id: id,
      sentAt: time,
      color: white,
      data: LiveSuperChat(
        message: label,
        price: _amountOf(amount),
        priceText: amount,
        startTime: start,
        endTime: start.add(display),
      ),
    );
  }

  static LiveMessage? _membership(Map<Object?, Object?> member) {
    final primary = _plain(member['headerPrimaryText']).trim();
    final subtext = _plain(member['headerSubtext']).trim();
    final header = primary.isEmpty ? subtext : (subtext.isEmpty ? primary : '$primary（$subtext）');
    if (header.isEmpty) return null;
    final text = _runs(member['message']);
    return _notice(member, _plain(member['authorName']), text.isEmpty ? header : '$header：$text');
  }

  static LiveMessage? _gift(Map<Object?, Object?> gift) {
    final text = _content(gift['text']);
    if (text.isEmpty) return null;
    final name = text.startsWith(_giftVerb) ? text.substring(_giftVerb.length).trim() : '';
    return LiveMessage(
      type: LiveMessageType.gift,
      userName: _content(gift['authorName']),
      userId: _string(gift['authorExternalChannelId']),
      message: name.isEmpty ? text : '$name ×1',
      id: _string(gift['id']),
      sentAt: _time(gift['timestampUsec']),
      color: white,
      data: LiveGift(name: name.isEmpty ? text : name, count: 1),
    );
  }

  static const String _giftVerb = 'sent ';

  static LiveMessage? _notice(
    Map<Object?, Object?> renderer,
    String name,
    String text, {
    String kind = 'subscription',
  }) {
    if (text.isEmpty) return null;
    return LiveMessage(
      type: LiveMessageType.notice,
      userName: name,
      userId: _string(renderer['authorExternalChannelId']),
      message: name.trim().isEmpty ? text : '${name.trim()} $text',
      id: _string(renderer['id']),
      sentAt: _time(renderer['timestampUsec']),
      color: white,
      data: kind,
    );
  }

  static String _runs(Object? message) {
    final runs = message is Map ? message['runs'] : null;
    if (runs is! List) return '';
    final out = StringBuffer();
    for (final run in runs) {
      if (run is! Map) continue;
      if (run['text'] case final String text) {
        out.write(text);
      } else if (run['emoji'] case final Map<Object?, Object?> emoji) {
        out.write(_emoji(emoji));
      }
    }
    return out.toString().trim();
  }

  /// The channel's custom emoji among a message's runs: each shortcut with its
  /// largest picture, once per shortcut.
  static List<LiveEmote> customEmoji(Object? message) {
    final runs = message is Map ? message['runs'] : null;
    if (runs is! List) return const [];
    final seen = <String>{};
    return [
      for (final run in runs)
        if (run case {'emoji': final Map<Object?, Object?> emoji} when emoji['isCustomEmoji'] == true)
          if ((_emoji(emoji), _largest(_map(emoji['image'])['thumbnails'])) case (final code, final url)
              when code.isNotEmpty && url.isNotEmpty && seen.add(code))
            LiveEmote(code: code, url: url),
    ];
  }

  static String _emoji(Map<Object?, Object?> emoji) {
    final shortcuts = emoji['shortcuts'];
    final shortcut = shortcuts is List && shortcuts.isNotEmpty ? _string(shortcuts.first) : '';
    if (emoji['isCustomEmoji'] == true) return shortcut;
    final id = _string(emoji['emojiId']);
    return id.isNotEmpty ? id : shortcut;
  }

  static String _plain(Object? node) {
    if (node is! Map) return '';
    if (node['simpleText'] case final String text) return text;
    final runs = node['runs'];
    if (runs is! List) return '';
    return [
      for (final run in runs)
        if (run is Map && run['text'] is String) run['text']! as String,
    ].join();
  }

  static String _accessibility(Object? node) => switch (node) {
    {'accessibility': {'accessibilityData': {'label': final String label}}} => label.trim(),
    _ => '',
  };

  static String _largest(Object? images) {
    if (images is! List || images.isEmpty) return '';
    final url = switch (images.last) {
      {'url': final String url} => url.trim(),
      _ => '',
    };
    if (url.startsWith('https://')) return url;
    if (url.startsWith('//')) return 'https:$url';
    return '';
  }

  static String _content(Object? node) => switch (node) {
    {'content': final String content} => content.trim(),
    _ => '',
  };

  /// The whole number in a super chat's amount text (`$ 5.00` to 5).
  static int _amountOf(String amount) {
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(amount);
    final value = match == null ? null : double.tryParse(match.group(0)!);
    return value == null ? 0 : value.round();
  }

  static String _string(Object? value) => value is String ? value : '';

  static Map<Object?, Object?> _map(Object? value) => value is Map<Object?, Object?> ? value : const {};

  static DateTime? _time(Object? value) {
    final micros = switch (value) {
      final int number => number,
      final String text when _digits.hasMatch(text.trim()) => int.tryParse(text.trim()),
      _ => null,
    };
    if (micros == null || micros <= 0 || micros > _maxMicros) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros);
  }

  /// White, the danmaku default.
  static const int white = 0xFFFFFF;
}
