/// The minimal protobuf codec niconico's comment server needs, in pure Dart
/// (no `protobuf` dependency, and not another platform's reader).
///
/// The comment server answers a varint-length-delimited stream of protobuf
/// messages (`ChunkedEntry`, `ChunkedMessage`): every message is a varint
/// byte-count followed by that many bytes. [NiconicoProtoMessage] decodes a
/// message one level deep without a schema, addressing fields by number, and
/// [NiconicoDelimitedReader] splits the arriving bytes into whole messages.
/// Nested messages are read only when asked for. The reading follows a
/// generated protobuf runtime where it matters for well-formed input:
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

// The value wrappers spell their class name in their constructors; the `.new`
// shorthand would read as a field declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One protobuf field as it appeared on the wire.
typedef NiconicoProtoField = ({int number, int wireType, Object value});

/// Wire type of varints.
const int niconicoProtoVarintType = 0;

/// Wire type of length-delimited fields (strings, bytes, messages).
const int niconicoProtoLengthDelimitedType = 2;

const int _fixed64 = 1;
const int _startGroup = 3;
const int _endGroup = 4;
const int _fixed32 = 5;

/// A protobuf message decoded one level deep, without a schema.
@immutable
final class NiconicoProtoMessage {
  /// Wraps [fields] in wire order.
  const NiconicoProtoMessage(this.fields);

  /// Decodes [bytes] one level deep.
  factory NiconicoProtoMessage.decode(List<int> bytes) {
    final reader = _NiconicoProtoReader(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    final fields = <NiconicoProtoField>[];
    while (!reader.atEnd) {
      final (number, wireType) = reader.tag();
      if (wireType == _endGroup) throw const FormatException('Protobuf group end without a start');
      fields.add((number: number, wireType: wireType, value: reader.value(number, wireType)));
    }
    return NiconicoProtoMessage(fields);
  }

  /// Fields in wire order.
  final List<NiconicoProtoField> fields;

  Object? _last(int number, int wireType) {
    for (var i = fields.length - 1; i >= 0; i--) {
      final field = fields[i];
      if (field.number == number && field.wireType == wireType) return field.value;
    }
    return null;
  }

  /// The last varint of [number] as a 64-bit two's complement `int`, or null
  /// when there is none.
  int? integer(int number) => _last(number, niconicoProtoVarintType) as int?;

  /// Whether the bool [number] is true.
  bool flag(int number) => ((integer(number) ?? 0) & 0xFFFFFFFF) != 0;

  /// The last length-delimited value of [number].
  Uint8List? bytes(int number) => _last(number, niconicoProtoLengthDelimitedType) as Uint8List?;

  /// The last value of [number] as UTF-8 text.
  String? string(int number) {
    final value = bytes(number);
    return value == null ? null : utf8.decode(value, allowMalformed: true);
  }

  /// The singular message [number]: every occurrence merged, or null when
  /// there is none.
  NiconicoProtoMessage? message(int number) {
    final parts = [
      for (final field in fields)
        if (field.number == number && field.wireType == niconicoProtoLengthDelimitedType) field.value as Uint8List,
    ];
    if (parts.isEmpty) return null;
    return NiconicoProtoMessage.decode(parts.length == 1 ? parts.single : [for (final part in parts) ...part]);
  }

  /// The repeated message [number], one entry per occurrence.
  List<NiconicoProtoMessage> messages(int number) => [
    for (final field in fields)
      if (field.number == number && field.wireType == niconicoProtoLengthDelimitedType)
        NiconicoProtoMessage.decode(field.value as Uint8List),
  ];

  /// The number of the last length-delimited field among [numbers] (a oneof:
  /// the last one wins), or null.
  int? lastOf(Set<int> numbers) {
    for (final field in fields.reversed) {
      if (field.wireType == niconicoProtoLengthDelimitedType && numbers.contains(field.number)) return field.number;
    }
    return null;
  }

  /// [value], a uint64 read into a 64-bit `int`, as unsigned decimal.
  static String unsigned(int value) => value >= 0 ? '$value' : BigInt.from(value).toUnsigned(64).toString();
}

final class _NiconicoProtoReader {
  _NiconicoProtoReader(this.data);

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
    niconicoProtoVarintType => varint(),
    _fixed64 => ByteData.sublistView(take(8)).getInt64(0, Endian.little),
    // Lengths are read as signed 32-bit values, as a generated runtime does.
    niconicoProtoLengthDelimitedType => take(varint().toSigned(32)),
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

/// Splits a varint-length-delimited protobuf stream (the comment server's
/// answers) into its whole messages as the bytes arrive.
final class NiconicoDelimitedReader {
  /// Creates a reader; a message over [maxLength] bytes is refused.
  NiconicoDelimitedReader({this.maxLength = _defaultMaxLength});

  static const int _defaultMaxLength = 1 << 20;

  /// The largest message accepted.
  final int maxLength;

  Uint8List _buffer = Uint8List(0);
  int _offset = 0;

  /// Whether bytes of an unfinished message are waiting.
  bool get hasPending => _offset < _buffer.length;

  /// Adds [chunk] and returns the messages it completes, in order. Throws
  /// [FormatException] for a length prefix over ten bytes or a message over
  /// [maxLength]; the stream cannot be read further after that.
  List<Uint8List> add(List<int> chunk) {
    final rest = _buffer.length - _offset;
    final data = Uint8List(rest + chunk.length)
      ..setRange(0, rest, _buffer, _offset)
      ..setRange(rest, rest + chunk.length, chunk);
    final messages = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      var length = 0;
      var cursor = offset;
      var complete = false;
      for (var shift = 0; cursor < data.length; shift += 7) {
        if (shift >= 70) throw const FormatException('Length prefix longer than ten bytes');
        final byte = data[cursor++];
        length |= (byte & 0x7F) << shift;
        if (byte < 0x80) {
          complete = true;
          break;
        }
      }
      if (!complete) {
        if (cursor - offset >= 10) throw const FormatException('Length prefix longer than ten bytes');
        break;
      }
      if (length < 0 || length > maxLength) throw FormatException('Message of $length bytes');
      if (data.length - cursor < length) break;
      messages.add(Uint8List.sublistView(data, cursor, cursor + length));
      offset = cursor + length;
    }
    _buffer = data;
    _offset = offset;
    return messages;
  }

  /// Ends the stream: [FormatException] when a message was left unfinished.
  void close() {
    if (hasPending) throw const FormatException('Truncated message stream');
  }
}

/// The whole of a buffered answer split into its messages, then the stream
/// is checked for a truncation.
List<Uint8List> niconicoSplitDelimited(List<int> bytes, {int maxLength = 1 << 20}) {
  final reader = NiconicoDelimitedReader(maxLength: maxLength);
  final messages = reader.add(bytes);
  reader.close();
  return messages;
}

/// Writes protobuf fields in call order (the reader is exercised in tests
/// through bytes built here).
final class NiconicoProtoWriter {
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
    _varint(number << 3 | niconicoProtoVarintType);
    _varint(value);
  }

  /// A length-delimited field.
  void bytes(int number, List<int> value) {
    _varint(number << 3 | niconicoProtoLengthDelimitedType);
    _varint(value.length);
    _out.add(value);
  }

  /// A UTF-8 string field.
  void string(int number, String value) => bytes(number, utf8.encode(value));

  /// A nested message field.
  void message(int number, List<int> value) => bytes(number, value);

  /// The message written so far.
  Uint8List toBytes() => _out.toBytes();
}
