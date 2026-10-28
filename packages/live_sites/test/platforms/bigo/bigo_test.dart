import 'dart:convert';

import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/bigo/danmaku/bigo_danmaku_codec.dart';
import 'package:test/test.dart';

const String _room = '123';

/// A `10|24` gift animation frame (uri 2584, `oriUri` 760969).
Map<String, Object?> _gift({String name = 'Flower', int count = 2, int? sends = 3, String room = _room}) => {
  'room_id': room,
  'seqId': '9',
  'from_uid': '1001',
  'payload': {
    'room_id': room,
    'oriUri': BigoDanmakuCodec.giftOriUri,
    'vgift_typeid': '77',
    'vgift_name': name,
    'vgift_count': count,
    'send_times': ?sends,
    'from_uid': '1001',
  },
};

/// The Base64 chat-list line that names a gift's sender.
String _line(Map<String, Object?> json) => base64.encode(utf8.encode(jsonEncode(json)));

void main() {
  group('gifts (760969)', () {
    test('a gift carries its id, name, count and the combo so far', () {
      final message = BigoDanmakuCodec.gift(_gift(), roomId: _room)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'Flower x2');
      expect(message.sender?.userId, '1001');
      expect(message.messageId, '1001:9');
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '77');
      expect(gift.name, 'Flower');
      expect(gift.count, 2);
      expect(gift.combo.comboTotal, 6);
    });

    test('another room, no name or no count of sends is handled', () {
      expect(BigoDanmakuCodec.gift(_gift(room: '999'), roomId: _room), isNull);
      expect(BigoDanmakuCodec.gift(_gift(name: ''), roomId: _room), isNull);
      final gift = BigoDanmakuCodec.gift(_gift(sends: null), roomId: _room)!.giftOrNull! as LiveGift;
      expect(gift.combo.comboTotal, isNull);
      expect(gift.count, 2);
    });

    test('the line after a gift names its sender, level and text', () {
      final frame = <Object?, Object?>{
        'room_id': _room,
        'payload': {
          'tag': '${BigoDanmakuCodec.giftLineTag}',
          'uid': '1001',
          'grade': '31',
          'content': _line({'n': 'Ann', 'm': 'Flower 送出了 2 个'}),
        },
      };
      final sender = BigoDanmakuCodec.giftLine(frame, roomId: _room)!;
      expect(sender.userId, '1001');
      expect(sender.name, 'Ann');
      expect(sender.level, '31');
      expect(
        BigoDanmakuCodec.giftLine({
          'room_id': _room,
          'payload': {'tag': '1'},
        }, roomId: _room),
        isNull,
      );
    });
  });

  group('audience', () {
    test('both audience frames are concurrent viewers', () {
      final first = BigoDanmakuCodec.audience(
        {'gid': _room, 'totalUserCount': '2472'},
        uri: BigoDanmakuCodec.audienceUri,
        roomId: _room,
      )!;
      final second = BigoDanmakuCodec.audience({'room_id': _room, 'total': 2513}, uri: 11032, roomId: _room)!;
      expect(first.type, LiveMessageType.audienceUpdate);
      expect('${first.payload}', contains('2472'));
      expect('${second.payload}', contains('2513'));
      expect(
        BigoDanmakuCodec.audience(
          {'gid': '999', 'totalUserCount': '1'},
          uri: BigoDanmakuCodec.audienceUri,
          roomId: _room,
        ),
        isNull,
      );
    });
  });
}
