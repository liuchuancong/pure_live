import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show md5;
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/huya/danmaku/huya_danmaku_codec.dart';
import 'package:live_sites/src/platforms/huya/huya_tars.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_room_parser.dart';
import 'package:test/test.dart';

/// Builds a server push frame: an outer struct {tag0 command, tag1 payload}
/// around a single-push payload {tag1 uri, tag2 body, tag5 message id}.
Uint8List pushFrame(int uri, Uint8List body, {int id = 0}) {
  final payload = (TarsWriter()
        ..writeInt(1, uri)
        ..writeBytes(2, body)
        ..writeInt(5, id))
      .toBytes();
  return (TarsWriter()..writeInt(0, HuyaDanmakuProtocol.pushCommand)..writeBytes(1, payload)).toBytes();
}

void main() {
  group('Tars', () {
    test('rotateUid moves the low-32-bit byte and round-trips', () {
      expect(HuyaPlayParser.rotateUid(0x00000001), 0x00000100);
      // An anonymous uid above 2^32 keeps its high half, only the low turns.
      const uid = (3 << 32) + 0x12345678;
      expect(HuyaPlayParser.unrotateUid(HuyaPlayParser.rotateUid(uid)), uid);
    });

    test('a client register frame decodes to command 16 with its groups', () {
      final frame = HuyaDanmakuProtocol.register(777);
      final outer = TarsStruct.decode(frame);
      expect(outer.integer(0), HuyaDanmakuProtocol.registerCommand);
      final payload = TarsStruct.decode(outer.bytes(1) ?? const <int>[]);
      expect(payload.list(0), containsAll(<Object>['live:777', 'chat:777']));
      expect(payload.string(1), '');
    });

    test('a heartbeat frame decodes to command 20', () {
      expect(TarsStruct.decode(HuyaDanmakuProtocol.heartbeat()).integer(0), HuyaDanmakuProtocol.heartbeatCommand);
    });
  });

  group('HuyaDanmakuProtocol decoding', () {
    test('uri 1400 becomes a chat message', () {
      final body = (TarsWriter()
            ..writeStruct(0, (s) => s..writeInt(0, 42)..writeString(2, 'Bob'))
            ..writeString(3, 'hello')
            ..writeStruct(6, (f) => f.writeInt(0, 0)))
          .toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.chatUri, body, id: 9));
      expect(r.ended, isEmpty);
      final message = r.messages.single;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.effectiveSender.userName, 'Bob');
      expect(message.effectiveSender.userId, '42');
      expect(message.messageId, 'huya:9');
    });

    test('uri 8006 becomes a popularity audience update', () {
      final body = (TarsWriter()..writeInt(0, 12345)).toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.popularityUri, body));
      final update = r.messages.single.payload! as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceSignalKind.popularity);
      expect(update.value, 12345);
    });

    test('uri 6501 becomes a gift priced from the packet, with a combo key', () {
      final body = (TarsWriter()
            ..writeInt(0, 500) // iItemType
            ..writeInt(2, 3) // iItemCount
            ..writeInt(4, 88) // lSenderUid
            ..writeString(6, 'Giver') // sSenderNick
            ..writeInt(9, 4) // iItemGroup combo counter
            ..writeString(20, '虎粮') // sPropsName
            ..writeInt(39, 999) // lComboSeqId
            ..writeInt(41, 1500)) // lPayTotal
          .toBytes();
      final r = HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.giftUri, body, id: 7));
      final gift = r.messages.single.payload! as LiveGift;
      expect(gift.name, '虎粮');
      expect(gift.count, 3);
      expect(gift.value.totalValue, 1500.0);
      expect(gift.combo.comboKey, '88:999');
      expect(gift.combo.comboTotal, 4);
      expect(r.messages.single.effectiveSender.userName, 'Giver');
    });

    test('a gift without a name is dropped', () {
      final body = (TarsWriter()..writeInt(2, 1)).toBytes();
      expect(HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.giftUri, body)).messages, isEmpty);
    });
  });

  test('a frame that is not Tars gives nothing, not a throw', () {
    expect(HuyaDanmakuProtocol.decode(const [0, 1, 2, 3]).messages, isEmpty);
  });

  group('signAntiCode', () {
    test('signs an fm template with the rotated uid and drops the template', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final wsSeconds = now.millisecondsSinceEpoch ~/ 1000;
      const stream = 'stream123';
      const uid = 123;
      const template = r'$0|$1|$2|$3';
      final antiCode =
          'fm=${Uri.encodeComponent(base64.encode(utf8.encode(template)))}'
          '&wsTime=${wsSeconds.toRadixString(16)}&ctype=huya_webh5&t=100&fs=bgct';

      final signed = HuyaPlayParser.signAntiCode(
        antiCode,
        streamName: stream,
        uid: uid,
        clock: HuyaSignClock(),
        now: now,
      );

      final millis = now.millisecondsSinceEpoch;
      final seqId = uid + millis;
      final hash = md5.convert(utf8.encode('$seqId|huya_webh5|100')).toString();
      final rotated = HuyaPlayParser.rotateUid(uid);
      final wsHex = wsSeconds.toRadixString(16);
      final expectedSecret = md5.convert(utf8.encode('$rotated|$stream|$hash|$wsHex')).toString();

      expect(signed, contains('wsSecret=$expectedSecret'));
      expect(signed, contains('u=$rotated'));
      expect(signed, contains('seqid=$seqId'));
      expect(signed, contains('ver=1'));
      expect(signed, isNot(contains('fm=')));
    });

    test('a query without fm is returned unchanged (a static token)', () {
      const antiCode = 'wsTime=abc&t=100';
      expect(
        HuyaPlayParser.signAntiCode(
          antiCode,
          streamName: 'x',
          uid: 1,
          clock: HuyaSignClock(),
          now: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        antiCode,
      );
    });

    test('a template that does not decode throws apiChanged', () {
      final antiCode = 'fm=${Uri.encodeComponent('not-base64-template-without-placeholders')}&wsTime=deadbeef';
      expect(
        () => HuyaPlayParser.signAntiCode(
          antiCode,
          streamName: 'x',
          uid: 1,
          clock: HuyaSignClock(),
          now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        ),
        throwsA(isA<HuyaFailure>()),
      );
    });
  });

  group('HuyaRoomParser link helpers', () {
    test('numeric vs alias', () {
      expect(HuyaRoomParser.isNumericId('12345'), isTrue);
      expect(HuyaRoomParser.isNumericId('lpl'), isFalse);
      expect(HuyaRoomParser.isRoomKey('lpl-1_A'), isTrue);
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://www.huya.com/12345')), '12345');
      expect(HuyaRoomParser.aliasAt(Uri.parse('https://www.huya.com/someone')), 'someone');
      expect(HuyaRoomParser.roomIdAt(Uri.parse('https://example.com/12345')), isNull);
    });

    test('roomIdFromPage reads TT_ROOM_DATA', () {
      expect(HuyaRoomParser.roomIdFromPage('var TT_ROOM_DATA = { "profileRoom": 999888 };'), '999888');
    });
  });

  group('HuyaDanmakuProtocol push/batch framing', () {
    test('uri 8001 end notice reports the streamer uid', () {
      final body = (TarsWriter()..writeInt(0, 4242)).toBytes();
      expect(HuyaDanmakuProtocol.decode(pushFrame(HuyaDanmakuProtocol.endUri, body)).ended, [4242]);
    });

    test('command 22 batch decodes every item', () {
      final chat = (TarsWriter()..writeString(3, 'one')).toBytes();
      final gift = (TarsWriter()..writeString(20, 'flower')..writeInt(2, 2)).toBytes();
      final items = <({int uri, Uint8List body})>[
        (uri: HuyaDanmakuProtocol.chatUri, body: chat),
        (uri: HuyaDanmakuProtocol.giftUri, body: gift),
      ];
      final batch = (TarsWriter()
            ..writeList<({int uri, Uint8List body})>(
              1,
              items,
              (writer, item) => writer.writeStruct(0, (s) => s..writeInt(0, item.uri)..writeBytes(1, item.body)),
            ))
          .toBytes();
      final frame = (TarsWriter()..writeInt(0, HuyaDanmakuProtocol.batchCommand)..writeBytes(1, batch)).toBytes();
      final r = HuyaDanmakuProtocol.decode(frame);
      expect(r.messages.map((m) => m.text), containsAll(<String>['one', 'flower ×2']));
    });
  });
}
