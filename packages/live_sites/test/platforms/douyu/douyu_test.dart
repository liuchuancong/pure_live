import 'dart:async';

import 'package:live_net/live_net.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyu/api/douyu_http.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_danmaku_session.dart';
import 'package:live_sites/src/platforms/douyu/danmaku/douyu_stt_codec.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_play_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_room_parser.dart';
import 'package:test/test.dart';

/// A transport that never answers: the descriptor test injects its own fetch.
final class _NoopHttp implements LiveHttp {
  @override
  Future<LiveResponse> send(LiveRequest request) async => throw UnimplementedError();

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) async => throw UnimplementedError();

  @override
  void close() {}
}

/// A server frame is a run of `length(4) length(4) type(2) enc(1) resv(1)
/// body \0` little-endian packets; the codec's own packet() wraps a body, so
/// these tests build real frames without I/O.
List<int> frameOf(List<String> bodies) {
  final out = <int>[];
  for (final body in bodies) {
    out.addAll(DouyuDanmakuProtocol.packet(body));
  }
  return out;
}

DouyuGiftCatalog catalogWith(String id, {required String name, int? priceFen, bool free = false}) => DouyuGiftCatalog({
  id: DouyuGiftInfo(id: id, name: name, price: priceFen, free: free, iconUrl: 'https://x/$id.png'),
});

LiveGift giftOf(List<LiveMessage> messages) => messages.single.payload! as LiveGift;

