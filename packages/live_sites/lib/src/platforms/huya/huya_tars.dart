/// The minimal Tars binary codec huya's WebSocket danmaku protocol needs,
/// in pure Dart (no `tars` dependency).
///
/// A WS frame is a bare Tars structure — no length prefix (unlike the WUP
/// HTTP packets, which huya's play-token RPC would use and which are not
/// needed here). [TarsWriter] writes the smallest integer type that holds a
/// value (0 as a zero tag), strings as `string1` up to 255 UTF-8 bytes and
/// byte arrays as simple lists; [TarsStruct] decodes a structure without a
/// schema, addressing fields by tag. Malformed input is a [FormatException].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

// These value wrappers spell their class name in the constructor; the
// shorthand would read as a method declaration at the call site.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Tars wire types (the `TarsStructType` byte a head's low nibble carries).
abstract final class TarsType {
  /// A one-byte signed integer.
  static const int8 = 0;

  /// A two-byte signed integer.
  static const int16 = 1;

  /// A four-byte signed integer.
  static const int32 = 2;

  /// An eight-byte signed integer.
  static const int64 = 3;

  /// A four-byte float.
  static const float32 = 4;

  /// An eight-byte float.
  static const float64 = 5;

  /// A string up to 255 bytes.
  static const string1 = 6;

  /// A string up to 2^31 bytes.
  static const string4 = 7;

  /// A map.
  static const map = 8;

  /// A list.
  static const list = 9;

  /// A nested structure begins.
  static const structBegin = 10;

  /// A nested structure ends.
  static const structEnd = 11;

  /// An integer field whose value is 0 (no body).
  static const zero = 12;

  /// A simple list (a byte array).
  static const simpleList = 13;
}

