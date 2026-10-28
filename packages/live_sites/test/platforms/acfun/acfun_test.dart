import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:live_sites/src/models/audience/live_audience_update/live_audience_update.dart';
import 'package:live_sites/src/models/enums/live_audience_signal_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_danmaku_codec.dart';
import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_room_parser.dart';
import 'package:test/test.dart';

const int _millis = 1790733600000;

const AcfunGiftCatalog _gifts = AcfunGiftCatalog({
  '1': AcfunGiftInfo(id: '1', name: '香蕉', price: 0, banana: true),
  '2': AcfunGiftInfo(id: '2', name: '快乐水', price: 10, iconUrl: 'https://static.acfun.com/gift/2.png'),
  '3': AcfunGiftInfo(id: '3', name: '谢谢参与', price: 0),
});

Uint8List _user({int id = 42, String name = 'Ann'}) =>
    (AcfunProtoWriter()
          ..integer(1, id)
          ..string(2, name))
        .toBytes();

Uint8List _giftSignal({
  Object? user = _defaultUser,
  int? giftId = 2,
  int? count = 2,
  int? combo = 3,
  String comboId = 'c1',
  int? millis = _millis,
}) {
  final writer = AcfunProtoWriter();
  if (user != null) writer.bytes(1, user is Uint8List ? user : _user());
  if (millis != null) writer.integer(2, millis);
  if (giftId != null) writer.integer(3, giftId);
  if (count != null) writer.integer(4, count);
  if (combo != null) writer.integer(5, combo);
  if (comboId.isNotEmpty) writer.string(7, comboId);
  return writer.toBytes();
}

const Object _defaultUser = Object();

Uint8List _bananaSignal({Object? user = _defaultUser, int count = 5, int? millis = _millis}) {
  final writer = AcfunProtoWriter();
  if (user != null) writer.bytes(1, user is Uint8List ? user : _user());
  writer.integer(2, count);
  if (millis != null) writer.integer(3, millis);
  return writer.toBytes();
}

Uint8List _commentSignal(String text, {int? millis = _millis, Uint8List? user}) =>
    (AcfunProtoWriter()
          ..string(1, text)
          ..integer(2, millis ?? 0)
          ..bytes(3, user ?? _user()))
        .toBytes();

Uint8List _actionBody(List<(String, Uint8List)> signals) {
  final body = AcfunProtoWriter();
  for (final (type, payload) in signals) {
    body.bytes(
      1,
      (AcfunProtoWriter()
            ..string(1, type)
            ..bytes(2, payload))
          .toBytes(),
    );
  }
  return body.toBytes();
}

Uint8List _stateBody(String type, Uint8List payload) => _actionBody([(type, payload)]);

Uint8List _message(String type, [Uint8List? body, int compression = 0]) {
  final writer = AcfunProtoWriter()
    ..string(1, type)
    ..integer(2, compression);
  if (body != null) writer.bytes(3, body);
  writer
    ..string(4, 'live1')
    ..integer(6, _millis);
  return writer.toBytes();
}

