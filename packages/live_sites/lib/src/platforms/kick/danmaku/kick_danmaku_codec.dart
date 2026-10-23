import 'dart:convert';
import 'dart:math';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/message/message_sender/message_sender.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_price/live_super_chat_price.dart';
import 'package:live_sites/src/platforms/kick/api/kick_endpoints.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// What one Pusher frame means for the connection: the handshake facts the
/// session acts on and the messages to report.
final class KickFrame {
  /// A frame read by [KickDanmakuCodec.read]; every fact defaults to nothing.
  const KickFrame({
    this.established = false,
    this.joined = false,
    this.ping = false,
    this.error,
    this.messages = const [],
  });

  /// The server opened the Pusher session: subscribe now.
  final bool established;

  /// The chat channel's subscription was confirmed (the join).
  final bool joined;

  /// The server pinged: answer `pusher:pong`.
  final bool ping;

  /// A Pusher error, a refused subscription or the server's activity
  /// timeout: reconnect.
  final String? error;

  /// Messages to report.
  final List<LiveMessage> messages;
}

/// Kick's public chat over Pusher, without I/O: the frame texts in, the
/// frames' meaning out ([read]), one JSON text frame at a time.
///
/// - One WebSocket of JSON text frames to Kick's Pusher app. The server
///   opens with `pusher:connection_established`; the client then subscribes
///   to the public channels `chatrooms.<chatroomId>.v2` (chat and
///   moderation), `channel.<channelId>` (the broadcast's own events) and
///   `channel_<channelId>` (the Kicks sent to the channel), without auth.
///   The chatroom id is not the channel id, so [KickDanmakuArgs] carries
///   both as the room answer named them.
/// - `pusher_internal:subscription_succeeded` of the chat channel is the
///   join. `pusher:ping` is answered `pusher:pong`; the client pings too.
/// - Events carry their payload as a JSON string in `data`, and their class
///   name behind a namespace (`App\Events\ChatMessageEvent` — the part after
///   the last backslash names the event).
abstract final class KickDanmakuCodec {
  /// Kick's Pusher endpoint (the app key, protocol 7, as the web client).
  static final Uri endpoint = KickEndpoints.pusherEndpoint();

  /// Handshake headers: the site's origin and the desktop UA.
  static const Map<String, String> socketHeaders = KickEndpoints.socketHeaders;

  /// Client ping period (the server's activity timeout is twice it plus
  /// slack; a silent socket is replaced).
  static const Duration heartbeatInterval = Duration(seconds: 30);

  /// How long the server has to confirm the chat subscription after the
  /// socket opened.
  static const Duration joinTimeout = Duration(seconds: 10);

  /// How long a frame may be before it is dropped.
  static const int maxFrameLength = 256 * 1024;

  /// The client ping.
  static final String ping = jsonEncode({'event': 'pusher:ping', 'data': <String, Object?>{}});

  /// The answer to the server's ping.
  static final String pong = jsonEncode({'event': 'pusher:pong', 'data': <String, Object?>{}});

  /// The chat channel of [args].
  static String chatChannel(KickDanmakuArgs args) => 'chatrooms.${args.chatroomId}.v2';

  /// The broadcast channel of [args].
  static String broadcastChannel(KickDanmakuArgs args) => 'channel.${args.channelId}';

  /// The channel of [args]'s Kicks (`KicksGifted` lives there).
  static String kicksChannel(KickDanmakuArgs args) => 'channel_${args.channelId}';

  /// The subscription to [channel].
  static String subscribe(String channel) => jsonEncode({
    'event': 'pusher:subscribe',
    'data': {'auth': '', 'channel': channel},
  });

  /// The three subscriptions of [args], in join order.
  static List<String> subscribeAll(KickDanmakuArgs args) => [
    subscribe(chatChannel(args)),
    subscribe(broadcastChannel(args)),
    subscribe(kicksChannel(args)),
  ];

