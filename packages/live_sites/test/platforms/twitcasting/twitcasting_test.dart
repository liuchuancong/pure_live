import 'dart:convert';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/gift/live_gift_value/live_gift_value.dart';
import 'package:live_sites/src/platforms/twitcasting/danmaku/twitcasting_danmaku_codec.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:test/test.dart';

const int _millis = 1790733600000;

Map<Object?, Object?> _commentEvent({
  Object? message = 'hello',
  Object? name = 'Ann',
  String screenName = 'ann',
  Object? id = 999,
  Object? authorId = 'c:tw1',
}) => {
  'type': 'comment',
  'message': message,
  'id': id,
  'createdAt': _millis,
  'author': {'id': authorId, 'name': name, 'screenName': screenName},
};

Map<Object?, Object?> _giftEvent({
  String name = 'お茶ｘ10',
  String image = 'https://cdn.example/tea.png',
  String words = '',
  bool showsSenderInfo = true,
  Object? id = 1000,
}) => {
  'type': 'gift',
  'id': id,
  'createdAt': _millis,
  'plainMessage': words,
  'item': {'name': name, 'image': image, 'showsSenderInfo': showsSenderInfo},
  'sender': {'id': 77, 'name': 'Bob', 'screenName': 'bob'},
};

void main() {
  group('socket URL', () {
    test('the answer names a signed wss URL on the site', () {
      final uri = TwitcastingDanmakuCodec.socketUrl(
        jsonEncode({'url': 'wss://twitcasting.tv/event.pubsub/v1/streams/12/events?token=t&n=1'}),
        status: 200,
      );
      expect(uri.scheme, 'wss');
      expect(uri.host, 'twitcasting.tv');
    });

    test('another scheme, no URL, bad JSON or a bad status is a failure', () {
      expect(
        () => TwitcastingDanmakuCodec.socketUrl(jsonEncode({'url': 'ws://twitcasting.tv/x'}), status: 200),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(
        () => TwitcastingDanmakuCodec.socketUrl(jsonEncode({'url': 'https://elsewhere.example/x'}), status: 200),
        throwsA(isA<TwitcastingFailure>()),
      );
      expect(() => TwitcastingDanmakuCodec.socketUrl('nope', status: 200), throwsA(isA<TwitcastingFailure>()));
      expect(() => TwitcastingDanmakuCodec.socketUrl('{}', status: 500), throwsA(isA<TwitcastingFailure>()));
    });

    test('gifts are asked for by appending gift=1 to the signature', () {
      expect(
        TwitcastingDanmakuCodec.withGifts(Uri.parse('wss://twitcasting.tv/e?token=t&n=1')).query,
        'token=t&n=1&gift=1',
      );
      expect(TwitcastingDanmakuCodec.withGifts(Uri.parse('wss://twitcasting.tv/e')).query, 'gift=1');
    });

    test('the signature values are redacted', () {
      expect(
        TwitcastingDanmakuCodec.redact('failed wss://a/b?token=secret&n=42&gift=1'),
        'failed wss://a/b?token=…&n=…&gift=1',
      );
    });

    test('the movie is read from the endpoint address only', () {
      final endpoint = TwitcastingDanmakuCodec.endpoint(12);
      expect(endpoint.queryParameters['movie_id'], '12');
      expect(TwitcastingDanmakuCodec.movieOf(endpoint), 12);
      expect(TwitcastingDanmakuCodec.movieOf(Uri.parse('https://twitcasting.tv/other?movie_id=12')), isNull);
      expect(
        TwitcastingDanmakuCodec.movieOf(Uri.parse('https://twitcasting.tv/eventpubsuburl.php?movie_id=no')),
        isNull,
      );
    });
  });

  group('comments', () {
    test('a comment is white chat with its author and time', () {
      final message = TwitcastingDanmakuCodec.comment(_commentEvent())!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.messageId, '999');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(_millis));
      expect(message.sender?.userId, 'c:tw1');
      expect(message.sender?.userName, 'Ann');
    });

    test('a nameless author falls back to the screen name; a blank message is nothing', () {
      final message = TwitcastingDanmakuCodec.comment(_commentEvent(name: '  '))!;
      expect(message.sender?.userName, 'ann');
      expect(TwitcastingDanmakuCodec.comment(_commentEvent(message: '   ')), isNull);
      expect(TwitcastingDanmakuCodec.comment(_commentEvent(message: 5)), isNull);
      expect(TwitcastingDanmakuCodec.comment({'type': 'gift'}), isNull);
    });
  });

  group('gifts', () {
    test('a gift is named and pictured without a value, with the words as chat after it', () {
      final messages = TwitcastingDanmakuCodec.gift(_giftEvent(words: 'ありがとう'));
      expect(messages.map((message) => message.type), [LiveMessageType.gift, LiveMessageType.chat]);
      final gift = messages.first;
      expect(gift.text, 'お茶ｘ10 ×1');
      expect(gift.messageId, '1000');
      expect(gift.sender?.userId, '77');
      expect(gift.sender?.userName, 'Bob');
      final payload = gift.payload! as LiveGift;
      expect(payload.count, 1);
      expect(payload.iconUrl, 'https://cdn.example/tea.png');
      expect(payload.value, LiveGiftValue());
      expect(payload.combo.comboKey, '');
      expect(messages.last.text, 'ありがとう');
      expect(messages.last.messageId, '1000:words');
    });

    test('a gift without a name, or a campaign notice without a sender, is nothing', () {
      expect(TwitcastingDanmakuCodec.gift(_giftEvent(name: '')), isEmpty);
      expect(TwitcastingDanmakuCodec.gift(_giftEvent(showsSenderInfo: false)), isEmpty);
      expect(TwitcastingDanmakuCodec.gift({'type': 'comment'}), isEmpty);
    });

    test('a non-https picture is left out', () {
      final gift = TwitcastingDanmakuCodec.gift(_giftEvent(image: 'http://cdn.example/tea.png')).single;
      expect((gift.payload! as LiveGift).iconUrl, isNull);
    });
  });

  group('decode', () {
    test('a pushed array gives its comments and gifts in order', () {
      final messages = TwitcastingDanmakuCodec.decode(jsonEncode([_commentEvent(), _giftEvent(words: 'thanks')]));
      expect(messages.map((message) => message.type), [
        LiveMessageType.chat,
        LiveMessageType.gift,
        LiveMessageType.chat,
      ]);
      expect(messages.first.text, 'hello');
      expect(messages.last.text, 'thanks');
    });

    test('the keep-alive, another event and a bad body give nothing', () {
      expect(TwitcastingDanmakuCodec.decode('[]'), isEmpty);
      expect(TwitcastingDanmakuCodec.decode('[{"type":"keepalive"}]'), isEmpty);
      expect(TwitcastingDanmakuCodec.decode('not json'), isEmpty);
      expect(TwitcastingDanmakuCodec.decode(42), isEmpty);
    });

    test('a single event outside an array is read like a one-event array', () {
      expect(TwitcastingDanmakuCodec.decode(jsonEncode(_commentEvent())).single.text, 'hello');
      final bytes = utf8.encode(jsonEncode(_commentEvent()));
      expect(TwitcastingDanmakuCodec.decode(bytes).single.text, 'hello');
    });
  });
}
