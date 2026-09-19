import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/bilibili_danmaku.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';

void main() {
  group('Bilibili danmaku protocol', () {
    test('parses every nested packet from a zlib notification', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      final nested = BytesBuilder(copy: false)
        ..add(_chatPacket('first', 'alice'))
        ..add(_chatPacket('second', 'bob'));
      final compressed = zlib.encode(nested.takeBytes());

      danmaku.decodeMessage(_packet(compressed, operation: 5, protocolVersion: 2));

      final chats = received.where((message) => message.type == LiveMessageType.chat).toList();
      expect(chats.map((message) => message.message), ['first', 'second']);
      expect(chats.map((message) => message.userName), ['alice', 'bob']);
    });

    test('parses concatenated top-level packets and auth acknowledgement', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      var readyCount = 0;
      danmaku.onMessage = received.add;
      danmaku.onReady = () => readyCount++;

      final stream = BytesBuilder(copy: false)
        ..add(_onlinePacket(12345))
        ..add(_chatPacket('visible', 'viewer'))
        ..add(_packet(utf8.encode('{"code":0}'), operation: 8));

      danmaku.decodeMessage(stream.takeBytes());

      expect(received.first.type, LiveMessageType.online);
      expect(received.first.data, isA<LiveAudienceUpdate>());
      expect((received.first.data as LiveAudienceUpdate).kind, LiveAudienceMetricKind.popularity);
      expect((received.first.data as LiveAudienceUpdate).value, 12345);
      expect(received.last.message, 'visible');
      expect(danmaku.isConnected, isTrue);
      expect(readyCount, 1);
    });

    test('malformed zero-length frame cannot loop or discard an earlier valid packet', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      final malformed = Uint8List(16);
      final header = ByteData.sublistView(malformed);
      header.setUint32(0, 0, Endian.big);
      header.setUint16(4, 16, Endian.big);
      final stream = BytesBuilder(copy: false)
        ..add(_chatPacket('before malformed frame', 'alice'))
        ..add(malformed);

      danmaku.decodeMessage(stream.takeBytes());
      danmaku.decodeMessage(_chatPacket('next websocket message', 'bob'));

      expect(received.map((message) => message.message), ['before malformed frame', 'next websocket message']);
    });

    test('compressed packet recursion is bounded and a later message still parses', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      List<int> nested = _chatPacket('too deep', 'alice');
      for (var index = 0; index < 4; index++) {
        nested = _packet(zlib.encode(nested), operation: 5, protocolVersion: 2);
      }
      danmaku.decodeMessage(nested);
      danmaku.decodeMessage(_chatPacket('connection survives', 'bob'));

      expect(received.map((message) => message.message), ['connection survives']);
    });

    test('prefers the complete rich username over a masked legacy field', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(_chatPacket('hello', '旧***', richUserName: '完整用户名'));

      expect(received.single.userName, '完整用户名');
      expect(received.single.userId, '1000');
    });

    test('does not replace a complete legacy username with masked rich data', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;

      danmaku.decodeMessage(_chatPacket('hello', '完整旧用户名', richUserName: '新***'));

      expect(received.single.userName, '完整旧用户名');
    });

    test('keeps cumulative watched count separate from popularity', () {
      final danmaku = BiliBiliDanmaku();
      final received = <LiveMessage>[];
      danmaku.onMessage = received.add;
      final body = json.encode({
        'cmd': 'WATCHED_CHANGE',
        'data': {'num': 18342},
      });

      danmaku.decodeMessage(_packet(utf8.encode(body), operation: 5));

      final update = received.single.data as LiveAudienceUpdate;
      expect(update.kind, LiveAudienceMetricKind.totalViewers);
      expect(update.value, 18342);
    });

    test('current web auth declares queue acknowledgement support', () {
      final danmaku = BiliBiliDanmaku();
      final payload = danmaku.buildJoinPayload(
        BiliBiliDanmakuArgs(
          roomId: 7734200,
          token: 'token-fixture',
          serverUrls: const ['wss://fixture.invalid/sub'],
          buvid: 'buvid-fixture',
          uid: 42,
          cookie: 'DedeUserID=42;SESSDATA=fixture',
        ),
        queueUuid: '1a2b3c4d',
      );

      expect(payload['uid'], 42);
      expect(payload['roomid'], 7734200);
      expect(payload['support_ack'], isTrue);
      expect(payload['queue_uuid'], '1a2b3c4d');
      expect(payload['scene'], 'room');

      final generatedQueueUuid = danmaku.buildJoinPayload(
        BiliBiliDanmakuArgs(
          roomId: 7734200,
          token: 'token-fixture',
          serverUrls: const ['wss://fixture.invalid/sub'],
          buvid: 'buvid-fixture',
          uid: 0,
          cookie: '',
        ),
      )['queue_uuid'];
      expect(generatedQueueUuid, isA<String>());
      expect(generatedQueueUuid as String, matches(RegExp(r'^[0-9a-f]{8}$')));
    });

    test('acknowledges an ack-required message without dropping its chat', () {
      final sent = <List<int>>[];
      final received = <LiveMessage>[];
      final danmaku = BiliBiliDanmaku(packetSender: sent.add)..onMessage = received.add;
      final payload = json.encode({
        'cmd': 'DANMU_MSG:4:0:2:2:2:0',
        'msg_id': 'fixture-message-id',
        'p_is_ack': true,
        'p_msg_type': 1,
        'info': [
          [0, 1, 25, 0x64B5F6],
          'ack me',
          [1000, 'viewer'],
        ],
      });

      danmaku.decodeMessage(_packet(utf8.encode(payload), operation: 5));

      expect(received.single.message, 'ack me');
      expect(sent, hasLength(1));
      final ack = _decodePacket(sent.single);
      expect(ack.operation, 24);
      expect(json.decode(utf8.decode(ack.body)), {
        'msg_id': 'fixture-message-id',
        'cmd': 'DANMU_MSG:4:0:2:2:2:0',
        'p_msg_type': 1,
      });
    });

    test('ignores incomplete acknowledgement metadata but still emits chat', () {
      final sent = <List<int>>[];
      final received = <LiveMessage>[];
      final danmaku = BiliBiliDanmaku(packetSender: sent.add)..onMessage = received.add;
      final payload = json.encode({
        'cmd': 'DANMU_MSG:4:0:2:2:2:0',
        'p_is_ack': true,
        'p_msg_type': 1,
        'info': [
          [0, 1, 25, 0x64B5F6],
          'still visible',
          [1000, 'viewer'],
        ],
      });

      danmaku.decodeMessage(_packet(utf8.encode(payload), operation: 5));

      expect(received.single.message, 'still visible');
      expect(sent, isEmpty);
    });

    test('binds logged-in websocket uid to the same Cookie identity', () {
      expect(
        BiliBiliSite.resolveDanmakuUid(
          cookie: 'SESSDATA=fixture; DedeUserID=778899; bili_jct=fixture',
          storedUserId: 42,
        ),
        778899,
      );
      expect(BiliBiliSite.resolveDanmakuUid(cookie: 'SESSDATA=fixture', storedUserId: 42), 42);
      expect(BiliBiliSite.resolveDanmakuUid(cookie: '', storedUserId: 42), 0);
      expect(BiliBiliSite.resolveDanmakuUid(cookie: 'SESSDATA=fixture', storedUserId: -1), 0);
    });
  });
}

