import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/live_gift/live_gift.dart';
import 'package:live_sites/src/models/live_message/live_message.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_parser.dart';
import 'package:meta/meta.dart';

/// What Kick's chat needs to open: the chatroom and channel ids and the
/// channel slug. The chatroom id is not the channel id, so both travel.
@immutable
final class KickDanmakuArgs {
  /// A chat subscription target.
  const new({required this.chatroomId, required this.channelId, required this.slug});

  /// `chatroom.id`: the Pusher channel `chatrooms.<id>.v2` carries the chat.
  final int chatroomId;

  /// The channel id, naming the broadcast and Kicks channels.
  final int channelId;

  /// The lower-cased channel slug.
  final String slug;

  @override
  String toString() => 'KickDanmakuArgs($slug, chatroom $chatroomId, channel $channelId)';
}

/// What one Pusher frame means for the connection.
@immutable
final class KickFrame {
  /// Creates the reading.
  const new({this.established = false, this.joined = false, this.ping = false, this.error, this.messages = const []});

  /// The server opened the session: subscribe now.
  final bool established;

  /// The chat channel's subscription was confirmed.
  final bool joined;

  /// The server pinged: answer [KickDanmakuProtocol.pong].
  final bool ping;

  /// A Pusher error (or a refused subscription): end the session.
  final String? error;

  /// Messages to report.
  final List<LiveMessage> messages;
}

/// Kick's public chat over Pusher (pure_live_TV's `KickDanmaku`), without
/// I/O.
///
/// - One WebSocket of JSON text frames to Kick's Pusher app. The server opens
///   with `pusher:connection_established`; the client then subscribes to the
///   public channels `chatrooms.<chatroomId>.v2` (chat and moderation),
///   `channel.<channelId>` (the broadcast's own events) and
///   `channel_<channelId>` (Kicks sent to the channel, `KicksGifted`), without
///   auth.
/// - `pusher_internal:subscription_succeeded` of the chat channel is the
///   join. `pusher:ping` is answered `pusher:pong`; the client pings too.
/// - Events carry their payload as a JSON string in `data`.
///
/// Archived from the reference and mapped onto this tree's models: a per-user
/// chat colour stays an int, a paid Kicks gift counts as the platform's paid
/// currency (this model has no `kicks` unit), the sender's Kick level and a
/// whole-chat clear have no field here and are dropped, and a deleted line or
/// banned viewer becomes a [LiveMessageType.recall] naming it by id or user.
abstract final class KickDanmakuProtocol {
  /// Kick's Pusher endpoint (app key, protocol 7, as the web client).
  static final Uri endpoint = Uri.parse(
    'wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679?protocol=7&client=js&version=8.4.0&flash=false',
  );

  /// Handshake headers: the site's origin and the desktop UA of every Kick
  /// request.
  static const Map<String, String> socketHeaders = {'origin': KickParser.origin, 'user-agent': KickParser.userAgent};

  /// Client ping period (the server's activity timeout is 120 s).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// The client ping.
  static final String ping = jsonEncode({'event': 'pusher:ping', 'data': <String, Object?>{}});

  /// The answer to the server's ping.
  static final String pong = jsonEncode({'event': 'pusher:pong', 'data': <String, Object?>{}});

  /// The chat channel of [args].
  static String chatChannel(KickDanmakuArgs args) => 'chatrooms.${args.chatroomId}.v2';

  /// The broadcast channel of [args].
  static String broadcastChannel(KickDanmakuArgs args) => 'channel.${args.channelId}';

  /// The channel of [args]'s Kicks (`KicksGifted`).
  static String kicksChannel(KickDanmakuArgs args) => 'channel_${args.channelId}';

  /// The subscription to [channel].
  static String subscribe(String channel) => jsonEncode({
    'event': 'pusher:subscribe',
    'data': {'auth': '', 'channel': channel},
  });

  /// [args] if they can be subscribed to: positive ids and a slug.
  static KickDanmakuArgs? checked(KickDanmakuArgs args) {
    final slug = KickParser.normalizeSlug(args.slug);
    return args.chatroomId > 0 && args.channelId > 0 && slug != null
        ? KickDanmakuArgs(chatroomId: args.chatroomId, channelId: args.channelId, slug: slug)
        : null;
  }

