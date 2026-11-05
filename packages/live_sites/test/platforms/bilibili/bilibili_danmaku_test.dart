import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:math';
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_emote/live_emote.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/message/live_retraction/live_retraction.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/bilibili/danmaku/bilibili_danmaku_codec.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_room_parser.dart';
import 'package:test/test.dart';

final ZLibCodec _zlib = ZLibCodec();

/// One wire packet: [body] behind the 16-byte big-endian header.
Uint8List _packet(int operation, List<int> body, {int version = 0}) {
  final bytes = Uint8List(16 + body.length);
  ByteData.sublistView(bytes)
    ..setUint32(0, bytes.length)
    ..setUint16(4, 16)
    ..setUint16(6, version)
    ..setUint32(8, operation)
    ..setUint32(12, 1);
  bytes.setRange(16, bytes.length, body);
  return bytes;
}

/// A notice packet holding [json].
Uint8List _notice(Object? json, {int version = 0}) => _packet(5, utf8.encode(jsonEncode(json)), version: version);

/// A zlib packet stream (protocol version 2) holding [inner].
Uint8List _inflateTo(List<int> inner) => _packet(5, _zlib.encode(inner), version: 2);

/// A brotli stream of [data] in uncompressed meta-blocks (RFC 7932 §9.2):
/// the smallest encoder whose bytes a decoder has to accept.
Uint8List _brotliStream(List<int> data) {
  final out = BytesBuilder();
  var bits = 0;
  var count = 0;
  void put(int value, int width) {
    bits |= value << count;
    count += width;
    while (count >= 8) {
      out.addByte(bits & 0xff);
      bits >>= 8;
      count -= 8;
    }
  }

  void align() {
    if (count > 0) put(0, 8 - count);
  }

  put(0, 1);
  put(0, 1);
  put(0, 2);
  put(data.length - 1, 16);
  put(1, 1);
  align();
  out.add(data);
  put(1, 1);
  put(1, 1);
  align();
  return out.takeBytes();
}

/// A protover 3 notice holding the packet stream [inner].
Uint8List _brotli(List<int> inner) => _packet(5, _brotliStream(inner), version: 3);

/// `DANMU_MSG` as the socket sends it: the meta array, the text, the sender.
Map<String, Object?> _danmu(String text, {int color = 0xE33FFF, int dmid = 1234567890}) => {
  'cmd': 'DANMU_MSG',
  'info': [
    [0, 1, 25, color, 1790519893202, dmid, 0, '8z3o13gj', 0, 0, 0, '', 0, '{}', '{}'],
    text,
    [1000, 'viewer'],
  ],
};

/// `info[0]` as a chat's own metadata, with the picture fields the room may
/// send: a sticker at 12/13 and the rich user at 15.
List<Object?> _chatMeta({Object? sticker, Object? rich}) => <Object?>[
  0,
  1,
  25,
  0xE33FFF,
  1790519893202,
  1234567890,
  0,
  '8z3o13gj',
  0,
  0,
  0,
  '',
  if (sticker == null) 0 else 1,
  sticker ?? '{}',
  '{}',
  rich,
];

/// A `DANMU_MSG` notice whose `info[0]` is [meta] and whose text is [text].
Map<String, Object?> _chatWith(List<Object?> meta, String text) => {
  'cmd': 'DANMU_MSG',
  'info': [
    meta,
    text,
    [1000, 'viewer'],
  ],
};

/// The chat lines of a frame, in the order the packets arrived.
List<String> _chats(BilibiliDanmakuFrame frame) => [
  for (final message in frame.messages)
    if (message.type == LiveMessageType.chat) message.text,
];

/// The operation a packet the room is asked to write back carries.
int _operation(List<int> packet) => ByteData.sublistView(Uint8List.fromList(packet)).getUint32(8);

/// The JSON body of a packet the room is asked to write back.
Map<String, Object?> _body(List<int> packet) {
  final bytes = Uint8List.fromList(packet);
  return jsonDecode(utf8.decode(bytes.sublist(ByteData.sublistView(bytes).getUint16(4)))) as Map<String, Object?>;
}

