import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message_color/live_message_color.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/youtube/danmaku/youtube_danmaku_codec.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_protobuf.dart';
import 'package:test/test.dart';

/// The field of the page's chat view inside a continuation token.
const int _chatField = 119693434;

/// One InnerTube label, as the feed writes it.
Map<String, Object?> _label(String text) => {
  'runs': [
    if (text.isNotEmpty) {'text': text},
  ],
};

/// One `addChatItemAction` holding [key] with these renderer fields.
Map<String, Object?> _action(String key, Map<String, Object?> fields) => {
  'addChatItemAction': {
    'item': {key: fields},
  },
};

/// A chat line; [id] and [name] are left out entirely when empty, because the
/// feed omits them rather than sending blanks.
Map<String, Object?> _chat({
  String id = 'm1',
  String name = 'Ann',
  String channelId = 'UC1',
  Object? message,
  Object? timestampUsec = '1790519893202000',
  Map<String, Object?> extra = const {},
}) => _action('liveChatTextMessageRenderer', {
  if (id.isNotEmpty) 'id': id,
  if (name.isNotEmpty) 'authorName': name,
  if (channelId.isNotEmpty) 'authorExternalChannelId': channelId,
  if (message != null) 'message': message is String ? _label(message) : message,
  'timestampUsec': ?timestampUsec,
  ...extra,
});

/// A paid message (Super Chat) or paid sticker, with the fields each is read
/// by. [sticker] sends the sticker's single `backgroundColor` instead of the
/// header/body pair.
Map<String, Object?> _paid({
  String id = 'p1',
  String amount = r'$5.00',
  String text = 'nice',
  Object? header = 0xFF00BFA5,
  Object? body = 0xFF007D52,
  Object? timestampUsec = '1790519893202000',
  bool sticker = false,
  Map<String, Object?> extra = const {},
}) {
  final fields = <String, Object?>{
    if (id.isNotEmpty) 'id': id,
    'authorName': 'Ann',
    'authorExternalChannelId': 'UC1',
    if (amount.isNotEmpty) 'purchaseAmountText': amount,
    if (text.isNotEmpty) 'message': _label(text),
    'timestampUsec': ?timestampUsec,
    ...extra,
  };
  if (sticker) {
    if (header != null) fields['backgroundColor'] = header;
    return _action('liveChatPaidStickerRenderer', fields);
  }
  if (header != null) fields['headerBackgroundColor'] = header;
  if (body != null) fields['bodyBackgroundColor'] = body;
  return _action('liveChatPaidMessageRenderer', fields);
}

/// The answer of one poll: these actions, and a single timed continuation
/// unless [continuations] names its own.
Map<String, Object?> _answer(List<Object?> actions, {List<Object?>? continuations}) => {
  'continuationContents': {
    'liveChatContinuation': {
      'actions': actions,
      if (continuations != null) 'continuations': continuations else 'continuations': const <Object?>[],
    },
  },
};

Map<String, Object?> _timed(String token, {Object? timeoutMs = '3000'}) => {
  'timedContinuationData': {'continuation': token, 'timeoutMs': ?timeoutMs},
};

/// A ticker item pinning a paid message for the page: [full] is how long the
/// pin lasts, [left] how much of it is left when the answer came.
Map<String, Object?> _ticker(String id, {Object? full = 315, Object? left = 60, Map<String, Object?>? paid}) => {
  'addLiveChatTickerItemAction': {
    'item': {
      'liveChatTickerPaidMessageItemRenderer': {
        'id': id,
        'fullDurationSec': ?full,
        'durationSec': ?left,
        'showItemEndpoint': {
          'showLiveChatItemEndpoint': {
            'renderer': {
              'liveChatPaidMessageRenderer': <String, Object?>{
                'id': id,
                'authorName': 'Ann',
                'purchaseAmountText': r'$5.00',
                'message': _label('still pinned'),
                'headerBackgroundColor': 0xFF00BFA5,
                'timestampUsec': '1790519893202000',
                ...?paid,
              },
            },
          },
        },
      },
    },
  },
};

