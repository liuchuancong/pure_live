/// The minimal schema-less protobuf reader Bilibili's danmaku protocol needs,
/// in pure Dart (no `protobuf` dependency).
///
/// Only one message is read with it: `SEND_GIFT_V2`'s `data.pb` (base64), the
/// protobuf form of the gift a guest receives. Everything else on this socket
/// is JSON. The reader walks a message one level deep and addresses fields by
/// number; nested messages are decoded only when asked for and unknown fields
/// are ignored, so a schema change never breaks a gift line.
///
/// The reading follows a generated protobuf runtime where it matters for
/// well-formed input:
///
/// - a singular field keeps its last value; a field sent with another wire
///   type than its declared one is ignored (an unknown field);
/// - a singular message sent more than once is the merge of all of them,
///   which is the message of their concatenated bytes; a repeated message is
///   one entry per occurrence;
/// - a bool is true when the low 32 bits of its varint are not zero;
/// - fixed64 and fixed32 are consumed and reported as varints of their
///   little-endian value; groups (wire types 3 and 4) are skipped;
/// - strings are UTF-8 with malformed bytes replaced;
/// - a truncated field, a varint of more than ten bytes, field number 0, a
///   length above 2^31 − 1, an unmatched group end or wire type 6 or 7 is a
///   [FormatException].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

// These value wrappers spell their class name in the constructor; the
// shorthand would read as a method declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One protobuf field as it appeared on the wire.
typedef BilibiliProtoField = ({int number, int wireType, Object value});

/// Wire type of varints.
const int bilibiliProtoVarintType = 0;

/// Wire type of length-delimited fields (strings, bytes, messages).
const int bilibiliProtoLengthDelimitedType = 2;

const int _fixed64 = 1;
const int _startGroup = 3;
const int _endGroup = 4;
const int _fixed32 = 5;

/// A protobuf message decoded one level deep, without a schema.
@immutable
final class BilibiliProtoMessage {
  /// Wraps [fields] in wire order.
  const BilibiliProtoMessage(this.fields);

  /// Decodes [bytes] one level deep.
  factory BilibiliProtoMessage.decode(List<int> bytes) {
    final reader = _BilibiliProtoReader(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    final fields = <BilibiliProtoField>[];
    while (!reader.atEnd) {
      final (number, wireType) = reader.tag();
      if (wireType == _endGroup) throw const FormatException('Protobuf group end without a start');
      fields.add((number: number, wireType: wireType, value: reader.value(number, wireType)));
    }
    return BilibiliProtoMessage(fields);
  }

  /// Fields in wire order.
  final List<BilibiliProtoField> fields;

  Object? _last(int number, int wireType) {
    for (var i = fields.length - 1; i >= 0; i--) {
      final field = fields[i];
      if (field.number == number && field.wireType == wireType) return field.value;
    }
    return null;
  }

  /// The last varint of [number] as a 64-bit two's complement `int`, or null
  /// when there is none.
  int? integer(int number) => _last(number, bilibiliProtoVarintType) as int?;

  /// Whether the bool [number] is true.
  bool flag(int number) => ((integer(number) ?? 0) & 0xFFFFFFFF) != 0;

  /// The last length-delimited value of [number].
  Uint8List? bytes(int number) => _last(number, bilibiliProtoLengthDelimitedType) as Uint8List?;

  /// The last value of [number] as UTF-8 text.
  String? string(int number) {
    final value = bytes(number);
    return value == null ? null : utf8.decode(value, allowMalformed: true);
  }

  /// The singular message [number]: every occurrence merged, or null when
  /// there is none.
  BilibiliProtoMessage? message(int number) {
    final parts = [
      for (final field in fields)
        if (field.number == number && field.wireType == bilibiliProtoLengthDelimitedType) field.value as Uint8List,
    ];
    if (parts.isEmpty) return null;
    return BilibiliProtoMessage.decode(parts.length == 1 ? parts.single : [for (final part in parts) ...part]);
  }

  /// The repeated message [number], one entry per occurrence.
  List<BilibiliProtoMessage> messages(int number) => [
    for (final field in fields)
      if (field.number == number && field.wireType == bilibiliProtoLengthDelimitedType)
        BilibiliProtoMessage.decode(field.value as Uint8List),
  ];

  /// [value], a uint64 read into a 64-bit `int`, as unsigned decimal.
  static String unsigned(int value) => value >= 0 ? '$value' : BigInt.from(value).toUnsigned(64).toString();
}

final class _BilibiliProtoReader {
  _BilibiliProtoReader(this.data);

  final Uint8List data;
  int offset = 0;

  bool get atEnd => offset >= data.length;

  int varint() {
    var result = 0;
    for (var shift = 0; shift < 70; shift += 7) {
      if (offset >= data.length) throw const FormatException('Truncated protobuf varint');
      final byte = data[offset++];
      result |= (byte & 0x7F) << shift;
      if (byte < 0x80) return result;
    }
    throw const FormatException('Protobuf varint longer than ten bytes');
  }

  (int, int) tag() {
    final tag = varint() & 0xFFFFFFFF;
    final number = tag >>> 3;
    if (number == 0) throw const FormatException('Protobuf field number 0');
    return (number, tag & 7);
  }

  Uint8List take(int length) {
    if (length < 0 || length > data.length - offset) throw const FormatException('Truncated protobuf field');
    final value = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    return value;
  }

  Object value(int number, int wireType) => switch (wireType) {
    bilibiliProtoVarintType => varint(),
    _fixed64 => ByteData.sublistView(take(8)).getInt64(0, Endian.little),
    // Lengths are read as signed 32-bit values, as a generated runtime does.
    bilibiliProtoLengthDelimitedType => take(varint().toSigned(32)),
    _startGroup => _skipGroup(number),
    _fixed32 => ByteData.sublistView(take(4)).getUint32(0, Endian.little),
    _ => throw FormatException('Unsupported protobuf wire type $wireType'),
  };

  /// Skips the fields of group [number] up to its end; the group reads as an
  /// empty value.
  Uint8List _skipGroup(int number) {
    while (true) {
      if (atEnd) throw const FormatException('Truncated protobuf group');
      final (inner, wireType) = tag();
      if (wireType == _endGroup) {
        if (inner != number) throw const FormatException('Mismatched protobuf group end');
        return Uint8List(0);
      }
      value(inner, wireType);
    }
  }
}
