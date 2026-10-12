/// The Tars binary codec and its TUP3 packet, used by Huya's danmaku protocol
/// (the reference's 3.x `pkg/tars`). Internal to this package: site decoders
/// import it directly rather than through the barrel.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Tars wire types.
abstract final class _Type {
  static const int int8 = 0;
  static const int int16 = 1;
  static const int int32 = 2;
  static const int int64 = 3;
  static const int float32 = 4;
  static const int float64 = 5;
  static const int string1 = 6;
  static const int string4 = 7;
  static const int map = 8;
  static const int list = 9;
  static const int structBegin = 10;
  static const int structEnd = 11;
  static const int zero = 12;
  static const int simpleList = 13;
}

/// Writes Tars fields byte for byte: integers in the smallest type that holds
/// them (0 as a zero tag), strings as `string1` up to 255 UTF-8 bytes, byte
/// arrays as simple lists.
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

  /// An integer field.
  void writeInt(int tag, int value) {
    if (value == 0) {
      _head(_Type.zero, tag);
    } else if (value >= -128 && value <= 127) {
      _head(_Type.int8, tag);
      _out.addByte(value & 0xFF);
    } else if (value >= -32768 && value <= 32767) {
      _head(_Type.int16, tag);
      _out.add((ByteData(2)..setInt16(0, value)).buffer.asUint8List());
    } else if (value >= -2147483648 && value <= 2147483647) {
      _head(_Type.int32, tag);
      _out.add((ByteData(4)..setInt32(0, value)).buffer.asUint8List());
    } else {
      _head(_Type.int64, tag);
      _out.add((ByteData(8)..setInt64(0, value)).buffer.asUint8List());
    }
  }

  /// A boolean field (an integer 0 or 1).
  void writeBool(int tag, {required bool value}) => writeInt(tag, value ? 1 : 0);

  /// A double field (`float64`).
  void writeDouble(int tag, double value) {
    _head(_Type.float64, tag);
    _out.add((ByteData(8)..setFloat64(0, value)).buffer.asUint8List());
  }

  /// A UTF-8 string field.
  void writeString(int tag, String value) {
    final bytes = utf8.encode(value);
    if (bytes.length > 255) {
      _head(_Type.string4, tag);
      _out.add((ByteData(4)..setInt32(0, bytes.length)).buffer.asUint8List());
    } else {
      _head(_Type.string1, tag);
      _out.addByte(bytes.length);
    }
    _out.add(bytes);
  }

  /// A byte array field (a simple list of bytes).
  void writeBytes(int tag, List<int> value) {
    _head(_Type.simpleList, tag);
    _head(_Type.int8, 0);
    writeInt(0, value.length);
    _out.add(value);
  }

  /// A list whose elements [element] writes, each at tag 0.
  void writeList<T>(int tag, List<T> items, void Function(TarsWriter writer, T item) element) {
    _head(_Type.list, tag);
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
    _head(_Type.map, tag);
    writeInt(0, map.length);
    for (final MapEntry(key: k, value: v) in map.entries) {
      key(this, k);
      value(this, v);
    }
  }

  /// A nested structure whose fields [fields] writes.
  void writeStruct(int tag, void Function(TarsWriter writer) fields) {
    _head(_Type.structBegin, tag);
    fields(this);
    _head(_Type.structEnd, 0);
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
///
/// Malformed input is a [FormatException] and `int8` is signed, as Tars defines
/// it (unlike 3.x's reader, which swallowed errors and read `int8` unsigned).
@immutable
final class TarsStruct {
  /// Wraps [fields].
  const new(this.fields);

  /// Decodes the fields of [bytes] up to their end.
  factory decode(List<int> bytes) => _TarsReader(bytes).fields(0);

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

  /// [value] as bytes: a simple list, or a list of integers from -128 to 255
  /// (some writers send byte arrays as plain lists); else null.
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
  new(List<int> bytes) : _data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final Uint8List _data;
  int _position = 0;

  static const int _maxDepth = 32;

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
      if (type == _Type.structEnd) {
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
    _Type.zero => 0,
    _Type.int8 => _take(1).getInt8(0),
    _Type.int16 => _take(2).getInt16(0),
    _Type.int32 => _take(4).getInt32(0),
    _Type.int64 => _take(8).getInt64(0),
    _ => _fail('type $type is not an integer'),
  };

  Object? _value(int type, int depth) {
    switch (type) {
      case _Type.zero || _Type.int8 || _Type.int16 || _Type.int32 || _Type.int64:
        return _integer(type);
      case _Type.float32:
        return _take(4).getFloat32(0);
      case _Type.float64:
        return _take(8).getFloat64(0);
      case _Type.string1:
        return _string(_byte());
      case _Type.string4:
        return _string(_take(4).getInt32(0));
      case _Type.map:
        final size = _size();
        final map = <Object?, Object?>{};
        for (var i = 0; i < size; i++) {
          final key = _element(depth);
          map[key] = _element(depth);
        }
        return map;
      case _Type.list:
        final size = _size();
        return <Object?>[for (var i = 0; i < size; i++) _element(depth)];
      case _Type.simpleList:
        final (elementType, _) = _head();
        if (elementType != _Type.int8) _fail('simple list of type $elementType');
        final view = _take(_size());
        return Uint8List.fromList(Uint8List.sublistView(view));
      case _Type.structBegin:
        return fields(depth + 1);
      default:
        _fail('unknown type $type');
    }
  }

  /// A container element. Its tag is 0 (key, list item) or 1 (value) on the
  /// wire; the tag itself is not checked, as 3.x's reader did.
  Object? _element(int depth) {
    final (type, _) = _head();
    if (type == _Type.structEnd) _fail('structure end inside a container');
    return _value(type, depth);
  }

  String _string(int length) => utf8.decode(Uint8List.sublistView(_take(length)), allowMalformed: true);
}

/// One TUP3 packet: the RPC envelope of a WUP call over HTTP and of some
/// danmaku frames.
@immutable
final class WupPacket {
  /// Creates a packet; [params] maps a parameter name to its encoded value
  /// (one Tars field at tag 0).
  const new({required this.servant, required this.function, required this.params, this.requestId = 0});

  /// Decodes a packet: a 4-byte big-endian length (itself included), the
  /// `RequestPacket` fields, and the parameter map in `sBuffer` (tag 7). A
  /// packet that is not TUP3 is a [FormatException].
  factory decode(List<int> bytes) {
    if (bytes.length < 4) throw const FormatException('WUP: shorter than its length prefix');
    final packet = TarsStruct.decode(bytes.sublist(4));
    final version = packet.integer(1);
    if (version != 3) throw FormatException('WUP: version $version, expected TUP3');
    final buffer = packet.bytes(7);
    if (buffer == null) throw const FormatException('WUP: no sBuffer');
    final raw = TarsStruct.decode(buffer).map(0);
    if (raw == null) throw const FormatException('WUP: sBuffer is not a map');
    final params = <String, Uint8List>{};
    for (final MapEntry(:key, :value) in raw.entries) {
      final bytes = TarsStruct.asBytes(value);
      if (key is! String || bytes == null) throw const FormatException('WUP: a parameter is not name → bytes');
      params[key] = bytes;
    }
    return WupPacket(
      servant: packet.string(5) ?? '',
      function: packet.string(6) ?? '',
      params: params,
      requestId: packet.integer(4) ?? 0,
    );
  }

  /// Servant (`liveui`).
  final String servant;

  /// Function (`getCdnTokenInfoEx`).
  final String function;

  /// Parameters by name, each one Tars field at tag 0. Requests carry `tReq`;
  /// responses carry the return code in `""` and the result in `tRsp`.
  final Map<String, List<int>> params;

  /// Request id; Huya's calls use 0.
  final int requestId;

  /// A parameter holding a structure at tag 0.
  static Uint8List structParam(void Function(TarsWriter writer) fields) =>
      (TarsWriter()..writeStruct(0, fields)).toBytes();

  /// A parameter holding an integer at tag 0.
  static Uint8List intParam(int value) => (TarsWriter()..writeInt(0, value)).toBytes();

  /// The return code (the integer parameter `""`); 0 when absent.
  int get code {
    final bytes = params[''];
    return bytes == null ? 0 : TarsStruct.decode(bytes).integer(0) ?? 0;
  }

  /// The structure in parameter [name], or null when there is none.
  TarsStruct? struct(String name) {
    final bytes = params[name];
    return bytes == null ? null : TarsStruct.decode(bytes).struct(0);
  }

  /// Encodes the packet: version 3, a normal call, no timeout, empty context
  /// and status.
  Uint8List encode() {
    final buffer = TarsWriter()
      ..writeMap<String, List<int>>(
        0,
        params,
        key: (writer, key) => writer.writeString(0, key),
        value: (writer, value) => writer.writeBytes(1, value),
      );
    void empty(TarsWriter writer, int tag) => writer.writeMap<String, String>(
      tag,
      const {},
      key: (writer, key) => writer.writeString(0, key),
      value: (writer, value) => writer.writeString(1, value),
    );
    final body = TarsWriter()
      ..writeInt(1, 3)
      ..writeInt(2, 0)
      ..writeInt(3, 0)
      ..writeInt(4, requestId)
      ..writeString(5, servant)
      ..writeString(6, function)
      ..writeBytes(7, buffer.toBytes())
      ..writeInt(8, 0);
    empty(body, 9);
    empty(body, 10);
    final bytes = body.toBytes();
    return (BytesBuilder(copy: false)
          ..add((ByteData(4)..setInt32(0, bytes.length + 4)).buffer.asUint8List())
          ..add(bytes))
        .toBytes();
  }

  @override
  String toString() => 'WupPacket($servant.$function)';
}
