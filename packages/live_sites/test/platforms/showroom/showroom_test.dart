import 'dart:convert';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/platforms/showroom/danmaku/showroom_danmaku_codec.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_models.dart';
import 'package:live_sites/src/platforms/showroom/parsers/showroom_parser.dart';
import 'package:test/test.dart';

/// A gift event of gift [id] sent [count] times.
Map<String, Object?> _event(String id, {int count = 1, String? gt}) => {
  't': 2,
  'g': id,
  'n': count,
  'ac': '送礼的',
  'u': 'u1',
  'cl': 5,
  'created_at': 1790733600,
  'gt': ?gt,
};

/// The room's table with one paid and one free gift.
final ShowroomGiftCatalog _table = ShowroomGiftCatalog({
  '12': ShowroomGiftInfo(
    name: 'バラ',
    point: 500,
    free: false,
    image: Uri.parse('https://static.showroom-live.com/image/gift/12_s.png'),
  ),
  '13': const ShowroomGiftInfo(name: 'たね', point: 1, free: true),
});

void main() {
  group('gifts (t 2)', () {
    test('a paid gift is priced from the table and counted', () {
      final message = ShowroomDanmakuCodec.gift(_event('12', count: 3), gifts: _table)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, 'バラ ×3');
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, '送礼的');
      expect(message.sender?.userLevel, '5');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600 * 1000));
      final gift = message.giftOrNull! as LiveGift;
      expect(gift.giftId, '12');
      expect(gift.name, 'バラ');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.point);
      expect(gift.value.unitPrice, 500);
      expect(gift.value.totalValue, 1500);
      expect(gift.iconUrl, 'https://static.showroom-live.com/image/gift/12_s.png');
    });

    test('a free gift has no value, whoever says it is free', () {
      for (final message in [
        ShowroomDanmakuCodec.gift(_event('13', count: 4), gifts: _table)!,
        ShowroomDanmakuCodec.gift(_event('99', gt: '2'))!,
      ]) {
        final gift = message.giftOrNull! as LiveGift;
        expect(gift.value.unit, LiveGiftUnit.free);
        expect(gift.value.unitPrice, isNull);
        expect(gift.value.totalValue, isNull);
      }
      expect(
        (ShowroomDanmakuCodec.gift(_event('99', gt: '2'))!.giftOrNull! as LiveGift).iconUrl,
        contains('/99_s.png'),
      );
    });

    test('a paid gift without its table keeps its id and picture only', () {
      final gift = ShowroomDanmakuCodec.gift(_event('7'))!.giftOrNull! as LiveGift;
      expect(gift.name, '');
      expect(gift.value.unit, LiveGiftUnit.point);
      expect(gift.value.unitPrice, isNull);
      expect(gift.value.totalValue, isNull);
    });

    test('another type, or no gift id, is no gift', () {
      expect(ShowroomDanmakuCodec.gift({'t': 1, 'g': '12'}, gifts: _table), isNull);
      expect(ShowroomDanmakuCodec.gift(_event('0'), gifts: _table), isNull);
      expect(ShowroomDanmakuCodec.gift('not a map', gifts: _table), isNull);
    });
  });

  group('the gift table (live/gift_list)', () {
    test('normal and enquete rows are read by their positive id', () {
      final table = ShowroomParser.giftList(
        jsonEncode({
          'normal': [
            {'gift_id': 12, 'gift_name': ' バラ ', 'point': 500, 'free': false},
            {'gift_id': 0, 'gift_name': 'skipped', 'point': 1, 'free': true},
          ],
          'enquete': [
            {'gift_id': 13, 'gift_name': 'たね', 'point': 1, 'free': true},
          ],
        }),
      );
      expect(table.length, 2);
      expect(table['12']?.name, 'バラ');
      expect(table['12']?.point, 500);
      expect(table['12']?.free, isFalse);
      expect(table['13']?.free, isTrue);
      expect(table['0'], isNull);
    });
  });
}