({int operation, Uint8List body}) _decodePacket(List<int> packet) {
  final bytes = Uint8List.fromList(packet);
  final header = ByteData.sublistView(bytes);
  final packetLength = header.getUint32(0, Endian.big);
  final headerLength = header.getUint16(4, Endian.big);
  return (operation: header.getUint32(8, Endian.big), body: bytes.sublist(headerLength, packetLength));
}

Uint8List _chatPacket(String message, String userName, {String? richUserName}) {
  final metadata = <dynamic>[0, 1, 25, 0x64B5F6];
  if (richUserName != null) {
    while (metadata.length <= 15) {
      metadata.add(null);
    }
    metadata[15] = {
      'user': {
        'base': {'name': richUserName},
      },
    };
  }
  final payload = json.encode({
    'cmd': 'DANMU_MSG:4:0:2:2:2:0',
    'info': [
      metadata,
      message,
      [1000, userName],
    ],
  });
  return _packet(utf8.encode(payload), operation: 5);
}

Uint8List _onlinePacket(int online) {
  final body = ByteData(4)..setUint32(0, online, Endian.big);
  return _packet(body.buffer.asUint8List(), operation: 3, protocolVersion: 1);
}

Uint8List _packet(List<int> body, {required int operation, int protocolVersion = 0}) {
  final bytes = Uint8List(16 + body.length);
  final header = ByteData.sublistView(bytes);
  header.setUint32(0, bytes.length, Endian.big);
  header.setUint16(4, 16, Endian.big);
  header.setUint16(6, protocolVersion, Endian.big);
  header.setUint32(8, operation, Endian.big);
  header.setUint32(12, 1, Endian.big);
  bytes.setRange(16, bytes.length, body);
  return bytes;
}