  /// What one frame of [args]'s connection means.
  static KickFrame read(Object? data, KickDanmakuArgs args) {
    final text = switch (data) {
      final String text => text,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null || text.length > 256 * 1024) return const KickFrame();
    final envelope = _object(text);
    if (envelope == null) return const KickFrame();
    final event = envelope['event'];
    final channel = envelope['channel'];
    switch (event) {
      case 'pusher:connection_established':
        return const KickFrame(established: true);
      case 'pusher:ping':
        return const KickFrame(ping: true);
      case 'pusher:error' || 'pusher_internal:subscription_error':
        return KickFrame(error: '$event ${_text(_object(envelope['data'])?['message'] ?? envelope['data'])}'.trim());
      case 'pusher_internal:subscription_succeeded':
        return KickFrame(joined: channel == chatChannel(args));
    }
    if (event is! String) return const KickFrame();
    final payload = _object(envelope['data']);
    if (payload == null) return const KickFrame();
    if (channel == broadcastChannel(args)) {
      return KickFrame(messages: [?broadcastEvent(event, payload, args)]);
    }
    if (channel == kicksChannel(args)) {
      return KickFrame(messages: [if (_name(event) == 'KicksGifted') ?kicks(payload)]);
    }
    if (channel != chatChannel(args)) return const KickFrame();
    return KickFrame(messages: [?chatEvent(event, payload, args)]);
  }

  /// One event of the chat channel, or null for one that shows nothing (polls,
  /// pins removed, chat modes, …). A cleared chat (`ChatroomClearEvent`) has no
  /// whole-chat form in this model and is dropped.
  static LiveMessage? chatEvent(String event, Map<String, Object?> data, KickDanmakuArgs args) =>
      switch (_name(event)) {
        'ChatMessageEvent' || 'ChatMessageSentEvent' => message(data, args),
        'MessageDeletedEvent' => _recall(_text(_object(data['message'])?['id'] ?? data['message_id']), null),
        'UserBannedEvent' => _recall(null, _text(_object(data['user'])?['id'])),
        'SubscriptionEvent' => _subscription(data, args),
        'GiftedSubscriptionsEvent' => _giftedSubscriptions(data, args),
        'StreamHostEvent' => _host(data, args),
        'PinnedMessageCreatedEvent' => _pinned(data),
        'KicksGifted' => kicks(data),
        _ => null,
      };

  /// The notice of the broadcast's end.
  static const String streamEndedNotice = '直播已结束';

  /// One event of the broadcast channel: the end of the broadcast shows a
  /// notice; the rest nothing.
  static LiveMessage? broadcastEvent(String event, Map<String, Object?> data, KickDanmakuArgs args) {
    if (_name(event) != 'StopStreamBroadcast') return null;
    final channel = _object(_object(data['livestream'])?['channel']);
    final id = channel == null ? null : _int(channel['id']);
    if (id != null && id != args.channelId) return null;
    return _notice(streamEndedNotice, 'system');
  }

  /// A chat line (`ChatMessageEvent`; `type` `message` or `reply`, an empty
  /// one counts as `message`): the content with inline emotes
  /// (`[emote:<id>:<name>]`) shown by name, the sender's name, id and colour,
  /// and the line's id and time. The sender's Kick level has no field in this
  /// model and is not carried. A line of another chatroom, without sender or
  /// text, or of another type is null.
  static LiveMessage? message(Map<String, Object?> data, KickDanmakuArgs args) {
    final legacy = _object(data['message']);
    final line = legacy ?? data;
    final room = _int(line['chatroom_id']);
    if (room != null && room != args.chatroomId) return null;
    final type = _text(line['type']);
    if (type.isNotEmpty && type != 'message' && type != 'reply') return null;
    final sender = _object(data['sender']) ?? _object(data['user']);
    final name = _text(sender?['username']);
    final content = _content(legacy == null ? line['content'] : line['message'] ?? line['content']);
    if (name.isEmpty || content.isEmpty || content.length > 16000 || name.length > 256) return null;
    final identity = _object(sender?['identity']);
    final color = int.tryParse(_text(identity?['color']).replaceFirst('#', ''), radix: 16);
    return LiveMessage(
      type: LiveMessageType.chat,
      userName: name,
      userId: _text(sender?['id']),
      message: content,
      id: _text(line['id']),
      sentAt: _time(line['created_at']),
      color: color == null || color < 0 || color > 0xFFFFFF ? null : color,
    );
  }

