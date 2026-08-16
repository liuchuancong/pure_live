import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/core/danmaku/bilibili_danmaku.dart';

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
      expect(received.first.data, 12345);
      expect(received.last.message, 'visible');
      expect(danmaku.isConnected, isTrue);
      expect(readyCount, 1);
    });
  });
}

Uint8List _chatPacket(String message, String userName) {
  final payload = json.encode({
    'cmd': 'DANMU_MSG:4:0:2:2:2:0',
    'info': [
      [0, 1, 25, 0x64B5F6],
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
