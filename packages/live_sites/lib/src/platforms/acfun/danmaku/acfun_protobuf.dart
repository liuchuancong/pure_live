/// The minimal protobuf codec AcFun's danmaku link needs, in pure Dart (no
/// `protobuf` dependency).
///
/// AcFun puts its live-platform protocol behind two more hand-written layers:
/// a message is protobuf, that protobuf is AES-128-CBC ciphertext, and the
/// ciphertext travels in a length-prefixed frame. Only the innermost layer is
/// this file's concern, and it stays free of AcFun so the frame and the cipher
/// can be tested apart from it. Nothing here knows a schema either — AcFun
/// publishes none for the link — so [AcfunProtoMessage] decodes a message one
/// level deep and addresses fields by number, while [AcfunProtoWriter] writes
/// fields in call order; a nested message is a second writer whose `toBytes()`
/// is passed to a length-delimited field. The reading follows a generated
/// protobuf runtime where it matters for well-formed input:
///
/// - a singular field keeps its last value; a field sent with another wire
///   type than its declared one is ignored (an unknown field);
/// - a singular message sent more than once is the merge of all of them,
///   which is the message of their concatenated bytes; a repeated message is
///   one entry per occurrence;
/// - a bool is true when the low 32 bits of its varint are not zero;
/// - fixed64 and fixed32 are consumed and kept under their own wire type, so
///   [AcfunProtoMessage.integer] (a varint reader) never reports them; groups
///   (wire types 3 and 4) are skipped;
/// - strings are UTF-8 with malformed bytes replaced;
/// - a truncated field, a varint of more than ten bytes, field number 0, a
///   length above 2^31 − 1, an unmatched group end or wire type 6 or 7 is a
///   [FormatException].
library;

import 'dart:convert';
import 'dart:typed_data';

// These value wrappers spell their class name in the constructor; the
// shorthand would read as a method declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// One protobuf field as it appeared on the wire.
///
/// The value is kept in the shape its wire type implies: an `int` for a varint
/// or a fixed width, a [Uint8List] view of the message for a length-delimited
/// field. Callers that walk [AcfunProtoMessage.fields] — reading every
/// repeated payload of a signal, whatever else the signal carries — filter on
/// [AcfunProtoMessage.varintType] and
/// [AcfunProtoMessage.lengthDelimitedType] rather than guessing a type.
typedef AcfunProtoField = ({int number, int wireType, Object value});

const int _fixed64 = 1;
const int _startGroup = 3;
const int _endGroup = 4;
const int _fixed32 = 5;

/// A protobuf message decoded one level deep, without a schema.
final class AcfunProtoMessage {
  /// Wraps [fields] in wire order.
  const AcfunProtoMessage(this.fields);

  /// Decodes [bytes] one level deep, so a nested message is only read when it
  /// is asked for.
  ///
  /// A frame that stops adding up throws a [FormatException]; the AcFun link
  /// treats that as one bad packet rather than one bad room, so nothing here
  /// partially returns what it managed to read.
  factory AcfunProtoMessage.decode(List<int> bytes) {
    final reader = _AcfunProtoReader(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    final fields = <AcfunProtoField>[];
    while (!reader.atEnd) {
      final (number, wireType) = reader.tag();
      if (wireType == _endGroup) throw const FormatException('Protobuf group end without a start');
      fields.add((number: number, wireType: wireType, value: reader.value(number, wireType)));
    }
    return AcfunProtoMessage(fields);
  }

  /// Fields in wire order.
  final List<AcfunProtoField> fields;

  /// Wire type of varints.
  static const int varintType = 0;

  /// Wire type of length-delimited fields (strings, bytes, messages).
  static const int lengthDelimitedType = 2;

  Object? _last(int number, int wireType) {
    for (var i = fields.length - 1; i >= 0; i--) {
      final field = fields[i];
      if (field.number == number && field.wireType == wireType) return field.value;
    }
    return null;
  }

  /// The last varint of [number] as a 64-bit two's complement `int`, or null
  /// when there is none.
  ///
  /// A protobuf `uint64` has no Dart equivalent, so a value at or above 2^63
  /// arrives negative; [unsigned] spells it out when one has to be shown or
  /// compared as an identifier.
  int? integer(int number) => _last(number, varintType) as int?;

  /// Whether the bool [number] is true.
  ///
  /// A proto3 bool is a varint, and a generated runtime only looks at the low
  /// 32 bits, so a sender that stuffed a larger number into the field still
  /// reads as false exactly as it did there.
  bool flag(int number) => ((integer(number) ?? 0) & 0xFFFFFFFF) != 0;

  /// The last length-delimited value of [number], as a view of the bytes being
  /// decoded — a caller that keeps it copies it first.
  ///
  /// This is the accessor for an opaque payload: AcFun's command bodies and
  /// signal payloads are handed on as bytes and decoded only once their type
  /// name says what they are.
  Uint8List? bytes(int number) => _last(number, lengthDelimitedType) as Uint8List?;

  /// The last value of [number] as UTF-8 text.
  ///
  /// Malformed bytes are replaced rather than thrown: a nickname the sender
  /// truncated mid-codepoint is still a readable nickname.
  String? string(int number) {
    final value = bytes(number);
    return value == null ? null : utf8.decode(value, allowMalformed: true);
  }

  /// The singular message [number]: every occurrence merged, or null when
  /// there is none.
  ///
  /// A repeated field packed into one message, or a sender that sent the same
  /// singular field twice, both mean one message whose bytes are the
  /// concatenation — which is why merging happens on the bytes, not on the
  /// already-decoded fields.
  AcfunProtoMessage? message(int number) {
    final parts = [
      for (final field in fields)
        if (field.number == number && field.wireType == lengthDelimitedType) field.value as Uint8List,
    ];
    if (parts.isEmpty) return null;
    return AcfunProtoMessage.decode(parts.length == 1 ? parts.single : [for (final part in parts) ...part]);
  }

  /// The repeated message [number], one entry per occurrence.
  ///
  /// Unlike [message] this never merges: AcFun's signal lists and comment
  /// batches are genuinely repeated, and folding two gifts into one would
  /// invent an event nobody sent.
  List<AcfunProtoMessage> messages(int number) => [
    for (final field in fields)
      if (field.number == number && field.wireType == lengthDelimitedType)
        AcfunProtoMessage.decode(field.value as Uint8List),
  ];

  /// [value], a uint64 read into a 64-bit `int`, as unsigned decimal.
  static String unsigned(int value) => value >= 0 ? '$value' : BigInt.from(value).toUnsigned(64).toString();
}

/// Consumes protobuf wire bytes; every read either moves forward or throws.
///
/// A single cursor over one buffer, with no bounds checks beyond the ones the
/// wire format needs, because the whole message is already in memory and a
/// frame that runs past its end is a corrupt frame, not a short read.
final class _AcfunProtoReader {
  _AcfunProtoReader(this.data);