void main() {
  group('what the room writes', () {
    test('client packets carry the header the web client writes', () {
      final packet = BilibiliDanmakuProtocol.packet(7, 'abc');
      expect(packet.take(16), [0, 0, 0, 19, 0, 16, 0, 0, 0, 0, 0, 7, 0, 0, 0, 1]);
      expect(utf8.decode(packet.sublist(16)), 'abc');
      expect(base64.encode(BilibiliDanmakuProtocol.heartbeat()), 'AAAAEAAQAAAAAAACAAAAAQ==');
    });

    test('the auth packet asks for brotli and spells its keys in the web order', () {
      final payload = BilibiliDanmakuProtocol.authPayload(
        uid: 1000,
        roomId: 5050,
        buvid: 'buvid-fixture',
        token: 'token-1',
        queueUuid: '0a1b2c3d',
      );
      expect(payload.keys, [
        'uid',
        'roomid',
        'protover',
        'buvid',
        'support_ack',
        'queue_uuid',
        'scene',
        'platform',
        'type',
        'key',
      ]);
      expect(payload['protover'], BilibiliDanmakuProtocol.protocolVersion);
      expect(payload['support_ack'], isTrue);

      final packet = BilibiliDanmakuProtocol.auth(
        uid: 1000,
        roomId: 5050,
        buvid: 'buvid-fixture',
        token: 'token-1',
        queueUuid: '0a1b2c3d',
      );
      expect(_operation(packet), BilibiliDanmakuProtocol.opAuth);
      expect(_body(packet), payload);
    });

    test('a queue_uuid is eight lower-case hexadecimal digits, and new each time', () {
      final seeds = [for (var seed = 0; seed < 20; seed++) BilibiliDanmakuProtocol.queueUuid(Random(seed))];
      for (final uuid in seeds) {
        expect(uuid, matches(RegExp(r'^[0-9a-f]{8}$')));
      }
      expect(seeds.toSet(), hasLength(20), reason: 'two sockets with one uuid share one join');
    });

    test('an acknowledgement is asked for only by a notice that says so', () {
      final ack = BilibiliDanmakuProtocol.acknowledgement({
        'p_is_ack': true,
        'msg_id': '9',
        'cmd': 'LIVE_OPENING_ATTACK',
        'p_msg_type': 6,
      });
      expect(ack, isNotNull);
      expect(_operation(ack!), BilibiliDanmakuProtocol.opAck);
      expect(_body(ack), {'msg_id': '9', 'cmd': 'LIVE_OPENING_ATTACK', 'p_msg_type': 6});

      for (final notice in [
        {'msg_id': '9', 'cmd': 'X', 'p_msg_type': 6},
        {'p_is_ack': true, 'cmd': 'X', 'p_msg_type': 6},
        {'p_is_ack': true, 'msg_id': '9', 'p_msg_type': 6},
        {'p_is_ack': true, 'msg_id': '9', 'cmd': 'X', 'p_msg_type': 'six'},
        {'p_is_ack': true, 'msg_id': '9', 'cmd': 'X'},
        {'p_is_ack': true, 'msg_id': '  ', 'cmd': 'X', 'p_msg_type': 6},
      ]) {
        expect(BilibiliDanmakuProtocol.acknowledgement(notice), isNull, reason: '$notice is nothing to acknowledge');
      }
    });

    test('a masked name is masked only when the platform doubled the star', () {
      expect(BilibiliDanmakuProtocol.isMaskedName('观***1'), isTrue);
      expect(BilibiliDanmakuProtocol.isMaskedName('观＊＊1'), isTrue);
      expect(BilibiliDanmakuProtocol.isMaskedName('观*1'), isFalse, reason: 'a name with one star is a real name');
      expect(BilibiliDanmakuProtocol.isMaskedName('viewer'), isFalse);
    });
  });

  group('one message, several packets', () {
    test('a clean message reports no fault and keeps the packet order', () {
      final frame = BilibiliDanmakuProtocol.decode([..._notice(_danmu('first')), ..._notice(_danmu('second'))]);
      expect(frame.error, isNull);
      expect(_chats(frame), ['first', 'second']);
    });

    test('a fault keeps what arrived before it', () {
      final zeroLength = Uint8List(16);
      ByteData.sublistView(zeroLength).setUint16(4, 16);
      final frame = BilibiliDanmakuProtocol.decode([..._notice(_danmu('before')), ...zeroLength]);
      expect(_chats(frame), ['before']);
      expect(frame.error, isA<FormatException>(), reason: 'a zero length must not spin the reader');
    });

    test('bytes left over after the last packet are a fault, not a partial room', () {
      final frame = BilibiliDanmakuProtocol.decode([..._notice(_danmu('one')), 1, 2, 3]);
      expect(_chats(frame), ['one']);
      expect(frame.error, isA<FormatException>());
    });

    test('a message over the cap is refused before any packet is read', () {
      final frame = BilibiliDanmakuProtocol.decode(Uint8List(BilibiliDanmakuProtocol.maxMessageBytes + 1));
      expect(frame.error, isA<FormatException>());
      expect(frame.messages, isEmpty);
    });

    test('one packet stream too many is a fault', () {
      final flood = [
        for (var i = 0; i <= BilibiliDanmakuProtocol.maxPackets; i++) ...BilibiliDanmakuProtocol.heartbeat(),
      ];
      expect(BilibiliDanmakuProtocol.decode(flood).error, isA<FormatException>());
    });

    test('a compressed stream is expanded only as deep as the format allows', () {
      final inside = _notice(_danmu('deep'));
      expect(_chats(BilibiliDanmakuProtocol.decode(_inflateTo(inside))), ['deep']);
      expect(_chats(BilibiliDanmakuProtocol.decode(_inflateTo(_inflateTo(inside)))), ['deep']);
      expect(
        BilibiliDanmakuProtocol.decode(_inflateTo(_inflateTo(_inflateTo(inside)))).error,
        isA<FormatException>(),
        reason: 'a third layer is not a stream this room joins',
      );
    });

    test('a compressed stream that would expand past the cap is a fault', () {
      final bomb = _packet(5, _zlib.encode(Uint8List(BilibiliDanmakuProtocol.maxInflatedBytes + 1)), version: 2);
      expect(BilibiliDanmakuProtocol.decode(bomb).error, isA<FormatException>());
    });

    test('protover 3 packets decode like zlib ones, nested and beside others', () {
      final stream = [..._notice(_danmu('first')), ..._notice(_danmu('second'))];
      expect(_chats(BilibiliDanmakuProtocol.decode(_brotli(stream))), ['first', 'second']);
      expect(_chats(BilibiliDanmakuProtocol.decode(_brotli(_inflateTo(_notice(_danmu('brotli inside')))))), [
        'brotli inside',
      ]);
    });

    test('a heartbeat reply arrives as the popularity figure and an auth reply as its code', () {
      final popularity = BilibiliDanmakuProtocol.decode(_packet(3, [0, 0, 0x16, 0x58]));
      final update = popularity.messages.single.payload! as LiveAudienceUpdate;
      expect(popularity.messages.single.type, LiveMessageType.audienceUpdate);
      expect(update.kind, LiveAudienceSignalKind.popularity);
      expect(update.value, 0x1658);

      expect(BilibiliDanmakuProtocol.decode(_packet(8, utf8.encode('{"code":0}'))).authCode, 0);
      expect(BilibiliDanmakuProtocol.decode(_packet(8, utf8.encode('{"code":-101}'))).authCode, -101);
      expect(BilibiliDanmakuProtocol.decode(_packet(8, const <int>[])).authCode, 0);
    });
  });

  group('the notices the room shows', () {
    test('a chat line carries who, what colour and when the platform said', () {
      final line = BilibiliDanmakuProtocol.decode(_notice(_danmu('hello'))).messages.single;
      expect(line.type, LiveMessageType.chat);
      expect(line.text, 'hello');
      expect(line.effectiveSender.userId, '1000');
      expect(line.effectiveSender.userName, 'viewer');
      expect(line.messageId, 'bilibili:1234567890');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893202, isUtc: true));
      expect(line.effectiveColor.r, 0xE3);
      expect(line.effectiveColor.g, 0x3F);
      expect(line.effectiveColor.b, 0xFF);
    });

    test('a colour the platform did not name reads as white, and a seconds timestamp as seconds', () {
      final frame = BilibiliDanmakuProtocol.decode(
        {
          'cmd': 'DANMU_MSG',
          'info': [
            [0, 1, 25, 0, 1790519893],
            'text',
            [1, 'one'],
          ],
        }.let(_notice),
      );
      final line = frame.messages.single;
      expect(line.color, line.effectiveColor);
      expect(<int>[line.color!.r, line.color!.g, line.color!.b], [255, 255, 255]);
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893000, isUtc: true));
      expect(line.messageId, isEmpty);
    });

    test('a recall is not a chat line, even though its cmd names one', () {
      final one = BilibiliDanmakuProtocol.decode(
        {
          'cmd': 'RECALL_DANMU_MSG',
          'data': {
            'recall_type': 2,
            'uinfo': {'uid': 1000},
          },
        }.let(_notice),
      ).messages.single;
      expect(one.type, LiveMessageType.retraction);
      expect((one.payload! as LiveRetraction).userId, '1000');

      final room = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'RECALL_DANMU_MSG',
          'data': {'recall_type': 3},
        }),
      );
      expect((room.messages.single.payload! as LiveRetraction).all, isTrue);

      expect(
        BilibiliDanmakuProtocol.decode(
          _notice({
            'cmd': 'RECALL_DANMU_MSG',
            'data': {
              'recall_type': 2,
              'uinfo': {'uid': 0},
            },
          }),
        ).messages,
        isEmpty,
        reason: 'a guest sees uid 0 for everybody, so this recall would take the whole room',
      );
      expect(
        BilibiliDanmakuProtocol.decode(
          _notice({
            'cmd': 'RECALL_DANMU_MSG',
            'data': {'recall_type': 1},
          }),
        ).messages,
        isEmpty,
      );
    });

    test('the audience figures arrive as audience, not as chat', () {
      final watched = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'WATCHED_CHANGE',
          'data': {'num': 1234},
        }),
      );
      expect(watched.messages.single.type, LiveMessageType.audienceUpdate);
      expect((watched.messages.single.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.totalViewers);
      expect((watched.messages.single.payload! as LiveAudienceUpdate).value, 1234);

      final online = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'ONLINE_RANK_COUNT',
          'data': {'online_count': 56},
        }),
      );
      expect((online.messages.single.payload! as LiveAudienceUpdate).kind, LiveAudienceSignalKind.onlineViewers);
      expect(_chats(watched), isEmpty);
    });

    test('the online figure prefers `online_count`, and an unreadable one says nothing', () {
      int? onlineOf(Map<String, Object?> data) {
        final messages = BilibiliDanmakuProtocol.decode(_notice({'cmd': 'ONLINE_RANK_COUNT', 'data': data})).messages;
        if (messages.isEmpty) return null;
        final update = messages.single.payload! as LiveAudienceUpdate;
        expect(update.kind, LiveAudienceSignalKind.onlineViewers);
        return update.value;
      }

      expect(onlineOf({'online_count': 56, 'count': 99}), 56, reason: 'the older key is only a fallback');
      expect(onlineOf({'count': 7}), 7);
      expect(onlineOf({'online_count': '8'}), 8, reason: 'bilibili sends counts as strings');
      expect(onlineOf({'online_count': 0}), 0);
      for (final data in [
        <String, Object?>{},
        {'online_count': -1},
        {'count': -1},
        {'online_count': 'seven'},
        {'online_count': 1.5},
        {'other': 3},
      ]) {
        expect(onlineOf(data), isNull, reason: '$data carries no figure a room can show');
      }
    });

    test('a bought guard is a subscription gift named by its level', () {
      final frame = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'GUARD_BUY',
          'data': {
            'uid': '7',
            'username': 'captain',
            'guard_level': 3,
            'num': 2,
            'price': 1980000,
            'start_time': 1790519893,
          },
        }),
      );
      final line = frame.messages.single;
      final gift = line.payload! as LiveGift;
      expect(line.type, LiveMessageType.gift);
      expect(line.effectiveSender.userId, '7');
      expect(gift.kind, LiveGiftKind.subscription);
      expect(gift.count, 2);
      expect(gift.recipientName, 'captain');
      expect(line.text, '${gift.name} ×2');
    });

    test('a guard level outside the three named tiers still says what was bought', () {
      final gift =
          BilibiliDanmakuProtocol.decode(
                _notice({
                  'cmd': 'GUARD_BUY',
                  'data': {'username': 'someone', 'gift_name': '无名舰', 'guard_level': 9, 'num': 1},
                }),
              ).messages.single.payload!
              as LiveGift;
      expect(gift.name, '无名舰');
      expect(gift.count, 1);
    });

    test('a paid message carries its price and the colours the platform paid for', () {
      final frame = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'SUPER_CHAT_MESSAGE',
          'data': {
            'id': 'sc-1',
            'message': 'pinned',
            'price': 30,
            'start_time': 1790519800,
            'end_time': 1790519900,
            'background_color': '#793749',
            'background_bottom_color': '#8F5566',
            'user_info': {'uid': 9, 'uname': 'payer', 'face': 'https://face.example/9.jpg'},
          },
        }),
      );
      final line = frame.messages.single;
      final paid = line.payload! as LiveSuperChatMessage;
      expect(line.type, LiveMessageType.superChat);
      expect(line.messageId, 'sc-1');
      expect(paid.price.amount, 30);
      expect(paid.price.currency, 'CNY');
      expect(paid.display.backgroundColor, '#793749');
      expect(paid.display.backgroundBottomColor, '#8F5566');
      expect(paid.endTime!.difference(paid.startTime!).inSeconds, 100);
    });

    test('a deleted paid message takes its own line back', () {
      final frame = BilibiliDanmakuProtocol.decode(
        {
          'cmd': 'SUPER_CHAT_MESSAGE_DELETE',
          'data': {
            'ids': ['sc-1', 'sc-2'],
          },
        }.let(_notice),
      );
      expect(frame.messages.map((line) => (line.payload! as LiveRetraction).messageId), ['sc-1', 'sc-2']);
    });

    test("a moderator warning and a cut-off lead with the room's own words", () {
      for (final (cmd, lead) in [
        ('WARNING', BilibiliDanmakuProtocol.warningNotice),
        ('CUT_OFF', BilibiliDanmakuProtocol.cutOffNotice),
      ]) {
        final withReason = BilibiliDanmakuProtocol.decode(_notice({'cmd': cmd, 'msg': 'talk about this'}))
            .messages
            .single;
        expect(withReason.type, LiveMessageType.notice);
        expect(withReason.text, '$lead：talk about this');
        expect(withReason.payload, LiveNoticeKind.system, reason: 'a notice row is not a chat line');
        // `msg` missing, empty or blank leaves the lead standing alone.
        for (final notice in [
          {'cmd': cmd},
          {'cmd': cmd, 'msg': ''},
          {'cmd': cmd, 'msg': '   '},
        ]) {
          final alone = BilibiliDanmakuProtocol.decode(_notice(notice)).messages.single;
          expect(alone.text, lead, reason: '$notice has no reason to say');
          expect(alone.payload, LiveNoticeKind.system);
        }
      }
    });

    test('a notice this decoder does not know is skipped without a fault', () {
      final frame = BilibiliDanmakuProtocol.decode([
        ..._notice({
          'cmd': 'INTERACT_WORD',
          'data': {'msg_type': 1},
        }),
        ..._notice(_danmu('kept')),
        ..._packet(5, utf8.encode('[1,2,3]')),
        ..._packet(5, utf8.encode('not json at all')),
      ]);
      expect(frame.error, isNull);
      expect(_chats(frame), ['kept']);
    });

    test('a notice that asks for an acknowledgement gets it written back', () {
      final frame = BilibiliDanmakuProtocol.decode(
        _notice({
          'cmd': 'LIVE_OPENING_ATTACK',
          'msg_id': '9',
          'p_is_ack': true,
          'p_msg_type': 6,
          'data': const <String, Object?>{},
        }),
      );
      expect(frame.sends, hasLength(1));
      expect(_operation(frame.sends.single), BilibiliDanmakuProtocol.opAck);
    });
  });

  group('the pictures a chat carries', () {
    test('a chat the platform sent no picture with carries none', () {
      expect(BilibiliDanmakuProtocol.decode(_notice(_danmu('hello'))).messages.single.emotes, isEmpty);
      final table = {
        '[dog]': {'url': 'https://p.hdslb.com/dog.png'},
      };
      expect(
        BilibiliDanmakuProtocol.emotes(
          '',
          _chatMeta(
            rich: {
              'extra': {'emots': table},
            },
          ),
        ),
        isEmpty,
      );
      expect(BilibiliDanmakuProtocol.emotes('[dog]', _chatMeta()), isEmpty);
      expect(BilibiliDanmakuProtocol.emotes('[dog]', _chatMeta(rich: {'extra': <String, Object?>{}})), isEmpty);
    });

    test('a sticker is the whole text, and its picture is made https', () {
      expect(
        BilibiliDanmakuProtocol.emotes('[打call]', _chatMeta(sticker: {'url': 'http://i0.hdslb.com/base/gif/s.png'})),
        [LiveEmote.of(code: '[打call]', url: 'https://i0.hdslb.com/base/gif/s.png')],
      );
      // Without a picture the sticker code stays plain text.
      for (final sticker in [
        {'url': ''},
        {'url': 'gifs/s.png'},
        <String, Object?>{},
      ]) {
        expect(BilibiliDanmakuProtocol.emotes('[打call]', _chatMeta(sticker: sticker)), isEmpty);
      }
      // The flag says sticker, but the field is not a picture record.
      expect(BilibiliDanmakuProtocol.emotes('[打call]', _chatMeta(sticker: 'https://p.hdslb.com/x.png')), isEmpty);
    });

    test("the inline codes of the text come from the rich user's table", () {
      final meta = _chatMeta(
        rich: {
          'extra': {
            'emots': {
              '[dog]': {'url': 'https://p.hdslb.com/dog.png'},
              '[absent]': {'url': 'https://p.hdslb.com/absent.png'},
              '[blank]': {'url': ''},
              '[plain]': {'url': 'plain'},
              '[cat]': {'url': 'http://p0.hdslb.com/cat.png'},
            },
          },
        },
      );
      final found = BilibiliDanmakuProtocol.emotes('[dog] [cat] [blank] [plain]', meta);
      expect(found.map((emote) => emote.code), ['[dog]', '[cat]']);
      expect(found.map((emote) => emote.url), ['https://p.hdslb.com/dog.png', 'https://p0.hdslb.com/cat.png']);
    });

    test('the rich user arrives as JSON text just as well as as an object', () {
      final table = {
        '[dog]': {'url': 'https://p.hdslb.com/dog.png'},
      };
      expect(
        BilibiliDanmakuProtocol.emotes(
          '[dog] hi',
          _chatMeta(
            rich: jsonEncode({
              'extra': {'emots': table},
            }),
          ),
        ),
        BilibiliDanmakuProtocol.emotes(
          '[dog] hi',
          _chatMeta(
            rich: {
              'extra': {'emots': table},
            },
          ),
        ),
      );

      final line = BilibiliDanmakuProtocol.decode(
        _notice(
          _chatWith(
            _chatMeta(
              rich: {
                'extra': {'emots': table},
              },
            ),
            '[dog] hi',
          ),
        ),
      ).messages.single;
      expect(line.text, '[dog] hi');
      expect(line.effectiveSender.userName, 'viewer');
      expect(line.emotes.single.url, 'https://p.hdslb.com/dog.png');
    });
  });

  group('a gift the room sends as protobuf', () {
    test('SEND_GIFT_V2 is the gift line the JSON packet would be', () {
      final pb = [
        ..._pv(1, 1000),
        ..._ps(2, 'payer'),
        ..._pm(8, [..._pv(5, 7), ..._ps(6, '小可爱')]),
        ..._pm(10, [
          ..._pv(1, 24),
          ..._ps(2, '小花花'),
          ..._pv(3, 3),
          ..._pv(5, 100),
          ..._pv(7, 300),
          ..._ps(8, 'gold'),
          ..._ps(9, 'tid-1'),
          ..._pv(10, 1790519893),
          ..._ps(12, 'combo-1'),
          ..._pm(29, [..._ps(1, 'anchor')]),
          ..._pm(35, [..._ps(1, 'https://p2.hdslb.com/gift.png')]),
        ]),
        ..._pm(15, [
          ..._pm(2, [..._ps(1, 'ignored')]),
        ]),
      ];
      final line = BilibiliDanmakuProtocol.decode(_notice(_giftV2(pb))).messages.single;
      final gift = line.payload! as LiveGift;
      expect(line.type, LiveMessageType.gift);
      expect(line.text, '小花花 ×3');
      expect(line.effectiveSender.userId, '1000');
      expect(line.effectiveSender.userName, 'payer', reason: 'the root name wins over the sender record');
      expect(line.effectiveSender.fanBadgeName, '小可爱');
      expect(line.effectiveSender.fanBadgeLevel, '7');
      expect(line.messageId, 'bilibili:gift:tid-1');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893000, isUtc: true));
      expect(gift.giftId, '24');
      expect(gift.count, 3);
      expect(gift.recipientName, 'anchor');
      expect(gift.iconUrl, 'https://p2.hdslb.com/gift.png');
      expect(gift.combo.comboKey, 'combo-1');
      expect(gift.value.unit, LiveGiftUnit.goldSeed);
      expect(gift.value.unitPrice, 100.0);
      expect(gift.value.totalValue, 300.0);
    });

    test('the price of one is what the total says, and a silver gift is free', () {
      LiveGift giftOf(List<int> giftFields) =>
          BilibiliDanmakuProtocol.decode(_notice(_giftV2([..._pm(10, giftFields)]))).messages.single.payload!
              as LiveGift;

      final silver = giftOf([..._pv(1, 24), ..._ps(2, '小花花'), ..._pv(3, 3), ..._pv(7, 600), ..._ps(8, 'silver')]);
      expect(silver.value.unit, LiveGiftUnit.silver);
      expect(silver.value.unitPrice, 200.0);
      expect(silver.value.totalValue, 600.0);
      // A total the count does not divide leaves the unit price unnamed.
      final odd = giftOf([..._pv(1, 24), ..._ps(2, '小花花'), ..._pv(3, 7), ..._pv(7, 600)]);
      expect(odd.value.unitPrice, isNull);
      expect(odd.value.totalValue, 600.0);
      // Neither price nor total claims anything about money.
      final free = giftOf([..._pv(1, 24), ..._ps(2, '小花花'), ..._pv(3, 1)]);
      expect(<double?>[free.value.unitPrice, free.value.totalValue], [null, null]);
      expect(free.count, 1, reason: 'a gift that names no count was still given once');
      // The medal falls back to the rich user the sender record carries.
      final withRich = BilibiliDanmakuProtocol.decode(
        _notice(
          _giftV2([
            ..._pm(10, [..._ps(2, '小花花')]),
            ..._pm(15, [
              ..._pm(3, [..._ps(1, 'fan'), ..._pv(2, 4)]),
            ]),
          ]),
        ),
      ).messages.single;
      expect(withRich.effectiveSender.fanBadgeName, 'fan');
      expect(withRich.effectiveSender.fanBadgeLevel, '4');
      expect((withRich.payload! as LiveGift).name, '小花花');
    });

    test('what the packet leaves out comes from the gift table', () {
      const catalog = BilibiliGiftCatalog(
        gifts: {'24': BilibiliGiftInfo(id: '24', name: '小花花', price: 990)},
      );
      final frame = BilibiliDanmakuProtocol.decode(
        _notice(
          _giftV2([
            ..._pv(1, 24),
            ..._pm(10, [..._pv(1, 24), ..._ps(2, '  '), ..._pv(3, 2)]),
          ]),
        ),
        gifts: catalog,
      );
      final gift = frame.messages.single.payload! as LiveGift;
      expect(gift.name, '小花花');
      expect(gift.value.unit, LiveGiftUnit.goldSeed);
      expect(gift.value.unitPrice, 990.0);
      expect(gift.value.totalValue, 1980.0);
      // An id of 0 names no gift, so the table is not asked.
      final unknown =
          BilibiliDanmakuProtocol.decode(
                _notice(
                  _giftV2([
                    ..._pm(10, [..._pv(1, 0), ..._ps(2, '无名'), ..._pv(3, 1)]),
                  ]),
                ),
                gifts: catalog,
              ).messages.single.payload!
              as LiveGift;
      expect(unknown.giftId, isEmpty);
      expect(unknown.value.unitPrice, isNull);
    });

    test('a packet that is not a gift gives nothing', () {
      for (final data in <Object?>[
        null,
        <String, Object?>{},
        {'pb': ''},
        {'pb': '@@@@'},
        {
          'pb': base64.encode([0x0A]),
        },
        {'pb': base64.encode(_pv(1, 1000))},
        {
          'pb': base64.encode([
            ..._pv(1, 1000),
            ..._pm(10, [..._pv(3, 2)]),
          ]),
        },
      ]) {
        final frame = BilibiliDanmakuProtocol.decode(_notice({'cmd': 'SEND_GIFT_V2', 'data': ?data}));
        expect(frame.error, isNull, reason: '$data is a gift this room was not told about, not a broken socket');
        expect(frame.messages, isEmpty);
      }
    });
  });
}

