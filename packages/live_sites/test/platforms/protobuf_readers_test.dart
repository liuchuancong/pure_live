import 'dart:convert';
import 'dart:typed_data';

import 'package:live_sites/src/platforms/acfun/danmaku/acfun_protobuf.dart';
import 'package:live_sites/src/platforms/bilibili/api/bilibili_protobuf.dart';
import 'package:live_sites/src/platforms/douyin/danmaku/douyin_protobuf.dart';
import 'package:live_sites/src/platforms/kugoulive/danmaku/kugoulive_protobuf.dart';
import 'package:live_sites/src/platforms/niconico/danmaku/niconico_protobuf.dart';
import 'package:test/test.dart';

// A private helper class that spells its own constructor: the rule that governs
// the public surface does not want it here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// The bytes of a varint, for the platform whose protobuf is only ever read
/// (bilibili's has no writer of its own).
List<int> _varint(int value) {
  var rest = value;
  final out = <int>[];
  while (true) {
    final byte = rest & 0x7F;
    rest >>>= 7;
    if (rest == 0) return [...out, byte];
    out.add(byte | 0x80);
  }
}

List<int> _handInteger(int number, int value) => [number << 3, ..._varint(value)];

List<int> _handBytes(int number, List<int> value) => [number << 3 | 2, ..._varint(value.length), ...value];

/// One platform's hand-written protobuf reader and writer, with the accessors
/// this contract needs.
///
/// Four live platforms (and a fifth, YouTube, that only walks fields) decoded
/// protobuf without a schema, each as its own file, because none of them wanted
/// a `protobuf` dependency. They all document the same reading rules, so the
/// rules are proved here once against every one of them rather than once per
/// platform — which is also the only way a new reader is covered by writing one
/// entry instead of twenty cases.
final class _ProtoCodec {
  const _ProtoCodec({
    required this.name,
    required this.decode,
    required this.integer,
    required this.text,
    required this.bytesOf,
    required this.flagOf,
    required this.merged,
    required this.repeated,
    required this.wireTypes,
    required this.valueAt,
    required this.integerField,
    required this.stringField,
    required this.bytesField,
    required this.unsignedOf,
  });

  /// The platform, for the failure message.
  final String name;

  final Object Function(List<int> bytes) decode;
  final int? Function(Object message, int number) integer;
  final String? Function(Object message, int number) text;
  final Uint8List? Function(Object message, int number) bytesOf;
  final bool Function(Object message, int number) flagOf;
  final Object? Function(Object message, int number) merged;
  final List<Object> Function(Object message, int number) repeated;
  final List<(int number, int wireType)> Function(Object message) wireTypes;
  final Object? Function(Object message, int number, int wireType) valueAt;
  final List<int> Function(int number, int value) integerField;
  final List<int> Function(int number, String value) stringField;
  final List<int> Function(int number, List<int> value) bytesField;
  final String Function(int value) unsignedOf;

  @override
  String toString() => name;
}

