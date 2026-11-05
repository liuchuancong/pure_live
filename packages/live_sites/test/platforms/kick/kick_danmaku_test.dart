import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/kick/danmaku/kick_danmaku_codec.dart';
import 'package:live_sites/src/platforms/kick/kick_site.dart';
import 'package:live_sites/src/platforms/kick/parsers/kick_json.dart';
import 'package:test/test.dart';

const KickDanmakuArgs _args = KickDanmakuArgs(chatroomId: 7001, channelId: 4242, slug: 'ann');

/// One Pusher frame; [raw] sends `data` as text rather than as an object.
String _pusher(String event, Object? data, {String? channel, bool raw = false}) =>
    jsonEncode({'event': event, 'channel': ?channel, 'data': raw ? (data is String ? data : jsonEncode(data)) : data});

/// A chat frame of the chat channel.
LiveMessage? _chatEvent(String event, Map<String, Object?> data) => KickDanmakuCodec.read(
  _pusher(event, data, channel: KickDanmakuCodec.chatChannel(_args), raw: true),
  _args,
).messages.singleOrNull;

/// One chat line's payload.
Map<String, Object?> _line({
  String content = '你好',
  String name = 'Ann',
  Object? id = 99,
  Object? senderId = 11,
  String type = 'message',
  Object? chatroomId = 7001,
  Object? createdAt,
  Map<String, Object?>? identity,
  String key = 'content',
  bool legacy = false,
  String userKey = 'sender',
}) {
  final body = <String, Object?>{
    'chatroom_id': ?chatroomId,
    'type': type,
    'id': ?id,
    key: content,
    'created_at': ?createdAt,
  };
  final sender = <String, Object?>{if (name.isNotEmpty) 'username': name, 'id': ?senderId, 'identity': ?identity};
  if (legacy) return {'message': body, userKey: sender};
  return {...body, userKey: sender};
}

