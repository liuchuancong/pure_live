import 'dart:convert';
import 'dart:typed_data';

class AcfunProtoWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  void integer(int field, int value) {
    _tag(field, 0);
    _varint(value);
  }

  void boolean(int field, bool value) => integer(field, value ? 1 : 0);

  void string(int field, String value) => bytes(field, utf8.encode(value));

  void bytes(int field, List<int> value) {
    _tag(field, 2);
    _varint(value.length);
    _out.add(value);
  }

  void message(int field, AcfunProtoWriter value) => bytes(field, value.toBytes());

  Uint8List toBytes() => _out.toBytes();

  void _tag(int field, int wire) => _varint((field << 3) | wire);

  void _varint(int value) {
    var rest = value;
    if (rest < 0) {
      for (var i = 0; i < 9; i++) {
        _out.addByte((rest & 0x7f) | 0x80);
        rest = rest >> 7;
      }
      _out.addByte(rest & 0x01);
      return;
    }
    while (rest >= 0x80) {
      _out.addByte((rest & 0x7f) | 0x80);
      rest = rest >> 7;
    }
    _out.addByte(rest);
  }
}

class AcfunProtoMessage {
  AcfunProtoMessage._(this._values);

  final Map<int, Object> _values;

  static AcfunProtoMessage decode(List<int> data) {
    final values = <int, Object>{};
    var index = 0;
    while (index < data.length) {
      final tag = _readVarint(data, index);
      if (tag == null) break;
      index = tag.next;
      final field = tag.value >> 3;
      final wire = tag.value & 0x07;
      switch (wire) {
        case 0:
          final value = _readVarint(data, index);
          if (value == null) return AcfunProtoMessage._(values);
          index = value.next;
          values[field] = value.value;
          break;
        case 1:
          if (index + 8 > data.length) return AcfunProtoMessage._(values);
          values[field] = data.sublist(index, index + 8);
          index += 8;
          break;
        case 2:
          final length = _readVarint(data, index);
          if (length == null) return AcfunProtoMessage._(values);
          index = length.next;
          final end = index + length.value;
          if (length.value < 0 || end > data.length) return AcfunProtoMessage._(values);
          final chunk = data.sublist(index, end);
          final existing = values[field];
          if (existing is List<Object>) {
            existing.add(Uint8List.fromList(chunk));
          } else if (existing == null) {
            values[field] = <Object>[Uint8List.fromList(chunk)];
          } else {
            values[field] = <Object>[existing, Uint8List.fromList(chunk)];
          }
          index = end;
          break;
        case 5:
          if (index + 4 > data.length) return AcfunProtoMessage._(values);
          values[field] = data.sublist(index, index + 4);
          index += 4;
          break;
        default:
          return AcfunProtoMessage._(values);
      }
    }
    return AcfunProtoMessage._(values);
  }

  int? integer(int field) {
    final value = _values[field];
    return value is int ? value : null;
  }

  bool? boolean(int field) => switch (integer(field)) {
    null => null,
    0 => false,
    _ => true,
  };

  String? string(int field) {
    final value = _values[field];
    if (value is! List<Object> || value.isEmpty) return null;
    final last = value.last;
    if (last is! Uint8List) return null;
    try {
      return utf8.decode(last);
    } on FormatException {
      return null;
    }
  }

  Uint8List? bytes(int field) {
    final value = _values[field];
    if (value is! List<Object> || value.isEmpty) return null;
    final last = value.last;
    return last is Uint8List ? last : null;
  }

  List<Uint8List> chunks(int field) {
    final value = _values[field];
    if (value is! List<Object>) return const <Uint8List>[];
    return value.whereType<Uint8List>().toList(growable: false);
  }

  List<AcfunProtoMessage> messages(int field) =>
      chunks(field).map(AcfunProtoMessage.decode).toList(growable: false);

  AcfunProtoMessage? message(int field) {
    final all = chunks(field);
    return all.isEmpty ? null : AcfunProtoMessage.decode(all.first);
  }

  static ({int value, int next})? _readVarint(List<int> data, int start) {
    var result = 0;
    var shift = 0;
    var index = start;
    while (index < data.length) {
      final byte = data[index++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return (value: result, next: index);
      shift += 7;
      if (shift > 63) return null;
    }
    return null;
  }
}
