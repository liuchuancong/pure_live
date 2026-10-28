import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_stream_format.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/models/message/live_message/live_message.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_stt_codec.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_play_parser.dart';
import 'package:test/test.dart';

const String _roomId = '123';
final DateTime _issuedAt = DateTime.utc(2026, 9, 27, 12);

Uint8List _frame(List<String> bodies) =>
    Uint8List.fromList([for (final body in bodies) ...DouyuDanmakuProtocol.packet(body)]);

final DouyuGiftCatalog _gifts = DouyuGiftCatalog({
  '20001': const DouyuGiftInfo(id: '20001', name: '火箭', price: 100, iconUrl: 'https://gift.douyucdn.cn/rocket.png'),
  '20002': const DouyuGiftInfo(id: '20002', name: '鱼丸', free: true),
});

List<LiveMessage> _decode(List<String> bodies, {bool Function()? filter, DouyuGiftCatalog? gifts}) =>
    DouyuDanmakuProtocol.decode(
      _frame(bodies),
      roomId: _roomId,
      filterSuspectedAutomated: filter,
      gifts: gifts ?? _gifts,
    );

void main() {
  group('STT encoding', () {
    test('escaping round-trips one nesting level', () {
      expect(DouyuStt.escape('a@b/c'), 'a@Ab@Sc');
      expect(DouyuStt.unescape('a@Ab@Sc'), 'a@b/c');
      expect(DouyuStt.map('type@=chatmsg/txt@=a@Sb/cnn@=Ann/'), {'type': 'chatmsg', 'txt': 'a/b', 'cnn': 'Ann'});
      expect(DouyuStt.map('type@=a/type@=b/'), {'type': 'b'});
      expect(DouyuStt.map('@=nothing/broken'), isEmpty);
      expect(DouyuStt.list('a@Sb//c//'), ['a/b', 'c']);
    });

    test('packets are split back into their bodies and stop at a bad length', () {
      final frame = _frame(['type@=a/', 'type@=b/']);
      expect(DouyuDanmakuProtocol.bodies(frame), ['type@=a/', 'type@=b/']);
      final broken = Uint8List.fromList([...frame, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(DouyuDanmakuProtocol.bodies(broken), hasLength(2));
      expect(DouyuDanmakuProtocol.bodies(DouyuDanmakuProtocol.heartbeat()), ['type@=mrkl/']);
      expect(DouyuDanmakuProtocol.joinPackets(_roomId), hasLength(2));
      expect(
        utf8.decode(DouyuDanmakuProtocol.joinPackets(_roomId).first.sublist(12)).replaceAll('\x00', ''),
        'type@=loginreq/roomid@=$_roomId/',
      );
    });
  });

  group('chat', () {
    test('a chat line keeps its sender, level, fan medal, colour and time', () {
      final message = _decode([
        'type@=chatmsg/rid@=$_roomId/txt@=hi/uid@=u1/nn@=Ann/col@=2/cst@=1790733600/cid@=c1/level@=12/bnn@=fan/bl@=3/',
      ]).single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hi');
      expect(message.messageId, 'douyu:c1');
      expect(message.color, DouyuDanmakuProtocol.color(2));
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(message.sender?.userId, 'u1');
      expect(message.sender?.userName, 'Ann');
      expect(message.sender?.userLevel, '12');
      expect(message.sender?.fanBadgeName, 'fan');
      expect(message.sender?.fanBadgeLevel, '3');
    });

    test('millisecond times are not read as seconds; another room is dropped', () {
      final message = _decode(['type@=chatmsg/rid@=$_roomId/txt@=hi/cst@=1790733600123/']).single;
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(1790733600123, isUtc: true));
      expect(_decode(['type@=chatmsg/rid@=999/txt@=hi/']), isEmpty);
      expect(_decode(['type@=chatmsg/rid@=$_roomId/txt@=/']), isEmpty);
    });

    test('a suspected automated line is dropped only when the filter says so', () {
      const body = 'type@=chatmsg/rid@=$_roomId/txt@=hi/';
      expect(_decode([body], filter: () => true), isEmpty);
      expect(_decode([body], filter: () => false), hasLength(1));
      expect(_decode(['type@=chatmsg/rid@=$_roomId/txt@=hi/if@=1/'], filter: () => true), hasLength(1));
      expect(DouyuDanmakuProtocol.isSuspectedAutomated(DouyuStt.map(body)), isTrue);
    });
  });

  group('super chats', () {
    test('a coloured super chat is priced in yuan for its duration', () {
      final message = _decode([
        'type@=comm_chatmsg/now@=1790733600000/cet@=60/cprice@=1200/chatmsg@=nn@A=Ann@Stxt@A=hello@Sic@A=face.png@S/',
      ]).single;
      expect(message.type, LiveMessageType.superChat);
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.userName, 'Ann');
      expect(chat.text, 'hello');
      expect(chat.faceUrl, 'https://apic.douyucdn.cn/upload/face.png_small.jpg');
      expect(chat.price.amount, 12);
      expect(chat.price.currency, 'CNY');
      expect(chat.price.displayText, '￥12');
      expect(chat.startTime, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(chat.endTime, chat.startTime!.add(const Duration(seconds: 60)));
    });

    test('a notice without a price or duration is not a super chat', () {
      expect(_decode(['type@=comm_chatmsg/now@=1790733600000/cet@=0/cprice@=0/chatmsg@=nn@A=A@Stxt@A=x@S/']), isEmpty);
      expect(_decode(['type@=comm_chatmsg/now@=1790733600000/cet@=60/chatmsg@=nn@A=A@Stxt@A=x@S/']), isEmpty);
    });

    test('a voice super chat reads its own map, times in seconds', () {
      final message = _decode([
        'type@=voice_trlt/list@=acptime@AA=1790733600@ASetime@AA=1790733700@ASrealPrice@AA=500@AScontent@AA=唱歌@ASun@AA=Bob@AS@S/',
      ]).single;
      final chat = message.payload! as LiveSuperChatMessage;
      expect(chat.userName, 'Bob');
      expect(chat.text, '唱歌');
      expect(chat.faceUrl, '');
      expect(chat.price.amount, 5);
      expect(chat.startTime, DateTime.fromMillisecondsSinceEpoch(1790733600000, isUtc: true));
      expect(chat.endTime, DateTime.fromMillisecondsSinceEpoch(1790733700000, isUtc: true));
    });
  });

  group('gifts', () {
    test('a catalogued gift is priced in fen, with its combo and receiver', () {
      final message = _decode([
        'type@=dgb/rid@=$_roomId/gfid@=20001/gfn@=火箭/gfcnt@=3/hits@=5/uid@=u1/nn@=Ann/receive_nn@=Chan/level@=10/bnn@=fan/bl@=2/',
      ]).single;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '火箭 ×3');
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '20001');
      expect(gift.name, '火箭');
      expect(gift.iconUrl, 'https://gift.douyucdn.cn/rocket.png');
      expect(gift.count, 3);
      expect(gift.value.unit, LiveGiftUnit.fen);
      expect(gift.value.unitPrice, 100);
      expect(gift.value.totalValue, 300);
      expect(gift.combo.comboKey, 'u1:20001');
      expect(gift.combo.comboTotal, 5);
      expect(gift.recipientName, 'Chan');
    });

    test('an unknown gift keeps its name, a backpack prop is free', () {
      final unknown = _decode(['type@=dgb/gfid@=99999/gfn@=礼物/']).single;
      expect((unknown.payload! as LiveGift).value.unit, LiveGiftUnit.other);
      expect((unknown.payload! as LiveGift).value.totalValue, isNull);

      final backpack = _decode(['type@=dgb/gfid@=20001/gfn@=火箭/gfcnt@=1/gpf@=1/']).single;
      expect((backpack.payload! as LiveGift).value.unit, LiveGiftUnit.free);

      final prop = _decode(['type@=dgb/gfid@=0/pid@=7/gfn@=喇叭/']).single;
      final propGift = prop.payload! as LiveGift;
      expect(propGift.giftId, '7');
      expect(propGift.value.unit, LiveGiftUnit.free);
    });

    test('another room and a gift without a name are dropped', () {
      expect(_decode(['type@=dgb/rid@=999/gfid@=20001/gfn@=火箭/']), isEmpty);
      expect(_decode(['type@=dgb/gfid@=99999/']), isEmpty);
    });
  });

  group('end of broadcast', () {
    test('the room ending is flagged and stops the frame', () {
      final read = DouyuDanmakuProtocol.read(
        _frame([
          'type@=chatmsg/rid@=$_roomId/txt@=hi/',
          'type@=rss/rid@=$_roomId/ss@=0/',
          'type@=chatmsg/rid@=$_roomId/txt@=after/',
        ]),
        roomId: _roomId,
      );
      expect(read.ended, isTrue);
      expect(read.messages.single.text, 'hi');
      expect(DouyuDanmakuProtocol.read(_frame(['type@=rss/rid@=999/ss@=0/']), roomId: _roomId).ended, isFalse);
      expect(DouyuDanmakuProtocol.read(_frame(['type@=rss/rid@=$_roomId/ss@=1/']), roomId: _roomId).ended, isFalse);
    });
  });

  group('play data', () {
    test('the tier list is deduplicated, and no pushed stream has no quality', () {
      final qualities = DouyuPlayParser.qualities({
        'streamStatus': 1,
        'multirates': [
          {'rate': 0, 'name': '原画'},
          {'rate': 2, 'name': '高清'},
          {'rate': 2, 'name': '重复'},
        ],
      });
      expect(qualities.map((quality) => quality.qualityId), ['0', '2']);
      expect(qualities.map((quality) => quality.label), ['原画', '高清']);
      expect(DouyuPlayParser.qualities({'streamStatus': 1, 'rate': 4}).single.qualityId, '4');
      expect(
        () => DouyuPlayParser.qualities({'streamStatus': 0}),
        throwsA(isA<DouyuFailure>().having((failure) => failure.kind, 'kind', DouyuFailureKind.streamUnavailable)),
      );
    });

    test('the CDN list puts the answering CDN first and scdn codes last', () {
      expect(
        DouyuPlayParser.cdns({
          'cdnsWithName': [
            {'cdn': 'hs'},
            {'cdn': 'scdn1'},
            {'cdn': 'hs'},
            {'cdn': 'ali'},
          ],
          'rtmp_cdn': 'wt',
        }),
        ['wt', 'hs', 'ali', 'scdn1'],
      );
      expect(DouyuPlayParser.cdns({}), ['']);
    });

    test('the media URL is the absolute one, or the joined base and path', () {
      expect(DouyuPlayParser.mediaUrl({'rtmp_live': 'https://cdn.example/live.flv'}), 'https://cdn.example/live.flv');
      expect(
        DouyuPlayParser.mediaUrl({'rtmp_url': 'https://cdn.example/', 'rtmp_live': '/live.flv'}),
        'https://cdn.example/live.flv',
      );
      expect(
        DouyuPlayParser.mediaUrl({'player_1': 'https://cdn.example/a.mp4?x=1&amp;y=2'}),
        'https://cdn.example/a.mp4?x=1&y=2',
      );
      expect(DouyuPlayParser.mediaUrl({'flv_url': 'https://cdn.example/a.flv'}), 'https://cdn.example/a.flv');
      expect(DouyuPlayParser.mediaUrl({'rtmp_url': 'https://cdn.example'}), isNull);
      expect(DouyuPlayParser.mediaUrl({}), isNull);
    });

    test('a stated lifetime is minutes, and the lease renews 45 s early', () {
      expect(DouyuPlayParser.statedLifetime('https://x/a.flv?expire=300'), const Duration(seconds: 300));
      expect(DouyuPlayParser.statedLifetime('https://x/a.flv?expire=0'), isNull);
      expect(DouyuPlayParser.statedLifetime('https://x/a.flv'), isNull);

      final lease = DouyuPlayParser.lease('https://x/a.flv?expire=300', _issuedAt)!;
      expect(lease.expiresAt, _issuedAt.add(const Duration(minutes: 5)));
      expect(lease.refreshAt, lease.expiresAt!.subtract(DouyuPlayParser.leaseLead));
      expect(lease.requiresReconnect, isTrue);

      final short = DouyuPlayParser.lease('https://x/a.flv?expire=120', _issuedAt)!;
      expect(short.refreshAt, short.expiresAt!.subtract(const Duration(seconds: 30)));
    });

    test('a renewal can be forced on a FLV that states no lifetime', () {
      final forced = DouyuPlayParser.lease('https://x/a.flv', _issuedAt, forceRenewal: true)!;
      expect(forced.expiresAt, _issuedAt.add(DouyuPlayParser.forcedLeaseLifetime));
      expect(forced.refreshAt, forced.expiresAt!.subtract(DouyuPlayParser.leaseLead));
      expect(DouyuPlayParser.lease('https://x/a.m3u8', _issuedAt, forceRenewal: true), isNull);
      expect(DouyuPlayParser.lease('https://x/a.flv', _issuedAt), isNull);
    });

    test('an answer builds its line with headers, format, lease and confirmed rate', () {
      final (:line, :rate) = DouyuPlayParser.answer(
        {'rtmp_live': 'https://cdn.example/a.flv?expire=300', 'rate': 2},
        roomId: _roomId,
        cdn: 'hs',
        cookie: 'did=1',
        issuedAt: _issuedAt,
      );
      expect(line.lineLabel, 'hs');
      expect(line.format, LiveStreamFormat.flv);
      expect(line.headers['referer'], 'https://www.douyu.com/$_roomId');
      expect(line.headers['cookie'], 'did=1');
      expect(line.lease?.expiresAt, _issuedAt.add(const Duration(minutes: 5)));
      expect(rate, 2);
      expect(
        () => DouyuPlayParser.answer({}, roomId: _roomId, cdn: 'hs', cookie: '', issuedAt: _issuedAt),
        throwsA(isA<DouyuFailure>().having((failure) => failure.kind, 'kind', DouyuFailureKind.apiChanged)),
      );
    });
  });
}