/// Writes Tars fields byte for byte: integers in the smallest type that
/// holds them (0 as a zero tag), strings as `string1` up to 255 UTF-8 bytes,
/// byte arrays as simple lists.
final class TarsWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  void _head(int type, int tag) {
    if (tag < 0 || tag > 255) throw ArgumentError.value(tag, 'tag', 'out of range');
    if (tag < 15) {
      _out.addByte(tag << 4 | type);
    } else {
      _out
        ..addByte(0xF0 | type)
        ..addByte(tag);
    }
  }

  /// An integer field, in the smallest type that holds [value].
  void writeInt(int tag, int value) {
    if (value == 0) {
      _head(TarsType.zero, tag);
    } else if (value >= -128 && value <= 127) {
      _head(TarsType.int8, tag);
      _out.addByte(value & 0xFF);
    } else if (value >= -32768 && value <= 32767) {
      _head(TarsType.int16, tag);
      _out.add((ByteData(2)..setInt16(0, value)).buffer.asUint8List());
    } else if (value >= -2147483648 && value <= 2147483647) {
      _head(TarsType.int32, tag);
      _out.add((ByteData(4)..setInt32(0, value)).buffer.asUint8List());
    } else {
      _head(TarsType.int64, tag);
      _out.add((ByteData(8)..setInt64(0, value)).buffer.asUint8List());
    }
  }

  /// A boolean field (an integer 0 or 1).
  void writeBool(int tag, {required bool value}) => writeInt(tag, value ? 1 : 0);

  /// A double field (`float64`).
  void writeDouble(int tag, double value) {
    _head(TarsType.float64, tag);
    _out.add((ByteData(8)..setFloat64(0, value)).buffer.asUint8List());
  }

  /// A UTF-8 string field.
  void writeString(int tag, String value) {
    final bytes = utf8.encode(value);
    if (bytes.length > 255) {
      _head(TarsType.string4, tag);
      _out.add((ByteData(4)..setInt32(0, bytes.length)).buffer.asUint8List());
    } else {
      _head(TarsType.string1, tag);
      _out.addByte(bytes.length);
    }
    _out.add(bytes);
  }

  /// A byte array field (a simple list of bytes).
  void writeBytes(int tag, List<int> value) {
    _head(TarsType.simpleList, tag);
    _head(TarsType.int8, 0);
    writeInt(0, value.length);
    _out.add(value);
  }

  /// A list whose elements [element] writes, each at tag 0.
  void writeList<T>(int tag, List<T> items, void Function(TarsWriter writer, T item) element) {
    _head(TarsType.list, tag);
    writeInt(0, items.length);
    for (final item in items) {
      element(this, item);
    }
  }

  /// A map; [key] writes each key at tag 0 and [value] each value at tag 1.
  void writeMap<K, V>(
    int tag,
    Map<K, V> map, {
    required void Function(TarsWriter writer, K key) key,
    required void Function(TarsWriter writer, V value) value,
  }) {
    _head(TarsType.map, tag);
    writeInt(0, map.length);
    for (final MapEntry(key: k, value: v) in map.entries) {
      key(this, k);
      value(this, v);
    }
  }

  /// A nested structure whose fields [fields] writes.
  void writeStruct(int tag, void Function(TarsWriter writer) fields) {
    _head(TarsType.structBegin, tag);
    fields(this);
    _head(TarsType.structEnd, 0);
  }

  /// Any decoded value (see [TarsStruct]); null writes nothing.
  void writeValue(int tag, Object? value) {
    switch (value) {
      case null:
        break;
      case final bool flag:
        writeBool(tag, value: flag);
      case final int number:
        writeInt(tag, number);
      case final double number:
        writeDouble(tag, number);
      case final String text:
        writeString(tag, text);
      case final Uint8List bytes:
        writeBytes(tag, bytes);
      case final TarsStruct nested:
        writeStruct(tag, (writer) => nested.fields.forEach(writer.writeValue));
      case final List<Object?> items:
        writeList<Object?>(tag, items, (writer, item) => writer.writeValue(0, item));
      case final Map<Object?, Object?> map:
        writeMap<Object?, Object?>(
          tag,
          map,
          key: (writer, key) => writer.writeValue(0, key),
          value: (writer, value) => writer.writeValue(1, value),
        );
      default:
        throw ArgumentError.value(value, 'value', 'not a Tars value');
    }
  }

  /// The bytes written so far.
  Uint8List toBytes() => _out.toBytes();
}

/// A Tars structure decoded without a schema: values by tag. Integers are
/// `int`, floats `double`, strings `String`, simple lists [Uint8List], lists
/// `List<Object?>`, maps `Map<Object?, Object?>` and nested structures
/// [TarsStruct].
@immutable
final class TarsStruct {
  /// Wraps [fields].
  const TarsStruct(this.fields);

  /// Decodes the fields of [bytes] up to their end.
  factory TarsStruct.decode(List<int> bytes) => _TarsReader(bytes).fields(0);

  /// Field values by tag, in wire order.
  final Map<int, Object?> fields;

  /// The integer at [tag], or null.
  int? integer(int tag) => switch (fields[tag]) {
    final int value => value,
    _ => null,
  };

  /// The string at [tag], or null.
  String? string(int tag) => switch (fields[tag]) {
    final String value => value,
    _ => null,
  };

  /// The byte array at [tag] (a simple list, or a list of byte-sized
  /// integers), or null.
  Uint8List? bytes(int tag) => asBytes(fields[tag]);

  /// The structure at [tag], or null.
  TarsStruct? struct(int tag) => switch (fields[tag]) {
    final TarsStruct value => value,
    _ => null,
  };

  /// The list at [tag], or empty.
  List<Object?> list(int tag) => switch (fields[tag]) {
    final List<Object?> value => value,
    _ => const [],
  };

  /// The map at [tag], or null.
  Map<Object?, Object?>? map(int tag) => switch (fields[tag]) {
    final Map<Object?, Object?> value => value,
    _ => null,
  };

  /// Encodes the fields back in their order.
  Uint8List encode() {
    final writer = TarsWriter();
    fields.forEach(writer.writeValue);
    return writer.toBytes();
  }