final List<_ProtoCodec> _codecs = [
  _ProtoCodec(
    name: 'acfun',
    decode: AcfunProtoMessage.decode,
    integer: (message, number) => (message as AcfunProtoMessage).integer(number),
    text: (message, number) => (message as AcfunProtoMessage).string(number),
    bytesOf: (message, number) => (message as AcfunProtoMessage).bytes(number),
    flagOf: (message, number) => (message as AcfunProtoMessage).flag(number),
    merged: (message, number) => (message as AcfunProtoMessage).message(number),
    repeated: (message, number) => (message as AcfunProtoMessage).messages(number),
    wireTypes: (message) => [for (final f in (message as AcfunProtoMessage).fields) (f.number, f.wireType)],
    valueAt: (message, number, wireType) => [
      for (final f in (message as AcfunProtoMessage).fields)
        if (f.number == number && f.wireType == wireType) f.value,
    ].lastOrNull,
    integerField: (number, value) => (AcfunProtoWriter()..integer(number, value)).toBytes(),
    stringField: (number, value) => (AcfunProtoWriter()..string(number, value)).toBytes(),
    bytesField: (number, value) => (AcfunProtoWriter()..bytes(number, value)).toBytes(),
    unsignedOf: AcfunProtoMessage.unsigned,
  ),
  _ProtoCodec(
    name: 'bilibili',
    decode: BilibiliProtoMessage.decode,
    integer: (message, number) => (message as BilibiliProtoMessage).integer(number),
    text: (message, number) => (message as BilibiliProtoMessage).string(number),
    bytesOf: (message, number) => (message as BilibiliProtoMessage).bytes(number),
    flagOf: (message, number) => (message as BilibiliProtoMessage).flag(number),
    merged: (message, number) => (message as BilibiliProtoMessage).message(number),
    repeated: (message, number) => (message as BilibiliProtoMessage).messages(number),
    wireTypes: (message) => [for (final f in (message as BilibiliProtoMessage).fields) (f.number, f.wireType)],
    valueAt: (message, number, wireType) => [
      for (final f in (message as BilibiliProtoMessage).fields)
        if (f.number == number && f.wireType == wireType) f.value,
    ].lastOrNull,
    integerField: _handInteger,
    stringField: (number, value) => _handBytes(number, utf8.encode(value)),
    bytesField: _handBytes,
    unsignedOf: BilibiliProtoMessage.unsigned,
  ),
  _ProtoCodec(
    name: 'douyin',
    decode: DouyinProtoMessage.decode,
    integer: (message, number) => (message as DouyinProtoMessage).integer(number),
    text: (message, number) => (message as DouyinProtoMessage).string(number),
    bytesOf: (message, number) => (message as DouyinProtoMessage).bytes(number),
    flagOf: (message, number) => (message as DouyinProtoMessage).flag(number),
    merged: (message, number) => (message as DouyinProtoMessage).message(number),
    repeated: (message, number) => (message as DouyinProtoMessage).messages(number),
    wireTypes: (message) => [for (final f in (message as DouyinProtoMessage).fields) (f.number, f.wireType)],
    valueAt: (message, number, wireType) => [
      for (final f in (message as DouyinProtoMessage).fields)
        if (f.number == number && f.wireType == wireType) f.value,
    ].lastOrNull,
    integerField: (number, value) => (DouyinProtoWriter()..integer(number, value)).toBytes(),
    stringField: (number, value) => (DouyinProtoWriter()..string(number, value)).toBytes(),
    bytesField: (number, value) => (DouyinProtoWriter()..bytes(number, value)).toBytes(),
    unsignedOf: DouyinProtoMessage.unsigned,
  ),
  _ProtoCodec(
    name: 'kugoulive',
    decode: KugouliveProtoMessage.decode,
    integer: (message, number) => (message as KugouliveProtoMessage).integer(number),
    text: (message, number) => (message as KugouliveProtoMessage).string(number),
    bytesOf: (message, number) => (message as KugouliveProtoMessage).bytes(number),
    flagOf: (message, number) => (message as KugouliveProtoMessage).flag(number),
    merged: (message, number) => (message as KugouliveProtoMessage).message(number),
    repeated: (message, number) => (message as KugouliveProtoMessage).messages(number),
    wireTypes: (message) => [for (final f in (message as KugouliveProtoMessage).fields) (f.number, f.wireType)],
    valueAt: (message, number, wireType) => [
      for (final f in (message as KugouliveProtoMessage).fields)
        if (f.number == number && f.wireType == wireType) f.value,
    ].lastOrNull,
    integerField: (number, value) => (KugouliveProtoWriter()..integer(number, value)).toBytes(),
    stringField: (number, value) => (KugouliveProtoWriter()..string(number, value)).toBytes(),
    bytesField: (number, value) => (KugouliveProtoWriter()..bytes(number, value)).toBytes(),
    unsignedOf: KugouliveProtoMessage.unsigned,
  ),
  _ProtoCodec(
    name: 'niconico',
    decode: NiconicoProtoMessage.decode,
    integer: (message, number) => (message as NiconicoProtoMessage).integer(number),
    text: (message, number) => (message as NiconicoProtoMessage).string(number),
    bytesOf: (message, number) => (message as NiconicoProtoMessage).bytes(number),
    flagOf: (message, number) => (message as NiconicoProtoMessage).flag(number),
    merged: (message, number) => (message as NiconicoProtoMessage).message(number),
    repeated: (message, number) => (message as NiconicoProtoMessage).messages(number),
    wireTypes: (message) => [for (final f in (message as NiconicoProtoMessage).fields) (f.number, f.wireType)],
    valueAt: (message, number, wireType) => [
      for (final f in (message as NiconicoProtoMessage).fields)
        if (f.number == number && f.wireType == wireType) f.value,
    ].lastOrNull,
    integerField: (number, value) => (NiconicoProtoWriter()..integer(number, value)).toBytes(),
    stringField: (number, value) => (NiconicoProtoWriter()..string(number, value)).toBytes(),
    bytesField: (number, value) => (NiconicoProtoWriter()..bytes(number, value)).toBytes(),
    unsignedOf: NiconicoProtoMessage.unsigned,
  ),
];