  /// What one frame of [args]'s connection means.
  static KickFrame read(Object? data, KickDanmakuArgs args) {
    final text = switch (data) {
      final String value => value,
      final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
      _ => null,
    };
    if (text == null || text.length > maxFrameLength) return const KickFrame();
    final envelope = jsonOrText(text);
    if (envelope == null) return const KickFrame();
    final event = envelope['event'];
    final channel = envelope['channel'];
    switch (event) {
      case 'pusher:connection_established':
        return const KickFrame(established: true);
      case 'pusher:ping':
        return const KickFrame(ping: true);
      case 'pusher:error' || 'pusher_internal:subscription_error' || 'activity_timeout':
        final detail = jsonOrText(envelope['data'])?['message'];
        return KickFrame(error: '$event ${detail ?? ''}'.trim());
      case 'pusher_internal:subscription_succeeded':
        return KickFrame(joined: channel == chatChannel(args));
    }
    if (event is! String) return const KickFrame();
    final payload = jsonOrText(envelope['data']);
    if (payload == null) return const KickFrame();
    if (channel == broadcastChannel(args)) {
      if (eventName(event) != 'StopStreamBroadcast') return const KickFrame();
      final endedChannel = jsonInt(jsonObject(jsonObject(payload['livestream'])?['channel'])?['id']);
      if (endedChannel != null && endedChannel != args.channelId) return const KickFrame();
      return KickFrame(messages: [streamEnded]);
    }
    if (channel == kicksChannel(args)) {
      if (eventName(event) != 'KicksGifted') return const KickFrame();
      final message = kicks(payload);
      return KickFrame(messages: message == null ? const [] : [message]);
    }
    if (channel != chatChannel(args)) return const KickFrame();
    final message = chatEvent(event, payload, args);
    return KickFrame(messages: message == null ? const [] : [message]);
  }

  /// The notice message emitted when the platform says the broadcast ended.
  static LiveMessage get streamEnded =>
      LiveMessage.normalized(type: LiveMessageType.system, text: 'Broadcast ended', color: LiveMessageColor.white);

  /// One event of the chat channel, or null for one that shows nothing
  /// (polls, pins removed, chat modes, …).
  static LiveMessage? chatEvent(String event, Map<String, dynamic> data, KickDanmakuArgs args) {
    switch (eventName(event)) {
      case 'ChatMessageEvent':
      case 'ChatMessageSentEvent':
        return message(data, args);
      case 'MessageDeletedEvent':
        return retraction(messageId: _text(jsonObject(data['message'])?['id'] ?? data['message_id']));
      case 'UserBannedEvent':
        return retraction(userId: _text(jsonObject(data['user'])?['id']));
      case 'ChatroomClearEvent':
        return _retract(LiveRetraction.of(all: true));
      case 'SubscriptionEvent':
        return subscription(data, args);
      case 'GiftedSubscriptionsEvent':
        return giftedSubscriptions(data, args);
      case 'StreamHostEvent':
        return host(data, args);
      case 'PinnedMessageCreatedEvent':
        return pinned(data);
      case 'KicksGifted':
        return kicks(data);
      default:
        return null;
    }
  }

  /// A chat line (`ChatMessageEvent`; `type` `message` or `reply`, an empty
  /// one counts as `message`): the content with inline emotes
  /// (`[emote:<id>:<name>]`) shown by name, the sender's name, id and colour
  /// (the identity's `#RRGGBB`), the line's id and time, and the sender's
  /// Kick level (the `level` badge of `badges_v2`). A line of another
  /// chatroom, without sender or text, is null.
  static LiveMessage? message(Map<String, dynamic> data, KickDanmakuArgs args) {
    final legacy = jsonObject(data['message']);
    final line = legacy ?? data;
    final room = jsonInt(line['chatroom_id']);
    if (room != null && room != args.chatroomId) return null;
    final type = _text(line['type']);
    if (type.isNotEmpty && type != 'message' && type != 'reply') return null;
    final sender = jsonObject(data['sender']) ?? jsonObject(data['user']);
    final name = _text(sender?['username']);
    final content = _content(legacy == null ? line['content'] : line['message'] ?? line['content']);
    if (name.isEmpty || content.isEmpty || content.length > 16000 || name.length > 256) return null;
    final identity = jsonObject(sender?['identity']);
    final color = _color(identity?['color']);
    return LiveMessage.normalized(
      text: content,
      sender: MessageSender.normalized(
        userId: _text(sender?['id']),
        userName: name,
        userLevel: _level(identity?['badges_v2']),
        nameColor: color,
      ),
      color: color,
      messageId: 'kick:${_text(line['id'])}',
      sentAt: jsonMessageTime(line['created_at']),
    );
  }