void main() {
  group('DouyuStt', () {
    test('map decodes key@=value pairs, unescaping once, later key wins', () {
      final fields = DouyuStt.map('type@=chatmsg/txt@=a@Ab@c/uid@=42/uid@=7/');
      expect(fields['type'], 'chatmsg');
      expect(fields['txt'], 'a@b@c');
      expect(fields['uid'], '7');
    });

    test('escape then unescape is identity for @ and /', () {
      const raw = 'a@b/c';
      expect(DouyuStt.unescape(DouyuStt.escape(raw)), raw);
    });

    test('list splits items and skips empties', () {
      expect(DouyuStt.list('x/y//z/'), ['x', 'y', 'z']);
    });
  });

  test('bodies recovers each packet body from a multi-packet frame', () {
    final bodies = ['type@=a/', 'type@=b/txt@=hi/'];
    expect(DouyuDanmakuProtocol.bodies(frameOf(bodies)), bodies);
  });

  group('DouyuDanmakuProtocol decoding', () {
    test('chatmsg becomes a chat message for the joined room', () {
      final r = DouyuDanmakuProtocol.read(
        frameOf(['type@=chatmsg/rid@=9999/uid@=1/nn@=Alice/col@=2/txt@=hello/']),
        roomId: '9999',
      );
      expect(r.ended, isFalse);
      expect(r.messages.single.type, LiveMessageType.chat);
      expect(r.messages.single.text, 'hello');
    });

    test("another room's chatmsg is dropped", () {
      final r = DouyuDanmakuProtocol.read(frameOf(['type@=chatmsg/rid@=1111/txt@=other/']), roomId: '9999');
      expect(r.ended, isFalse);
      expect(r.messages, isEmpty);
    });

    test('dgb is priced and pictured from the catalogue', () {
      final r = DouyuDanmakuProtocol.read(
        frameOf(['type@=dgb/rid@=9999/uid@=1/nn@=Alice/gfid@=55/gfcnt@=2/hits@=0/gpf@=0/']),
        roomId: '9999',
        gifts: catalogWith('55', name: '火箭', priceFen: 500),
      );
      final gift = giftOf(r.messages);
      expect(gift.name, '火箭');
      expect(gift.count, 2);
      expect(gift.iconUrl, 'https://x/55.png');
      expect(gift.value.unit, LiveGiftUnit.rmb);
      expect(gift.value.unitPrice, 5.0);
      expect(gift.value.totalValue, 10.0);
    });

    test('a gift the catalogue does not know is reported by packet name, unpriced', () {
      final r = DouyuDanmakuProtocol.read(
        frameOf(['type@=dgb/rid@=9999/nn@=Alice/gfn@=小心心/gfid@=9/gfcnt@=1/']),
        roomId: '9999',
      );
      final gift = giftOf(r.messages);
      expect(gift.name, '小心心');
      expect(gift.value.unitPrice, isNull);
    });

    test('a backpack prop (gpf=1) is free', () {
      final r = DouyuDanmakuProtocol.read(
        frameOf(['type@=dgb/rid@=9999/nn@=Alice/gfn@=道具/gfid@=3/gfcnt@=1/gpf@=1/']),
        roomId: '9999',
        gifts: catalogWith('3', name: '道具', priceFen: 100),
      );
      final gift = giftOf(r.messages);
      expect(gift.value.unit, LiveGiftUnit.free);
      expect(gift.value.unitPrice, isNull);
    });

    test('a gift with neither a packet name nor a known id is dropped', () {
      final r = DouyuDanmakuProtocol.read(frameOf(['type@=dgb/rid@=9999/nn@=Alice/gfid@=0/']), roomId: '9999');
      expect(r.messages, isEmpty);
    });

    test('an rss end packet for this room ends the broadcast', () {
      final r = DouyuDanmakuProtocol.read(frameOf(['type@=rss/rid@=9999/ss@=0/']), roomId: '9999');
      expect(r.ended, isTrue);
      expect(r.messages, isEmpty);
    });
  });

  group('DouyuRoomParser link helpers', () {
    test('roomIdInPage reads window.room_id', () {
      expect(DouyuRoomParser.roomIdInPage('x window.room_id = 12345; y'), '12345');
      expect(DouyuRoomParser.roomIdInPage('no id here'), isNull);
    });

    test('roomIdAt reads a numeric first path segment on a douyu host', () {
      expect(DouyuRoomParser.roomIdAt(Uri.parse('https://www.douyu.com/12345')), '12345');
      expect(DouyuRoomParser.roomIdAt(Uri.parse('https://m.douyu.com/9999')), '9999');
      expect(DouyuRoomParser.roomIdAt(Uri.parse('https://example.com/12345')), isNull);
      expect(DouyuRoomParser.roomIdAt(Uri.parse('https://www.douyu.com/lpl')), isNull);
    });

    test('isRoomKey / isNumericRid', () {
      expect(DouyuRoomParser.isRoomKey('lpl-1_A'), isTrue);
      expect(DouyuRoomParser.isRoomKey('has space'), isFalse);
      expect(DouyuRoomParser.isNumericRid('42'), isTrue);
      expect(DouyuRoomParser.isNumericRid('42a'), isFalse);
    });
  });

  test('addGifts merges a late catalogue into the live session', () {
    final session = DouyuDanmakuSession(
      roomId: '9999',
      gifts: catalogWith('1', name: 'a', priceFen: 100),
    );
    expect(session.gifts['2'], isNull);
    session.addGifts(catalogWith('2', name: 'b', priceFen: 200));
    expect(session.gifts['1']?.name, 'a');
    expect(session.gifts['2']?.name, 'b');
  });

  group('login cookie merge', () {
    test('a renewal with several Set-Cookie lines keeps every cookie after the first', () {
      // Each element is one raw Set-Cookie header (live_net keeps them per-line,
      // not the comma-joined header, which cannot be re-split).
      final renewed = DouyuAccount.renewedCookie('dy_did=abc; LTP0=keep', [
        'acf_jwt_token=NEW; path=/; domain=.douyu.com; secure',
        'acf_stk=STK; path=/; httponly',
      ]);
      expect(renewed, isNotNull);
      expect(DouyuAccount.cookieField(renewed!, 'acf_jwt_token'), 'NEW');
      expect(DouyuAccount.cookieField(renewed, 'acf_stk'), 'STK');
      expect(DouyuAccount.cookieField(renewed, 'LTP0'), 'keep', reason: 'untouched fields stay');
    });

    test('a renewal that answers no cookie leaves the saved one unchanged', () {
      expect(DouyuAccount.renewedCookie('acf_auth=x', const <String>[]), isNull);
    });
  });

  test('two concurrent descriptor misses share one fetch', () async {
    final site = DouyuSite(http: DouyuHttp(_NoopHttp()));
    var calls = 0;
    final descriptor = DouyuDescriptor(
      key: 'k',
      randStr: 'r',
      encData: 'e',
      encTime: 1,
      expireAt: DateTime.now().add(const Duration(hours: 1)),
      isSpecial: false,
    );
    Future<DouyuDescriptor> fetch() async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return descriptor;
    }

    final results = await Future.wait([site.descriptorFor('did', fetch), site.descriptorFor('did', fetch)]);
    expect(calls, 1, reason: 'the second caller joins the flight in the first');
    expect(identical(results[0], results[1]), isTrue);
  });
}
