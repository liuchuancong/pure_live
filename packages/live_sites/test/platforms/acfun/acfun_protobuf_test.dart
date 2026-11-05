import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:test/test.dart';

/// A message with the fields [write] adds, in call order.
Uint8List _message(void Function(AcfunProtoWriter) write) {
  final writer = AcfunProtoWriter();
  write(writer);
  return writer.toBytes();
}

/// One protobuf tag byte for field [number] of wire type [wireType].
List<int> _tag(int number, int wireType) => [number << 3 | wireType];

/// [value] as a 64-bit little-endian fixed field.
List<int> _fixed64(int number, int value) {
  final data = ByteData(8)..setInt64(0, value, Endian.little);
  return [..._tag(number, 1), ...data.buffer.asUint8List()];
}

/// [value] as a 32-bit little-endian fixed field.
List<int> _fixed32(int number, int value) {
  final data = ByteData(4)..setUint32(0, value, Endian.little);
  return [..._tag(number, 5), ...data.buffer.asUint8List()];
}

/// The last field of a decoded message.
AcfunProtoField _only(AcfunProtoMessage message) => message.fields.single;

void main() {
  group('varints', () {
    test('a written field is read back by its number', () {
      final message = AcfunProtoMessage.decode(
        _message(
          (w) => w
            ..integer(1, 0)
            ..integer(2, 127)
            ..integer(3, 128)
            ..integer(4, 300)
            ..integer(5, 9007199254740991),
        ),
      );
      expect(message.integer(1), 0);
      expect(message.integer(2), 127);
      expect(message.integer(3), 128);
      expect(message.integer(4), 300);
      expect(message.integer(5), 9007199254740991);
      expect(message.fields.map((field) => field.number), [1, 2, 3, 4, 5], reason: 'fields stay in wire order');
      expect(message.integer(6), isNull);
    });

    test("a tag is its field number and wire type, and the bytes are the page's", () {
      expect(_message((w) => w.integer(1, 2)), [0x08, 0x02]);
      expect(_message((w) => w.integer(16, 300)), [0x80, 0x01, 0xAC, 0x02]);
      expect(_tag(1, AcfunProtoMessage.varintType), [0x08]);
    });

    test('a negative value is the 64-bit two complement, so a uid round trips', () {
      final bytes = _message((w) => w.integer(1, -1));
      expect(bytes.length, 11, reason: 'ten varint bytes plus the tag');
      expect(AcfunProtoMessage.decode(bytes).integer(1), -1);
      expect(AcfunProtoMessage.unsigned(-1), '18446744073709551615');
      expect(AcfunProtoMessage.unsigned(5), '5');
      expect(AcfunProtoMessage.unsigned(1 << 62), '${1 << 62}');
      // A uint64 at or above 2^63 arrives negative, and reads back unsigned.
      expect(
        AcfunProtoMessage.unsigned(AcfunProtoMessage.decode(_message((w) => w.integer(1, -5))).integer(1)!),
        '18446744073709551611',
      );
    });

    test('a singular field keeps its last value', () {
      final message = AcfunProtoMessage.decode(
        _message(
          (w) => w
            ..integer(3, 1)
            ..integer(3, 2)
            ..string(3, 'not a varint'),
        ),
      );
      expect(message.integer(3), 2, reason: 'the earlier value is what a generated runtime drops too');
      expect(message.string(3), 'not a varint');
    });

    test('a bool is its low thirty-two bits, as a generated runtime reads it', () {
      expect(AcfunProtoMessage.decode(_message((w) => w.integer(1, 1))).flag(1), isTrue);
      expect(AcfunProtoMessage.decode(_message((w) => w.integer(1, -1))).flag(1), isTrue);
      expect(AcfunProtoMessage.decode(_message((w) => w.integer(1, 0x100000000))).flag(1), isFalse);
      expect(AcfunProtoMessage.decode(_message((w) => w.integer(1, 0x100000001))).flag(1), isTrue);
      expect(const AcfunProtoMessage([]).flag(7), isFalse, reason: 'a missing bool is false, not null');
    });
  });

  group('length-delimited fields', () {
    test('a string is UTF-8 and a broken byte is replaced, not thrown', () {
      final message = AcfunProtoMessage.decode(_message((w) => w..string(1, '弹幕 ☃')));
      expect(message.string(1), '弹幕 ☃');
      final broken = AcfunProtoMessage.decode([..._tag(1, 2), 3, 0xFF, 0xFE, 0x41]);
      expect(broken.string(1), '\uFFFD\uFFFDA', reason: 'a nickname cut mid-codepoint is still a nickname');
    });

    test('a field set to nothing is not a field that was never set', () {
      final empty = AcfunProtoMessage.decode(_message((w) => w..bytes(1, const [])));
      expect(empty.fields, hasLength(1));
      expect(empty.bytes(1), isEmpty);
      expect(empty.string(1), isEmpty);
      expect(AcfunProtoMessage.decode(const <int>[]).bytes(1), isNull);
    });

    test('the bytes are a view of what is being decoded', () {
      final buffer = Uint8List.fromList(_message((w) => w..bytes(1, [1, 2, 3])));
      final view = AcfunProtoMessage.decode(buffer).bytes(1)!;
      expect(view, [1, 2, 3]);
      buffer[buffer.length - 1] = 9;
      expect(view.last, 9, reason: 'a caller that keeps a payload copies it first');
    });

    test('a field sent with another wire type is not read by the wrong accessor', () {
      final message = AcfunProtoMessage.decode(_message((w) => w..string(3, 'five')));
      expect(message.integer(3), isNull);
      expect(message.flag(3), isFalse);
      expect(message.bytes(3), utf8.encode('five'));
      final other = AcfunProtoMessage.decode(_message((w) => w..integer(3, 5)));
      expect(other.string(3), isNull);
      expect(other.bytes(3), isNull);
    });
  });

  group('nested messages', () {
    test('a singular message sent twice is the merge of its bytes', () {
      final message = AcfunProtoMessage.decode(
        _message(
          (w) => w
            ..bytes(2, _message((inner) => inner..integer(1, 7)))
            ..bytes(2, _message((inner) => inner..integer(5, 9)))
            ..bytes(2, _message((inner) => inner..integer(1, 11))),
        ),
      );
      final merged = message.message(2)!;
      expect(merged.integer(1), 11);
      expect(merged.integer(5), 9, reason: 'merging happens on the bytes, so a field the later part omits survives');
      expect(message.message(3), isNull);
    });

    test('a repeated message is one entry per occurrence and never merges', () {
      final message = AcfunProtoMessage.decode(
        _message(
          (w) => w
            ..bytes(2, _message((inner) => inner..integer(1, 7)))
            ..bytes(2, _message((inner) => inner..integer(1, 8))),
        ),
      );
      expect(message.messages(2).map((entry) => entry.integer(1)), [7, 8]);
      expect(
        message.message(2)!.integer(1),
        8,
        reason: 'the singular read keeps the last, as a generated runtime does',
      );
      expect(message.messages(3), isEmpty);
    });

    test('a nested message is decoded only when it is asked for', () {
      // The payload is bytes this reader never walks, so nonsense inside them is
      // not a corrupt message.
      final message = AcfunProtoMessage.decode(_message((w) => w..bytes(1, [0xFF, 0xFF])));
      expect(message.bytes(1), [0xFF, 0xFF]);
      expect(() => message.message(1), throwsA(isA<FormatException>()));
    });
  });

  group('fixed widths and groups', () {
    test('a fixed field keeps its own wire type, so the varint reader never sees it', () {
      final sixty = AcfunProtoMessage.decode([..._fixed64(1, -2), ..._tag(2, 0), 5]);
      expect(sixty.fields.map((field) => (field.number, field.wireType)), [(1, 1), (2, 0)]);
      expect(sixty.integer(1), isNull, reason: 'a fixed64 is not a varint of the same number');
      expect(sixty.integer(2), 5);
      final max = AcfunProtoMessage.decode(_fixed64(1, 0x7FFFFFFFFFFFFFFF));
      expect(_only(max).value, 0x7FFFFFFFFFFFFFFF);
      expect(_only(max).number, 1);

      final thirty = AcfunProtoMessage.decode([..._fixed32(1, 0xFFFFFFFF), ..._tag(3, 0), 1]);
      expect(_only(AcfunProtoMessage.decode(_fixed32(1, 0))).wireType, 5);
      expect(thirty.integer(1), isNull);
      expect(thirty.fields.first.value, 0xFFFFFFFF, reason: 'a fixed32 reads unsigned');
      expect(thirty.integer(3), 1);
    });

    test('a group is walked past and reads as an empty value', () {
      final message = AcfunProtoMessage.decode([
        ..._tag(1, 3), // start group 1
        ..._tag(2, 0),
        5,
        ..._fixed32(2, 7),
        ..._tag(1, 4), // end group 1
        ..._tag(3, 0),
        7,
      ]);
      expect(message.fields.map((field) => (field.number, field.wireType)), [
        (1, 3),
        (3, 0),
      ], reason: 'what was inside the group is skipped, not kept');
      expect(message.fields.first.value, isEmpty);
      expect(message.integer(3), 7, reason: 'the reader knows where the group ended');
    });

    test('a group that does not add up is a bad packet', () {
      expect(
        () => AcfunProtoMessage.decode([..._tag(1, 4)]),
        throwsA(isA<FormatException>()),
        reason: 'end without start',
      );
      expect(
        () => AcfunProtoMessage.decode([..._tag(1, 3), ..._tag(2, 4)]),
        throwsA(isA<FormatException>()),
        reason: 'a group ended by another number',
      );
      expect(() => AcfunProtoMessage.decode([..._tag(1, 3)]), throwsA(isA<FormatException>()), reason: 'never ended');
      expect(() => AcfunProtoMessage.decode([..._tag(1, 3), ..._tag(2, 0), 5]), throwsA(isA<FormatException>()));
    });
  });

  group('a frame that stops adding up', () {
    test('nothing is returned for a message that runs past its end', () {
      for (final bytes in <List<int>>[
        [0x80], // a varint that never ends
        [0x08, 0x80], // a value cut off
        [0x00], // field number 0
        [0xFF, 0xFF, 0xFF, 0xFF, 0x1F], // a tag whose wire type is 7
        [0x0E, 0x05], // wire type 6
        [0x0A, 0x80, 0x80, 0x80, 0x80, 0x08], // a length above 2^31 − 1
        [0x0A, 0x04, 0x01], // a field shorter than it says
        [for (var i = 0; i < 11; i++) 0x80], // a varint of more than ten bytes
      ]) {
        expect(
          () => AcfunProtoMessage.decode(bytes),
          throwsA(isA<FormatException>()),
          reason: '$bytes is not a message, and not a partial one either',
        );
      }
    });

    test('an empty message has no fields and answers with nothing', () {
      final empty = AcfunProtoMessage.decode(const <int>[]);
      expect(empty.fields, isEmpty);
      expect(empty.integer(1), isNull);
      expect(empty.string(1), isNull);
      expect(empty.bytes(1), isNull);
      expect(empty.message(1), isNull);
      expect(empty.messages(1), isEmpty);
      expect(empty.flag(1), isFalse);
    });
  });

  group('what the writer does', () {
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
      final inner = _message((w) => w..string(1, '1.2万'));
      final outer = _message((w) => w..bytes(2, inner));
      expect(AcfunProtoMessage.decode(outer).message(2)!.string(1), '1.2万');
    });
  });
}