  /// Kicks sent to the streamer (`KicksGifted`, Kick's paid gifts, 100 Kicks
  /// to a US dollar): with a message it is a super chat of `gift.amount`
  /// Kicks kept for the gift's `pinned_time` seconds (or [superChatDuration]
  /// by amount); without one a gift `Hell Yeah ×1`-style with a [LiveGift].
  static LiveMessage? kicks(Map<String, dynamic> data) {
    final sender = jsonObject(data['sender']);
    final gift = jsonObject(data['gift']);
    final name = _text(sender?['username']);
    final amount = max(jsonInt(gift?['amount']) ?? 0, 0);
    if (name.isEmpty || gift == null) return null;
    final text = _content(data['message']);
    final giftName = _text(gift['name']);
    final rawId = _text(data['gift_transaction_id']);
    final messageId = rawId.isEmpty ? '' : 'kick:$rawId';
    final sentAt = jsonMessageTime(data['created_at']);
    final userId = _text(sender?['id']);
    if (text.isEmpty) {
      final display = giftName.isEmpty ? 'Kicks' : giftName;
      return LiveMessage.normalized(
        type: LiveMessageType.gift,
        text: '$display ×1',
        sender: MessageSender.normalized(userId: userId, userName: name),
        color: LiveMessageColor.white,
        messageId: messageId,
        sentAt: sentAt,
        payload: LiveGift.of(
          giftId: display,
          name: display,
          value: LiveGiftValue.of(
            unit: LiveGiftUnit.kicks,
            unitPrice: amount > 0 ? amount.toDouble() : null,
            totalValue: amount > 0 ? amount.toDouble() : null,
          ),
        ),
      );
    }
    final start = sentAt ?? DateTime.now();
    final pinned = jsonInt(gift['pinned_time']) ?? 0;
    return LiveMessage.normalized(
      type: LiveMessageType.superChat,
      text: text,
      sender: MessageSender.normalized(userId: userId, userName: name),
      color: LiveMessageColor.white,
      messageId: messageId,
      sentAt: sentAt,
      payload: LiveSuperChatMessage.of(
        messageId: messageId,
        userName: name,
        text: text,
        price: SuperChatPrice.of(
          amount: amount > 0 ? amount : null,
          currency: 'Kicks',
          displayText: amount > 0 ? '$amount Kicks' : giftName,
        ),
        startTime: start,
        endTime: start.add(pinned > 0 && pinned <= 86400 ? Duration(seconds: pinned) : superChatDuration(amount)),
      ),
    );
  }

  /// How long a Kicks super chat stays without its own `pinned_time`: the
  /// steps of Bilibili's super chats by amount (100 Kicks is one dollar).
  static Duration superChatDuration(int amount) => switch (amount) {
    >= 10000 => const Duration(minutes: 30),
    >= 5000 => const Duration(minutes: 5),
    >= 1000 => const Duration(minutes: 2),
    _ => const Duration(minutes: 1),
  };

  /// The retraction of a deleted line (by id), a banned viewer (by user id)
  /// or a cleared chat (all); null when neither id is there.
  static LiveMessage? retraction({String? messageId, String? userId}) {
    final id = messageId?.trim() ?? '';
    if (id.isNotEmpty) return _retract(LiveRetraction.of(messageId: 'kick:$id'));
    final user = userId?.trim() ?? '';
    if (user.isNotEmpty) return _retract(LiveRetraction.of(userId: user));
    return null;
  }