  /// Kicks sent to the streamer (`KicksGifted`, Kick's paid gifts): with a
  /// message it is a super chat of `gift.amount` Kicks, kept for the gift's
  /// `pinned_time` seconds (or by amount, as [superChatDuration]); without one
  /// a gift of one [LiveGift] worth `amount` Kicks. Kicks count as the
  /// platform's paid currency — this model has no `kicks` unit.
  static LiveMessage? kicks(Map<String, Object?> data) {
    final sender = _object(data['sender']);
    final gift = _object(data['gift']);
    final name = _text(sender?['username']);
    final amount = max(_int(gift?['amount']) ?? 0, 0);
    if (name.isEmpty || gift == null) return null;
    final text = _content(data['message']);
    final giftName = _text(gift['name']);
    final label = giftName.isEmpty ? 'Kicks' : giftName;
    final id = _text(data['gift_transaction_id']);
    final sentAt = _time(data['created_at']);
    if (text.isEmpty) {
      return LiveMessage(
        type: LiveMessageType.gift,
        userName: name,
        userId: _text(sender?['id']),
        message: '$label ×1',
        id: id.isEmpty ? null : id,
        sentAt: sentAt,
        data: LiveGift(name: label, count: 1, unitPrice: amount, totalValue: amount > 0 ? amount : null),
      );
    }
    final start = sentAt ?? DateTime.now();
    final pinned = _int(gift['pinned_time']) ?? 0;
    return LiveMessage(
      type: LiveMessageType.superChat,
      userName: name,
      userId: _text(sender?['id']),
      message: text,
      id: id.isEmpty ? null : id,
      sentAt: sentAt,
      data: LiveSuperChat(
        message: text,
        price: amount,
        priceText: amount > 0 ? '$amount Kicks' : label,
        startTime: start,
        endTime: start.add(pinned > 0 && pinned <= 86400 ? Duration(seconds: pinned) : superChatDuration(amount)),
      ),
    );
  }

  /// How long a Kicks super chat stays without its own pin time: the first
  /// steps of Bilibili's super chats by amount (100 Kicks is one dollar).
  static Duration superChatDuration(int amount) => switch (amount) {
    >= 10000 => const Duration(minutes: 30),
    >= 5000 => const Duration(minutes: 5),
    >= 1000 => const Duration(minutes: 2),
    _ => const Duration(minutes: 1),
  };

  static LiveMessage? _subscription(Map<String, Object?> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final name = _text(data['username']);
    if (name.isEmpty) return null;
    final months = _int(data['months']) ?? 0;
    return _notice(months > 1 ? '$name 订阅了 $months 个月' : '$name 订阅了频道', 'subscription', user: name);
  }

  static LiveMessage? _giftedSubscriptions(Map<String, Object?> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final gifter = _text(data['gifter_username']);
    final names = [if (data['gifted_usernames'] case final List<Object?> list) ...list];
    final count = names.length;
    if (count == 0) return null;
    final giver = gifter.isEmpty ? '匿名用户' : gifter;
    return _notice(
      count == 1 ? '$giver 向 ${_text(names.first)} 赠送了订阅' : '$giver 赠送了 $count 个订阅',
      'subscription',
      user: gifter,
    );
  }

  static LiveMessage? _host(Map<String, Object?> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final host = _text(data['host_username']);
    if (host.isEmpty) return null;
    final viewers = _int(data['number_viewers']) ?? 0;
    final note = _content(data['optional_message']);
    final text = viewers > 0 ? '$host 带着 $viewers 位观众来了' : '$host 转播了本频道';
    return _notice(note.isEmpty ? text : '$text：$note', 'raid', user: host);
  }

  static LiveMessage? _pinned(Map<String, Object?> data) {
    final line = _object(data['message']);
    final author = _text(_object(line?['sender'])?['username']);
    final text = _content(line?['content']);
    if (text.isEmpty) return null;
    return _notice(author.isEmpty ? '置顶消息：$text' : '置顶了 $author 的消息：$text', 'system', user: author);
  }

  static LiveMessage _notice(String text, String kind, {String user = ''}) =>
      LiveMessage(type: LiveMessageType.notice, userName: user, message: text, data: kind);

  /// The recall of a deleted line (by id) or a banned viewer (by user id). The
  /// clear-all case has no form here and never reaches this.
  static LiveMessage? _recall(String? messageId, String? userId) {
    if (messageId != null && messageId.isNotEmpty) {
      return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', id: messageId);
    }
    if (userId != null && userId.isNotEmpty) {
      return LiveMessage(type: LiveMessageType.recall, userName: '', message: '', userId: userId);
    }
    return null;
  }

  static bool _inRoom(Map<String, Object?> data, KickDanmakuArgs args) {
    final room = _int(data['chatroom_id']);
    return room == null || room == args.chatroomId;
  }

  /// `App\Events\ChatMessageEvent` → `ChatMessageEvent`.
  static String _name(String event) => event.substring(event.lastIndexOf(r'\') + 1);

  static final RegExp _emote = RegExp(r'\[emote:\d+:([^\]\s]+)\]');

  static String _content(Object? value) =>
      (value is String ? value : '').replaceAllMapped(_emote, (match) => match.group(1)!).trim();

  static DateTime? _time(Object? value) {
    if (value is int) return value > 0 && value < 8640000000 ? DateTime.fromMillisecondsSinceEpoch(value * 1000) : null;
    return value is String ? DateTime.tryParse(value) : null;
  }

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };

  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim());

  /// A JSON object, or the object a JSON text holds.
  static Map<String, Object?>? _object(Object? value) {
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    if (value is! String || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? decoded.map((key, value) => MapEntry('$key', value)) : null;
    } on FormatException {
      return null;
    }
  }
}