  final Uint8List data;
  int offset = 0;

  bool get atEnd => offset >= data.length;

  /// A base-128 varint, at most ten bytes so it cannot overflow a 64-bit `int`.
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

  /// A field number and wire type; a tag is only ever 32 bits wide, and field
  /// number 0 belongs to no schema, so both end the message for a generated
  /// runtime and for this one.
  (int, int) tag() {
    final tag = varint() & 0xFFFFFFFF;
    final number = tag >>> 3;
    if (number == 0) throw const FormatException('Protobuf field number 0');
    return (number, tag & 7);
  }

  /// The next [length] bytes.
  Uint8List take(int length) {
    if (length < 0 || length > data.length - offset) throw const FormatException('Truncated protobuf field');
    final value = Uint8List.sublistView(data, offset, offset + length);
    offset += length;
    return value;
  }

  /// The payload of the field just tagged, in the shape its wire type implies.
  Object value(int number, int wireType) => switch (wireType) {
    AcfunProtoMessage.varintType => varint(),
    _fixed64 => ByteData.sublistView(take(8)).getInt64(0, Endian.little),
    // Lengths are read as signed 32-bit values, as a generated runtime does.
    AcfunProtoMessage.lengthDelimitedType => take(varint().toSigned(32)),
    _startGroup => _skipGroup(number),
    _fixed32 => ByteData.sublistView(take(4)).getUint32(0, Endian.little),
    _ => throw FormatException('Unsupported protobuf wire type $wireType'),
  };

  /// Skips the fields of group [number] up to its end; the group reads as an
  /// empty value.
  ///
  /// Groups are a legacy encoding AcFun never sends, so the only honest thing
  /// to do with one is move past it — which still needs to walk its contents,
  /// because their lengths are the only way to find where the group ends.
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
///
/// There is no schema to validate against, so the order and the numbers are
/// the caller's responsibility — AcFun's bodies are written the same way the
/// generated classes of the reference client were filled in.
final class AcfunProtoWriter {
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
  ///
  /// Writing the two's complement rather than rejecting the negative is what
  /// lets a uid or a timestamp that arrived through [AcfunProtoMessage.integer]
  /// be echoed back unchanged.
  void integer(int number, int value) {
    _varint(number << 3 | AcfunProtoMessage.varintType);
    _varint(value);
  }

  /// A length-delimited field.
  ///
  /// An empty [value] still writes its tag and a zero length, because a field
  /// set to nothing and a field that was never set are different messages to a
  /// generated runtime, and AcFun's answers are read by one.
  void bytes(int number, List<int> value) {
    _varint(number << 3 | AcfunProtoMessage.lengthDelimitedType);
    _varint(value.length);
    _out.add(value);
  }

  /// A UTF-8 string field.
  void string(int number, String value) => bytes(number, utf8.encode(value));

  /// The message written so far.
  Uint8List toBytes() => _out.toBytes();
}
