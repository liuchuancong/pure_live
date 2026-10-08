import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_protobuf.dart';

void main() {
  group('AcfunProtoWriter / AcfunProtoMessage', () {
    test('整数、布尔、字符串与字节往返', () {
      final bytes = (AcfunProtoWriter()
            ..integer(1, 0)
            ..integer(2, 300)
            ..boolean(3, true)
            ..string(4, '进入房间')
            ..bytes(5, const <int>[1, 2, 3]))
          .toBytes();
      final message = AcfunProtoMessage.decode(bytes);
      expect(message.integer(1), 0);
      expect(message.integer(2), 300);
      expect(message.boolean(3), isTrue);
      expect(message.string(4), '进入房间');
      expect(message.bytes(5), Uint8List.fromList(<int>[1, 2, 3]));
    });

    test('负数按 64 位补码写十个字节并能读回', () {
      final bytes = (AcfunProtoWriter()..integer(1, -1)).toBytes();
      expect(bytes.length, 11); // 1 字节 tag + 10 字节 varint
      expect(AcfunProtoMessage.decode(bytes).integer(1), -1);
    });

    test('没有的字段读出来是 null', () {
      final message = AcfunProtoMessage.decode((AcfunProtoWriter()..integer(1, 7)).toBytes());
      expect(message.integer(2), isNull);
      expect(message.string(2), isNull);
      expect(message.bytes(2), isNull);
      expect(message.message(2), isNull);
    });

    test('嵌套消息与重复字段', () {
      final inner = AcfunProtoWriter()
        ..string(1, 'ZtLiveCsEnterRoom')
        ..integer(2, 5);
      final bytes = (AcfunProtoWriter()
            ..message(1, inner)
            ..message(1, AcfunProtoWriter()..string(1, '第二条'))
            ..integer(9, 42))
          .toBytes();
      final message = AcfunProtoMessage.decode(bytes);
      final nested = message.messages(1);
      expect(nested, hasLength(2));
      expect(nested.first.string(1), 'ZtLiveCsEnterRoom');
      expect(nested.first.integer(2), 5);
      expect(nested.last.string(1), '第二条');
      expect(message.message(1)?.string(1), 'ZtLiveCsEnterRoom');
      expect(message.integer(9), 42);
    });

    test('读到一半截断的输入不会抛异常', () {
      final bytes = (AcfunProtoWriter()
            ..string(1, '一个很长的字符串')
            ..integer(2, 300))
          .toBytes();
      for (var cut = 1; cut < bytes.length; cut++) {
        expect(() => AcfunProtoMessage.decode(bytes.sublist(0, cut)), returnsNormally);
      }
      // 完整的输入仍然读得回来。
      expect(AcfunProtoMessage.decode(bytes).string(1), '一个很长的字符串');
    });

    test('字符串按 UTF-8 解码，非法字节返回 null 而不是抛出', () {
      final bytes = (AcfunProtoWriter()..bytes(1, const <int>[0xff, 0xfe])).toBytes();
      expect(AcfunProtoMessage.decode(bytes).string(1), isNull);
      expect(AcfunProtoMessage.decode(bytes).bytes(1), Uint8List.fromList(<int>[0xff, 0xfe]));
    });

    test('大数（毫秒时间戳）往返', () {
      const now = 1790000000000;
      final bytes = (AcfunProtoWriter()..integer(1, now)).toBytes();
      expect(AcfunProtoMessage.decode(bytes).integer(1), now);
    });
  });
}
