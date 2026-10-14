import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:test/test.dart';

void main() {
  group('varints', () {
    test('a one-byte varint keeps its field number and wire type', () {
      final message = AcfunProtoMessage.decode(const [0x08, 0x01]);
      expect(message.integer(1), 1);
      expect(message.fields, hasLength(1));
      expect(message.fields.single.number, 1);
      expect(message.fields.single.wireType, AcfunProtoMessage.varintType);
    });

    test('a multi-byte varint reads back its value', () {
      // Field 1, varint 300 = 0xAC 0x02.
      expect(AcfunProtoMessage.decode(const [0x08, 0xAC, 0x02]).integer(1), 300);
    });

    test("the ten-byte maximum reads as a negative two's complement int", () {
      // Field 1, varint 2^64 − 1: nine 0xFF bytes and a final 0x01.
      final message = AcfunProtoMessage.decode(const [
        0x08,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0x01,
      ]);
      expect(message.integer(1), -1);
      expect(AcfunProtoMessage.unsigned(message.integer(1)!), '18446744073709551615');
      expect(AcfunProtoMessage.unsigned(7687741736843512), '7687741736843512');
    });

    test("a negative value writes its 64-bit two's complement", () {
      final bytes = (AcfunProtoWriter()..integer(3, -1)).toBytes();
      expect(bytes, const [0x18, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x01]);
      expect(AcfunProtoMessage.decode(bytes).integer(3), -1);
    });
  });

  group('tags and field numbers', () {
    test('a multi-byte tag decodes into a field number and a wire type', () {
      // Tag 1520 = 0xF0 0x0B → field 190, varint, value 42.
      final message = AcfunProtoMessage.decode(const [0xF0, 0x0B, 0x2A]);
      expect(message.integer(190), 42);
      expect(message.fields.single.wireType, AcfunProtoMessage.varintType);
    });

    test('a tag keeps only its low 32 bits, as a generated runtime does', () {
      // Tag varint 2^32 + 8 → field 1, varint, value 7.
      expect(AcfunProtoMessage.decode(const [0x88, 0x80, 0x80, 0x80, 0x10, 0x07]).integer(1), 7);
    });

    test('a three-byte tag decodes a field number above 255', () {
      // Field 3072, length-delimited: tag 24578 = 82 C0 01, one payload byte.
      final message = AcfunProtoMessage.decode(const [0x82, 0xC0, 0x01, 0x01, 0x7A]);
      expect(message.bytes(3072), [0x7A]);
      expect(message.fields.single.number, 3072);
      expect(message.fields.single.wireType, AcfunProtoMessage.lengthDelimitedType);
    });

    test('an empty message has no fields', () {
      expect(AcfunProtoMessage.decode(const []).fields, isEmpty);
    });
  });

  group('accessors', () {
    test('every accessor picks the last occurrence of its number', () {
      final message = AcfunProtoMessage.decode(const [
        0x0A, 0x01, 0x61, // field 1 string 'a'
        0x0A, 0x01, 0x62, // field 1 string 'b'
        0x10, 0x03, // field 2 varint 3
        0x10, 0x04, // field 2 varint 4
        0x1A, 0x01, 0x07, // field 3 bytes [7]
        0x1A, 0x02, 0x08, 0x09, // field 3 bytes [8, 9]
        0x20, 0x80, 0x80, 0x80, 0x80, 0x10, // field 4 varint 2^32
      ]);
      expect(message.string(1), 'b');
      expect(message.integer(2), 4);
      expect(message.bytes(3), [8, 9]);
      expect(message.flag(2), isTrue);
      expect(message.integer(4), 4294967296);
      expect(message.fields, hasLength(7));
    });

    test('a bool is true when the low 32 bits of its varint are not zero', () {
      expect(AcfunProtoMessage.decode(const [0x48, 0x80, 0x80, 0x80, 0x80, 0x10]).flag(9), isFalse);
      expect(AcfunProtoMessage.decode(const [0x48, 0x01]).flag(9), isTrue);
      expect(AcfunProtoMessage.decode(const [0x08, 0x01]).flag(9), isFalse);
    });

    test('a field sent with another wire type is not read as its declared one', () {
      // Field 1 as fixed32 (tag 0x0D), then as a varint (tag 0x08).
      final message = AcfunProtoMessage.decode(const [0x0D, 0x01, 0x00, 0x00, 0x00, 0x08, 0x02]);
      expect(message.bytes(1), isNull);
      expect(message.string(1), isNull);
      expect(message.integer(1), 2);
    });

    test('a missing field reads as null', () {
      final message = AcfunProtoMessage.decode(const [0x08, 0x01]);
      expect(message.integer(5), isNull);
      expect(message.bytes(5), isNull);
      expect(message.string(5), isNull);
      expect(message.message(5), isNull);
      expect(message.messages(5), isEmpty);
    });

    test('malformed UTF-8 is replaced, not thrown', () {
      expect(AcfunProtoMessage.decode(const [0x0A, 0x03, 0x61, 0xFF, 0x62]).string(1), 'a\uFFFDb');
    });
  });

  group('nested messages', () {
    test('message(n) merges repeats where messages(n) keeps them apart', () {
      // Field 2 twice: {1: 7} then {3: 'x'}.
      const bytes = [0x12, 0x02, 0x08, 0x07, 0x12, 0x03, 0x1A, 0x01, 0x78];
      final merged = AcfunProtoMessage.decode(bytes).message(2)!;
      expect(merged.integer(1), 7);
      expect(merged.string(3), 'x');

      final parts = AcfunProtoMessage.decode(bytes).messages(2);
      expect(parts, hasLength(2));
      expect(parts.first.integer(1), 7);
      expect(parts.first.string(3), isNull);
      expect(parts.last.integer(1), isNull);
      expect(parts.last.string(3), 'x');
    });

    test('the codec reads every repeated payload through fields and the constants', () {
      // Field 1's type name, then three payloads: two length-delimited and one
      // varint that is not a payload at all.
      const body = [0x0A, 0x01, 0x61, 0x12, 0x01, 0x62, 0x12, 0x01, 0x63, 0x10, 0x01];
      final signal = AcfunProtoMessage.decode(body);
      final payloads = [
        for (final field in signal.fields)
          if (field.number == 2 && field.wireType == AcfunProtoMessage.lengthDelimitedType) field.value as List<int>,
      ];
      expect(signal.string(1), 'a');
      expect(payloads, [
        [0x62],
        [0x63],
      ]);
    });

    test('a nested body decodes the way the link reads one', () {
      final payload =
          (AcfunProtoWriter()
                ..string(1, 'ZtLiveScActionSignal')
                ..integer(2, 2)
                ..bytes(3, (AcfunProtoWriter()..string(1, 'CommonActionSignalComment')).toBytes()))
              .toBytes();
      final message = AcfunProtoMessage.decode(payload);
      expect(message.string(1), 'ZtLiveScActionSignal');
      expect(message.integer(2), 2);
      expect(message.message(3)?.string(1), 'CommonActionSignalComment');
    });
  });

  group('fixed widths and groups', () {
    test('fixed64 reads little-endian', () {
      final message = AcfunProtoMessage.decode(const [0x09, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]);
      expect(message.fields.single.wireType, 1);
      // 0x0102030405060708, as unsigned decimal because it is above 2^53.
      expect(AcfunProtoMessage.unsigned(message.fields.single.value as int), '72623859790382856');
      expect(message.integer(1), isNull);
    });

    test("a fixed64 above 2^63 reads as a negative two's complement int", () {
      final message = AcfunProtoMessage.decode(const [0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80]);
      expect(message.fields.single.value, -9223372036854775808);
      expect(AcfunProtoMessage.unsigned(message.fields.single.value as int), '9223372036854775808');
    });

    test('fixed32 reads little-endian', () {
      expect(AcfunProtoMessage.decode(const [0x15, 0xEF, 0xBE, 0xAD, 0xDE]).fields.single.value, 3735928559);
    });

    test('a group is skipped and reads as an empty value', () {
      // Field 3 group {1: 1}, then field 4 = 2.
      final message = AcfunProtoMessage.decode(const [0x1B, 0x08, 0x01, 0x1C, 0x20, 0x02]);
      expect(message.fields, hasLength(2));
      expect(message.fields.first.number, 3);
      expect(message.fields.first.value, isEmpty);
      expect(message.integer(4), 2);
    });
  });

  group('malformed input', () {
    void expectMalformed(List<int> bytes, String message) {
      expect(
        () => AcfunProtoMessage.decode(bytes),
        throwsA(isA<FormatException>().having((error) => error.message, 'message', message)),
      );
    }

    test('a truncated varint', () {
      expectMalformed(const [0x08], 'Truncated protobuf varint');
      expectMalformed(const [0x08, 0x80], 'Truncated protobuf varint');
      expectMalformed(const [0x80], 'Truncated protobuf varint');
    });

    test('a varint longer than ten bytes', () {
      expectMalformed(const [
        0x08,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0xFF,
        0x01,
      ], 'Protobuf varint longer than ten bytes');
    });

    test('field number 0', () {
      expectMalformed(const [0x00], 'Protobuf field number 0');
      expectMalformed(const [0x02, 0x01, 0x01], 'Protobuf field number 0');
    });

    test('a truncated length-delimited field', () {
      expectMalformed(const [0x0A, 0x05, 0x01], 'Truncated protobuf field');
    });

    test('a length read as a signed 32-bit value is negative above 2^31 − 1', () {
      // Field 1, length varint 0xFFFFFFFF → −1.
      expectMalformed(const [0x0A, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x01], 'Truncated protobuf field');
    });

    test('wire type 6 or 7', () {
      expectMalformed(const [0x0E, 0x05], 'Unsupported protobuf wire type 6');
      expectMalformed(const [0x0F], 'Unsupported protobuf wire type 7');
    });

    test('a group end with no start', () {
      expectMalformed(const [0x1C], 'Protobuf group end without a start');
    });

    test('a group that does not end, or ends another field', () {
      expectMalformed(const [0x1B], 'Truncated protobuf group');
      expectMalformed(const [0x1B, 0x08, 0x01], 'Truncated protobuf group');
      expectMalformed(const [0x1B, 0x24], 'Mismatched protobuf group end');
    });
  });

  group('writer', () {
    test('a register body writes nested messages in call order', () {
      final sdk =
          (AcfunProtoWriter()
                ..string(1, 'link-sdk')
                ..string(4, '1.2.1'))
              .toBytes();
      final client =
          (AcfunProtoWriter()
                ..string(1, 'kpn')
                ..integer(4, 1000))
              .toBytes();
      final bytes =
          (AcfunProtoWriter()
                ..bytes(1, sdk)
                ..integer(4, 1)
                ..bytes(11, client))
              .toBytes();

      expect(bytes, const [
        0x0A, 0x11, // field 1, a 17-byte sub-message
        0x0A, 0x08, 0x6C, 0x69, 0x6E, 0x6B, 0x2D, 0x73, 0x64, 0x6B, // 1: 'link-sdk'
        0x22, 0x05, 0x31, 0x2E, 0x32, 0x2E, 0x31, // 4: '1.2.1'
        0x20, 0x01, // field 4 = 1
        0x5A, 0x08, // field 11, an 8-byte sub-message
        0x0A, 0x03, 0x6B, 0x70, 0x6E, // 1: 'kpn'
        0x20, 0xE8, 0x07, // 4: 1000
      ]);

      final message = AcfunProtoMessage.decode(bytes);
      expect(message.message(1)?.string(1), 'link-sdk');
      expect(message.message(1)?.string(4), '1.2.1');
      expect(message.integer(4), 1);
      expect(message.message(11)?.string(1), 'kpn');
      expect(message.message(11)?.integer(4), 1000);
    });

    test('an empty bytes field still writes its tag and a zero length', () {
      final bytes = (AcfunProtoWriter()..bytes(4, const [])).toBytes();
      expect(bytes, const [0x22, 0x00]);
      expect(AcfunProtoMessage.decode(bytes).bytes(4), isEmpty);
      expect(AcfunProtoMessage.decode(bytes).bytes(5), isNull);
    });

    test('every accessor the link reads survives a write', () {
      final key = List<int>.generate(16, (i) => i);
      final answer = AcfunProtoMessage.decode(
        (AcfunProtoWriter()
              ..bytes(2, key)
              ..integer(3, 9876543210))
            .toBytes(),
      );
      expect(answer.bytes(2), key);
      expect(answer.integer(3), 9876543210);

      final header = AcfunProtoMessage.decode(
        (AcfunProtoWriter()
              ..integer(8, 2)
              ..integer(10, 41))
            .toBytes(),
      );
      expect(header.integer(8), 2);
      expect(header.integer(10), 41);

      final down = AcfunProtoMessage.decode(
        (AcfunProtoWriter()
              ..string(1, 'ZtLiveScMessage')
              ..integer(2, 7)
              ..bytes(4, const [0x01])
              ..string(5, 'gone'))
            .toBytes(),
      );
      expect(down.string(1), 'ZtLiveScMessage');
      expect(down.integer(2), 7);
      expect(down.bytes(4), [0x01]);
      expect(down.string(5), 'gone');
    });

    test('a UTF-8 string writes the bytes the reader takes back', () {
      final bytes = (AcfunProtoWriter()..string(1, 'banana\u0001\u{1F34C}')).toBytes();
      expect(bytes, const [0x0A, 0x0B, 0x62, 0x61, 0x6E, 0x61, 0x6E, 0x61, 0x01, 0xF0, 0x9F, 0x8D, 0x8C]);
      expect(AcfunProtoMessage.decode(bytes).string(1), 'banana\u0001\u{1F34C}');
    });
  });
}
