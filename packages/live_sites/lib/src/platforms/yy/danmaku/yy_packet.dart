import 'dart:convert';
import 'dart:typed_data';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bounded little-endian reader of YY's H5 packets (3.x `YyProtocolReader`,
/// legacy/lib/core/utils/yy/yy_protocol.dart).
///
/// A packet starts with a 10-byte header: `u32` length (itself included),
/// `u32` uri, `u16` response code. Strings are a `u16` byte count and bytes
/// (Latin-1 or UTF-8); UCS-2 strings a `u32` byte count and UTF-16LE. Every
/// read past the end throws [FormatException].
final class YyPacketReader {
  /// Reads [bytes]; with [hasHeader] the header comes first, and a length
  /// below 10 or past the end of [bytes] throws [FormatException].
  YyPacketReader(Uint8List bytes, {bool hasHeader = false}) : _bytes = bytes, _data = ByteData.sublistView(bytes) {
    if (!hasHeader) return;
    packetLength = readUint32();
    uri = readUint32();
    responseCode = readUint16();
    if (packetLength < 10 || packetLength > bytes.length) {
      throw FormatException('YY packet length $packetLength exceeds ${bytes.length} bytes');
    }
  }

  final Uint8List _bytes;
  final ByteData _data;

  /// Where the next read starts.
  int offset = 0;

  /// The header's length; 0 without a header.
  int packetLength = 0;

  /// The header's uri; 0 without a header.
  int uri = 0;

  /// The header's response code; 0 without a header.
  int responseCode = 0;

  /// Bytes left after [offset].
  int get bytesAvailable => _bytes.length - offset;

  void _require(int length) {
    if (length < 0 || offset + length > _bytes.length) {
      throw FormatException('YY packet is truncated at $offset: need $length, available $bytesAvailable');
    }
  }

  /// An unsigned byte.
  int readUint8() {
    _require(1);
    return _data.getUint8(offset++);
  }

  /// An unsigned 16-bit number.
  int readUint16() {
    _require(2);
    final value = _data.getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  /// An unsigned 32-bit number.
  int readUint32() {
    _require(4);
    final value = _data.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  /// A 64-bit number: low word, then high word (the bits of an unsigned
  /// value; 3.x used `BigInt`, every value seen fits 63 bits).
  int readUint64() {
    final low = readUint32();
    final high = readUint32();
    return low | (high << 32);
  }

  /// [length] bytes (a view, not a copy).
  Uint8List readBytes(int length) {
    _require(length);
    final value = Uint8List.sublistView(_bytes, offset, offset + length);
    offset += length;
    return value;
  }

  /// Bytes after a `u16` count.
  Uint8List readByteArray() => readBytes(readUint16());

  /// Bytes after a `u32` count.
  Uint8List readByteArray32() => readBytes(readUint32());

  /// A Latin-1 string after a `u16` count.
  String readString() => String.fromCharCodes(readByteArray());

  /// A UTF-8 string after a `u16` count; malformed bytes become U+FFFD.
  String readUtf8String() => utf8.decode(readByteArray(), allowMalformed: true);

  /// A UTF-16LE string after a `u32` byte count; an odd last byte is
  /// ignored.
  String readUcs2String32() {
    final bytes = readByteArray32();
    final data = ByteData.sublistView(bytes);
    return String.fromCharCodes([
      for (var index = 0; index + 1 < bytes.length; index += 2) data.getUint16(index, Endian.little),
    ]);
  }
}

/// Little-endian writer of YY's H5 packets (3.x `YyProtocolWriter`, the web
/// client's `PMarshall`). With a uri the packet header comes first, and
/// [takeBytes] fills in the length.
final class YyPacketWriter {
  /// Starts a packet of [uri] (response code 200), or bare fields without.
  YyPacketWriter({int? uri}) : _uri = uri {
    if (uri == null) return;
    writeUint32(10);
    writeUint32(uri);
    writeUint16(200);
  }

  final BytesBuilder _builder = BytesBuilder(copy: false);
  final int? _uri;

  /// The low 8 bits of [value].
  void writeUint8(int value) => _builder.addByte(value & 0xff);

  /// The low 16 bits of [value].
  void writeUint16(int value) {
    _builder.add((ByteData(2)..setUint16(0, value & 0xffff, Endian.little)).buffer.asUint8List());
  }

  /// The low 32 bits of [value].
  void writeUint32(int value) {
    _builder.add((ByteData(4)..setUint32(0, value & 0xffffffff, Endian.little)).buffer.asUint8List());
  }

  /// [value] as low word, then high word.
  void writeUint64(int value) {
    writeUint32(value & 0xffffffff);
    writeUint32((value >> 32) & 0xffffffff);
  }

  /// [bytes] as they are.
  void writeBytes(List<int> bytes) => _builder.add(bytes);

  /// [bytes] after a `u16` count.
  void writeByteArray(List<int> bytes) {
    writeUint16(bytes.length);
    writeBytes(bytes);
  }

  /// [bytes] after a `u32` count.
  void writeByteArray32(List<int> bytes) {
    writeUint32(bytes.length);
    writeBytes(bytes);
  }

  /// [value]'s code units, 8 bits each, after a `u16` count (3.x; every
  /// string the client writes is ASCII).
  void writeString(String value) => writeByteArray([for (final unit in value.codeUnits) unit & 0xff]);

  /// [value] in UTF-8 after a `u16` count.
  void writeUtf8String(String value) => writeByteArray(utf8.encode(value));

  /// [value] in UTF-16LE after a `u32` byte count.
  void writeUcs2String32(String value) {
    final data = ByteData(value.length * 2);
    for (var index = 0; index < value.length; index++) {
      data.setUint16(index * 2, value.codeUnitAt(index), Endian.little);
    }
    writeByteArray32(data.buffer.asUint8List());
  }

  /// The packet; with a uri its length is filled in.
  Uint8List takeBytes() {
    final bytes = _builder.takeBytes();
    if (_uri != null) ByteData.sublistView(bytes).setUint32(0, bytes.length, Endian.little);
    return bytes;
  }
}