  /// [value] as bytes: a simple list, or a list of integers from -128 to
  /// 255 (some writers send byte arrays as plain lists); else null.
  static Uint8List? asBytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List && value.every((item) => item is int && item >= -128 && item <= 255)) {
      return Uint8List.fromList([for (final item in value) (item as int) & 0xFF]);
    }
    return null;
  }

  @override
  String toString() => 'TarsStruct(${fields.keys.join(', ')})';
}

final class _TarsReader {
  _TarsReader(List<int> bytes) : _data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final Uint8List _data;
  int _position = 0;

  static const _maxDepth = 32;

  Never _fail(String reason) => throw FormatException('Tars: $reason', null, _position);

  int _byte() {
    if (_position >= _data.length) _fail('unexpected end');
    return _data[_position++];
  }

  ByteData _take(int length) {
    if (length < 0 || _position + length > _data.length) _fail('length $length beyond the data');
    final view = ByteData.sublistView(_data, _position, _position + length);
    _position += length;
    return view;
  }

  (int, int) _head() {
    final first = _byte();
    final type = first & 0x0F;
    var tag = first >> 4;
    if (tag == 15) tag = _byte();
    return (type, tag);
  }

  /// Fields until the end of the data (top level) or a structure end.
  TarsStruct fields(int depth) {
    if (depth > _maxDepth) _fail('nested too deep');
    final fields = <int, Object?>{};
    while (_position < _data.length) {
      final (type, tag) = _head();
      if (type == TarsType.structEnd) {
        if (depth == 0) _fail('structure end at the top level');
        return TarsStruct(fields);
      }
      fields[tag] = _value(type, depth);
    }
    if (depth > 0) _fail('unterminated structure');
    return TarsStruct(fields);
  }

  /// A container size: every element takes at least one byte.
  int _size() {
    final (type, _) = _head();
    final size = _integer(type);
    if (size < 0 || size > _data.length - _position) _fail('size $size');
    return size;
  }

  int _integer(int type) => switch (type) {
    TarsType.zero => 0,
    TarsType.int8 => _take(1).getInt8(0),
    TarsType.int16 => _take(2).getInt16(0),
    TarsType.int32 => _take(4).getInt32(0),
    TarsType.int64 => _take(8).getInt64(0),
    _ => _fail('type $type is not an integer'),
  };

  Object? _value(int type, int depth) {
    switch (type) {
      case TarsType.zero || TarsType.int8 || TarsType.int16 || TarsType.int32 || TarsType.int64:
        return _integer(type);
      case TarsType.float32:
        return _take(4).getFloat32(0);
      case TarsType.float64:
        return _take(8).getFloat64(0);
      case TarsType.string1:
        return _string(_byte());
      case TarsType.string4:
        return _string(_take(4).getInt32(0));
      case TarsType.map:
        final size = _size();
        final map = <Object?, Object?>{};
        for (var i = 0; i < size; i++) {
          final key = _element(depth);
          map[key] = _element(depth);
        }
        return map;
      case TarsType.list:
        final size = _size();
        return <Object?>[for (var i = 0; i < size; i++) _element(depth)];
      case TarsType.simpleList:
        final (elementType, _) = _head();
        if (elementType != TarsType.int8) _fail('simple list of type $elementType');
        final view = _take(_size());
        return Uint8List.fromList(Uint8List.sublistView(view));
      case TarsType.structBegin:
        return fields(depth + 1);
      default:
        _fail('unknown type $type');
    }
  }

  /// A container element. Its tag is 0 (key, list item) or 1 (value) on the
  /// wire; the tag itself is not checked.
  Object? _element(int depth) {
    final (type, _) = _head();
    if (type == TarsType.structEnd) _fail('structure end inside a container');
    return _value(type, depth);
  }

  String _string(int length) => utf8.decode(Uint8List.sublistView(_take(length)), allowMalformed: true);
}
