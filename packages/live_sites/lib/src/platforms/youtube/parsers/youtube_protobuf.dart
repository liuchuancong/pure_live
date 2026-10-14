/// The minimal protobuf codec YouTube's live chat needs, in pure Dart (no
/// `protobuf` dependency).
///
/// A live-chat continuation is a base64url protobuf message; the view it names
/// is a varint nested two messages deep. [YoutubeProtoMessage] decodes a
/// message one level deep without a schema, addressing fields by number, and
/// [YoutubeProtoWriter] writes fields in call order; the rewrite re-encodes a
/// message with one nested varint changed. Nested messages are read only when
/// asked for. The reading follows a generated protobuf runtime where it matters
/// for well-formed input:
///
/// - a singular field keeps its last value; a field sent with another wire
///   type than its declared one is ignored (an unknown field);
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
typedef YoutubeProtoField = ({int number, int wireType, Object value});

/// Wire type of varints.
const int youtubeProtoVarintType = 0;

/// Wire type of length-delimited fields (strings, bytes, messages).
const int youtubeProtoLengthDelimitedType = 2;

const int _fixed64 = 1;
const int _startGroup = 3;
const int _endGroup = 4;
const int _fixed32 = 5;

/// A protobuf message decoded one level deep, without a schema.
@immutable
final class YoutubeProtoMessage {
  /// Wraps [fields] in wire order.
  const YoutubeProtoMessage(this.fields);

  /// Decodes [bytes] one level deep.
  factory YoutubeProtoMessage.decode(List<int> bytes) {
    final reader = _YoutubeProtoReader(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    final fields = <YoutubeProtoField>[];
    while (!reader.atEnd) {
      final (number, wireType) = reader.tag();
      if (wireType == _endGroup) throw const FormatException('Protobuf group end without a start');
      fields.add((number: number, wireType: wireType, value: reader.value(number, wireType)));
    }
    return YoutubeProtoMessage(fields);
  }

  /// Fields in wire order.
  final List<YoutubeProtoField> fields;

  /// The repeated message [number], one entry per occurrence.
  List<YoutubeProtoMessage> messages(int number) => [
    for (final field in fields)
      if (field.number == number && field.wireType == youtubeProtoLengthDelimitedType)
        YoutubeProtoMessage.decode(field.value as Uint8List),
  ];
}

final class _YoutubeProtoReader {
  _YoutubeProtoReader(this.data);

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
    youtubeProtoVarintType => varint(),
    _fixed64 => ByteData.sublistView(take(8)).getInt64(0, Endian.little),
    // Lengths are read as signed 32-bit values, as a generated runtime does.
    youtubeProtoLengthDelimitedType => take(varint().toSigned(32)),
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

/// Writes protobuf fields in call order.
final class YoutubeProtoWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  void _varint(int value) {
    var rest = value;
    while (true) {
      final byte = rest & 0x7F;
      rest >>>= 7;
      if (rest == 0) {
        _out.addByte(byte);
        return;
      }
      _out.addByte(byte | 0x80);
    }
  }

  /// A varint field; a negative [value] is its 64-bit two's complement (ten
  /// bytes), as for a uint64 above 2^63.
  void integer(int number, int value) {
    _varint(number << 3 | youtubeProtoVarintType);
    _varint(value);
  }

  /// A length-delimited field.
  void bytes(int number, List<int> value) {
    _varint(number << 3 | youtubeProtoLengthDelimitedType);
    _varint(value.length);
    _out.add(value);
  }

  /// A UTF-8 string field.
  void string(int number, String value) => bytes(number, utf8.encode(value));

  /// The message written so far.
  Uint8List toBytes() => _out.toBytes();
}
