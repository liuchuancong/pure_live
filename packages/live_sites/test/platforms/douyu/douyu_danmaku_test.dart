import 'dart:typed_data';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_stt_codec.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:test/test.dart';

/// One server frame of [texts] as the socket would send it.
Uint8List _frame(List<String> texts) {
  final out = BytesBuilder();
  for (final text in texts) {
    out.add(DouyuDanmakuProtocol.packet(text));
  }
  return out.takeBytes();
}

/// The messages of [texts], read as room [roomId]'s.
List<LiveMessage> _read(
  List<String> texts, {
  String roomId = '7099',
  bool Function()? filterSuspectedAutomated,
  DouyuGiftCatalog gifts = DouyuGiftCatalog.empty,
}) => DouyuDanmakuProtocol.read(
  _frame(texts),
  roomId: roomId,
  filterSuspectedAutomated: filterSuspectedAutomated,
  gifts: gifts,
).messages;

/// A `chatmsg` body with [fields] appended.
String _chatMsg([Map<String, String> fields = const <String, String>{}]) {
  final all = <String, String>{'type': 'chatmsg', 'rid': '7099', 'uid': '42', 'nn': 'nick', 'txt': 'hello', ...fields};
  return '${[for (final entry in all.entries) '${entry.key}@=${DouyuStt.escape(entry.value)}'].join('/')}/';
}