/// A continuation token naming the chat view [view] (4 is Top chat, 1 Live).
String _token(int view) {
  final inner = YoutubeProtoWriter()..integer(1, view);
  final wrapper = YoutubeProtoWriter()..bytes(16, inner.toBytes());
  return _encode((YoutubeProtoWriter()..bytes(_chatField, wrapper.toBytes())).toBytes());
}

String _encode(Uint8List bytes) => base64Url.encode(bytes).replaceAll('=', '%3D');

void main() {
  group('the shape of one answer', () {
    test('a body that is not an object is a format failure', () {
      for (final body in <Object?>[null, '[1,2]', 'not json', 7]) {
        expect(() => YoutubeDanmakuCodec.parse(body), throwsA(isA<FormatException>()), reason: '$body');
      }
    });

    test('the timed continuation carries the next request and its wait', () {
      final batch = YoutubeDanmakuCodec.parse(_answer([_chat(message: 'hello')], continuations: [_timed('next')]));
      expect(batch.continuation, 'next');
      expect(batch.pullDelay, const Duration(seconds: 3));
      expect(batch.reload, isFalse);
      expect(batch.over, isFalse);
      expect(batch.messages.single.text, 'hello');
      expect(batch.reported, batch.messages, reason: 'the session reports exactly the messages');
      expect(
        YoutubeDanmakuCodec.parse(_answer([_chat()])).messages.single.text,
        isEmpty,
        reason: 'a line without a message is kept undropped: the list decides what an empty line shows',
      );
    });

    test('the wait is clamped to 1–5 seconds, and an unnamed one is 5', () {
      expect(YoutubeDanmakuCodec.pullDelay(0), YoutubeDanmakuCodec.maxPullDelay);
      expect(YoutubeDanmakuCodec.pullDelay(-5), YoutubeDanmakuCodec.maxPullDelay);
      expect(YoutubeDanmakuCodec.pullDelay(400), YoutubeDanmakuCodec.minPullDelay);
      expect(YoutubeDanmakuCodec.pullDelay(30000), YoutubeDanmakuCodec.maxPullDelay);
      expect(YoutubeDanmakuCodec.pullDelay(1200), const Duration(milliseconds: 1200));

      final unnamed = YoutubeDanmakuCodec.parse(_answer([_chat()], continuations: [_timed('next', timeoutMs: null)]));
      expect(unnamed.pullDelay, YoutubeDanmakuCodec.maxPullDelay, reason: 'no timeoutMs of its own is none at all');
    });

    test('a reload continuation restarts the feed with its history', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer(
          [_chat()],
          continuations: [
            {
              'reloadContinuationData': {'continuation': 'back-to-back'},
            },
          ],
        ),
      );
      expect(batch.reload, isTrue);
      expect(batch.continuation, 'back-to-back');
    });

    test('an invalid continuation ends the chat even though it still names a token', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer(
          [_chat()],
          continuations: [
            {'invalidContinuationEndpoint': <String, Object?>{}},
            _timed('still here'),
          ],
        ),
      );
      expect(batch.over, isTrue);
      expect(batch.continuation, 'still here');
    });

    test('an answer that runs out of continuations is over only once it also has nothing', () {
      final withChat = YoutubeDanmakuCodec.parse(_answer([_chat()]));
      expect(withChat.continuation, isEmpty);
      expect(withChat.over, isFalse);
      expect(YoutubeDanmakuCodec.parse(_answer([])).over, isTrue);
      expect(
        YoutubeDanmakuCodec.parse(
          _answer([
            {'unknownAction': 1},
          ]),
        ).over,
        isTrue,
      );
    });

    test('the chat-over answer names its own notice, and may name none', () {
      final ended = YoutubeDanmakuCodec.parse({
        'continuations': [
          {
            'messageRenderer': {
              'text': {'simpleText': 'This live chat replay ended.'},
            },
          },
        ],
      });
      expect(ended.over, isTrue);
      expect(ended.notice, 'This live chat replay ended.');
      expect(ended.messages, isEmpty);
      expect(ended.pullDelay, YoutubeDanmakuCodec.maxPullDelay);
      expect(YoutubeDanmakuCodec.parse({'a': 1}).notice, isEmpty);
    });

    test('the pacing numbers the session polls by', () {
      expect(YoutubeDanmakuCodec.startRetryDelays, const [Duration(milliseconds: 600), Duration(milliseconds: 1400)]);
      expect(YoutubeDanmakuCodec.startAttempts, 3);
      expect(YoutubeDanmakuCodec.maxFailures, 8);
      expect(YoutubeDanmakuCodec.requestTimeout, const Duration(seconds: 15));
      expect(YoutubeDanmakuCodec.viewerInterval, const Duration(seconds: 30));
      expect(YoutubeDanmakuCodec.anonymousUserName, 'YouTube');
      expect(
        [for (var failures = 1; failures <= 5; failures++) YoutubeDanmakuCodec.backoff(failures).inSeconds],
        [1, 2, 4, 8, 8],
      );
    });

    test('the audience number is its own message', () {
      final message = YoutubeDanmakuCodec.audience(1250);
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.onlineViewers);
      expect(audience.value, 1250);
    });
  });

  group('chat lines', () {
    test('a text message carries its author, avatar, id and UTC time', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _chat(
            message: _label('hello'),
            extra: {
              'authorPhoto': {
                'thumbnails': [
                  {'url': 'https://i.ytimg.com/one.jpg'},
                  {'url': '//i.ytimg.com/two.jpg'},
                ],
              },
            },
          ),
        ]),
      ).messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.messageId, 'youtube:m1');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userId, 'UC1');
      expect(message.sender?.avatarUrl, 'https://i.ytimg.com/two.jpg', reason: 'the last thumbnail, made absolute');
      expect(message.sentAt, DateTime.fromMicrosecondsSinceEpoch(1790519893202000, isUtc: true));
      expect(message.emotes, isEmpty);
    });

    test('a nameless commenter is YouTube and an item without an id has no message id', () {
      final message = YoutubeDanmakuCodec.parse(_answer([_chat(id: '', name: '', channelId: '', message: 'hi')]))
          .messages
          .single;
      expect(message.sender?.userName, YoutubeDanmakuCodec.anonymousUserName);
      expect(message.sender?.userId, isEmpty);
      expect(message.sender?.avatarUrl, isNull);
      expect(message.messageId, isEmpty);
    });

    test('a time the answer does not give leaves the line undated', () {
      for (final usec in <Object?>[null, '0', '-1', '1.5', '8640000000000001', 'x']) {
        final message = YoutubeDanmakuCodec.parse(_answer([_chat(timestampUsec: usec, message: 'hi')])).messages.single;
        expect(message.sentAt, isNull, reason: 'timestampUsec $usec');
      }
      final held = YoutubeDanmakuCodec.parse(_answer([_chat(timestampUsec: '8640000000000000')])).messages.single;
      expect(held.sentAt, DateTime.fromMicrosecondsSinceEpoch(8640000000000000, isUtc: true));
    });

    test('the emoji runs of a message are its emotes, keyed by shortcut', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _chat(
            message: {
              'runs': [
                {'text': 'one '},
                {
                  'text': '',
                  'emoji': {
                    'shortcuts': ['[smile]', ':)'],
                    'image': {
                      'thumbnails': [
                        {'url': '//i.ytimg.com/small.png'},
                        {'url': 'https://i.ytimg.com/big.png'},
                      ],
                    },
                  },
                },
                {
                  'emoji': {
                    'emojiId': 'X-1',
                    'image': {
                      'thumbnails': [
                        {'url': 'https://i.ytimg.com/x.png'},
                      ],
                    },
                  },
                },
                {'emoji': <String, Object?>{}},
                {
                  'emoji': {
                    'shortcuts': ['[no image]'],
                  },
                },
                {'text': 'two'},
              ],
            },
          ),
        ]),
      ).messages.single;
      expect(message.text, 'one two');
      expect(message.emotes.map((emote) => emote.code), ['[smile]', 'X-1']);
      expect(message.emotes.first.url, 'https://i.ytimg.com/big.png');
    });

    test('an item that cannot be read is skipped without losing the others', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer([
          _chat(message: 'kept'),
          _action('liveChatHeartbeatRenderer', {'id': 'h1'}),
          'not an action',
          {'addChatItemAction': <String, Object?>{}},
          {'markChatItemAsDeletedAction': <String, Object?>{}},
        ]),
      );
      expect(batch.messages.single.text, 'kept');
    });
  });

  group('retractions', () {
    test('a deleted message is named by its id, under either action spelling', () {
      for (final action in <Map<String, Object?>>[
        {
          'markChatItemAsDeletedAction': {'targetId': 'm1'},
        },
        {
          'removeChatItemAction': {'targetItemId': 'm1'},
        },
      ]) {
        final message = YoutubeDanmakuCodec.parse(_answer([action])).messages.single;
        expect(message.type, LiveMessageType.retraction, reason: '$action');
        expect((message.payload! as LiveRetraction).messageId, 'youtube:m1');
        expect((message.payload! as LiveRetraction).userId, isNull);
      }
    });

    test('a deleted author is named by their channel, and without one nothing is retracted', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer([
          {
            'markChatItemsByAuthorAsDeletedAction': {'externalChannelId': 'UC2'},
          },
          {'removeChatItemByAuthorAction': <String, Object?>{}},
          {
            'markChatItemAsDeletedAction': {'targetId': ''},
          },
          {'markChatItemAsDeletedAction': <String, Object?>{}},
          {'removeChatItemAction': <String, Object?>{}},
        ]),
      );
      final retraction = batch.messages.single.payload! as LiveRetraction;
      expect(retraction.userId, 'UC2');
      expect(retraction.messageId, isNull);
      expect(batch.messages.single.text, isEmpty);
    });
  });

  group('super chats', () {
    test('a paid message is a super chat with its price, colours and tier display', () {
      final message = YoutubeDanmakuCodec.parse(_answer([_paid()])).messages.single;
      expect(message.type, LiveMessageType.superChat);
      expect(message.text, 'nice');
      expect(message.messageId, 'youtube:p1');
      final paid = message.payload! as LiveSuperChatMessage;
      expect(paid.messageId, 'youtube:p1');
      expect(paid.userName, 'Ann');
      expect(paid.price.amount, 5, reason: r'the digits before the decimal point: $5.00 is 5');
      expect(paid.price.displayText, r'$5.00');
      expect(paid.display.backgroundColor, '#00bfa5');
      expect(paid.display.backgroundBottomColor, '#007d52');
      final start = DateTime.fromMicrosecondsSinceEpoch(1790519893202000, isUtc: true);
      expect(paid.startTime, start);
      expect(paid.endTime, start.add(const Duration(minutes: 2)), reason: 'the green tier pins two minutes');
      expect(message.replayed, isFalse);
    });

    test('the colour tiers and the ticker pin decide how long a super chat shows', () {
      Duration endOf(Map<String, Object?> action) {
        final paid = YoutubeDanmakuCodec.parse(_answer([action])).messages.single.payload! as LiveSuperChatMessage;
        return paid.endTime!.difference(paid.startTime!);
      }

      for (final tier in <int, Duration>{
        0xFF00BFA5: const Duration(minutes: 2),
        0xFFFFB300: const Duration(minutes: 5),
        0xFFE65100: const Duration(minutes: 10),
        0xFFC2185B: const Duration(minutes: 30),
        0xFFD00000: const Duration(hours: 1),
        0xFF9E9E9E: const Duration(minutes: 1),
        0xFF000000: const Duration(minutes: 1),
      }.entries) {
        expect(endOf(_paid(header: tier.key)), tier.value, reason: 'header ${tier.key.toRadixString(16)}');
      }

      Duration pinnedFor(List<Object?> actions) =>
          (YoutubeDanmakuCodec.parse(_answer(actions)).messages.single.payload! as LiveSuperChatMessage).endTime!
              .difference(DateTime.fromMicrosecondsSinceEpoch(1790519893202000, isUtc: true));

      expect(pinnedFor([_ticker('p1'), _paid()]), const Duration(seconds: 315), reason: 'the ticker wins');
      expect(
        pinnedFor([_ticker('p2', full: '315'), _paid(id: 'p2')]),
        const Duration(minutes: 2),
        reason: 'a fullDurationSec written as text is not a pin: the tier applies',
      );
      expect(
        pinnedFor([_ticker('p3', full: 0), _paid(id: 'p3')]),
        const Duration(minutes: 2),
        reason: 'a pin of no length pins nothing',
      );
      expect(
        YoutubeDanmakuCodec.parse(_answer([_ticker('p4')])).messages,
        isEmpty,
        reason: 'a ticker item is not itself a chat line',
      );
    });

    test('a paid message with neither an amount nor a message is dropped', () {
      final batch = YoutubeDanmakuCodec.parse(_answer([_paid(amount: '', text: ''), _chat(message: 'kept')]));
      expect(batch.messages.single.text, 'kept');
    });

    test('a super chat without a platform time starts when the answer came', () {
      final now = DateTime.utc(2026, 11, 5, 12);
      final paid = YoutubeDanmakuCodec.parse(_answer([_paid(timestampUsec: null)]), now: now).messages.single;
      expect(paid.sentAt, isNull);
      final message = paid.payload! as LiveSuperChatMessage;
      expect(message.startTime, now);
      expect(message.endTime, now.add(const Duration(minutes: 2)));
      expect(
        YoutubeDanmakuCodec.parse(_answer([_paid(timestampUsec: null)])).messages.first.sentAt,
        isNull,
        reason: 'only the start moves to the answer time',
      );
    });

    test('a header colour the feed does not name reads as white and no background', () {
      final paid = YoutubeDanmakuCodec.parse(_answer([_paid(header: null, body: null)])).messages.single;
      expect(paid.color, LiveMessageColor.white);
      final message = paid.payload! as LiveSuperChatMessage;
      expect(message.display.backgroundColor, isEmpty);
      expect(message.display.backgroundBottomColor, isEmpty);
    });

    test('a super sticker is a super chat whose text falls back to its amount', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer([
          _paid(
            text: '',
            sticker: true,
            extra: {
              'authorPhoto': {'url': 'https://i.ytimg.com/s.jpg'},
            },
          ),
          _paid(text: 'words', sticker: true, header: 0xFFD00000),
        ]),
      );
      expect(batch.messages, hasLength(2));
      expect(batch.messages.first.text, r'$5.00', reason: 'no message: the amount is what shows');
      expect(batch.messages.last.text, 'words');
      final sticker = batch.messages.first.payload! as LiveSuperChatMessage;
      expect(sticker.faceUrl, 'https://i.ytimg.com/s.jpg');
      expect(sticker.display.backgroundColor, '#00bfa5');
      expect(sticker.display.backgroundBottomColor, isEmpty);
      expect(batch.messages.last.color, LiveMessageColor.white, reason: 'a sticker line is always white text');
    });

    test('a ticker item with time left is replayed, oldest first and once per id', () {
      final now = DateTime.utc(2026, 11, 5, 12);
      final batch = YoutubeDanmakuCodec.parse(
        _answer([
          _ticker('p2', left: '60', paid: {'timestampUsec': '1790519899202000'}),
          _ticker('p1', left: 30),
          _ticker('p1', left: 30),
          _ticker('p3', left: 0),
          _ticker('p4', left: null),
          _chat(message: 'kept'),
        ]),
        now: now,
      );
      expect(batch.messages.single.text, 'kept');
      expect(batch.pinned, hasLength(2));
      expect(batch.pinned.map((message) => message.messageId), ['youtube:p1', 'youtube:p2']);
      expect(batch.pinned.every((message) => message.replayed), isTrue);
      final first = batch.pinned.first.payload! as LiveSuperChatMessage;
      expect(first.startTime, DateTime.fromMicrosecondsSinceEpoch(1790519893202000, isUtc: true));
      expect(first.endTime, now.add(const Duration(seconds: 30)), reason: 'the pin ends while the answer is current');
    });
  });

  group('memberships and gifts', () {
    test('a membership item joins the parts it names', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _action('liveChatMembershipItemRenderer', {
            'id': 'j1',
            'authorName': 'Ann',
            'headerSubtext': '3 months',
            'message': _label('hello'),
          }),
        ]),
      ).messages.single;
      expect(message.type, LiveMessageType.membershipJoin);
      expect(
        message.text,
        '3 months · hello',
        reason: 'the header part comes first, and an absent one is not a separator',
      );
      expect(message.messageId, 'youtube:j1');
    });

    test('a gifted membership purchase is a notice naming the gifter', () {
      final batch = YoutubeDanmakuCodec.parse(
        _answer([
          _action('liveChatSponsorshipsGiftPurchaseAnnouncementRenderer', {
            'id': 'g1',
            'authorExternalChannelId': 'UC3',
            'header': {
              'liveChatSponsorshipsHeaderRenderer': {
                'authorName': 'Gifter',
                'primaryText': _label('gifted 5 memberships'),
              },
            },
          }),
          _action('liveChatSponsorshipsGiftPurchaseAnnouncementRenderer', {
            'id': 'g2',
            'header': {
              'liveChatSponsorshipsHeaderRenderer': {'primaryText': _label('gifted 1 membership')},
            },
          }),
          _action('liveChatSponsorshipsGiftPurchaseAnnouncementRenderer', {'id': 'g3'}),
        ]),
      );
      expect(batch.messages, hasLength(2), reason: 'a gift with no text is dropped');
      expect(batch.messages.first.type, LiveMessageType.notice);
      expect(batch.messages.first.text, 'Gifter gifted 5 memberships');
      expect(batch.messages.first.payload, LiveNoticeKind.subscription);
      expect(batch.messages.first.sender?.userId, 'UC3');
      expect(batch.messages.first.messageId, 'youtube:g1');
      expect(batch.messages.last.text, 'gifted 1 membership');
      expect(batch.messages.last.sender?.userName, YoutubeDanmakuCodec.anonymousUserName);
    });

    test('a gifted membership received is its own notice and needs no header', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _action('liveChatSponsorshipsGiftRedemptionAnnouncementRenderer', {
            'id': 'r1',
            'authorName': 'Ann',
            'message': _label('received a membership!'),
          }),
        ]),
      ).messages.single;
      expect(message.type, LiveMessageType.notice);
      expect(message.text, 'received a membership!');
      expect(message.payload, LiveNoticeKind.giftedSubscription);
      expect(message.sender?.userName, YoutubeDanmakuCodec.anonymousUserName, reason: 'a redemption names no gifter');
    });

    test('a gift of the view-model shape carries its id, name and first image', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _action('giftMessageViewModel', {
            'id': 'gift-1',
            'text': {'content': 'sent a Super Star Car'},
            'authorName': {'content': 'Ann'},
            'giftImage': {
              'sources': [
                {'url': 'https://static.youtube.com/gift.png'},
                {'url': 'https://static.youtube.com/gift-big.png'},
              ],
            },
          }),
        ]),
      ).messages.single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'sent a Super Star Car');
      expect(message.sender?.userName, 'Ann');
      expect(message.messageId, 'youtube:gift-1');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, 'gift-1');
      expect(gift.name, 'sent a Super Star Car');
      expect(gift.iconUrl, 'https://static.youtube.com/gift.png', reason: 'the first source is the one the card shows');
    });

    test('a gift without an id keeps its text but claims no message id', () {
      final message = YoutubeDanmakuCodec.parse(
        _answer([
          _action('giftMessageViewModel', {
            'text': {'simpleText': 'sent a gift'},
          }),
        ]),
      ).messages.single;
      expect(message.text, 'sent a gift');
      expect(message.messageId, isEmpty);
      expect((message.payload! as LiveGift).iconUrl, isEmpty);
    });
  });

  group('the audience of the page', () {
    test('the live viewer count is the digits of the first live renderer', () {
      Map<String, Object?> nested(Map<String, Object?> renderer) => {
        'contents': [
          {
            'itemSectionRenderer': {
              'contents': [renderer],
            },
          },
        ],
      };
      expect(
        YoutubeDanmakuCodec.viewers(
          nested({
            'videoViewCountRenderer': {'viewCount': _label('1,250 watching now'), 'isLive': true},
          }),
        ),
        1250,
      );
      expect(
        YoutubeDanmakuCodec.viewers(
          nested({
            'videoViewCountRenderer': {
              'viewCount': {'simpleText': '2 K'},
              'isLive': 1,
            },
          }),
        ),
        2,
        reason: 'the flags come as bool, number or text',
      );
      expect(
        YoutubeDanmakuCodec.viewers(
          nested({
            'videoViewCountRenderer': {'viewCount': _label('true'), 'isLive': 'true'},
          }),
        ),
        isNull,
      );
      expect(
        YoutubeDanmakuCodec.viewers(
          nested({
            'videoViewCountRenderer': {'viewCount': _label('9 views'), 'isLive': false},
          }),
        ),
        isNull,
        reason: 'a finished broadcast is not an audience',
      );
      expect(YoutubeDanmakuCodec.viewers({'a': 1}), isNull);
    });

    test('an updated_metadata answer gives the viewers and the next continuation', () {
      final metadata = YoutubeDanmakuCodec.parseMetadata({
        'contents': [
          {
            'videoViewCountRenderer': {'viewCount': _label('42 watching'), 'isLive': true},
          },
        ],
        'continuation': {
          'invalidContinuationEndpoint': <String, Object?>{},
          'timedContinuationData': {'continuation': 'meta-next'},
        },
      });
      expect(metadata.viewers, 42);
      expect(metadata.continuation, 'meta-next');

      final bare = YoutubeDanmakuCodec.parseMetadata({
        'continuation': {
          'a': {'continuation': ''},
        },
      });
      expect(bare.viewers, isNull);
      expect(bare.continuation, isNull);
      expect(() => YoutubeDanmakuCodec.parseMetadata('[1]'), throwsA(isA<FormatException>()));
    });
  });

  group('the every-message chat view', () {
    test('a top-chat token is rewritten to the live view and left alone after that', () {
      final top = _token(4);
      final live = YoutubeDanmakuCodec.allChatContinuation(top);
      expect(live, isNotNull);
      expect(live, isNot(top));
      expect(live, contains('%3D'), reason: 'the padding is written the way the page sends it');
      expect(
        YoutubeProtoMessage.decode(base64Url.decode(base64Url.normalize(live!.replaceAll('%3D', '=')))).fields,
        hasLength(1),
      );
      expect(YoutubeDanmakuCodec.allChatContinuation(live), live, reason: 'already the live view: itself');
    });

    test('a token that is not a rewritable top-chat view is refused', () {
      expect(YoutubeDanmakuCodec.allChatContinuation(_token(2)), isNull, reason: 'another view than the two known');
      expect(YoutubeDanmakuCodec.allChatContinuation('not a token at all'), isNull);
      expect(YoutubeDanmakuCodec.allChatContinuation(''), isNull);

      final noView = _encode((YoutubeProtoWriter()..integer(7, 1)).toBytes());
      expect(YoutubeDanmakuCodec.allChatContinuation(noView), isNull, reason: 'no chat field on the way');

      final viewMessage = YoutubeProtoWriter()..integer(1, 4);
      final twice = YoutubeProtoWriter()
        ..bytes(16, viewMessage.toBytes())
        ..bytes(16, viewMessage.toBytes());
      expect(
        YoutubeDanmakuCodec.allChatContinuation(
          _encode((YoutubeProtoWriter()..bytes(_chatField, twice.toBytes())).toBytes()),
        ),
        isNull,
        reason: 'the view named twice is not guessed at',
      );

      final fixed = Uint8List.fromList([0x81, 0x01, ...List<int>.filled(8, 0)]);
      expect(
        YoutubeDanmakuCodec.allChatContinuation(_encode((YoutubeProtoWriter()..bytes(_chatField, fixed)).toBytes())),
        isNull,
        reason: 'a fixed-width field where the view message sits is not walked into',
      );
    });
  });
}