void main() {
  group('gift signal', () {
    test('a table gift is priced in AC coins, with its combo and per-send id', () {
      final message = AcfunDanmakuProtocol.gift(_giftSignal(), gifts: _gifts)!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '快乐水 x2');
      expect(message.messageId, '42:c1:3');
      expect(message.sender?.userId, '42');
      expect(message.sender?.userName, 'Ann');
      expect(message.sentAt, DateTime.fromMillisecondsSinceEpoch(_millis));
      final gift = message.payload! as LiveGift;
      expect(gift.giftId, '2');
      expect(gift.name, '快乐水');
      expect(gift.iconUrl, 'https://static.acfun.com/gift/2.png');
      expect(gift.count, 2);
      expect(gift.value.unit, LiveGiftUnit.acCoin);
      expect(gift.value.unitPrice, 10);
      expect(gift.value.totalValue, 20);
      expect(gift.combo.comboKey, 'c1');
      expect(gift.combo.comboTotal, 6);
    });

    test('a gift the table does not know keeps an unknown value; a zero price is free', () {
      final unknown = AcfunDanmakuProtocol.gift(_giftSignal(giftId: 9), gifts: _gifts)!;
      final unknownGift = unknown.payload! as LiveGift;
      expect(unknownGift.name, '');
      expect(unknownGift.value.unit, LiveGiftUnit.other);
      expect(unknownGift.value.unitPrice, isNull);

      final free = AcfunDanmakuProtocol.gift(_giftSignal(giftId: 3, count: 1, combo: null), gifts: _gifts)!;
      final freeGift = free.payload! as LiveGift;
      expect(freeGift.name, '谢谢参与');
      expect(freeGift.value.unit, LiveGiftUnit.free);
      expect(freeGift.value.totalValue, isNull);
      expect(freeGift.combo.comboTotal, isNull);
    });

    test('a gift without a sender or id, or bytes that do not decode, is nothing', () {
      expect(AcfunDanmakuProtocol.gift(_giftSignal(user: null), gifts: _gifts), isNull);
      expect(AcfunDanmakuProtocol.gift(_giftSignal(giftId: null), gifts: _gifts), isNull);
      expect(AcfunDanmakuProtocol.gift(_giftSignal(giftId: 0), gifts: _gifts), isNull);
      expect(AcfunDanmakuProtocol.gift(Uint8List.fromList([0xFF, 0x01]), gifts: _gifts), isNull);
    });
  });

  group('banana signal', () {
    test('a banana is the free gift, named by the table or by the platform', () {
      final known = AcfunDanmakuProtocol.banana(_bananaSignal(), gifts: _gifts)!;
      final knownGift = known.payload! as LiveGift;
      expect(known.text, '香蕉 x5');
      expect(knownGift.value.unit, LiveGiftUnit.free);
      expect(knownGift.value.unitPrice, isNull);
      expect(knownGift.combo.comboKey, '');

      final bare = AcfunDanmakuProtocol.banana(_bananaSignal())!;
      expect((bare.payload! as LiveGift).name, AcfunDanmakuProtocol.bananaName);
      expect((bare.payload! as LiveGift).value.unit, LiveGiftUnit.free);
      expect(AcfunDanmakuProtocol.banana(_bananaSignal(user: null)), isNull);
    });
  });

  group('push', () {
    test('an action signal reports comments and gifts in order', () {
      final body = _actionBody([
        ('CommonActionSignalComment', _commentSignal('hello')),
        ('CommonActionSignalGift', _giftSignal()),
        ('CommonActionSignalLike', Uint8List.fromList([0x08, 0x01])),
      ]);
      final push = AcfunDanmakuProtocol.push(_message('ZtLiveScActionSignal', body), gifts: _gifts);
      expect(push.messages.map((message) => message.type), [LiveMessageType.chat, LiveMessageType.gift]);
      expect(push.messages.first.text, 'hello');
      expect(push.messages.first.sender?.userName, 'Ann');
      expect(push.ticketInvalid, isFalse);
      expect(push.statusChanged, isNull);
    });

    test('a gzipped signal decodes the same way', () {
      final body = _actionBody([('CommonActionSignalComment', _commentSignal('packed'))]);
      final push = AcfunDanmakuProtocol.push(
        _message('ZtLiveScActionSignal', Uint8List.fromList(gzip.encode(body)), 2),
        gifts: _gifts,
      );
      expect(push.messages.single.text, 'packed');
    });

    test('the display info is the concurrent audience', () {
      final payload = (AcfunProtoWriter()..string(1, '1.2万')).toBytes();
      final push = AcfunDanmakuProtocol.push(
        _message('ZtLiveScStateSignal', _stateBody('CommonStateSignalDisplayInfo', payload)),
      );
      final message = push.messages.single;
      expect(message.type, LiveMessageType.audienceUpdate);
      final audience = message.payload! as LiveAudienceUpdate;
      expect(audience.kind, LiveAudienceSignalKind.onlineViewers);
      expect(audience.value, 12000);
    });

    test('a dead ticket and a status change are flagged, not reported', () {
      final invalid = AcfunDanmakuProtocol.push(_message('ZtLiveScTicketInvalid'));
      expect(invalid.ticketInvalid, isTrue);
      expect(invalid.messages, isEmpty);

      final closed = AcfunDanmakuProtocol.push(
        _message('ZtLiveScStatusChanged', (AcfunProtoWriter()..integer(1, 2)).toBytes()),
      );
      expect(closed.statusChanged, 2);
      expect(closed.ticketInvalid, isFalse);
    });

    test('a message that does not decode yields nothing', () {
      final push = AcfunDanmakuProtocol.push(Uint8List.fromList([0xFF, 0x01]));
      expect(push.messages, isEmpty);
      expect(push.ticketInvalid, isFalse);
      expect(push.statusChanged, isNull);
    });
  });

  group('protocol', () {
    test('acSecurity is a Base64 AES-128 key or nothing', () {
      expect(AcfunDanmakuProtocol.securityKey(base64.encode(List.filled(16, 7))), hasLength(16));
      expect(AcfunDanmakuProtocol.securityKey(base64.encode([1, 2, 3])), isNull);
      expect(AcfunDanmakuProtocol.securityKey('not base64!'), isNull);
      expect(AcfunDanmakuProtocol.securityKey(''), isNull);
    });

    test('a frame round-trips, and malformed frames are refused', () {
      final headerBytes = (AcfunProtoWriter()..integer(8, 2)).toBytes();
      final payloadBytes = Uint8List.fromList([1, 2, 3]);
      final frame = AcfunDanmakuProtocol.frame(headerBytes, payloadBytes);
      final (:header, :payload) = AcfunDanmakuProtocol.unframe(frame);
      expect(header.integer(8), 2);
      expect(payload, [1, 2, 3]);
      expect(() => AcfunDanmakuProtocol.unframe(Uint8List.fromList([0, 0, 1, 2])), throwsA(isA<FormatException>()));
    });

    test('the enter-room answer gives the heartbeat interval', () {
      expect(
        AcfunDanmakuProtocol.heartbeatInterval((AcfunProtoWriter()..integer(1, 5000)).toBytes()),
        const Duration(seconds: 5),
      );
      expect(AcfunDanmakuProtocol.heartbeatInterval((AcfunProtoWriter()..integer(1, 0)).toBytes()), isNull);
    });
  });
}