void main() {
  group('the STT text', () {
    test('a value is escaped once per nesting level and read back once', () {
      expect(DouyuStt.escape('a@b'), 'a@Ab');
      expect(DouyuStt.escape('a/b'), 'a@Sb');
      expect(DouyuStt.escape('a@b/c'), 'a@Ab@Sc');
      expect(DouyuStt.unescape('a@Ab@Sc'), 'a@b/c');
      expect(DouyuStt.unescape(DouyuStt.escape('@S')), '@S', reason: 'an escaped marker is not a second level');
      expect(
        DouyuStt.unescape(DouyuStt.escape(DouyuStt.escape('a/b'))),
        'a@Sb',
        reason: 'the shallow read the protocol promises leaves the inner level as text',
      );
      expect(
        DouyuStt.unescape(DouyuStt.unescape(DouyuStt.escape(DouyuStt.escape('a/b')))),
        'a/b',
        reason: 'two levels come back only when both are read',
      );
    });

    test('a map skips parts without a key, keeps keys as written, and a later duplicate wins', () {
      final fields = DouyuStt.map('type@=chatmsg//txt@=hi/loose/level@=5/@=nobody/txt@=later');
      expect(fields, {'type': 'chatmsg', 'txt': 'later', 'level': '5'});
    });

    test('a list drops the empty items and unescapes each one', () {
      expect(DouyuStt.list('a/b//c@Sd/'), ['a', 'b', 'c/d']);
      expect(DouyuStt.list(''), <String>[]);
    });
  });

  group('the packet frame', () {
    test('a packet writes its length twice, little endian, then type, flags, body and a terminator', () {
      final packet = DouyuDanmakuProtocol.packet('type@=abc/');
      expect(packet.take(12), [19, 0, 0, 0, 19, 0, 0, 0, 0xB1, 0x02, 0, 0]);
      expect(packet.last, 0, reason: 'the body is terminated, and the length counts itself out');
      expect(DouyuStt.map(DouyuDanmakuProtocol.bodies(packet).single), {'type': 'abc'});
    });

    test('joining a room is loginreq then joingroup at group -9999, and a heartbeat is mrkl', () {
      final join = DouyuDanmakuProtocol.joinPackets('7099');
      expect(join, hasLength(2));
      expect(DouyuStt.map(DouyuDanmakuProtocol.bodies(join[0]).single), {'type': 'loginreq', 'roomid': '7099'});
      expect(DouyuStt.map(DouyuDanmakuProtocol.bodies(join[1]).single), {
        'type': 'joingroup',
        'rid': '7099',
        'gid': '-9999',
      });
      expect(DouyuStt.map(DouyuDanmakuProtocol.bodies(DouyuDanmakuProtocol.heartbeat()).single), {'type': 'mrkl'});
    });

    test('one frame carries several packets in order, and a broken tail is dropped', () {
      expect(DouyuDanmakuProtocol.bodies(_frame(['type@=a/', 'type@=b/'])), ['type@=a/', 'type@=b/']);
      expect(DouyuDanmakuProtocol.bodies(DouyuDanmakuProtocol.packet('type@=whole/') + Uint8List(5)), ['type@=whole/']);

      final truncated = Uint8List.fromList(DouyuDanmakuProtocol.packet('type@=first/').sublist(0, 20));
      expect(DouyuDanmakuProtocol.bodies(Uint8List.fromList([..._packetWithBadLength(), ...truncated])), isEmpty);
    });
  });

  group('what the room shows', () {
    test('a chat line carries who spoke, their level, medal, colour and id', () {
      final line = _read([
        _chatMsg({'col': '2', 'level': '17', 'bnn': '粉丝牌', 'bl': '9', 'cid': '555', 'cst': '1790519893'}),
      ]).single;
      expect(line.type, LiveMessageType.chat);
      expect(line.text, 'hello');
      expect(line.sender?.userId, '42');
      expect(line.sender?.userName, 'nick');
      expect(line.sender?.userLevel, '17');
      expect(line.sender?.fanBadgeName, '粉丝牌');
      expect(line.sender?.fanBadgeLevel, '9');
      expect(line.messageId, 'douyu:555');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893000, isUtc: true));
      expect(<int>[line.color!.r, line.color!.g, line.color!.b], [30, 135, 240]);
    });

    test('a medal level is said only beside a medal, and a seconds timestamp is read as seconds', () {
      final line = _read([
        _chatMsg({'bl': '9', 'cst': '1790519893202'}),
      ]).single;
      expect(line.sender?.fanBadgeLevel, isEmpty, reason: 'bnn is blank, so bl names no medal');
      expect(line.sentAt, DateTime.fromMillisecondsSinceEpoch(1790519893202, isUtc: true));

      expect(
        _read([
          _chatMsg({'cst': 'not a time'}),
        ]).single.sentAt,
        isNull,
      );
      expect(
        _read([
          _chatMsg({'cst': ''}),
        ]).single.messageId,
        isEmpty,
      );
    });

    test('the six named colours map and anything else is white', () {
      for (final (col, rgb) in [
        (1, [255, 0, 0]),
        (2, [30, 135, 240]),
        (3, [122, 200, 75]),
        (4, [255, 127, 0]),
        (5, [155, 57, 244]),
        (6, [255, 105, 180]),
        (0, [255, 255, 255]),
        (99, [255, 255, 255]),
      ]) {
        final color = DouyuDanmakuProtocol.color(col);
        expect(<int>[color.r, color.g, color.b], rgb, reason: 'col $col');
      }
    });

    test('another room and an empty line are not this room chat', () {
      expect(
        _read([
          _chatMsg({'rid': '1111'}),
        ]),
        isEmpty,
      );
      expect(
        _read([
          _chatMsg({'txt': ''}),
        ]),
        isEmpty,
      );
      expect(
        _read([
          _chatMsg({'rid': ''}),
        ]),
        hasLength(1),
        reason: 'a packet that names no room is this room',
      );
    });

    test('a suspected automated line is dropped only when the switch says so, read per line', () {
      expect(DouyuDanmakuProtocol.isSuspectedAutomated({'txt': 'x'}), isTrue);
      expect(DouyuDanmakuProtocol.isSuspectedAutomated({'dms': '1', 'txt': 'x'}), isFalse);
      expect(DouyuDanmakuProtocol.isSuspectedAutomated({'if': '1', 'txt': 'x'}), isFalse);

      final calls = <bool?>[];
      final switched = _read(
        [
          _chatMsg({'txt': 'one'}),
          _chatMsg({'txt': 'two'}),
        ],
        filterSuspectedAutomated: () {
          calls.add(calls.isNotEmpty);
          return calls.last!;
        },
      );
      expect(switched.map((line) => line.text), ['one'], reason: 'the second line is judged by the new answer');
    });

    test('a packet that throws does not lose the packets after it in the frame', () {
      final messages = _read([
        _chatMsg({'cst': '9007199254740992'}),
        _chatMsg({'txt': 'after'}),
      ]);
      expect(messages.map((line) => line.text), ['after']);
    });

    test('the end of the broadcast stops the frame and only for this room', () {
      expect(DouyuDanmakuProtocol.endsBroadcast({'type': 'rss', 'ss': '0', 'rid': '7099'}, '7099'), isTrue);
      expect(DouyuDanmakuProtocol.endsBroadcast({'type': 'rss', 'ss': '0', 'rid': '1111'}, '7099'), isFalse);
      expect(DouyuDanmakuProtocol.endsBroadcast({'type': 'rss', 'ss': '1', 'rid': '7099'}, '7099'), isFalse);
      expect(DouyuDanmakuProtocol.endsBroadcast({'type': 'rss', 'ss': '0'}, '7099'), isTrue);
      expect(DouyuDanmakuProtocol.endsBroadcast({'type': 'chatmsg', 'ss': '0'}, '7099'), isFalse);

      final frame = _frame([
        _chatMsg({'txt': 'before'}),
        'type@=rss/ss@=0/rid@=7099/',
        _chatMsg({'txt': 'after'}),
      ]);
      final read = DouyuDanmakuProtocol.read(frame, roomId: '7099');
      expect(read.ended, isTrue);
      expect(read.messages.map((line) => line.text), ['before']);
    });

    test('a paid message carries the nested chat, its price and its window', () {
      const nested = 'nn@=payer/txt@=shown/ic@=abc123';
      final line = _read([
        'type@=comm_chatmsg/now@=1790519893000/cet@=60/cprice@=2000/chatmsg@=${DouyuStt.escape(nested)}/',
      ]).single;
      final paid = line.payload! as LiveSuperChatMessage;
      expect(line.type, LiveMessageType.superChat);
      expect(line.text, 'shown');
      expect(paid.userName, 'payer');
      expect(paid.faceUrl, 'https://apic.douyucdn.cn/upload/abc123_small.jpg');
      expect(paid.price.amount, 20, reason: 'cprice is in fen');
      expect(paid.price.displayText, '￥20');
      expect(paid.endTime!.difference(paid.startTime!).inSeconds, 60);
      expect(paid.display.backgroundColor, '#c1c1ff');
    });

    test('a notice that shares the type but paid nothing or lasts no time is not a paid message', () {
      final nested = DouyuStt.escape('nn@=x/txt@=y');
      for (final body in [
        'type@=comm_chatmsg/now@=1790519893000/cet@=60/cprice@=0/chatmsg@=$nested/',
        'type@=comm_chatmsg/now@=1790519893000/cet@=0/cprice@=2000/chatmsg@=$nested/',
        'type@=comm_chatmsg/now@=1790519893000/cet@=60/cprice@=2000/',
        'type@=comm_chatmsg/chatmsg@=$nested/',
      ]) {
        expect(_read([body]), isEmpty, reason: '$body is a pandora box, not a super chat');
      }
    });

    // `voice_trlt` (a paid voice message) is deliberately NOT pinned here: its
    // `list` and `uat` fields are escaped at three nesting levels, and neither
    // this repo nor the reference has a captured wire sample to copy. Guessing
    // the escaping would pin the test to an invention rather than to douyu.
  });

  group('a gift', () {
    test('a known gift carries the catalogue price, the picture and its count', () {
      final gifts = DouyuGiftCatalog({
        '7': const DouyuGiftInfo(id: '7', name: '小心心', price: 100, iconUrl: 'https://gift.example/7.png'),
      });
      final line = _read([
        'type@=dgb/rid@=7099/uid@=42/nn@=giver/gfid@=7/gfcnt@=3/receive_nn@=streamer/',
      ], gifts: gifts).single;
      final gift = line.payload! as LiveGift;
      expect(line.type, LiveMessageType.gift);
      expect(line.text, '小心心 ×3');
      expect(gift.giftId, '7');
      expect(gift.iconUrl, 'https://gift.example/7.png');
      expect(gift.recipientName, 'streamer');
      expect(gift.value.unit, LiveGiftUnit.fen);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 300);
      expect(line.sender?.userId, '42');
    });

    test('a gift the catalogue does not know keeps its own name and says no price', () {
      final gift = _read(['type@=dgb/rid@=7099/gfid@=999/gfn@=陌生礼物/gfcnt@=1/']).single.payload! as LiveGift;
      expect(gift.name, '陌生礼物');
      expect(gift.value.unitPrice, isNull);
      expect(gift.value.unit, LiveGiftUnit.other);
    });

    test('a count of zero is still one gift, and hits carry the combo', () {
      final alone = _read(['type@=dgb/rid@=7099/gfid@=0/gfn@=无名/gfcnt@=0/']).single.payload! as LiveGift;
      expect(alone.count, 1);
      expect(alone.combo.comboTotal, isNull);
      expect(alone.combo.comboKey, isEmpty);

      final combo = _read(['type@=dgb/rid@=7099/uid@=42/gfid@=7/gfn@=花/gfcnt@=2/hits@=9/']).single.payload! as LiveGift;
      expect(combo.combo.comboTotal, 9);
      expect(combo.combo.comboKey, '42:7');
    });

    test('a backpack prop is free whatever the catalogue says', () {
      final gifts = DouyuGiftCatalog({'7': const DouyuGiftInfo(id: '7', name: '小心心', price: 100)});
      final byFlag = _read(['type@=dgb/rid@=7099/gfid@=7/gfcnt@=1/gpf@=1/'], gifts: gifts).single.payload! as LiveGift;
      expect(byFlag.value.unit, LiveGiftUnit.free);
      expect(byFlag.value.unitPrice, isNull);

      final byProp = _read(['type@=dgb/rid@=7099/gfid@=0/pid@=55/gfn@=道具/'], gifts: gifts).single.payload! as LiveGift;
      expect(byProp.giftId, '55', reason: 'with no gift id the prop id names the gift');
      expect(byProp.value.unit, LiveGiftUnit.free);
    });

    test('another room gift, and a gift with no name at all, give nothing', () {
      expect(_read(['type@=dgb/rid@=1111/gfid@=7/gfn@=花/']), isEmpty);
      expect(_read(['type@=dgb/rid@=7099/gfid@=0/pid@=0/gfn@=  /']), isEmpty);
    });
  });
}

/// A packet whose length field is below the smallest legal one.
Uint8List _packetWithBadLength() {
  final bytes = Uint8List(16);
  ByteData.sublistView(bytes).setUint32(0, 8, Endian.little);
  return bytes;
}