/// A tag byte for field [number] of wire type [wireType], then [value].
List<int> _raw(int number, int wireType, List<int> value) => [number << 3 | wireType, ...value];

void main() {
  for (final codec in _codecs) {
    group('what ${codec.name} reads', () {
      test('a varint field is the tag and the value, and the last one written wins', () {
        expect(codec.integerField(1, 2), [0x08, 0x02]);
        final message = codec.decode([
          ...codec.integerField(1, 0),
          ...codec.integerField(2, 127),
          ...codec.integerField(3, 128),
          ...codec.integerField(4, 300),
          ...codec.integerField(1, 2),
        ]);
        expect(codec.integer(message, 1), 2, reason: 'a singular field keeps what arrived last');
        expect(codec.integer(message, 2), 127);
        expect(codec.integer(message, 3), 128);
        expect(codec.integer(message, 4), 300);
        expect(codec.integer(message, 4), 300);
        expect(
          [codec.integer(message, 9), codec.text(message, 9), codec.bytesOf(message, 9)],
          [null, null, null],
          reason: 'a field never sent is nothing',
        );
        expect(codec.flagOf(message, 4), isTrue, reason: 'any nonzero varint reads as a set flag');
      });

      test('a string is UTF-8 with a broken byte replaced, and the wrong accessor sees nothing', () {
        final spoken = codec.decode(codec.stringField(1, '弹幕 ☃'));
        expect(codec.text(spoken, 1), '弹幕 ☃');
        expect(codec.bytesOf(spoken, 1), utf8.encode('弹幕 ☃'));
        expect(codec.integer(spoken, 1), isNull, reason: 'a length-delimited field is not a varint');

        final broken = codec.decode(codec.bytesField(1, [0xFF, 0x41]));
        expect(codec.text(broken, 1), '\uFFFDA', reason: 'a nickname cut mid-codepoint is still a nickname');

        final counted = codec.decode(codec.integerField(1, 5));
        expect(codec.text(counted, 1), isNull);
        expect(codec.bytesOf(counted, 1), isNull);
      });

      test('a field set to nothing is not a field that was never set', () {
        final empty = codec.decode(codec.bytesField(1, const []));
        expect(codec.wireTypes(empty), [(1, 2)]);
        expect(codec.bytesOf(empty, 1), isEmpty);
        expect(codec.text(empty, 1), isEmpty);
        expect(codec.wireTypes(codec.decode(const <int>[])), isEmpty);
        expect(codec.bytesOf(codec.decode(const <int>[]), 1), isNull);
      });

      test('a bool is the low thirty-two bits of its varint', () {
        for (final (value, expected) in [
          (1, true),
          (-1, true),
          (0x100000000, false),
          (0x100000001, true),
          (0, false),
        ]) {
          expect(
            codec.flagOf(codec.decode(codec.integerField(4, value)), 4),
            expected,
            reason: 'a bool of $value reads as a generated runtime reads it',
          );
        }
        expect(codec.flagOf(codec.decode(const <int>[]), 4), isFalse, reason: 'a missing bool is false, not null');
      });

      test('a singular message merges on its bytes and a repeated one never merges', () {
        final twice = codec.decode([
          ...codec.bytesField(2, codec.integerField(1, 7)),
          ...codec.bytesField(2, codec.integerField(5, 9)),
          ...codec.bytesField(2, codec.integerField(1, 11)),
        ]);
        final merged = codec.merged(twice, 2)!;
        expect(codec.integer(merged, 1), 11);
        expect(
          codec.integer(merged, 5),
          9,
          reason: 'merging happens on the bytes, so a field the last part omits survives',
        );
        expect(
          codec.repeated(twice, 2),
          hasLength(3),
          reason: 'two gifts folded into one invents an event nobody sent',
        );
        expect(codec.repeated(twice, 2).map((entry) => codec.integer(entry, 1)), [7, null, 11]);
        expect(codec.merged(twice, 3), isNull);
        // The body is only decoded when it is asked for, so nonsense inside it is
        // not a corrupt message.
        final opaque = codec.decode(codec.bytesField(1, [0xFF, 0xFF]));
        expect(codec.bytesOf(opaque, 1), [0xFF, 0xFF]);
        expect(() => codec.merged(opaque, 1), throwsFormatException);
      });

      test('a fixed width stays under its own wire type, so the varint reader never sees it', () {
        final fixed = codec.decode([
          ..._raw(1, 1, [1, 0, 0, 0, 0, 0, 0, 0]),
          ..._raw(1, 5, [1, 0, 0, 0]),
          ...codec.integerField(1, 2),
        ]);
        expect(codec.wireTypes(fixed), [(1, 1), (1, 5), (1, 0)]);
        expect(codec.integer(fixed, 1), 2, reason: 'the varint of the same number is the one that reads');
        expect(codec.valueAt(fixed, 1, 1), 1, reason: 'a fixed64 keeps its little-endian value');
        expect(codec.valueAt(fixed, 1, 5), 1, reason: 'a fixed32 keeps its own, unsigned');
        expect(
          codec.valueAt(codec.decode(_raw(1, 1, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F])), 1, 1),
          0x7FFFFFFFFFFFFFFF,
        );
        expect(codec.valueAt(codec.decode(_raw(1, 1, [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])), 1, 1), -1);
        expect(codec.valueAt(codec.decode(_raw(1, 5, [0, 0, 0, 0x40])), 1, 5), 0x40000000);
        expect(codec.valueAt(fixed, 9, 0), isNull);
      });

      test('a group is walked past and reads as an empty value', () {
        final grouped = codec.decode([
          ..._raw(1, 3, [
            ..._raw(2, 0, [5]),
            ..._raw(3, 5, [1, 0, 0, 0]),
            ..._raw(1, 4, const []),
          ]),
          ...codec.integerField(4, 7),
        ]);
        expect(codec.wireTypes(grouped), [(1, 3), (4, 0)], reason: 'what was inside the group is skipped, not kept');
        expect(codec.integer(grouped, 4), 7, reason: 'the reader knows where the group ended');
        expect(codec.bytesOf(grouped, 1), isNull);
      });

      test('a message that stops adding up throws, and none of it is kept', () {
        for (final bytes in <List<int>>[
          [0x80], // a varint that never ends
          [0x08, 0x80], // a value cut off
          [0x00], // field number 0
          [0x0C], // a group end without its start
          [0x0E, 0x05], // wire type 6
          [0x0F, 0x05], // wire type 7
          [0x0A, 0x04, 0x01], // a field shorter than it says
          [0x0B, 0x14], // a group ended by another number
          [0x0B], // a group that never ends
          [0x0B, 0x10, 0x05], // a group whose content is cut off
          [for (var i = 0; i < 11; i++) 0x80], // a varint of more than ten bytes
        ]) {
          expect(
            () => codec.decode(bytes),
            throwsFormatException,
            reason: '${codec.name} should refuse $bytes whole, not half of it',
          );
        }
        // The whole message written by the writer still reads back.
        final composite = codec.decode([
          ...codec.integerField(1, 300),
          ...codec.stringField(2, '弹幕'),
          ...codec.bytesField(3, [1, 2, 3]),
          ...codec.bytesField(4, codec.integerField(1, 7)),
        ]);
        expect(codec.integer(composite, 1), 300);
        expect(codec.text(composite, 2), '弹幕');
        expect(codec.bytesOf(composite, 3), [1, 2, 3]);
        expect(codec.integer(codec.merged(composite, 4)!, 1), 7);
      });

      test('a uint64 at or above 2^63 is spelled out unsigned', () {
        expect(codec.unsignedOf(-1), '18446744073709551615');
        expect(codec.unsignedOf(-5), '18446744073709551611');
        expect(codec.unsignedOf(5), '5');
        expect(codec.unsignedOf(1 << 62), '${1 << 62}');
        // A negative value is written as the 64-bit two's complement (ten bytes
        // plus the tag) so a uid that arrived through `integer` goes back out
        // unchanged.
        final back = codec.decode(codec.integerField(1, -5));
        expect(codec.integer(back, 1), -5);
        expect(codec.integerField(1, -5), hasLength(11));
      });
    });
  }
}