void main() {
  group('the channels and the handshake', () {
    test('the three public channels name what they carry', () {
      expect(KickDanmakuCodec.chatChannel(_args), 'chatrooms.7001.v2');
      expect(KickDanmakuCodec.broadcastChannel(_args), 'channel.4242');
      expect(KickDanmakuCodec.kicksChannel(_args), 'channel_4242');
    });

    test('subscribing asks for an empty auth, in join order', () {
      expect(jsonDecode(KickDanmakuCodec.subscribe('chatrooms.1.v2')), {
        'event': 'pusher:subscribe',
        'data': {'auth': '', 'channel': 'chatrooms.1.v2'},
      });
      final all = KickDanmakuCodec.subscribeAll(_args);
      expect(all, hasLength(3));
      expect(
        all.map((text) => ((jsonDecode(text) as Map<String, Object?>)['data']! as Map<String, Object?>)['channel']),
        ['chatrooms.7001.v2', 'channel.4242', 'channel_4242'],
      );
      expect(KickDanmakuCodec.ping, '{"event":"pusher:ping","data":{}}');
      expect(KickDanmakuCodec.pong, '{"event":"pusher:pong","data":{}}');
    });

    test('the socket’s own numbers', () {
      expect(KickDanmakuCodec.heartbeatInterval, const Duration(seconds: 30));
      expect(KickDanmakuCodec.joinTimeout, const Duration(seconds: 10));
      expect(KickDanmakuCodec.maxFrameLength, 256 * 1024);
      expect(KickDanmakuCodec.endpoint.scheme, 'wss');
      expect(KickDanmakuCodec.socketHeaders, isNotEmpty);
    });

    test('the handshake frames are read as what they do', () {
      KickFrame read(String text) => KickDanmakuCodec.read(text, _args);
      final established = read(
        _pusher('pusher:connection_established', {
          'data': {'socket_id': '1'},
        }, raw: true),
      );
      expect(established.established, isTrue);
      expect(established.messages, isEmpty);

      expect(read(_pusher('pusher:ping', null)).ping, isTrue);
      expect(read(_pusher('pusher:pong', null)).ping, isFalse);

      final joined = read(_pusher('pusher_internal:subscription_succeeded', {}, channel: 'chatrooms.7001.v2'));
      expect(joined.joined, isTrue);
      expect(
        read(_pusher('pusher_internal:subscription_succeeded', {}, channel: 'channel.4242')).joined,
        isFalse,
        reason: 'only the chat channel confirms the join',
      );

      for (final event in ['pusher:error', 'pusher_internal:subscription_error', 'activity_timeout']) {
        final error = read(_pusher(event, {'message': 'too many'}, channel: 'chatrooms.7001.v2'));
        expect(error.error, '$event too many', reason: 'the frame names itself and the server’s reason');
      }
      expect(read(_pusher('pusher:error', '{}', raw: true)).error, 'pusher:error');
    });

    test('a frame that is not text, too long, or not JSON gives nothing', () {
      const empty = KickFrame();
      expect(KickDanmakuCodec.read(12, _args).messages, isEmpty);
      expect(KickDanmakuCodec.read(null, _args).established, isFalse);
      expect(
        KickDanmakuCodec.read(utf8.encode('{"event":"pusher:ping"}'), _args).ping,
        isTrue,
        reason: 'bytes are decoded',
      );
      expect(
        KickDanmakuCodec.read([0xFF, 0xFF, 0x7B], _args).messages,
        isEmpty,
        reason: 'malformed bytes are replaced, not thrown',
      );
      expect(KickDanmakuCodec.read('a' * (KickDanmakuCodec.maxFrameLength + 1), _args).messages, isEmpty);
      expect(KickDanmakuCodec.read('not json', _args).messages, isEmpty);
      expect(KickDanmakuCodec.read(_pusher('unknown_event', {}), _args).messages, isEmpty);
      expect(
        KickDanmakuCodec.read(jsonEncode(<String, Object?>{'event': 7, 'data': <String, Object?>{}}), _args).messages,
        isEmpty,
      );
      expect(
        KickDanmakuCodec.read(_pusher(r'App\Events\UnknownEvent', {}, channel: 'chatrooms.7001.v2'), _args).messages,
        isEmpty,
      );
      expect(empty.messages, isEmpty);
    });
  });

  group('the event names', () {
    test('the class behind the namespace is what matters', () {
      expect(KickDanmakuCodec.eventName(r'App\Events\ChatMessageEvent'), 'ChatMessageEvent');
      expect(KickDanmakuCodec.eventName('ChatMessageEvent'), 'ChatMessageEvent');
      expect(KickDanmakuCodec.eventName(r'a\b\c\d'), 'd');
      expect(KickDanmakuCodec.eventName(''), isEmpty);
    });
  });

  group('chat lines', () {
    test('a line carries its text, sender, colour, level, id and time', () {
      final message = _chatEvent(
        r'App\Events\ChatMessageEvent',
        _line(
          createdAt: '2026-09-27T14:38:13Z',
          identity: {
            'color': '#FF8800',
            'badges_v2': [
              {'name': 'mod', 'metadata': <String, Object?>{}},
              {
                'name': 'level',
                'metadata': {'level': 7},
              },
            ],
          },
        ),
      )!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, '你好');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, '11');
      expect(message.sender?.userLevel, '7', reason: 'the level badge rides in badges_v2');
      expect(message.sender?.nameColor, const LiveMessageColor(255, 136, 0));
      expect(message.color, const LiveMessageColor(255, 136, 0));
      expect(message.messageId, 'kick:99');
      expect(message.sentAt, DateTime.parse('2026-09-27T14:38:13Z'));
    });

    test('a line may be nested under message, and its sender under user', () {
      expect(_chatEvent(r'App\Events\ChatMessageSentEvent', _line(legacy: true))?.text, '你好');
      expect(_chatEvent('ChatMessageEvent', _line(userKey: 'user'))?.sender?.userName, 'Ann');
      expect(_chatEvent('ChatMessageEvent', _line(legacy: true, key: 'message'))?.text, '你好');
    });

    test('the line types the page shows, and the ones it does not', () {
      expect(_chatEvent('ChatMessageEvent', _line(type: 'reply'))?.text, '你好');
      expect(_chatEvent('ChatMessageEvent', _line(type: ''))?.text, '你好', reason: 'an empty type is a message');
      expect(_chatEvent('ChatMessageEvent', _line(type: 'system')), isNull);
      expect(
        _chatEvent('ChatMessageEvent', _line(content: '[emote:1:]'))?.text,
        '[emote:1:]',
        reason: 'an emote with no name is written as it came',
      );
    });

    test('a line of another chatroom is not this room’s', () {
      expect(_chatEvent('ChatMessageEvent', _line(chatroomId: 7002)), isNull);
      expect(_chatEvent('ChatMessageEvent', _line(chatroomId: null)), isNotNull, reason: 'no room named is this room');
      expect(_chatEvent('ChatMessageEvent', _line(name: '')), isNull, reason: 'no sender name');
      expect(_chatEvent('ChatMessageEvent', _line(content: '   ')), isNull);
      expect(_chatEvent('ChatMessageEvent', _line(senderId: null))?.sender?.userId, isEmpty);
      expect(_chatEvent('ChatMessageEvent', _line(id: null))?.messageId, 'kick:');
      expect(_chatEvent('ChatMessageEvent', _line(content: 'x' * 16001)), isNull, reason: 'over the page’s own cap');
      expect(_chatEvent('ChatMessageEvent', _line(content: 'x' * 16000)), isNotNull);
      expect(
        _chatEvent('ChatMessageEvent', _line(name: 'n' * 257)),
        isNull,
        reason: 'a name longer than the platform writes one is not shown',
      );
    });

    test('inline emotes are shown by name', () {
      String text(String content) => _chatEvent('ChatMessageEvent', _line(content: content))!.text;
      expect(text('one [emote:12:pepe] two'), 'one pepe two');
      expect(text('[emote:1:PogChamp]'), 'PogChamp');
      expect(text('a [emote:2:cat face] b'), 'a [emote:2:cat face] b', reason: 'the page’s name has no space');
      expect(text('a [emote:x:y] b'), 'a [emote:x:y] b', reason: 'the id is numeric');
      expect(text('a [emote:1: b]'), 'a [emote:1: b]', reason: 'the page’s name holds no space');
    });

    test('the sender colour is read as the page writes it', () {
      LiveMessageColor? colorOf(Object? identityValue) =>
          _chatEvent('ChatMessageEvent', _line(identity: {'color': identityValue}))?.color;
      expect(colorOf('#00ff00'), const LiveMessageColor(0, 255, 0));
      expect(colorOf('00ff00'), const LiveMessageColor(0, 255, 0), reason: 'the hash is optional');
      expect(colorOf(0x00FF00), const LiveMessageColor(0, 255, 0), reason: 'or a packed number');
      expect(colorOf(0xFF00FF00), const LiveMessageColor(0, 255, 0), reason: 'the alpha byte is cut off');
      expect(colorOf('green'), isNull, reason: 'not a colour the codec can read');
      expect(colorOf(null), isNull, reason: 'no identity colour means the theme’s own');
      expect(colorOf('#12345'), isNull, reason: 'six characters or nothing');
    });

    test('the level badge is the one named level, and only with a number', () {
      String? level(List<Map<String, Object?>> badges) =>
          _chatEvent('ChatMessageEvent', _line(identity: {'badges_v2': badges}))!.sender!.userLevel;
      expect(
        level([
          {
            'name': 'level',
            'metadata': {'level': 3},
          },
        ]),
        '3',
      );
      expect(
        level([
          {
            'name': 'sub',
            'metadata': {'level': 9},
          },
          {
            'name': 'level',
            'metadata': {'level': 3},
          },
        ]),
        '3',
      );
      expect(
        level([
          {
            'name': 'level',
            'metadata': {'level': 0},
          },
        ]),
        isEmpty,
        reason: 'a level of zero is not shown',
      );
      expect(
        level([
          {
            'name': 'level',
            'metadata': {'level': 'x'},
          },
        ]),
        isEmpty,
      );
      expect(level([]), isEmpty);
      expect(_chatEvent('ChatMessageEvent', _line(identity: {'badges_v2': 'not a list'}))!.sender!.userLevel, isEmpty);
    });

    test('a time may be seconds, an ISO string, or absent', () {
      DateTime? at(Object? value) => _chatEvent('ChatMessageEvent', _line(createdAt: value))?.sentAt;
      expect(at(1790519893), DateTime.fromMillisecondsSinceEpoch(1790519893 * 1000));
      expect(at('2026-09-27T14:38:13Z'), DateTime.utc(2026, 9, 27, 14, 38, 13));
      expect(at(0), isNull, reason: 'a clock of zero is no time');
      expect(at(-1), isNull);
      expect(at(8640000000), isNull, reason: 'beyond the year 2737 the number is not seconds');
      expect(at('not a time'), isNull);
      expect(at(null), isNull);
      expect(jsonMessageTime(1.5), isNull, reason: 'a fractional number is not an int here');
    });
  });

  group('taking lines back', () {
    test('a deleted line is named by its id, under either spelling', () {
      expect(
        _chatEvent(r'App\Events\MessageDeletedEvent', {
          'message': {'id': 55},
        })!.type,
        LiveMessageType.retraction,
      );
      final byId = _chatEvent('MessageDeletedEvent', {
        'message': {'id': ' 55 '},
      })!;
      expect((byId.payload! as LiveRetraction).messageId, 'kick:55', reason: 'the id is the chat line’s own key');
      final byField = _chatEvent('MessageDeletedEvent', {'message_id': 55})!;
      expect((byField.payload! as LiveRetraction).messageId, 'kick:55');
      expect(_chatEvent('MessageDeletedEvent', {'message_id': '  '}), isNull, reason: 'blank names nothing');
      expect(_chatEvent('MessageDeletedEvent', {}), isNull);
    });

    test('a banned viewer is named by user id, and a cleared chat by all', () {
      final banned = _chatEvent(r'App\Events\UserBannedEvent', {
        'user': {'id': 1234},
      })!;
      final target = banned.payload! as LiveRetraction;
      expect(target.userId, '1234', reason: 'a ban is not prefixed: it names the sender');
      expect(target.messageId, isNull);
      expect(_chatEvent('UserBannedEvent', {'user': <String, Object?>{}}), isNull);
      final cleared = _chatEvent(r'App\Events\ChatroomClearEvent', <String, Object?>{})!;
      expect((cleared.payload! as LiveRetraction).all, isTrue);
      expect(cleared.color, LiveMessageColor.white);
    });
  });

  group('kicks', () {
    test('kicks without a message are a gift of one item', () {
      final message = _chatEvent(r'App\Events\KicksGifted', {
        'sender': {'username': 'Ann', 'id': 11},
        'gift': {'name': 'Hell Yeah', 'amount': 500},
        'gift_transaction_id': 'tx1',
        'created_at': 1790519893,
      })!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Hell Yeah ×1');
      expect(message.messageId, 'kick:tx1');
      expect(message.sender?.userId, '11');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893 * 1000));
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, 'Hell Yeah');
      expect(gift.name, 'Hell Yeah');
      expect(gift.value.unit, LiveGiftUnit.kicks);
      expect(gift.value.unitPrice, 500);
      expect(gift.value.totalValue, 500);
    });

    test('an unnamed gift is Kicks, and a sender or gift missing is nothing', () {
      LiveMessage? of(Map<String, Object?> data) => _chatEvent('KicksGifted', data);
      expect(
        of({
          'sender': {'username': 'Ann'},
          'gift': {'amount': 1},
        })!.text,
        'Kicks ×1',
      );
      expect(
        of({
          'sender': {'username': 'Ann'},
        }),
        isNull,
        reason: 'no gift named',
      );
      expect(
        of({
          'gift': {'name': 'Hell Yeah'},
        }),
        isNull,
        reason: 'no sender named',
      );
      final negative = of({
        'sender': {'username': 'Ann'},
        'gift': {'name': 'Hell Yeah', 'amount': -5},
      })!;
      expect((negative.giftOrNull! as LiveGift).value.unitPrice, isNull, reason: 'a negative amount names no price');
      expect(
        of({
          'sender': {'username': 'Ann'},
          'gift': {'name': 'Hell Yeah'},
          'created_at': 0,
        })!.sentAt,
        isNull,
      );
    });

    test('kicks with a message are a super chat priced in Kicks', () {
      final message = _chatEvent(r'App\Events\KicksGifted', {
        'sender': {'username': 'Ann', 'id': 11},
        'gift': {'name': 'Hell Yeah', 'amount': 1000, 'pinned_time': 120},
        'message': 'nice [emote:1:pepe]',
      })!;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'nice pepe');
      final paid = message.payload! as LiveSuperChatMessage;
      expect(paid.price.amount, 1000);
      expect(paid.price.currency, 'Kicks');
      expect(paid.price.displayText, '1000 Kicks');
      expect(paid.endTime!.difference(paid.startTime!), const Duration(seconds: 120));
    });

    test('without its own pin the ladder of amounts decides, and a wild one falls back to it', () {
      Duration held({int amount = 100, int? pinned}) {
        final paid =
            _chatEvent('KicksGifted', {
                  'sender': {'username': 'Ann'},
                  'gift': {'name': 'Hell Yeah', 'amount': amount, 'pinned_time': ?pinned},
                  'message': 'x',
                  'created_at': 1790519893,
                })!.payload!
                as LiveSuperChatMessage;
        return paid.endTime!.difference(paid.startTime!);
      }

      expect(held(pinned: 86400), const Duration(hours: 24), reason: 'the day cap is still the pin');
      expect(held(pinned: 86401), const Duration(minutes: 1), reason: 'a pin beyond a day is not believed');
      expect(held(pinned: 0), const Duration(minutes: 1));
      expect(held(amount: 1000), const Duration(minutes: 2));
      expect(held(amount: 5000), const Duration(minutes: 5));
      expect(held(amount: 10000), const Duration(minutes: 30));
      expect(KickDanmakuCodec.superChatDuration(0), const Duration(minutes: 1));
      expect(KickDanmakuCodec.superChatDuration(999), const Duration(minutes: 1));
    });

    test('a super chat of no amount says the gift’s name and claims no number', () {
      final paid =
          _chatEvent('KicksGifted', {
                'sender': {'username': 'Ann'},
                'gift': {'name': 'Hell Yeah'},
                'message': 'x',
              })!.payload!
              as LiveSuperChatMessage;
      expect(paid.price.amount, isNull);
      expect(paid.price.displayText, 'Hell Yeah');
      expect(paid.messageId, isEmpty, reason: 'no transaction id names nothing');
      expect(paid.startTime, isNotNull, reason: 'a super chat without a platform time starts now');
    });

    test('the kicks channel carries the same event, and the chat channel may too', () {
      final kicks = KickDanmakuCodec.read(
        _pusher(
          r'App\Events\KicksGifted',
          {
            'sender': {'username': 'Ann'},
            'gift': {'name': 'Hell Yeah', 'amount': 20},
          },
          channel: KickDanmakuCodec.kicksChannel(_args),
          raw: true,
        ),
        _args,
      );
      expect(kicks.messages.single.type, LiveMessageType.gift);
      expect(
        KickDanmakuCodec.read(
          _pusher(
            'OtherEvent',
            {
              'sender': {'username': 'Ann'},
              'gift': {'name': 'x'},
            },
            channel: KickDanmakuCodec.kicksChannel(_args),
            raw: true,
          ),
          _args,
        ).messages,
        isEmpty,
        reason: 'only the Kicks event is read there',
      );
    });
  });

  group('the notices', () {
    test('a subscription says the months it covers', () {
      expect(_chatEvent(r'App\Events\SubscriptionEvent', {'username': 'Ann'})!.text, 'Ann subscribed');
      expect(_chatEvent('SubscriptionEvent', {'username': 'Ann', 'months': 1})!.text, 'Ann subscribed');
      expect(_chatEvent('SubscriptionEvent', {'username': 'Ann', 'months': 3})!.text, 'Ann subscribed for 3 months');
      expect(
        _chatEvent('SubscriptionEvent', {'months': 3}),
        isNull,
        reason: 'a subscription with no name says nothing',
      );
      expect(_chatEvent('SubscriptionEvent', {'username': 'Ann', 'chatroom_id': 7002}), isNull);
      expect(_chatEvent('SubscriptionEvent', {'username': 'Ann'})!.payload, LiveNoticeKind.subscription);
    });

    test('a gifted subscription counts them, and an anonymous giver says so', () {
      Map<String, Object?> giftOf(List<String> names, {String? gifter}) => {
        'gifter_username': ?gifter,
        'gifted_usernames': names,
      };
      expect(
        _chatEvent(r'App\Events\GiftedSubscriptionsEvent', giftOf(['Bea'], gifter: 'Ann'))!.text,
        'Ann gifted a subscription to Bea',
      );
      expect(
        _chatEvent('GiftedSubscriptionsEvent', giftOf(['Bea', 'Cai'], gifter: 'Ann'))!.text,
        'Ann gifted 2 subscriptions',
      );
      expect(
        _chatEvent('GiftedSubscriptionsEvent', giftOf(['Bea']))!.text,
        'An anonymous viewer gifted a subscription to Bea',
      );
      expect(_chatEvent('GiftedSubscriptionsEvent', giftOf(const [])), isNull);
      expect(_chatEvent('GiftedSubscriptionsEvent', giftOf(['Bea'])..['chatroom_id'] = 7002), isNull);
      expect(_chatEvent('GiftedSubscriptionsEvent', giftOf(['Bea']))!.payload, LiveNoticeKind.giftedSubscription);
    });

    test('a host raiding the channel says who came and with how many', () {
      expect(_chatEvent(r'App\Events\StreamHostEvent', {'host_username': 'Ann'})!.text, 'Ann hosted this channel');
      expect(
        _chatEvent('StreamHostEvent', {'host_username': 'Ann', 'number_viewers': 12})!.text,
        'Ann brought 12 viewers',
      );
      expect(
        _chatEvent('StreamHostEvent', {'host_username': 'Ann', 'optional_message': '  hello  '})!.text,
        'Ann hosted this channel: hello',
      );
      expect(_chatEvent('StreamHostEvent', {'number_viewers': 3}), isNull, reason: 'no host named');
      expect(_chatEvent('StreamHostEvent', {'host_username': 'Ann', 'chatroom_id': 7002}), isNull);
      expect(_chatEvent('StreamHostEvent', {'host_username': 'Ann'})!.payload, LiveNoticeKind.raid);
    });

    test('a pinned line is shown as a notice, with or without its author', () {
      expect(
        _chatEvent(r'App\Events\PinnedMessageCreatedEvent', {
          'message': {
            'content': 'pinned text',
            'sender': {'username': 'Ann'},
          },
        })!.text,
        "Pinned Ann's message: pinned text",
      );
      expect(
        _chatEvent('PinnedMessageCreatedEvent', {
          'message': {'content': 'pinned text'},
        })!.text,
        'Pinned message: pinned text',
      );
      expect(
        _chatEvent('PinnedMessageCreatedEvent', {
          'message': {'content': '  '},
        }),
        isNull,
      );
      expect(_chatEvent('PinnedMessageCreatedEvent', <String, Object?>{}), isNull);
      expect(
        _chatEvent('PinnedMessageCreatedEvent', {
          'message': {'content': 'a [emote:1:pepe]'},
        })!.text,
        'Pinned message: a pepe',
        reason: 'the pin’s emotes are named too',
      );
    });

    test('the broadcast’s own channel ends the run, and only for this channel', () {
      List<LiveMessage> broadcast(Map<String, Object?> payload) => KickDanmakuCodec.read(
        _pusher(
          r'App\Events\StopStreamBroadcast',
          payload,
          channel: KickDanmakuCodec.broadcastChannel(_args),
          raw: true,
        ),
        _args,
      ).messages;
      expect(
        broadcast({
          'livestream': {
            'channel': {'id': 4242},
          },
        }).single.type,
        LiveMessageType.system,
      );
      expect(
        broadcast({
          'livestream': {
            'channel': {'id': 4242},
          },
        }).single.text,
        'Broadcast ended',
      );
      expect(broadcast(<String, Object?>{}), isNotEmpty, reason: 'a stop that names no channel is this one’s');
      expect(
        broadcast({
          'livestream': {
            'channel': {'id': 999},
          },
        }),
        isEmpty,
        reason: 'another channel’s stop is not ours',
      );
    });
  });
}
