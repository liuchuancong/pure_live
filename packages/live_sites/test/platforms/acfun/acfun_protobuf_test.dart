import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:test/test.dart';

/// The reading rules this codec documents in its own header — varints and their
/// tags, a field sent with another wire type, the low 32 bits of a bool, merged
/// against repeated, fixed widths, groups and the frames that stop adding up —
/// are proved once for all five hand-written platform readers in
/// `test/platforms/protobuf_readers_test.dart`. What is only true of AcFun's
/// reader, or only how its link uses it, is here.
void main() {
  group('what acfun hands back', () {
    test('the bytes are a view of what is being decoded', () {
      final buffer = Uint8List.fromList((AcfunProtoWriter()..bytes(1, [1, 2, 3])).toBytes());
      final view = AcfunProtoMessage.decode(buffer).bytes(1)!;
      expect(view, [1, 2, 3]);
      buffer[buffer.length - 1] = 9;
      expect(view.last, 9, reason: 'a caller that keeps a payload copies it first');
    });

    test('a body is kept as bytes until its type name says what it is', () {
      final payload = utf8.encode(jsonEncode({'a': 1}));
      final message = AcfunProtoMessage.decode((AcfunProtoWriter()..bytes(4, payload)).toBytes());
      expect(message.bytes(4), payload);
      expect(message.string(4), '{"a":1}');
      expect(
        () => message.message(4),
        throwsFormatException,
        reason: 'the body is only walked when its type name says it is a message',
      );
    });

    test('a command body and a signal list ride on as the bytes they came in', () {
      final signal = (AcfunProtoWriter()..string(1, 'CommonActionSignalComment')).toBytes();
      final list = AcfunProtoMessage.decode((AcfunProtoWriter()..bytes(1, signal)).toBytes());
      expect(list.messages(1).single.string(1), 'CommonActionSignalComment');
      // A varint field is not a message, and asking for one is not an error.
      final counted = AcfunProtoMessage.decode((AcfunProtoWriter()..integer(1, 5)).toBytes());
      expect(counted.messages(1), isEmpty);
      expect(counted.bytes(1), isNull);
    });
  });

  group('what acfun writes', () {
    test('a fresh writer writes nothing and every call appends behind the last', () {
      expect(AcfunProtoWriter().toBytes(), isEmpty);
      final writer = AcfunProtoWriter()
        ..integer(1, 1)
        ..string(2, 'ab')
        ..integer(1, 2);
      expect(writer.toBytes(), [
        0x08, 0x01, //
        0x12, 0x02, 0x61, 0x62,
        0x08, 0x02,
      ], reason: "call order is the caller's responsibility, there is no schema to sort by");
      expect(AcfunProtoMessage.decode(writer.toBytes()).integer(1), 2);
    });

    test('a nested body is written by its own writer', () {
      final inner = (AcfunProtoWriter()..string(1, '1.2万')).toBytes();
      final outer = (AcfunProtoWriter()..bytes(2, inner)).toBytes();
      expect(AcfunProtoMessage.decode(outer).message(2)!.string(1), '1.2万');
    });
  });
}