/// A protobuf varint field, as `SEND_GIFT_V2`'s `data.pb` carries it.
List<int> _pv(int field, int value) => [..._ptag(field, 0), ..._pvarint(value)];

/// A protobuf UTF-8 text field.
List<int> _ps(int field, String text) {
  final data = utf8.encode(text);
  return [..._ptag(field, 2), ..._pvarint(data.length), ...data];
}

/// A nested protobuf message field.
List<int> _pm(int field, List<int> inner) => [..._ptag(field, 2), ..._pvarint(inner.length), ...inner];

List<int> _ptag(int field, int wireType) => _pvarint((field << 3) | wireType);

List<int> _pvarint(int value) {
  var rest = value;
  final out = <int>[];
  while (true) {
    final byte = rest & 0x7F;
    rest >>>= 7;
    if (rest == 0) return [...out, byte];
    out.add(byte | 0x80);
  }
}

/// A `SEND_GIFT_V2` notice holding [pb] as its `data.pb`.
Map<String, Object?> _giftV2(List<int> pb) => {
  'cmd': 'SEND_GIFT_V2',
  'data': {'pb': base64.encode(pb)},
};

extension on Object? {
  /// Wraps a notice the decoder reads, so a case can be written as its JSON.
  Uint8List let(Uint8List Function(Object?) make) => make(this);
}