  /// The notice of a channel subscription.
  static LiveMessage? subscription(Map<String, dynamic> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final name = _text(data['username']);
    if (name.isEmpty) return null;
    final months = jsonInt(data['months']) ?? 0;
    return _notice(
      months > 1 ? '$name subscribed for $months months' : '$name subscribed',
      LiveNoticeKind.subscription,
    );
  }

  /// The notice of subscriptions gifted to viewers.
  static LiveMessage? giftedSubscriptions(Map<String, dynamic> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final gifter = _text(data['gifter_username']);
    final gifted = [for (final name in jsonList(data['gifted_usernames'])) _text(name)];
    if (gifted.isEmpty) return null;
    final giver = gifter.isEmpty ? 'An anonymous viewer' : gifter;
    final first = gifted.first;
    return _notice(
      gifted.length == 1 ? '$giver gifted a subscription to $first' : '$giver gifted ${gifted.length} subscriptions',
      LiveNoticeKind.giftedSubscription,
    );
  }

  /// The notice of a host raiding the channel.
  static LiveMessage? host(Map<String, dynamic> data, KickDanmakuArgs args) {
    if (!_inRoom(data, args)) return null;
    final host = _text(data['host_username']);
    if (host.isEmpty) return null;
    final viewers = jsonInt(data['number_viewers']) ?? 0;
    final note = _content(data['optional_message']);
    final text = viewers > 0 ? '$host brought $viewers viewers' : '$host hosted this channel';
    return _notice(note.isEmpty ? text : '$text: $note', LiveNoticeKind.raid);
  }

  /// The notice of a pinned chat line; null when the pin carries no text.
  static LiveMessage? pinned(Map<String, dynamic> data) {
    final line = jsonObject(data['message']);
    final author = _text(jsonObject(line?['sender'])?['username']);
    final text = _content(line?['content']);
    if (text.isEmpty) return null;
    return _notice(author.isEmpty ? 'Pinned message: $text' : "Pinned $author's message: $text", LiveNoticeKind.system);
  }

  /// `App\Events\ChatMessageEvent` → `ChatMessageEvent` (the class name
  /// after the last backslash; a name with no namespace is kept).
  static String eventName(String event) => event.substring(event.lastIndexOf(r'\') + 1);

  static LiveMessage _notice(String text, LiveNoticeKind kind) =>
      LiveMessage.normalized(type: LiveMessageType.notice, text: text, color: LiveMessageColor.white, payload: kind);

  static LiveMessage _retract(LiveRetraction retraction) =>
      LiveMessage.normalized(type: LiveMessageType.retraction, color: LiveMessageColor.white, payload: retraction);

  static bool _inRoom(Map<String, dynamic> data, KickDanmakuArgs args) {
    final room = jsonInt(data['chatroom_id']);
    return room == null || room == args.chatroomId;
  }

  static final RegExp _emote = RegExp(r'\[emote:\d+:([^\]\s]+)\]');

  /// The visible content of a chat field: inline emotes shown by name.
  static String _content(Object? value) =>
      (value is String ? value : '').replaceAllMapped(_emote, (match) => match.group(1)!).trim();

  static String _level(Object? badges) {
    for (final raw in jsonList(badges)) {
      final badge = jsonObject(raw);
      if (badge == null || badge['name'] != 'level') continue;
      final level = jsonInt(jsonObject(badge['metadata'])?['level']);
      if (level != null && level > 0) return '$level';
    }
    return '';
  }

  static LiveMessageColor? _color(Object? value) {
    if (value is int) {
      final argb = value >= 0 && value <= 0xFFFFFF ? value : (value & 0xFFFFFF);
      return LiveMessageColor.numberToColor(argb);
    }
    final hex = _text(value).replaceFirst('#', '');
    final color = hex.length == 6 ? int.tryParse(hex, radix: 16) : null;
    return color == null ? null : LiveMessageColor.numberToColor(color);
  }

  static String _text(Object? value) => switch (value) {
    final String text => text.trim(),
    final int number => '$number',
    _ => '',
  };
}
