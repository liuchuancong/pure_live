import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/models/enums/live_gift_kind.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/enums/live_message_type.dart';
import 'package:live_sites/src/models/enums/live_notice_kind.dart';
import 'package:live_sites/src/models/gift/live_gift/live_gift.dart';
import 'package:live_sites/src/platforms/soop/danmaku/soop_danmaku_codec.dart';
import 'package:test/test.dart';

const String _uuid = '12345678-1234-1234-1234-123456789abc';

/// The body of a packet whose fields follow the leading empty field, as
/// [SoopDanmakuCodec.fieldsOf] reads them.
String _body(List<String> fields) => '\f${fields.join('\f')}';

Uint8List _frame(List<(int, String)> packets) {
  final out = BytesBuilder();
  for (final (service, body) in packets) {
    final bytes = utf8.encode(body);
    final header = '\x1b\t${service.toString().padLeft(4, '0')}${bytes.length.toString().padLeft(6, '0')}00';
    out
      ..add(ascii.encode(header))
      ..add(bytes);
  }
  return out.toBytes();
}

SoopPacket _packet(int service, List<String> fields) =>
    (service: service, body: Uint8List.fromList(utf8.encode(_body(fields))));

void main() {
  group('packets', () {
    test('a frame carries several packets, and the split stops at a bad one', () {
      final frame = _frame([
        (SoopDanmakuCodec.chatService, _body(['hi'])),
        (SoopDanmakuCodec.balloonService, 'x'),
      ]);
      final packets = SoopDanmakuCodec.packets(frame);
      expect(packets.map((packet) => packet.service), [SoopDanmakuCodec.chatService, SoopDanmakuCodec.balloonService]);
      expect(utf8.decode(packets.last.body), 'x');

      final broken = Uint8List.fromList([...frame, ...ascii.encode('\x1b\t000500000200\f')]);
      expect(SoopDanmakuCodec.packets(broken), hasLength(2));
    });

    test('the join packet counts the chat number in UTF-8 bytes', () {
      expect(SoopDanmakuCodec.join('123'), '\x1b\t000200000900\f123\f\f\f\f\f');
      expect(SoopDanmakuCodec.join('방'), '\x1b\t000200000900\f방\f\f\f\f\f');
    });
  });

  group('chat', () {
    test('text, sender and nick, with a second session marker dropped from the id', () {
      final body = _body(['hello', 'loo3672(2)', 'x', 'x', 'x', 'Ann']);
      final message = SoopDanmakuCodec.chat(utf8.encode(body))!;
      expect(message.type, LiveMessageType.chat);
      expect(message.text, 'hello');
      expect(message.sender?.userId, 'loo3672');
      expect(message.sender?.userName, 'Ann');
      expect(SoopDanmakuCodec.userId('loo3672'), 'loo3672');
      expect(SoopDanmakuCodec.userId('loo3672(12)'), 'loo3672');
    });

    test('a line without text, nick or enough fields is nothing', () {
      expect(SoopDanmakuCodec.chat(utf8.encode(_body(['', 'u', 'x', 'x', 'x', 'Ann']))), isNull);
      expect(SoopDanmakuCodec.chat(utf8.encode(_body(['hi', 'u', 'x', 'x', 'x', '']))), isNull);
      expect(SoopDanmakuCodec.chat(utf8.encode(_body(['hi', 'u']))), isNull);
    });
  });

  group('balloons', () {
    test('a star balloon is counted in star balloons and keeps the packet uuid', () {
      final message = SoopDanmakuCodec.balloon(
        _packet(SoopDanmakuCodec.balloonService, ['', 's1', 'Ann', '10', '', '', '', '', '', '', '', _uuid]),
      )!;
      expect(message.type, LiveMessageType.gift);
      expect(message.text, '별풍선 ×10');
      expect(message.messageId, _uuid);
      expect(message.sender?.userId, 's1');
      expect(message.sender?.userName, 'Ann');
      final gift = message.payload! as LiveGift;
      expect(gift.name, SoopDanmakuCodec.starBalloonName);
      expect(gift.count, 10);
      expect(gift.kind, LiveGiftKind.tip);
      expect(gift.value.unit, LiveGiftUnit.starBalloon);
      expect(gift.value.unitPrice, 1);
      expect(gift.value.totalValue, 10);
    });

    test('a relayed star balloon reads its fields one further on', () {
      final message = SoopDanmakuCodec.balloon(
        _packet(SoopDanmakuCodec.relayedBalloonService, ['', '', '', 's3', 'Cid', '7', '', '', '', '', '', '', _uuid]),
      )!;
      expect(message.sender?.userName, 'Cid');
      expect(message.text, '별풍선 ×7');
      expect(message.messageId, _uuid);
    });

    test('an ad balloon has its picture and no value this app can place', () {
      final message = SoopDanmakuCodec.balloon(
        _packet(SoopDanmakuCodec.adBalloonService, [
          '',
          '',
          's2',
          'Bob',
          '',
          '',
          '',
          'https://cdn.example/ad.png',
          '',
          '3',
          '',
          '',
          '',
          '',
          '',
          _uuid,
        ]),
      )!;
      final gift = message.payload! as LiveGift;
      expect(gift.name, SoopDanmakuCodec.adBalloonName);
      expect(gift.iconUrl, 'https://cdn.example/ad.png');
      expect(gift.value.unit, LiveGiftUnit.other);
      expect(gift.value.totalValue, isNull);
      expect(message.messageId, _uuid);
    });

    test('a video balloon is a star balloon without an id', () {
      final message = SoopDanmakuCodec.balloon(
        _packet(SoopDanmakuCodec.videoBalloonService, ['', '', 's4', 'Dan', '4']),
      )!;
      final gift = message.payload! as LiveGift;
      expect(gift.name, SoopDanmakuCodec.videoBalloonName);
      expect(gift.value.unit, LiveGiftUnit.starBalloon);
      expect(message.messageId, '');
    });

    test('a balloon without a sender or with no count is nothing', () {
      expect(SoopDanmakuCodec.balloon(_packet(SoopDanmakuCodec.balloonService, ['', '', 'Ann', '10'])), isNull);
      expect(SoopDanmakuCodec.balloon(_packet(SoopDanmakuCodec.balloonService, ['', 's1', 'Ann', '0'])), isNull);
      expect(SoopDanmakuCodec.balloon(_packet(SoopDanmakuCodec.chatService, ['', 's1', 'Ann', '10'])), isNull);
    });
  });

  group('subscriptions', () {
    test('a subscription names the subscriber and its id', () {
      final message = SoopDanmakuCodec.subscription(
        _packet(SoopDanmakuCodec.subscriptionService, ['', '', 's5', 'Ann', '', '', '', '', _uuid]),
      )!;
      expect(message.type, LiveMessageType.notice);
      expect(message.payload, LiveNoticeKind.subscription);
      expect(message.text, 'Ann 订阅了频道');
      expect(message.messageId, 'subscription:$_uuid');
      expect(message.sender?.userId, 's5');
    });

    test('the ceremony adds the months it read', () {
      final message = SoopDanmakuCodec.subscription(
        _packet(SoopDanmakuCodec.subscriptionMonthsService, ['', 's6', 'Eve', '', '', '', '3', '', _uuid]),
      )!;
      expect(message.text, 'Eve 订阅了频道，已订阅 3 个月');
      final fallback = SoopDanmakuCodec.subscription(
        _packet(SoopDanmakuCodec.subscriptionMonthsService, ['', 's6', 'Eve', '5']),
      )!;
      expect(fallback.text, 'Eve 订阅了频道，已订阅 5 个月');
      expect(fallback.messageId, '');
    });

    test('a subscription without a sender is nothing', () {
      expect(SoopDanmakuCodec.subscription(_packet(SoopDanmakuCodec.subscriptionService, ['', '', '', 'Ann'])), isNull);
      expect(SoopDanmakuCodec.subscription(_packet(SoopDanmakuCodec.adBalloonService, ['', '', 's', 'A'])), isNull);
    });
  });

  group('decode', () {
    test('one frame gives its chat, gift and subscription, and ignores the rest', () {
      final frame = _frame([
        (SoopDanmakuCodec.chatService, _body(['hello', 'u1', 'x', 'x', 'x', 'Ann'])),
        (SoopDanmakuCodec.balloonService, _body(['', 's1', 'Bob', '2', '', '', '', '', '', '', '', _uuid])),
        (SoopDanmakuCodec.subscriptionService, _body(['', '', 's2', 'Cid', '', '', '', '', _uuid])),
        (999, _body(['ignored'])),
      ]);
      final messages = SoopDanmakuCodec.decode(frame);
      expect(messages.map((message) => message.type), [
        LiveMessageType.chat,
        LiveMessageType.gift,
        LiveMessageType.notice,
      ]);
    });
  });

  group('wiring', () {
    test('handshake headers are spelled as the chat edge writes them', () {
      expect(SoopDanmakuCodec.handshakeHeaders({'user-agent': 'UA', 'origin': 'https://soop.example'}), {
        'User-Agent': 'UA',
        'Origin': 'https://soop.example',
      });
      expect(SoopDanmakuCodec.headerName('sec-websocket-protocol'), 'Sec-Websocket-Protocol');
    });

    test('endpoints try the TLS port first, then the plain one', () {
      final args = SoopDanmakuArgs(
        url: Uri.parse('wss://chat.example:8444/Websocket/123'),
        plainUrl: Uri.parse('ws://chat.example:8443/Websocket/123'),
        chatNo: '123',
        headers: const {},
      );
      expect(SoopDanmakuCodec.endpoints(args), [
        Uri.parse('wss://chat.example:8444/Websocket/123'),
        Uri.parse('ws://chat.example:8443/Websocket/123'),
      ]);
    });
  });
}
