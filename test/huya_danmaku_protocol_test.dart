import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';

void main() {
  group('Huya danmaku protocol', () {
    test('uses the current OnUserHeartBeat payload', () {
      final heartbeat = HuyaDanmaku().heartbeatData;

      expect(heartbeat.length, 112);
      expect(utf8.decode(heartbeat, allowMalformed: true), contains('OnUserHeartBeat'));
      expect(heartbeat, isNot(base64.decode('ABQdAAwsNgBM')));
    });

    test('serializes the current room registration fields', () {
      const uid = 294636272;
      final packet = HuyaDanmaku().getJoinData(uid);
      final outer = TarsInputStream(Uint8List.fromList(packet));

      expect(outer.read(0, 0, false), 1);
      final inner = TarsInputStream(Uint8List.fromList(outer.readBytes(1, false)));
      expect(inner.read(0, 0, false), uid);
      expect(inner.read(false, 1, false), isFalse);
      expect(inner.read('', 2, false), isEmpty);
      expect(inner.read('', 3, false), isEmpty);
      expect(inner.read(0, 4, false), 0);
      expect(inner.read(0, 5, false), 0);
      expect(inner.read(0, 6, false), uid);
      expect(inner.read(0, 7, false), 3);
    });
  });
}
